// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if compiler(>=6.4)
  import Foundation
  import Synchronization

  extension LanguageModelSession {
    // MARK: - Internal Core Respond Implementation

    /// Runs a synchronous multi-turn conversation loop and returns the completed response.
    @discardableResult
    nonisolated(nonsending) internal final func performRespond<Content: Generable>(
      to prompt: Prompt,
      schema: GenerationSchema?,
      options: GenerationOptions,
      contextOptions: ContextOptions,
      metadata: [String: any ConvertibleToGeneratedContent],
      convert: (GeneratedContent) throws -> Content
    ) async throws -> LanguageModelSession.Response<Content> {
      // 1. Check concurrent requests. Both outcomes write `isResponding`, so observers are notified
      // either way, like Apple's session.
      var (preCallTranscript, preCallMutationCount, preCallReentrantCount) = try mutateState(
        notifying: \.isResponding
      ) { state -> (Transcript, UInt64, UInt64) in
        if state.isResponding {
          // Rejecting a call also clears `isResponding`, as Apple's framework does, so a later
          // call is admitted even while the first one is still running.
          state.isResponding = false
          throw LanguageModelSession.Error.concurrentRequests
        }
        state.isResponding = true
        return (state.transcript, state.externalMutationCount, state.reentrantMutationCount)
      }

      defer {
        setResponding(false)
      }

      await awaitPendingInitialActivation()

      var config = await resolveConfigurationAndHandleSwitch()
      var effectiveOptions = config.effectiveGenerationOptions(perCall: options)
      var effectiveContextOptions = config.effectiveContextOptions(perCall: contextOptions)
      if let policyOverride = config.transcriptErrorHandlingPolicyOverride {
        state.withLock { $0.transcriptErrorHandlingPolicy = policyOverride }
      }

      // 2. Validate capabilities before creating executor or modifying transcript
      try validateCapabilities(
        modelBox: config.modelBox,
        tools: config.tools,
        prompt: prompt,
        transcript: preCallTranscript,
        options: effectiveOptions,
        contextOptions: effectiveContextOptions,
        schema: schema
      )

      // 3. Build and append the prompt entry
      let responseFormat: Transcript.ResponseFormat? =
        if let schema, effectiveContextOptions.includeSchemaInPrompt != false {
          Transcript.ResponseFormat(schema: schema)
        } else {
          nil
        }
      let promptEntry = Transcript.Prompt(
        id: UUID().uuidString,
        metadata: metadata,
        segments: prompt.segments,
        options: effectiveOptions,
        responseFormat: responseFormat,
        contextOptions: effectiveContextOptions
      )

      try await validateDataCapabilities(
        modelBox: config.modelBox,
        prompt: promptEntry,
        transcript: preCallTranscript
      )

      let generationID = GenerationID()
      let requestID = UUID()
      let metadataValues: [String: GeneratedContent] = metadata.mapValues(\.generatedContent)

      var promptIndex: Int
      let rawContent: GeneratedContent
      let finalTranscript: Transcript
      let lastTurnUsage: LanguageModelSession.Usage

      // Every transcript write below checks `externalMutationCount` under the same lock as the
      // write, and the final read checks it too. Observers run synchronously in `willSet`, between
      // any earlier check and the write, so an observer that writes `session.transcript` from
      // `onChange` is detected as a mutation instead of being overwritten.
      do {
        promptIndex = try withCheckedTranscript(since: preCallMutationCount) { transcript in
          if !config.isStatic {
            _ = Self.applyDynamicInstructions(from: config, to: &transcript)
          }
          transcript.append(.prompt(promptEntry))
          return transcript.count - 1
        }
        if !config.isStatic {
          let current = state.withLock { $0.transcript }
          Self.syncLeadingInstructions(from: current, to: &preCallTranscript)
        }

        if !config.onPromptHooks.isEmpty {
          try await SessionPropertyValues.$isInHistoryWriteScope.withValue(true) {
            for hook in config.onPromptHooks {
              try await hook(promptEntry)
            }
          }
          try Task.checkCancellation()
          promptIndex = state.withLock { max(0, $0.transcript.count - 1) }
        }

        // 4. Multi-turn tool loop
        var isFirstTurn = true
        while true {
          try Task.checkCancellation()

          if !isFirstTurn && !config.isStatic {
            config = await resolveConfigurationAndHandleSwitch()
            effectiveOptions = config.effectiveGenerationOptions(perCall: options)
            effectiveContextOptions = config.effectiveContextOptions(perCall: contextOptions)
            if let policyOverride = config.transcriptErrorHandlingPolicyOverride {
              state.withLock { $0.transcriptErrorHandlingPolicy = policyOverride }
            }
            let currentForValidation = state.withLock { $0.transcript }
            try validateCapabilities(
              modelBox: config.modelBox,
              tools: config.tools,
              prompt: prompt,
              transcript: currentForValidation,
              options: effectiveOptions,
              contextOptions: effectiveContextOptions,
              schema: schema
            )
            try await validateDataCapabilities(
              modelBox: config.modelBox,
              transcript: currentForValidation
            )
            let didInsertLeading = state.withLock { state -> Bool in
              let inserted = Self.applyDynamicInstructions(from: config, to: &state.transcript)
              Self.syncLeadingInstructions(from: state.transcript, to: &preCallTranscript)
              return inserted
            }
            if didInsertLeading {
              promptIndex += 1
            }
          }
          isFirstTurn = false

          let currentTranscript = state.withLock { $0.transcript }
          var requestTranscript = currentTranscript
          if !config.historyTransforms.isEmpty {
            var entries = Array(currentTranscript)
            for transform in config.historyTransforms {
              entries = transform(entries)
            }
            requestTranscript = Transcript(entries: entries)
          }
          let request = buildGenerationRequest(
            id: requestID,
            transcript: requestTranscript,
            tools: config.tools,
            options: effectiveOptions,
            contextOptions: effectiveContextOptions,
            schema: schema,
            metadata: metadataValues
          )

          let channel = LanguageModelExecutorGenerationChannel()
          let collectedEvents = SendableEventBox()
          let activeModelBox = config.modelBox

          let executorTask = Task {
            do {
              try await activeModelBox.respond(to: request, streamingInto: channel)
              channel.finish()
            } catch {
              channel.finish()
              throw error
            }
          }

          try await withTaskCancellationHandler {
            for try await event in channel {
              if Task.isCancelled || collectedEvents.isCancelled {
                channel.cancel()
                executorTask.cancel()
                break
              }
              collectedEvents.append(event)
            }
          } onCancel: {
            collectedEvents.markCancelled()
            channel.cancel()
            executorTask.cancel()
          }

          // On caller task cancellation, do not await `executorTask.value` so an uncooperative
          // executor cannot block cancellation.
          if Task.isCancelled || collectedEvents.isCancelled {
            channel.cancel()
            executorTask.cancel()
            var cancelledTranscript = state.withLock { $0.transcript }
            var cancelledReducer = TurnReducer(schema: schema, generationID: generationID)
            for event in collectedEvents.events {
              _ = try? cancelledReducer.apply(event, to: &cancelledTranscript)
            }
            try commitCancelledTurn(
              cancelledTranscript,
              events: collectedEvents.events,
              schema: schema,
              generationID: generationID,
              since: (preCallMutationCount, preCallReentrantCount)
            )
            throw CancellationError()
          }

          do {
            try await executorTask.value
          } catch {
            if Task.isCancelled || collectedEvents.isCancelled {
              var cancelledTranscript = state.withLock { $0.transcript }
              var cancelledReducer = TurnReducer(schema: schema, generationID: generationID)
              for event in collectedEvents.events {
                _ = try? cancelledReducer.apply(event, to: &cancelledTranscript)
              }
              try commitCancelledTurn(
                cancelledTranscript,
                events: collectedEvents.events,
                schema: schema,
                generationID: generationID,
                since: (preCallMutationCount, preCallReentrantCount)
              )
              throw CancellationError()
            }
            // When the executor throws on its own (including `CancellationError`), partial events
            // from the failed turn are discarded even under `.preserveTranscript`.
            throw error
          }

          // Early exit if external code mutated session.transcript while the turn was running, so
          // the mutation error wins over event errors; the locked check in the commit is what counts.
          let mutatedExternally = state.withLock {
            $0.externalMutationCount != preCallMutationCount
          }
          if mutatedExternally {
            // Like Apple, keep the external write and append this turn's events to it; under
            // `.revertTranscript` the catch below reverts afterwards.
            try mergeEventsAfterExternalWrite(
              collectedEvents.events,
              schema: schema,
              generationID: generationID,
              reentrantMutationCount: preCallReentrantCount,
              propagatingErrors: false
            )
            throw LanguageModelSession.Error.transcriptMutationWhileResponding
          }

          // Apply buffered events for this turn to a working copy first so failed turns in `respond`
          // do not leave partial entries behind under `.preserveTranscript`.
          var workingTranscript = state.withLock { $0.transcript }
          var reducer = TurnReducer(schema: schema, generationID: generationID)
          for event in collectedEvents.events {
            _ = try reducer.apply(event, to: &workingTranscript)
          }

          // Turn succeeded: commit working transcript and run lifecycle hooks
          do {
            try setCheckedTranscript(workingTranscript, since: preCallMutationCount)
          } catch {
            try mergeEventsAfterExternalWrite(
              collectedEvents.events,
              schema: schema,
              generationID: generationID,
              reentrantMutationCount: preCallReentrantCount,
              propagatingErrors: false
            )
            throw error
          }

          if !config.onReasoningHooks.isEmpty {
            try await SessionPropertyValues.$isInHistoryWriteScope.withValue(true) {
              for index in reducer.createdReasoningEntryIndices
              where index < workingTranscript.count {
                if case .reasoning(let reasoningEntry) = workingTranscript[index] {
                  for hook in config.onReasoningHooks {
                    try await hook(reasoningEntry)
                  }
                }
              }
            }
            try Task.checkCancellation()
          }

          // Check for tool calls created in this turn
          var usageAdded = false
          if !reducer.createdToolCallsEntryIndices.isEmpty {
            addSessionUsage(reducer.usage)
            usageAdded = true
            if let toolCallOutputs = try await executeTurnToolCalls(
              createdIndices: reducer.createdToolCallsEntryIndices,
              in: workingTranscript,
              tools: config.tools,
              onToolCallHooks: config.onToolCallHooks
            ) {
              // Early exit only; the checked tool-output appends below are what count.
              let mutatedDuringTools = state.withLock {
                $0.externalMutationCount != preCallMutationCount
              }
              if mutatedDuringTools {
                throw LanguageModelSession.Error.transcriptMutationWhileResponding
              }
              // Append each output separately: Apple's session notifies `transcript` observers once
              // per tool output.
              for (call, output) in toolCallOutputs {
                // The `onToolOutput` hooks run before the output is appended, as with Apple's
                // framework, so they see the transcript without it.
                if !config.onToolOutputHooks.isEmpty {
                  try await SessionPropertyValues.$isInHistoryWriteScope.withValue(true) {
                    for hook in config.onToolOutputHooks {
                      try await hook(call, output)
                    }
                  }
                  try Task.checkCancellation()
                }
                try withCheckedTranscript(since: preCallMutationCount) { transcript in
                  transcript.append(.toolOutput(output))
                }
              }
              continue
            }
          }

          // No tool calls in this turn: resolve final response.
          if let firstResponseIdx = reducer.createdResponseEntryIndices.first,
            promptIndex >= firstResponseIdx
          {
            promptIndex = max(0, firstResponseIdx - 1)
          }
          // The turn's response is read from the transcript as the turn left it, so an
          // `onReasoning` hook that rewrites the history doesn't drop it, as with Apple's framework.
          // The checked read catches an external mutation during the `onReasoning` hooks.
          _ = try checkedTranscript(since: preCallMutationCount)
          if !config.onResponseHooks.isEmpty {
            if let responseEntry = Self.extractFinalResponseEntry(
              from: workingTranscript,
              afterPromptIndex: promptIndex
            ) {
              try await SessionPropertyValues.$isInHistoryWriteScope.withValue(true) {
                for hook in config.onResponseHooks {
                  try await hook(responseEntry)
                }
              }
            }
            try Task.checkCancellation()
          }
          if !usageAdded {
            addSessionUsage(reducer.usage)
          }
          // The checked read catches an observer write from the commit's `usage` notification or an
          // external mutation during `onResponse`.
          finalTranscript = try checkedTranscript(since: preCallMutationCount)
          rawContent = try Self.extractRawResponseContent(
            from: workingTranscript,
            afterPromptIndex: promptIndex,
            schema: schema,
            generationID: generationID
          )
          lastTurnUsage = reducer.usage
          break
        }
      } catch {
        if shouldRevert(after: error, reentrantMutationCount: preCallReentrantCount) {
          revertTranscript(to: preCallTranscript)
        }
        throw error
      }

      // Note: Conversion to the Swift type runs AFTER the transcript is committed.
      // If `convert(rawContent)` throws (e.g. missing required property on valid JSON),
      // the transcript is NOT reverted!
      return try Self.buildResponse(
        rawContent: rawContent,
        transcriptEntries: Self.callEntries(
          in: finalTranscript, promptID: promptEntry.id, preCallTranscript: preCallTranscript),
        usage: lastTurnUsage,
        convert: convert
      )
    }

    /// Commits the partial events of a cancelled turn.
    ///
    /// If the transcript was written externally since the call started, this matches Apple's
    /// `respond`: the mutation wins over the cancellation. The partial events are merged onto the
    /// written transcript and `transcriptMutationWhileResponding` is thrown, so the caller's
    /// error-handling policy reverts (`.revertTranscript`) or keeps the merge
    /// (`.preserveTranscript`). Streams differ: there cancellation wins.
    ///
    /// - Parameters:
    ///   - transcript: The transcript read before cancellation, with the turn's partial events
    ///     applied.
    ///   - events: The turn's partial events.
    ///   - schema: The call's generation schema, if any.
    ///   - generationID: The call's generation identifier.
    ///   - counts: The `externalMutationCount` and `reentrantMutationCount` captured when the call
    ///     started.
    /// - Throws: `transcriptMutationWhileResponding` if the transcript was written externally.
    private func commitCancelledTurn(
      _ transcript: Transcript,
      events: [LanguageModelExecutorGenerationChannel.Event],
      schema: GenerationSchema?,
      generationID: GenerationID,
      since counts: (mutation: UInt64, reentrant: UInt64)
    ) throws {
      // Check first, so an external write costs one notification (the merge), as in Apple's
      // session, rather than a failed commit plus the merge.
      let unchanged = state.withLock { $0.externalMutationCount == counts.mutation }
      if unchanged {
        do {
          try setCheckedTranscript(transcript, since: counts.mutation)
          return
        } catch {
          // An observer of the commit's notification wrote; handled below.
        }
      }
      try mergeEventsAfterExternalWrite(
        events,
        schema: schema,
        generationID: generationID,
        reentrantMutationCount: counts.reentrant,
        propagatingErrors: false
      )
      throw LanguageModelSession.Error.transcriptMutationWhileResponding
    }

    /// Converts raw response content and constructs a `Response` value.
    private static func buildResponse<Content: Generable>(
      rawContent: GeneratedContent,
      transcriptEntries: ArraySlice<Transcript.Entry>,
      usage: LanguageModelSession.Usage,
      convert: (GeneratedContent) throws -> Content
    ) throws -> LanguageModelSession.Response<Content> {
      let content = try convert(rawContent)
      return LanguageModelSession.Response(
        content: content,
        rawContent: rawContent,
        transcriptEntries: transcriptEntries,
        usage: usage
      )
    }

    /// Returns the entries of `transcript` that a call added after its prompt.
    ///
    /// Profile hooks can rewrite the history during a call, so the prompt is looked up by ID. If a
    /// hook removed it, the call's entries are those that weren't in the transcript before the call.
    ///
    /// - Parameters:
    ///   - transcript: The transcript at the end of the call.
    ///   - promptID: The ID of the call's prompt entry.
    ///   - preCallTranscript: The transcript before the call.
    /// - Returns: The call's entries, in transcript order.
    internal static func callEntries(
      in transcript: Transcript,
      promptID: String,
      preCallTranscript: Transcript
    ) -> ArraySlice<Transcript.Entry> {
      let entries = Array(transcript)
      if let promptIndex = entries.lastIndex(where: { entry in
        if case .prompt = entry { return entry.id == promptID }
        return false
      }) {
        return entries[(promptIndex + 1)...]
      }
      let preCallIDs = Set(preCallTranscript.map(\.id))
      return entries.filter { entry in
        if case .instructions = entry { return false }
        return !preCallIDs.contains(entry.id)
      }[...]
    }
  }

  /// Thread-safe buffer for collecting channel events during a non-streaming executor turn.
  private final class SendableEventBox: Sendable {
    /// Mutable state guarded by `state`.
    private struct State: Sendable {
      /// Buffered channel events received before cancellation.
      var storage: [LanguageModelExecutorGenerationChannel.Event] = []

      /// Whether task cancellation has occurred.
      var cancelled: Bool = false
    }

    /// Mutex protecting `State`.
    private let state = Mutex(State())

    /// Appends an event if the box has not been marked cancelled.
    func append(_ event: LanguageModelExecutorGenerationChannel.Event) {
      state.withLock { state in
        if !state.cancelled {
          state.storage.append(event)
        }
      }
    }

    /// Marks the event buffer as cancelled, freezing further appends.
    func markCancelled() {
      state.withLock { $0.cancelled = true }
    }

    /// Whether the event buffer was marked cancelled.
    var isCancelled: Bool {
      state.withLock { $0.cancelled }
    }

    /// Snapshot of all events buffered prior to cancellation.
    var events: [LanguageModelExecutorGenerationChannel.Event] {
      state.withLock { $0.storage }
    }
  }

  // MARK: - Public Respond Overloads (Legacy 9)

  extension LanguageModelSession {
    /// Generates a string response for a prompt.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to respond to.
    ///   - options: Options controlling generation.
    /// - Returns: A response containing the generated text.
    /// - Throws: An error if generation fails.
    @discardableResult
    nonisolated(nonsending) public final func respond(
      to prompt: Prompt,
      options: GenerationOptions = GenerationOptions()
    ) async throws -> LanguageModelSession.Response<String> {
      try await respond(
        to: prompt,
        options: options,
        contextOptions: ContextOptions(),
        metadata: [:]
      )
    }

    /// Generates a string response for a text prompt.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to respond to.
    ///   - options: Options controlling generation.
    /// - Returns: A response containing the generated text.
    /// - Throws: An error if generation fails.
    @discardableResult
    @_disfavoredOverload
    nonisolated(nonsending) public final func respond(
      to prompt: String,
      options: GenerationOptions = GenerationOptions()
    ) async throws -> LanguageModelSession.Response<String> {
      try await respond(
        to: Prompt(prompt),
        options: options,
        contextOptions: ContextOptions(),
        metadata: [:]
      )
    }

    /// Generates a string response using a prompt builder.
    ///
    /// - Parameters:
    ///   - options: Options controlling generation.
    ///   - prompt: A closure building the prompt.
    /// - Returns: A response containing the generated text.
    /// - Throws: An error if generation fails or prompt building throws.
    @discardableResult
    nonisolated(nonsending) public final func respond(
      options: GenerationOptions = GenerationOptions(),
      @PromptBuilder prompt: () throws -> Prompt
    ) async throws -> LanguageModelSession.Response<String> {
      try await respond(
        to: try prompt(),
        options: options,
        contextOptions: ContextOptions(),
        metadata: [:]
      )
    }

    /// Generates structured content adhering to a schema for a prompt.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to respond to.
    ///   - schema: The schema guiding generation.
    ///   - includeSchemaInPrompt: Whether to include the schema description in the prompt.
    ///   - options: Options controlling generation.
    /// - Returns: A response containing the generated structured content.
    /// - Throws: An error if generation fails.
    @discardableResult
    nonisolated(nonsending) public final func respond(
      to prompt: Prompt,
      schema: GenerationSchema,
      includeSchemaInPrompt: Bool = true,
      options: GenerationOptions = GenerationOptions()
    ) async throws -> LanguageModelSession.Response<GeneratedContent> {
      try await respond(
        to: prompt,
        schema: schema,
        options: options,
        contextOptions: ContextOptions(includeSchemaInPrompt: includeSchemaInPrompt),
        metadata: [:]
      )
    }

    /// Generates structured content adhering to a schema for a text prompt.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to respond to.
    ///   - schema: The schema guiding generation.
    ///   - includeSchemaInPrompt: Whether to include the schema description in the prompt.
    ///   - options: Options controlling generation.
    /// - Returns: A response containing the generated structured content.
    /// - Throws: An error if generation fails.
    @discardableResult
    @_disfavoredOverload
    nonisolated(nonsending) public final func respond(
      to prompt: String,
      schema: GenerationSchema,
      includeSchemaInPrompt: Bool = true,
      options: GenerationOptions = GenerationOptions()
    ) async throws -> LanguageModelSession.Response<GeneratedContent> {
      try await respond(
        to: Prompt(prompt),
        schema: schema,
        options: options,
        contextOptions: ContextOptions(includeSchemaInPrompt: includeSchemaInPrompt),
        metadata: [:]
      )
    }

    /// Generates structured content adhering to a schema using a prompt builder.
    ///
    /// - Parameters:
    ///   - schema: The schema guiding generation.
    ///   - includeSchemaInPrompt: Whether to include the schema description in the prompt.
    ///   - options: Options controlling generation.
    ///   - prompt: A closure building the prompt.
    /// - Returns: A response containing the generated structured content.
    /// - Throws: An error if generation fails or prompt building throws.
    @discardableResult
    nonisolated(nonsending) public final func respond(
      schema: GenerationSchema,
      includeSchemaInPrompt: Bool = true,
      options: GenerationOptions = GenerationOptions(),
      @PromptBuilder prompt: () throws -> Prompt
    ) async throws -> LanguageModelSession.Response<GeneratedContent> {
      try await respond(
        to: try prompt(),
        schema: schema,
        options: options,
        contextOptions: ContextOptions(includeSchemaInPrompt: includeSchemaInPrompt),
        metadata: [:]
      )
    }

    /// Generates a strongly typed value for a prompt.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to respond to.
    ///   - type: The expected type of the generated value.
    ///   - includeSchemaInPrompt: Whether to include the schema description in the prompt.
    ///   - options: Options controlling generation.
    /// - Returns: A response containing the generated value.
    /// - Throws: An error if generation or conversion fails.
    @discardableResult
    nonisolated(nonsending) public final func respond<Content>(
      to prompt: Prompt,
      generating type: Content.Type = Content.self,
      includeSchemaInPrompt: Bool = true,
      options: GenerationOptions = GenerationOptions()
    ) async throws -> LanguageModelSession.Response<Content> where Content: Generable {
      try await respond(
        to: prompt,
        generating: type,
        options: options,
        contextOptions: ContextOptions(includeSchemaInPrompt: includeSchemaInPrompt),
        metadata: [:]
      )
    }

    /// Generates a strongly typed value for a text prompt.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to respond to.
    ///   - type: The expected type of the generated value.
    ///   - includeSchemaInPrompt: Whether to include the schema description in the prompt.
    ///   - options: Options controlling generation.
    /// - Returns: A response containing the generated value.
    /// - Throws: An error if generation or conversion fails.
    @discardableResult
    @_disfavoredOverload
    nonisolated(nonsending) public final func respond<Content>(
      to prompt: String,
      generating type: Content.Type = Content.self,
      includeSchemaInPrompt: Bool = true,
      options: GenerationOptions = GenerationOptions()
    ) async throws -> LanguageModelSession.Response<Content> where Content: Generable {
      try await respond(
        to: Prompt(prompt),
        generating: type,
        options: options,
        contextOptions: ContextOptions(includeSchemaInPrompt: includeSchemaInPrompt),
        metadata: [:]
      )
    }

    /// Generates a strongly typed value using a prompt builder.
    ///
    /// - Parameters:
    ///   - type: The expected type of the generated value.
    ///   - includeSchemaInPrompt: Whether to include the schema description in the prompt.
    ///   - options: Options controlling generation.
    ///   - prompt: A closure building the prompt.
    /// - Returns: A response containing the generated value.
    /// - Throws: An error if generation or conversion fails.
    @discardableResult
    nonisolated(nonsending) public final func respond<Content>(
      generating type: Content.Type = Content.self,
      includeSchemaInPrompt: Bool = true,
      options: GenerationOptions = GenerationOptions(),
      @PromptBuilder prompt: () throws -> Prompt
    ) async throws -> LanguageModelSession.Response<Content> where Content: Generable {
      try await respond(
        to: try prompt(),
        generating: type,
        options: options,
        contextOptions: ContextOptions(includeSchemaInPrompt: includeSchemaInPrompt),
        metadata: [:]
      )
    }
  }

  // MARK: - Public Respond Overloads (With ContextOptions & Metadata 9)

  extension LanguageModelSession {
    /// Generates a string response for a prompt with context options and metadata.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to respond to.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    /// - Returns: A response containing the generated text.
    /// - Throws: An error if generation fails.
    @discardableResult
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func respond(
      to prompt: Prompt,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(),
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) async throws -> LanguageModelSession.Response<String> {
      try await performRespond(
        to: prompt,
        schema: nil,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      ) { rawContent in
        try String(rawContent)
      }
    }

    /// Generates a string response for a text prompt with context options and metadata.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to respond to.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    /// - Returns: A response containing the generated text.
    /// - Throws: An error if generation fails.
    @discardableResult
    @_disfavoredOverload
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func respond(
      to prompt: String,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(),
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) async throws -> LanguageModelSession.Response<String> {
      try await respond(
        to: Prompt(prompt),
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }

    /// Generates a string response using a prompt builder with context options and metadata.
    ///
    /// - Parameters:
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    ///   - prompt: A closure building the prompt.
    /// - Returns: A response containing the generated text.
    /// - Throws: An error if generation fails or prompt building throws.
    @discardableResult
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func respond(
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(),
      metadata: [String: any ConvertibleToGeneratedContent] = [:],
      @PromptBuilder prompt: () throws -> Prompt
    ) async throws -> LanguageModelSession.Response<String> {
      try await respond(
        to: try prompt(),
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }

    /// Generates structured content for a prompt with context options and metadata.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to respond to.
    ///   - schema: The schema guiding generation.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    /// - Returns: A response containing the generated structured content.
    /// - Throws: An error if generation fails.
    @discardableResult
    @_disfavoredOverload
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func respond(
      to prompt: Prompt,
      schema: GenerationSchema,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) async throws -> LanguageModelSession.Response<GeneratedContent> {
      try await performRespond(
        to: prompt,
        schema: schema,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      ) { rawContent in
        rawContent
      }
    }

    /// Generates structured content for a text prompt with context options and metadata.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to respond to.
    ///   - schema: The schema guiding generation.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    /// - Returns: A response containing the generated structured content.
    /// - Throws: An error if generation fails.
    @discardableResult
    @_disfavoredOverload
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func respond(
      to prompt: String,
      schema: GenerationSchema,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) async throws -> LanguageModelSession.Response<GeneratedContent> {
      try await respond(
        to: Prompt(prompt),
        schema: schema,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }

    /// Generates structured content using a prompt builder with context options and metadata.
    ///
    /// - Parameters:
    ///   - schema: The schema guiding generation.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    ///   - prompt: A closure building the prompt.
    /// - Returns: A response containing the generated structured content.
    /// - Throws: An error if generation fails or prompt building throws.
    @discardableResult
    @_disfavoredOverload
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func respond(
      schema: GenerationSchema,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
      metadata: [String: any ConvertibleToGeneratedContent] = [:],
      @PromptBuilder prompt: () throws -> Prompt
    ) async throws -> LanguageModelSession.Response<GeneratedContent> {
      try await respond(
        to: try prompt(),
        schema: schema,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }

    /// Generates a strongly typed value for a prompt with context options and metadata.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to respond to.
    ///   - type: The expected type of the generated value.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    /// - Returns: A response containing the generated value.
    /// - Throws: An error if generation or conversion fails.
    @discardableResult
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func respond<Content>(
      to prompt: Prompt,
      generating type: Content.Type = Content.self,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) async throws -> LanguageModelSession.Response<Content> where Content: Generable {
      let schema: GenerationSchema? = (Content.self == String.self) ? nil : Content.generationSchema
      return try await performRespond(
        to: prompt,
        schema: schema,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      ) { rawContent in
        try Content(rawContent)
      }
    }

    /// Generates a strongly typed value for a text prompt with context options and metadata.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to respond to.
    ///   - type: The expected type of the generated value.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    /// - Returns: A response containing the generated value.
    /// - Throws: An error if generation or conversion fails.
    @discardableResult
    @_disfavoredOverload
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func respond<Content>(
      to prompt: String,
      generating type: Content.Type = Content.self,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) async throws -> LanguageModelSession.Response<Content> where Content: Generable {
      try await respond(
        to: Prompt(prompt),
        generating: type,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }

    /// Generates a strongly typed value using a prompt builder with context options and metadata.
    ///
    /// - Parameters:
    ///   - type: The expected type of the generated value.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    ///   - prompt: A closure building the prompt.
    /// - Returns: A response containing the generated value.
    /// - Throws: An error if generation or conversion fails.
    @discardableResult
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func respond<Content>(
      generating type: Content.Type = Content.self,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
      metadata: [String: any ConvertibleToGeneratedContent] = [:],
      @PromptBuilder prompt: () throws -> Prompt
    ) async throws -> LanguageModelSession.Response<Content> where Content: Generable {
      try await respond(
        to: try prompt(),
        generating: type,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }
  }
#endif  // compiler(>=6.4)
