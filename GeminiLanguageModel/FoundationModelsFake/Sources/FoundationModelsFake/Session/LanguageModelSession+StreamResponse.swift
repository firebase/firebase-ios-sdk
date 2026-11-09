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
    // MARK: - Internal Core StreamResponse Implementation

    /// Runs a streaming multi-turn conversation loop and returns a response stream.
    internal final func performStreamResponse<Content: Generable>(
      to prompt: Prompt,
      schema: GenerationSchema?,
      options: GenerationOptions,
      contextOptions: ContextOptions,
      metadata: [String: any ConvertibleToGeneratedContent],
      convertPartial: @escaping @Sendable (GeneratedContent) throws -> Content.PartiallyGenerated,
      convertFinal: @escaping @Sendable (GeneratedContent) throws -> Content
    ) -> sending LanguageModelSession.ResponseStream<Content> {
      // 1. Check concurrent requests synchronously. Both outcomes write `isResponding`, so observers
      // are notified either way, like Apple's session.
      let preflightResult: Result<(Transcript, UInt64, UInt64), any Swift.Error> = mutateState(
        notifying: \.isResponding
      ) { state in
        if state.isResponding {
          // Rejecting a call also clears `isResponding`, as Apple's framework does, so a later
          // call is admitted even while the first one is still running.
          state.isResponding = false
          return .failure(LanguageModelSession.Error.concurrentRequests)
        }
        state.isResponding = true
        return .success(
          (state.transcript, state.externalMutationCount, state.reentrantMutationCount)
        )
      }

      let (preCallTranscript, preCallMutationCount, preCallReentrantCount):
        (Transcript, UInt64, UInt64)
      switch preflightResult {
      case .failure(let error):
        return ResponseStream(throwing: error)
      case .success(let values):
        (preCallTranscript, preCallMutationCount, preCallReentrantCount) = values
      }

      let initialConfig = resolveConfiguration()
      let effectiveOptions = initialConfig.effectiveGenerationOptions(perCall: options)
      let effectiveContextOptions = initialConfig.effectiveContextOptions(perCall: contextOptions)
      if let policyOverride = initialConfig.transcriptErrorHandlingPolicyOverride {
        state.withLock { $0.transcriptErrorHandlingPolicy = policyOverride }
      }

      // 2. Validate capabilities before creating executor or modifying transcript
      do {
        try validateCapabilities(
          modelBox: initialConfig.modelBox,
          tools: initialConfig.tools,
          prompt: prompt,
          transcript: preCallTranscript,
          options: effectiveOptions,
          contextOptions: effectiveContextOptions,
          schema: schema
        )
      } catch {
        setResponding(false)
        return ResponseStream(throwing: error)
      }

      // 3. Build and append the prompt entry synchronously before returning the stream
      let responseFormat: Transcript.ResponseFormat? =
        if let schema, effectiveContextOptions.includeSchemaInPrompt != false {
          Transcript.ResponseFormat(schema: schema)
        } else {
          nil
        }
      let metadataValues: [String: GeneratedContent] = metadata.mapValues(\.generatedContent)
      let promptEntry = Transcript.Prompt(
        id: UUID().uuidString,
        metadata: metadataValues,
        segments: prompt.segments,
        options: effectiveOptions,
        responseFormat: responseFormat,
        contextOptions: effectiveContextOptions
      )

      // Every transcript write below checks `externalMutationCount` under the same lock as the
      // write, and the final reads check it too. Observers run synchronously in `willSet`, between
      // any earlier check and the write, so an observer that writes `session.transcript` from
      // `onChange` is detected as a mutation instead of being overwritten.
      var mutablePreCallTranscript = preCallTranscript
      let initialPromptIndex: Int
      do {
        initialPromptIndex = try withCheckedTranscript(since: preCallMutationCount) { transcript in
          if !initialConfig.isStatic {
            _ = Self.applyDynamicInstructions(from: initialConfig, to: &transcript)
          }
          transcript.append(.prompt(promptEntry))
          return transcript.count - 1
        }
        if !initialConfig.isStatic {
          let current = state.withLock { $0.transcript }
          Self.syncLeadingInstructions(from: current, to: &mutablePreCallTranscript)
        }
      } catch {
        // A write between the preflight and the append gets here: an observer writing from the
        // prompt's `willSet` (always reverted) or a write from another thread (the policy decides).
        if shouldRevert(after: error, reentrantMutationCount: preCallReentrantCount) {
          revertTranscript(to: mutablePreCallTranscript)
        }
        setResponding(false)
        return ResponseStream(throwing: error)
      }

      let controller = StreamController<Content>()
      let generationID = GenerationID()
      let requestID = UUID()
      let revertSnapshot = mutablePreCallTranscript

      let driverTask = Task<Void, Never> {
        var ownsRespondingFlag = true
        func releaseResponding() {
          guard ownsRespondingFlag else { return }
          ownsRespondingFlag = false
          self.setResponding(false)
        }
        defer {
          releaseResponding()
        }

        var transcriptCommitted = false
        var config = initialConfig
        var turnOptions = effectiveOptions
        var turnContextOptions = effectiveContextOptions
        var promptIndex = initialPromptIndex
        var revertTargetTranscript = revertSnapshot
        var isFirstTurn = true

        do {
          await self.awaitPendingInitialActivation()
          await self.runProfileTransitionIfNeeded(for: config)
          try await self.validateDataCapabilities(
            modelBox: config.modelBox,
            prompt: promptEntry,
            transcript: revertTargetTranscript
          )
          if !config.onPromptHooks.isEmpty {
            try await SessionPropertyValues.$isInHistoryWriteScope.withValue(true) {
              for hook in config.onPromptHooks {
                try await hook(promptEntry)
              }
            }
            if Task.isCancelled || controller.wasCancelledByConsumer {
              throw CancellationError()
            }
            promptIndex = self.state.withLock { max(0, $0.transcript.count - 1) }
          }

          while true {
            if Task.isCancelled || controller.wasCancelledByConsumer {
              throw CancellationError()
            }

            if !isFirstTurn && !config.isStatic {
              config = await self.resolveConfigurationAndHandleSwitch()
              turnOptions = config.effectiveGenerationOptions(perCall: options)
              turnContextOptions = config.effectiveContextOptions(perCall: contextOptions)
              if let policyOverride = config.transcriptErrorHandlingPolicyOverride {
                self.state.withLock { $0.transcriptErrorHandlingPolicy = policyOverride }
              }
              let currentForValidation = self.state.withLock { $0.transcript }
              try self.validateCapabilities(
                modelBox: config.modelBox,
                tools: config.tools,
                prompt: prompt,
                transcript: currentForValidation,
                options: turnOptions,
                contextOptions: turnContextOptions,
                schema: schema
              )
              try await self.validateDataCapabilities(
                modelBox: config.modelBox,
                transcript: currentForValidation
              )
              let didInsertLeading = self.state.withLock { state -> Bool in
                let inserted = Self.applyDynamicInstructions(from: config, to: &state.transcript)
                Self.syncLeadingInstructions(from: state.transcript, to: &revertTargetTranscript)
                return inserted
              }
              if didInsertLeading {
                promptIndex += 1
              }
            }
            isFirstTurn = false

            let currentTranscript = self.state.withLock { $0.transcript }
            var requestTranscript = currentTranscript
            if !config.historyTransforms.isEmpty {
              var entries = Array(currentTranscript)
              for transform in config.historyTransforms {
                entries = transform(entries)
              }
              requestTranscript = Transcript(entries: entries)
            }
            let request = self.buildGenerationRequest(
              id: requestID,
              transcript: requestTranscript,
              tools: config.tools,
              options: turnOptions,
              contextOptions: turnContextOptions,
              schema: schema,
              metadata: metadataValues
            )

            let channel = LanguageModelExecutorGenerationChannel()
            var reducer = TurnReducer(schema: schema, generationID: generationID)
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

            var eventProcessingError: (any Swift.Error)? = nil
            var deferredSnapshots: [ResponseStream<Content>.Snapshot] = []

            do {
              for try await event in channel {
                if Task.isCancelled || controller.wasCancelledByConsumer {
                  channel.cancel()
                  executorTask.cancel()
                  break
                }
                do {
                  // The check runs under the same lock as `apply`, after this event's `willSet`, so
                  // the reducer never applies its indices to a transcript an observer replaced.
                  let shouldYield: Bool
                  do {
                    shouldYield = try self.withCheckedTranscript(since: preCallMutationCount) {
                      transcript in
                      try reducer.apply(event, to: &transcript)
                    }
                  } catch LanguageModelSession.Error.transcriptMutationWhileResponding {
                    // Like Apple, apply this event with a fresh reducer to the external write, then
                    // fail; if the event doesn't apply on its own (for example a partial JSON
                    // fragment), its error is thrown instead.
                    try self.mergeEventsAfterExternalWrite(
                      [event],
                      schema: schema,
                      generationID: generationID,
                      reentrantMutationCount: preCallReentrantCount,
                      propagatingErrors: true
                    )
                    throw LanguageModelSession.Error.transcriptMutationWhileResponding
                  }
                  if shouldYield {
                    let (snapTranscript, mutatedBeforeSnapshot) = self.state.withLock {
                      ($0.transcript, $0.externalMutationCount != preCallMutationCount)
                    }
                    if mutatedBeforeSnapshot {
                      throw LanguageModelSession.Error.transcriptMutationWhileResponding
                    }
                    if let firstResponseIdx = reducer.createdResponseEntryIndices.first,
                      promptIndex >= firstResponseIdx
                    {
                      promptIndex = max(0, firstResponseIdx - 1)
                    }
                    let rawContent = try Self.extractRawResponseContent(
                      from: snapTranscript,
                      afterPromptIndex: promptIndex,
                      schema: schema,
                      generationID: generationID
                    )
                    let partialContent = try convertPartial(rawContent)
                    let sliceStart = min(max(0, promptIndex + 1), snapTranscript.count)
                    let entriesArray = Array(snapTranscript[sliceStart...])
                    let snapshot = ResponseStream<Content>.Snapshot(
                      content: partialContent,
                      rawContent: rawContent,
                      transcriptEntries: entriesArray[...],
                      usage: reducer.usage
                    )
                    if !config.onReasoningHooks.isEmpty
                      && !reducer.createdReasoningEntryIndices.isEmpty
                    {
                      deferredSnapshots.append(snapshot)
                    } else {
                      controller.yield(snapshot)
                    }
                  }
                } catch {
                  eventProcessingError = error
                  channel.cancel()
                  executorTask.cancel()
                  break
                }
              }
            } catch {
              eventProcessingError = error
              channel.cancel()
              executorTask.cancel()
            }

            if let eventProcessingError {
              // Don't wait for the cancelled executor: one that ignores cancellation would hang
              // the stream.
              throw eventProcessingError
            }

            if Task.isCancelled || controller.wasCancelledByConsumer {
              // Do not await `executorTask.value` on consumer cancellation: the session returns
              // immediately even if an uncooperative executor ignores cancellation.
              channel.cancel()
              executorTask.cancel()
              throw CancellationError()
            }

            do {
              try await executorTask.value
            } catch {
              if Task.isCancelled || controller.wasCancelledByConsumer {
                throw CancellationError()
              }
              // Non-cancellation executor error mid-stream (including an executor throwing
              // `CancellationError` on its own without consumer cancellation): usage from applied
              // events is kept.
              self.addSessionUsage(reducer.usage)
              throw error
            }

            if Task.isCancelled || controller.wasCancelledByConsumer {
              throw CancellationError()
            }

            // Early exit before the turn's usage is added; the checked reads below are what count.
            let mutatedExternally = self.state.withLock {
              $0.externalMutationCount != preCallMutationCount
            }
            if mutatedExternally {
              throw LanguageModelSession.Error.transcriptMutationWhileResponding
            }

            // Turn completed normally: commit turn usage. The events were already applied live, but
            // Apple's session also notifies `transcript` observers when a streamed turn completes.
            self.notifyObservers(of: \.transcript)
            self.addSessionUsage(reducer.usage)

            // The transcript as the turn left it, before the `onReasoning` hooks run. The turn's
            // tool calls and response are read from it, so a hook that rewrites the history doesn't
            // drop them, as with Apple's framework.
            var turnTranscript: Transcript? = nil
            if !config.onReasoningHooks.isEmpty {
              // Snapshots from a turn with reasoning are delivered after the `onReasoning` hooks
              // run, or after a short delay if a hook is still running. This keeps the observable
              // order: a slow `onReasoning` hook doesn't hold back the turn's snapshots.
              let flusher = OnceSnapshotFlusher(
                snapshots: deferredSnapshots, controller: controller)
              let flushTask = Task {
                try? await Task.sleep(for: .milliseconds(5))
                flusher.flush()
              }
              do {
                let currentForReasoning = try self.checkedTranscript(since: preCallMutationCount)
                turnTranscript = currentForReasoning
                try await SessionPropertyValues.$isInHistoryWriteScope.withValue(true) {
                  for index in reducer.createdReasoningEntryIndices
                  where index < currentForReasoning.count {
                    if case .reasoning(let reasoningEntry) = currentForReasoning[index] {
                      for hook in config.onReasoningHooks {
                        try await hook(reasoningEntry)
                      }
                    }
                  }
                }
                // Wait for the delayed flush to stop, so that snapshots it took are delivered
                // before the turn continues.
                flushTask.cancel()
                await flushTask.value
                flusher.flush()
              } catch {
                flushTask.cancel()
                await flushTask.value
                flusher.flush()
                throw error
              }
              if Task.isCancelled || controller.wasCancelledByConsumer {
                throw CancellationError()
              }
              // Hop through the main actor so the stream's consumer receives the flushed snapshots
              // before the `onResponse` hooks run.
              await Task { @MainActor in
                await Task.yield()
              }.value
            }

            // Check for tool calls created in this turn. The checked read catches an observer write
            // from the turn-end `transcript` or `usage` notification.
            let currentAfterTurn = try self.checkedTranscript(since: preCallMutationCount)
            if let toolCallOutputs = try await self.executeTurnToolCalls(
              createdIndices: reducer.createdToolCallsEntryIndices,
              in: turnTranscript ?? currentAfterTurn,
              tools: config.tools,
              onToolCallHooks: config.onToolCallHooks
            ) {
              // Early exit only; the checked tool-output appends below are what count.
              let mutatedDuringTools = self.state.withLock {
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
                  if Task.isCancelled || controller.wasCancelledByConsumer {
                    throw CancellationError()
                  }
                }
                try self.withCheckedTranscript(since: preCallMutationCount) { transcript in
                  transcript.append(.toolOutput(output))
                }
              }
              continue
            }

            // Final turn completed with no tool calls
            if let firstResponseIdx = reducer.createdResponseEntryIndices.first,
              promptIndex >= firstResponseIdx
            {
              promptIndex = max(0, firstResponseIdx - 1)
            }
            var finalTranscript = try self.checkedTranscript(since: preCallMutationCount)
            let responseTranscript = turnTranscript ?? finalTranscript
            let rawContent = try Self.extractRawResponseContent(
              from: responseTranscript,
              afterPromptIndex: promptIndex,
              schema: schema,
              generationID: generationID
            )
            if !config.onResponseHooks.isEmpty {
              if let responseEntry = Self.extractFinalResponseEntry(
                from: responseTranscript,
                afterPromptIndex: promptIndex
              ) {
                try await SessionPropertyValues.$isInHistoryWriteScope.withValue(true) {
                  for hook in config.onResponseHooks {
                    try await hook(responseEntry)
                  }
                }
              }
              if Task.isCancelled || controller.wasCancelledByConsumer {
                throw CancellationError()
              }
              finalTranscript = try self.checkedTranscript(since: preCallMutationCount)
            }

            // A turn without tool calls is the last one: from here on, releasing the stream no
            // longer cancels, and the response is committed.
            controller.markFinishing()
            transcriptCommitted = true

            // Build final completion snapshot and final response result before clearing
            // `isResponding` or waking any snapshot iterator / `collect()` waiter.
            let finalPartial = try convertPartial(rawContent)
            let finalEntries = Self.callEntries(
              in: finalTranscript, promptID: promptEntry.id, preCallTranscript: preCallTranscript)
            let finalSnapshot = ResponseStream<Content>.Snapshot(
              content: finalPartial,
              rawContent: rawContent,
              transcriptEntries: finalEntries,
              usage: reducer.usage
            )
            // With both `onReasoning` and `onResponse` hooks, the final snapshot is intentionally
            // delivered twice: once here and once when the stream completes, as with Apple's
            // framework.
            if !config.onReasoningHooks.isEmpty && !config.onResponseHooks.isEmpty {
              controller.yield(finalSnapshot)
            }
            let finalResult: Result<LanguageModelSession.Response<Content>, any Swift.Error>
            do {
              let finalContent = try convertFinal(rawContent)
              let finalResponse = LanguageModelSession.Response(
                content: finalContent,
                rawContent: rawContent,
                transcriptEntries: finalEntries,
                usage: reducer.usage
              )
              finalResult = .success(finalResponse)
            } catch {
              finalResult = .failure(error)
            }

            releaseResponding()
            controller.complete(finalSnapshot: finalSnapshot, result: finalResult)
            return
          }
        } catch {
          if !transcriptCommitted {
            // Apple's session notifies `transcript` observers when a consumer cancels a stream (or
            // releases it), even though the applied events are unchanged, before any revert below.
            // A tool that honors the cancellation surfaces it as `ToolCallError`, so the check is on
            // the consumer's cancellation rather than on the error's type.
            if Task.isCancelled || controller.wasCancelledByConsumer {
              self.notifyObservers(of: \.transcript)
            }

            // Under `.revertTranscript`, errors and consumer cancellation restore
            // `revertTargetTranscript` (removing the prompt). Under `.preserveTranscript` the
            // transcript stays, including an external write, unless an observer wrote from a
            // notification.
            if self.shouldRevert(after: error, reentrantMutationCount: preCallReentrantCount) {
              self.revertTranscript(to: revertTargetTranscript)
            }
          }
          releaseResponding()
          controller.fail(with: error)
        }
      }

      controller.setCancellationHandler {
        driverTask.cancel()
      }

      return ResponseStream(controller: controller)
    }
  }

  // MARK: - Public StreamResponse Overloads (Legacy 9)

  extension LanguageModelSession {
    /// Streams a string response for a prompt.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to respond to.
    ///   - options: Options controlling generation.
    /// - Returns: A stream yielding response snapshots as text is generated.
    public final func streamResponse(
      to prompt: Prompt,
      options: GenerationOptions = GenerationOptions()
    ) -> sending LanguageModelSession.ResponseStream<String> {
      streamResponse(
        to: prompt,
        options: options,
        contextOptions: ContextOptions(),
        metadata: [:]
      )
    }

    /// Streams a string response for a text prompt.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to respond to.
    ///   - options: Options controlling generation.
    /// - Returns: A stream yielding response snapshots as text is generated.
    @_disfavoredOverload
    public final func streamResponse(
      to prompt: String,
      options: GenerationOptions = GenerationOptions()
    ) -> sending LanguageModelSession.ResponseStream<String> {
      streamResponse(
        to: Prompt(prompt),
        options: options,
        contextOptions: ContextOptions(),
        metadata: [:]
      )
    }

    /// Streams a string response using a prompt builder.
    ///
    /// - Parameters:
    ///   - options: Options controlling generation.
    ///   - prompt: A closure building the prompt.
    /// - Returns: A stream yielding response snapshots as text is generated.
    /// - Throws: An error if prompt building throws.
    public final func streamResponse(
      options: GenerationOptions = GenerationOptions(),
      @PromptBuilder prompt: () throws -> Prompt
    ) rethrows -> sending LanguageModelSession.ResponseStream<String> {
      let builtPrompt = try prompt()
      return streamResponse(
        to: builtPrompt,
        options: options,
        contextOptions: ContextOptions(),
        metadata: [:]
      )
    }

    /// Streams structured content adhering to a schema for a prompt.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to respond to.
    ///   - schema: The schema guiding generation.
    ///   - includeSchemaInPrompt: Whether to include the schema description in the prompt.
    ///   - options: Options controlling generation.
    /// - Returns: A stream yielding response snapshots as structured content is generated.
    public final func streamResponse(
      to prompt: Prompt,
      schema: GenerationSchema,
      includeSchemaInPrompt: Bool = true,
      options: GenerationOptions = GenerationOptions()
    ) -> sending LanguageModelSession.ResponseStream<GeneratedContent> {
      streamResponse(
        to: prompt,
        schema: schema,
        options: options,
        contextOptions: ContextOptions(includeSchemaInPrompt: includeSchemaInPrompt),
        metadata: [:]
      )
    }

    /// Streams structured content adhering to a schema for a text prompt.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to respond to.
    ///   - schema: The schema guiding generation.
    ///   - includeSchemaInPrompt: Whether to include the schema description in the prompt.
    ///   - options: Options controlling generation.
    /// - Returns: A stream yielding response snapshots as structured content is generated.
    @_disfavoredOverload
    public final func streamResponse(
      to prompt: String,
      schema: GenerationSchema,
      includeSchemaInPrompt: Bool = true,
      options: GenerationOptions = GenerationOptions()
    ) -> sending LanguageModelSession.ResponseStream<GeneratedContent> {
      streamResponse(
        to: Prompt(prompt),
        schema: schema,
        options: options,
        contextOptions: ContextOptions(includeSchemaInPrompt: includeSchemaInPrompt),
        metadata: [:]
      )
    }

    /// Streams structured content adhering to a schema using a prompt builder.
    ///
    /// - Parameters:
    ///   - schema: The schema guiding generation.
    ///   - includeSchemaInPrompt: Whether to include the schema description in the prompt.
    ///   - options: Options controlling generation.
    ///   - prompt: A closure building the prompt.
    /// - Returns: A stream yielding response snapshots as structured content is generated.
    /// - Throws: An error if prompt building throws.
    public final func streamResponse(
      schema: GenerationSchema,
      includeSchemaInPrompt: Bool = true,
      options: GenerationOptions = GenerationOptions(),
      @PromptBuilder prompt: () throws -> Prompt
    ) rethrows -> sending LanguageModelSession.ResponseStream<GeneratedContent> {
      let builtPrompt = try prompt()
      return streamResponse(
        to: builtPrompt,
        schema: schema,
        options: options,
        contextOptions: ContextOptions(includeSchemaInPrompt: includeSchemaInPrompt),
        metadata: [:]
      )
    }

    /// Streams a strongly typed value for a prompt.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to respond to.
    ///   - type: The expected type of the generated value.
    ///   - includeSchemaInPrompt: Whether to include the schema description in the prompt.
    ///   - options: Options controlling generation.
    /// - Returns: A stream yielding response snapshots as content is generated.
    public final func streamResponse<Content>(
      to prompt: Prompt,
      generating type: Content.Type = Content.self,
      includeSchemaInPrompt: Bool = true,
      options: GenerationOptions = GenerationOptions()
    ) -> sending LanguageModelSession.ResponseStream<Content> where Content: Generable {
      streamResponse(
        to: prompt,
        generating: type,
        options: options,
        contextOptions: ContextOptions(includeSchemaInPrompt: includeSchemaInPrompt),
        metadata: [:]
      )
    }

    /// Streams a strongly typed value for a text prompt.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to respond to.
    ///   - type: The expected type of the generated value.
    ///   - includeSchemaInPrompt: Whether to include the schema description in the prompt.
    ///   - options: Options controlling generation.
    /// - Returns: A stream yielding response snapshots as content is generated.
    @_disfavoredOverload
    public final func streamResponse<Content>(
      to prompt: String,
      generating type: Content.Type = Content.self,
      includeSchemaInPrompt: Bool = true,
      options: GenerationOptions = GenerationOptions()
    ) -> sending LanguageModelSession.ResponseStream<Content> where Content: Generable {
      streamResponse(
        to: Prompt(prompt),
        generating: type,
        options: options,
        contextOptions: ContextOptions(includeSchemaInPrompt: includeSchemaInPrompt),
        metadata: [:]
      )
    }

    /// Streams a strongly typed value using a prompt builder.
    ///
    /// - Parameters:
    ///   - type: The expected type of the generated value.
    ///   - includeSchemaInPrompt: Whether to include the schema description in the prompt.
    ///   - options: Options controlling generation.
    ///   - prompt: A closure building the prompt.
    /// - Returns: A stream yielding response snapshots as content is generated.
    /// - Throws: An error if prompt building throws.
    public final func streamResponse<Content>(
      generating type: Content.Type = Content.self,
      includeSchemaInPrompt: Bool = true,
      options: GenerationOptions = GenerationOptions(),
      @PromptBuilder prompt: () throws -> Prompt
    ) rethrows -> sending LanguageModelSession.ResponseStream<Content> where Content: Generable {
      let builtPrompt = try prompt()
      return streamResponse(
        to: builtPrompt,
        generating: type,
        options: options,
        contextOptions: ContextOptions(includeSchemaInPrompt: includeSchemaInPrompt),
        metadata: [:]
      )
    }
  }

  // MARK: - Public StreamResponse Overloads (With ContextOptions & Metadata 9)

  extension LanguageModelSession {
    /// Streams a string response for a prompt with context options and metadata.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to respond to.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    /// - Returns: A stream yielding response snapshots as text is generated.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public final func streamResponse(
      to prompt: Prompt,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(),
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) -> sending LanguageModelSession.ResponseStream<String> {
      performStreamResponse(
        to: prompt,
        schema: nil,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata,
        convertPartial: { try String($0) },
        convertFinal: { try String($0) }
      )
    }

    /// Streams a string response for a text prompt with context options and metadata.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to respond to.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    /// - Returns: A stream yielding response snapshots as text is generated.
    @_disfavoredOverload
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public final func streamResponse(
      to prompt: String,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(),
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) -> sending LanguageModelSession.ResponseStream<String> {
      streamResponse(
        to: Prompt(prompt),
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }

    /// Streams a string response using a prompt builder with context options and metadata.
    ///
    /// - Parameters:
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    ///   - prompt: A closure building the prompt.
    /// - Returns: A stream yielding response snapshots as text is generated.
    /// - Throws: An error if prompt building throws.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public final func streamResponse(
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(),
      metadata: [String: any ConvertibleToGeneratedContent] = [:],
      @PromptBuilder prompt: () throws -> Prompt
    ) rethrows -> sending LanguageModelSession.ResponseStream<String> {
      let builtPrompt = try prompt()
      return streamResponse(
        to: builtPrompt,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }

    /// Streams structured content for a prompt with context options and metadata.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to respond to.
    ///   - schema: The schema guiding generation.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    /// - Returns: A stream yielding response snapshots as structured content is generated.
    @_disfavoredOverload
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public final func streamResponse(
      to prompt: Prompt,
      schema: GenerationSchema,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) -> sending LanguageModelSession.ResponseStream<GeneratedContent> {
      performStreamResponse(
        to: prompt,
        schema: schema,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata,
        convertPartial: { $0 },
        convertFinal: { $0 }
      )
    }

    /// Streams structured content for a text prompt with context options and metadata.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to respond to.
    ///   - schema: The schema guiding generation.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    /// - Returns: A stream yielding response snapshots as structured content is generated.
    @_disfavoredOverload
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public final func streamResponse(
      to prompt: String,
      schema: GenerationSchema,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) -> sending LanguageModelSession.ResponseStream<GeneratedContent> {
      streamResponse(
        to: Prompt(prompt),
        schema: schema,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }

    /// Streams structured content using a prompt builder with context options and metadata.
    ///
    /// - Parameters:
    ///   - schema: The schema guiding generation.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    ///   - prompt: A closure building the prompt.
    /// - Returns: A stream yielding response snapshots as structured content is generated.
    /// - Throws: An error if prompt building throws.
    @_disfavoredOverload
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public final func streamResponse(
      schema: GenerationSchema,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
      metadata: [String: any ConvertibleToGeneratedContent] = [:],
      @PromptBuilder prompt: () throws -> Prompt
    ) rethrows -> sending LanguageModelSession.ResponseStream<GeneratedContent> {
      let builtPrompt = try prompt()
      return streamResponse(
        to: builtPrompt,
        schema: schema,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }

    /// Streams a strongly typed value for a prompt with context options and metadata.
    ///
    /// - Parameters:
    ///   - prompt: The prompt to respond to.
    ///   - type: The expected type of the generated value.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    /// - Returns: A stream yielding response snapshots as content is generated.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public final func streamResponse<Content>(
      to prompt: Prompt,
      generating type: Content.Type = Content.self,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) -> sending LanguageModelSession.ResponseStream<Content> where Content: Generable {
      let schema: GenerationSchema? = (Content.self == String.self) ? nil : Content.generationSchema
      return performStreamResponse(
        to: prompt,
        schema: schema,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata,
        convertPartial: { try Content.PartiallyGenerated($0) },
        convertFinal: { try Content($0) }
      )
    }

    /// Streams a strongly typed value for a text prompt with context options and metadata.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to respond to.
    ///   - type: The expected type of the generated value.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    /// - Returns: A stream yielding response snapshots as content is generated.
    @_disfavoredOverload
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public final func streamResponse<Content>(
      to prompt: String,
      generating type: Content.Type = Content.self,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) -> sending LanguageModelSession.ResponseStream<Content> where Content: Generable {
      streamResponse(
        to: Prompt(prompt),
        generating: type,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }

    /// Streams a strongly typed value using a prompt builder with context options and metadata.
    ///
    /// - Parameters:
    ///   - type: The expected type of the generated value.
    ///   - options: Options controlling generation.
    ///   - contextOptions: Options controlling context management.
    ///   - metadata: Metadata to attach to the prompt.
    ///   - prompt: A closure building the prompt.
    /// - Returns: A stream yielding response snapshots as content is generated.
    /// - Throws: An error if prompt building throws.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public final func streamResponse<Content>(
      generating type: Content.Type = Content.self,
      options: GenerationOptions = GenerationOptions(),
      contextOptions: ContextOptions = ContextOptions(includeSchemaInPrompt: true),
      metadata: [String: any ConvertibleToGeneratedContent] = [:],
      @PromptBuilder prompt: () throws -> Prompt
    ) rethrows -> sending LanguageModelSession.ResponseStream<Content> where Content: Generable {
      let builtPrompt = try prompt()
      return streamResponse(
        to: builtPrompt,
        generating: type,
        options: options,
        contextOptions: contextOptions,
        metadata: metadata
      )
    }
  }

  /// Ensures snapshots deferred during `onReasoning` hooks are yielded at most once, either when
  /// `onReasoning` completes or while `onReasoning` is suspended.
  private final class OnceSnapshotFlusher<Content: Generable>: Sendable {
    /// Mutable snapshot list guarded by `state`.
    private struct State: @unchecked Sendable {
      var snapshots: [LanguageModelSession.ResponseStream<Content>.Snapshot]
    }

    /// Pending snapshots guarded by a mutex.
    private let state: Mutex<State>

    /// Stream controller receiving the snapshots.
    private let controller: LanguageModelSession.StreamController<Content>

    /// Creates a snapshot flusher.
    init(
      snapshots: [LanguageModelSession.ResponseStream<Content>.Snapshot],
      controller: LanguageModelSession.StreamController<Content>
    ) {
      self.state = Mutex(State(snapshots: snapshots))
      self.controller = controller
    }

    /// Yields any remaining snapshots into `controller` once.
    func flush() {
      let toYield = state.withLock { state -> State in
        let copy = state
        state.snapshots.removeAll()
        return copy
      }
      for snapshot in toYield.snapshots {
        controller.yield(snapshot)
      }
    }
  }
#endif  // compiler(>=6.4)
