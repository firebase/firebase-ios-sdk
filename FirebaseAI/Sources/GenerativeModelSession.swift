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

// TODO: Remove the `#if compiler(>=6.2.3)` when Xcode 26.2 is the minimum supported version.
#if compiler(>=6.2.3)
  import Foundation
  #if canImport(FoundationModels)
    import FoundationModels
  #endif // canImport(FoundationModels)

  /// A session that handles multi-turn interactions with a generative model, similar to ``Chat``.
  ///
  /// A `GenerativeModelSession` retains history between requests. For single-turn requests to a
  /// model, use `generativeModelSession(model:tools:instructions:)` to start a new session.
  /// `GenerativeModelSession` is particularly useful for generating structured data.
  ///
  /// **Public Preview**: This API is a public preview and may be subject to change.
  ///
  /// Example usage:
  /// ```swift
  /// @Generable
  /// struct UserProfile {
  ///   @Guide(description: "A unique username for the user.")
  ///   var username: String
  ///
  ///   @Guide(description: "A short bio about the user, no more than 100 characters.")
  ///   var bio: String
  ///
  ///   @Guide(description: "A list of the user's favorite topics.", .count(3))
  ///   var favoriteTopics: [String]
  /// }
  ///
  /// let firebaseAI = // ... a `FirebaseAI` instance
  /// let session = firebaseAI.generativeModelSession(model: "gemini-model-name")
  /// let prompt = "Generate a user profile for a cat lover who enjoys hiking."
  /// let response = try await session.respond(to: prompt, generating: UserProfile.self)
  ///
  /// print("Username: \(response.content.username)")
  /// print("Bio: \(response.content.bio)")
  /// print("Favorite Topics: \(response.content.favoriteTopics.joined(separator: ", "))")
  /// ```
  public final class GenerativeModelSession: Sendable {
    let session: Chat
    let functionDeclarations: [String: FunctionDeclaration]

    // The maximum number of automatic back-and-forth turns the session will perform to resolve
    // function calls.
    //
    // This prevents infinite looping if the model consistently requests one or more function calls.
    //
    // TODO: Add ability to configure this setting.
    static let maxAutoFunctionCallTurns = 10

    /// Creates a new `GenerativeModelSession` with the given model.
    ///
    /// **Public Preview**: This API is a public preview and may be subject to change.
    /// - Parameter model: The `GenerativeModel` to use for generating content.
    init(model: GenerativeModel) {
      session = model.startChat()
      functionDeclarations = model.functionDeclarationsByName()
    }

    /// Sends a new prompt to the model and returns a `Response` containing the generated content as
    /// a `String`.
    ///
    /// **Public Preview**: This API is a public preview and may be subject to change.
    /// - Parameter prompt: The content to send to the model.
    /// - Parameter options: An optional `GenerationConfig` to override the model's default
    /// generation configuration.
    /// - Returns: A `Response` containing the generated content as a `String`.
    /// - Throws: A `GenerationError` if the model fails to generate a response.
    @discardableResult
    public nonisolated(nonsending)
    func respond(to prompt: PartsRepresentable..., options: GenerationConfig? = nil) async throws
      -> GenerativeModelSession.Response<String> {
      return try await respond(
        to: prompt,
        schema: nil as FirebaseAI.GenerationSchema?,
        generating: String.self,
        includeSchemaInPrompt: false,
        options: options
      )
    }

    #if canImport(FoundationModels)
      /// Sends a new prompt to the model and returns a `Response` containing the generated content
      /// as
      /// `GeneratedContent`.
      ///
      /// **Public Preview**: This API is a public preview and may be subject to change.
      /// - Parameter prompt: The content to send to the model.
      /// - Parameter schema: The `GenerationSchema` to use for generating the content.
      /// - Parameter includeSchemaInPrompt: Whether to include the schema in the prompt to the
      /// model.
      /// - Parameter options: An optional `GenerationConfig` to override the model's default
      /// generation configuration.
      /// - Returns: A `Response` containing the generated content as `GeneratedContent`.
      /// - Throws: A `GenerationError` if the model fails to generate a response.
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      @discardableResult
      nonisolated(nonsending)
      func respond(to prompt: PartsRepresentable..., schema: FoundationModels.GenerationSchema,
                   includeSchemaInPrompt: Bool = true,
                   options: GenerationConfig? = nil) async throws
        -> GenerativeModelSession.Response<FirebaseAI.GeneratedContent> {
        // TODO: Replace `FoundationModels.GenerationSchema` and make this method public when
        // `FirebaseAI.GenerationSchema`'s public API is ready.
        return try await respond(
          to: prompt,
          schema: FirebaseAI.GenerationSchema(schema),
          generating: FirebaseAI.GeneratedContent.self,
          includeSchemaInPrompt: includeSchemaInPrompt,
          options: options
        )
      }

      /// Sends a new prompt to the model and returns a `Response` containing the generated content
      /// as
      /// a `Generable` type.
      ///
      /// **Public Preview**: This API is a public preview and may be subject to change.
      /// - Parameter prompt: The content to send to the model.
      /// - Parameter type: The `Generable` type to decode the response into.
      /// - Parameter includeSchemaInPrompt: Whether to include the schema in the prompt to the
      /// model.
      /// - Parameter options: An optional `GenerationConfig` to override the model's default
      /// generation configuration.
      /// - Returns: A `Response` containing the generated content as the specified `Generable`
      /// type.
      /// - Throws: A `GenerationError` if the model fails to generate a response.
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      @discardableResult
      public nonisolated(nonsending)
      func respond<Content>(to prompt: PartsRepresentable...,
                            generating type: Content.Type = Content.self,
                            includeSchemaInPrompt: Bool = true,
                            options: GenerationConfig? = nil) async throws
        -> GenerativeModelSession.Response<Content> where Content: Generable {
        return try await respond(
          to: prompt,
          schema: FirebaseAI.GenerationSchema(Content.generationSchema),
          generating: type,
          includeSchemaInPrompt: includeSchemaInPrompt,
          options: options
        )
      }

      /// Streams the model's response as `GeneratedContent`.
      ///
      /// **Public Preview**: This API is a public preview and may be subject to change.
      /// - Parameter prompt: The content to send to the model.
      /// - Parameter schema: The `GenerationSchema` to use for generating the content.
      /// - Parameter includeSchemaInPrompt: Whether to include the schema in the prompt to the
      /// model.
      /// - Parameter options: An optional `GenerationConfig` to override the model's default
      /// generation configuration.
      /// - Returns: A `ResponseStream` that yields snapshots of the generated content.
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      func streamResponse(to prompt: PartsRepresentable...,
                          schema: FoundationModels.GenerationSchema,
                          includeSchemaInPrompt: Bool = true, options: GenerationConfig? = nil)
        -> sending GenerativeModelSession.ResponseStream<
          FirebaseAI.GeneratedContent, FirebaseAI.GeneratedContent
        > {
        // TODO: Replace `FoundationModels.GenerationSchema` and make this method public when
        // `FirebaseAI.GenerationSchema`'s public API is ready.
        return streamResponse(
          to: prompt,
          schema: FirebaseAI.GenerationSchema(schema),
          generating: FirebaseAI.GeneratedContent.self,
          includeSchemaInPrompt: includeSchemaInPrompt,
          options: options
        )
      }

      /// Streams the model's response as a `Generable` type.
      ///
      /// **Public Preview**: This API is a public preview and may be subject to change.
      /// - Parameter prompt: The content to send to the model.
      /// - Parameter type: The `Generable` type to decode the response into.
      /// - Parameter includeSchemaInPrompt: Whether to include the schema in the prompt to the
      /// model.
      /// - Parameter options: An optional `GenerationConfig` to override the model's default
      /// generation configuration.
      /// - Returns: A `ResponseStream` that yields snapshots of the generated content.
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      public func streamResponse<Content>(to prompt: PartsRepresentable...,
                                          generating type: Content.Type = Content.self,
                                          includeSchemaInPrompt: Bool = true,
                                          options: GenerationConfig? = nil)
        -> sending GenerativeModelSession.ResponseStream<Content, Content.PartiallyGenerated>
        where Content: Generable {
        return streamResponse(
          to: prompt,
          schema: FirebaseAI.GenerationSchema(type.generationSchema),
          generating: type,
          includeSchemaInPrompt: includeSchemaInPrompt,
          options: options
        )
      }
    #endif // canImport(FoundationModels)

    /// Streams the model's response as a `String`.
    ///
    /// **Public Preview**: This API is a public preview and may be subject to change.
    /// - Parameter prompt: The content to send to the model.
    /// - Parameter options: An optional `GenerationConfig` to override the model's default
    /// generation configuration.
    /// - Returns: A `ResponseStream` that yields snapshots of the generated content.
    @available(macOS 12.0, watchOS 8.0, *)
    public func streamResponse(to prompt: PartsRepresentable..., options: GenerationConfig? = nil)
      -> sending GenerativeModelSession.ResponseStream<String, String> {
      return streamResponse(
        to: prompt,
        schema: nil,
        generating: String.self,
        includeSchemaInPrompt: false,
        options: options
      )
    }

    // MARK: - Internal

    private nonisolated(nonsending)
    func respond<Content>(to prompt: [PartsRepresentable], schema: FirebaseAI.GenerationSchema?,
                          generating type: Content.Type, includeSchemaInPrompt: Bool,
                          options: GenerationConfig?) async throws
      -> GenerativeModelSession.Response<Content> {
      let parts = [ModelContent(parts: prompt)]
      let config = try buildConfig(
        options: options,
        schema: schema,
        includeSchemaInPrompt: includeSchemaInPrompt
      )

      var response = try await session.sendMessage(parts, generationConfig: config)

      var autoFunctionCallTurns = 0
      while !response.functionCalls.isEmpty {
        guard autoFunctionCallTurns < GenerativeModelSession.maxAutoFunctionCallTurns else {
          throw GenerationError.internalError(
            GenerationError.Context(
              debugDescription: """
              The model exceeded the maximum allowed automatic function call iterations \
              (\(GenerativeModelSession.maxAutoFunctionCallTurns)).
              """
            ),
            underlyingError: FunctionCallingError.maxFunctionCallTurnsExceeded
          )
        }

        let functionResponses = try await execute(functionCalls: response.functionCalls)

        guard !functionResponses.isEmpty else { break }
        response = try await session.sendMessage(
          [ModelContent(role: "user", parts: functionResponses)],
          generationConfig: config
        )

        autoFunctionCallTurns += 1
      }

      let text: String
      if let responseText = response.text {
        text = responseText
      } else if let parts = response.candidates.first?.content.parts, !parts.isEmpty {
        text = ""
      } else {
        throw GenerationError.decodingFailure(
          GenerationError.Context(debugDescription: "No parts in response: \(response)")
        )
      }
      let generationID = response.responseID.map {
        #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
          if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return FirebaseAI.GenerationID(responseID: $0, generationID: GenerationID())
          }
        #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM

        return FirebaseAI.GenerationID(responseID: $0, generationID: nil)
      }

      let rawContent = try Self.makeRawContent(
        from: text,
        generationID: generationID,
        hasSchema: schema != nil,
        isComplete: true
      )
      let content: Content = try Self.resolveContent(from: rawContent)

      return GenerativeModelSession.Response(
        content: content, rawContent: rawContent, rawResponse: response
      )
    }

    @available(macOS 12.0, watchOS 8.0, *)
    private func streamResponse<Content, PartialContent>(to prompt: [PartsRepresentable],
                                                         schema: FirebaseAI.GenerationSchema?,
                                                         generating type: Content.Type,
                                                         includeSchemaInPrompt: Bool,
                                                         options: GenerationConfig?)
      -> sending GenerativeModelSession.ResponseStream<Content, PartialContent> {
      let initialParts = [ModelContent(parts: prompt)]
      return GenerativeModelSession.ResponseStream { context in
        do {
          let config = try self.buildConfig(
            options: options,
            schema: schema,
            includeSchemaInPrompt: includeSchemaInPrompt
          )

          var currentParts = initialParts
          var generationID: FirebaseAI.GenerationID?
          var autoFunctionCallTurns = 0

          functionCallingLoop: while true {
            let stream = try self.session.sendMessageStream(currentParts, generationConfig: config)

            var streamedText = ""
            var functionCalls = [FunctionCallPart]()

            // 1. Create a buffer to hold the previous iteration's data in order to differentiate
            //    the last chunk to accurately set `isComplete`.
            var pendingChunkData: (
              text: String,
              id: FirebaseAI.GenerationID?,
              response: GenerateContentResponse
            )?

            for try await chunk in stream {
              functionCalls.append(contentsOf: chunk.functionCalls)

              let text: String
              if let responseText = chunk.text {
                text = responseText
              } else if let parts = chunk.candidates.first?.content.parts, !parts.isEmpty {
                text = ""
              } else {
                throw GenerationError.decodingFailure(
                  GenerationError.Context(debugDescription: "No parts in response: \(chunk)")
                )
              }

              // 2. If we have pending data, we now know it wasn't the last chunk.
              if let pending = pendingChunkData,
                 !pending.text.isEmpty || pending.response.thoughtSummary != nil {
                let rawContent = try Self.makeRawContent(
                  from: pending.text,
                  generationID: pending.id,
                  hasSchema: schema != nil,
                  isComplete: false
                )
                let rawResult = GenerativeModelSession.ResponseStream<Content, PartialContent>
                  .RawResult(
                    rawContent: rawContent,
                    rawResponse: pending.response
                  )
                await context.yield(rawResult)
              }

              // 3. Update our cumulative state for the current chunk
              streamedText.append(text)
              if generationID == nil {
                generationID = chunk.responseID.map {
                  #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
                    if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
                      return FirebaseAI.GenerationID(
                        responseID: $0, generationID: FoundationModels.GenerationID()
                      )
                    }
                  #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM

                  return FirebaseAI.GenerationID(responseID: $0, generationID: nil)
                }
              }

              // 4. Save the current state as the new pending chunk.
              pendingChunkData = (text: streamedText, id: generationID, response: chunk)
            }

            // Stream for the current turn finished. Check if there are function calls to handle.
            if !functionCalls.isEmpty {
              guard autoFunctionCallTurns < GenerativeModelSession.maxAutoFunctionCallTurns else {
                throw GenerationError.internalError(
                  GenerationError.Context(
                    debugDescription: """
                    The model exceeded the maximum allowed automatic function call iterations \
                    (\(GenerativeModelSession.maxAutoFunctionCallTurns)).
                    """
                  ),
                  underlyingError: FunctionCallingError.maxFunctionCallTurnsExceeded
                )
              }
              let functionResponses = try await self.execute(functionCalls: functionCalls)

              if !functionResponses.isEmpty {
                // Yield any pending text if it's not empty, but mark it as NOT complete yet.
                if let pending = pendingChunkData,
                   !pending.text.isEmpty || pending.response.thoughtSummary != nil {
                  let rawContent = try Self.makeRawContent(
                    from: pending.text,
                    generationID: pending.id,
                    hasSchema: schema != nil,
                    isComplete: false
                  )
                  let rawResult = GenerativeModelSession.ResponseStream<Content, PartialContent>
                    .RawResult(
                      rawContent: rawContent,
                      rawResponse: pending.response
                    )
                  await context.yield(rawResult)
                }

                currentParts = [ModelContent(role: "user", parts: functionResponses)]
                autoFunctionCallTurns += 1
                continue functionCallingLoop
              }
            }

            // 5. The remaining pending chunk is the final one.
            if let finalChunk = pendingChunkData {
              let rawContent = try Self.makeRawContent(
                from: finalChunk.text,
                generationID: finalChunk.id,
                hasSchema: schema != nil,
                isComplete: true
              )
              let rawResult = GenerativeModelSession.ResponseStream<Content, PartialContent>
                .RawResult(
                  rawContent: rawContent,
                  rawResponse: finalChunk.response
                )
              await context.yield(rawResult)
            }

            break functionCallingLoop
          }

          await context.finish()
        } catch {
          await context.finish(throwing: error)
        }
      }
    }

    private func execute(functionCalls: [FunctionCallPart]) async throws -> [FunctionResponsePart] {
      var functionResponses = [FunctionResponsePart]()
      for functionCall in functionCalls {
        guard let functionDeclaration = functionDeclarations[functionCall.name] else {
          throw GenerationError.internalError(
            GenerationError.Context(debugDescription: """
            No function named "\(functionCall.name)" was declared.
            """),
            underlyingError: FunctionCallingError.invalidFunctionCall
          )
        }

        switch functionDeclaration.kind {
        case .manual:
          continue
        case let .foundationModels(tool):
          #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
            if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
              guard let tool = tool as? (any FoundationModels.Tool) else {
                assertionFailure("The value '\(tool)' is not a Foundation Models `Tool`.")
                throw TypeConversionError(
                  from: (any Sendable).self, to: (any FoundationModels.Tool).self
                )
              }
              try functionResponses.append(await FunctionDeclaration.call(
                tool: tool,
                functionCall: functionCall
              ))
              continue
            }
          #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
          assertionFailure("""
          A Foundation Models `Tool` '\(tool)' was provided but not running on a supported platform.
          """)
        }
      }

      return functionResponses
    }

    private func buildConfig(options: GenerationConfig?,
                             schema: FirebaseAI.GenerationSchema?,
                             includeSchemaInPrompt: Bool) throws -> GenerationConfig {
      var config = GenerationConfig.merge(
        session.generationConfig, with: options
      ) ?? GenerationConfig()

      if let schema {
        config.responseMIMEType = "application/json"
        config.responseJSONSchema = includeSchemaInPrompt ? try schema.toGeminiJSONSchema() : nil
        config.responseSchema = nil // `responseSchema` must not be set with `responseJSONSchema`
      }

      config.responseModalities = nil // Override to the default (text only)
      config.candidateCount = nil // Override to the default (one candidate)

      return config
    }

    private static func makeRawContent(from text: String, generationID: FirebaseAI.GenerationID?,
                                       hasSchema: Bool, isComplete: Bool) throws
      -> FirebaseAI.GeneratedContent {
      if hasSchema {
        if text.isEmpty && !isComplete {
          return FirebaseAI.GeneratedContent(
            // TODO: Set `kind:` to `.array(...)`, `.bool()`, `.number()` based on schema type.
            kind: .structure(properties: [:], orderedKeys: []),
            id: generationID,
            isComplete: isComplete
          )
        }

        return try FirebaseAI.GeneratedContent(json: text, id: generationID, isComplete: isComplete)
      }

      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          return FirebaseAI
            .GeneratedContent(
              kind: FoundationModels.GeneratedContent.Kind.string(text),
              id: generationID,
              isComplete: isComplete
            )
        }
      #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM

      return FirebaseAI.GeneratedContent(
        kind: FirebaseAI.GeneratedContent.Kind.string(text),
        id: generationID,
        isComplete: isComplete
      )
    }

    static func resolveContent<T>(from rawContent: FirebaseAI.GeneratedContent) throws -> T {
      if let content = rawContent as? T {
        return content
      }

      #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *), let contentMetatype = T
          .self as? (any FoundationModels.ConvertibleFromGeneratedContent.Type),
          let content = try contentMetatype.init(rawContent) as? T {
          return content
        }
      #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM

      if let contentMetatype = T.self as? (any FirebaseAI.ConvertibleFromGeneratedContent.Type),
         let content = try contentMetatype.init(rawContent) as? T {
        return content
      }

      assertionFailure("Unsupported type: \(T.self).")
      // In release builds we throw an error instead of crashing but this state should be
      // unreachable based on the public API.
      throw GenerativeModelSession.TypeConversionError(
        from: type(of: rawContent), to: T.self
      )
    }
  }

  // MARK: - Response Types

  public extension GenerativeModelSession {
    /// The response from a `respond` call.
    struct Response<Content> {
      /// The generated content, decoded into the requested `Generable` type.
      public let content: Content
      /// The raw, undecoded `GeneratedContent` from the model.
      public let rawContent: FirebaseAI.GeneratedContent
      /// The raw `GenerateContentResponse` from the model.
      public let rawResponse: GenerateContentResponse
    }
  }

  public extension GenerativeModelSession {
    /// An asynchronous sequence of snapshots of the model's response.
    struct ResponseStream<Content, PartialContent>: AsyncSequence {
      public typealias Element = Snapshot

      /// A snapshot of the model's response at a point in time.
      public struct Snapshot {
        /// The partially generated content, decoded into the requested `Generable`'s partial type.
        public let content: PartialContent
        /// The raw, undecoded `GeneratedContent` from the model.
        public let rawContent: FirebaseAI.GeneratedContent
        /// The raw `GenerateContentResponse` from the model.
        public let rawResponse: GenerateContentResponse
      }

      private let rawStream: AsyncThrowingStream<RawResult, Error>
      private let context: StreamContext

      init(_ builder: @escaping @Sendable (StreamContext) async -> Void) {
        var extractedContinuation: AsyncThrowingStream<RawResult, Error>.Continuation!
        let stream = AsyncThrowingStream(RawResult.self) { continuation in
          extractedContinuation = continuation
        }
        rawStream = stream

        let context = StreamContext(continuation: extractedContinuation)
        self.context = context

        Task {
          await builder(context)
        }
      }

      /// An iterator that provides snapshots of the model's response.
      public struct AsyncIterator: AsyncIteratorProtocol {
        private var rawIterator: AsyncThrowingStream<RawResult, Error>.Iterator

        init(rawIterator: AsyncThrowingStream<RawResult, Error>.Iterator) {
          self.rawIterator = rawIterator
        }

        @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        public mutating func next(isolation actor: isolated (any Actor)?) async throws
          -> Snapshot? {
          var lastDecodingError: Error? = nil

          while let rawResult = try await rawIterator.next(isolation: actor) {
            do {
              // If it parses successfully, return the snapshot and discard any errors from previous
              // loop iterations.
              return try process(rawResult)
            } catch {
              // Intermediate failure (e.g., incomplete JSON that could not be parsed).
              // Hold onto the error and let the loop fetch the next chunk.
              lastDecodingError = error
            }
          }

          // If the last chunk processed resulted in an error, throw it.
          if let lastDecodingError {
            throw lastDecodingError
          }

          return nil
        }

        public mutating func next() async throws -> Snapshot? {
          var lastDecodingError: Error? = nil

          while let rawResult = try await rawIterator.next() {
            do {
              // If it parses successfully, return the snapshot and discard any errors from previous
              // loop iterations.
              return try process(rawResult)
            } catch {
              // Intermediate failure (e.g., incomplete JSON that could not be parsed).
              // Hold onto the error and let the loop fetch the next chunk.
              lastDecodingError = error
            }
          }

          // If the last chunk processed resulted in an error, throw it.
          if let lastDecodingError {
            throw lastDecodingError
          }

          return nil
        }

        private func process(_ rawResult: RawResult) throws -> Snapshot {
          let partialContent: PartialContent = try GenerativeModelSession
            .resolveContent(from: rawResult.rawContent)

          return Snapshot(
            content: partialContent,
            rawContent: rawResult.rawContent,
            rawResponse: rawResult.rawResponse
          )
        }
      }

      public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(rawIterator: rawStream.makeAsyncIterator())
      }

      /// Collects the entire streamed response into a single `Response`.
      /// - Returns: The final `Response` containing the fully generated content.
      /// - Throws: A `GenerationError` if the model fails to generate a response.
      public nonisolated(nonsending)
      func collect() async throws -> sending GenerativeModelSession.Response<Content> {
        let finalResult = try await context.value

        let content: Content = try GenerativeModelSession
          .resolveContent(from: finalResult.rawContent)
        return GenerativeModelSession.Response(
          content: content,
          rawContent: finalResult.rawContent,
          rawResponse: finalResult.rawResponse
        )
      }
    }
  }

  extension GenerativeModelSession.ResponseStream {
    struct RawResult: Sendable {
      let rawContent: FirebaseAI.GeneratedContent
      let rawResponse: GenerateContentResponse
    }

    actor StreamContext {
      private let continuation: AsyncThrowingStream<RawResult, Error>.Continuation
      private var finalResult: Result<RawResult, Error>?
      private var waitingContinuations: [CheckedContinuation<RawResult, Error>] = []
      private var latestRaw: RawResult?

      init(continuation: AsyncThrowingStream<RawResult, Error>.Continuation) {
        self.continuation = continuation
      }

      func yield(_ rawResult: RawResult) {
        // Prevent yielding new values if the stream has already been finalized
        guard finalResult == nil else { return }

        latestRaw = rawResult
        continuation.yield(rawResult)
      }

      func finish() {
        continuation.finish()
        finalize(with: nil)
      }

      func finish(throwing error: Error) {
        // TODO: Wrap `FoundationModels.GenerationError` errors into equivalent
        //       `GenerativeModelSession.GenerationError` values.
        continuation.finish(throwing: error)
        finalize(with: error)
      }

      var value: RawResult {
        get async throws {
          // 1. Return immediately if we already have the final result.
          if let result = finalResult {
            return try result.get()
          }

          // 2. Cancellation check: bail out early if the calling task was cancelled.
          try Task.checkCancellation()

          // 3. Suspend and wait.
          return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
              self.add(continuation)
            }
          } onCancel: {
            // If the task calling `collect()` is cancelled, fail the stream immediately.
            // This guarantees the continuation is resumed with a CancellationError.
            Task {
              await self.finish(throwing: CancellationError())
            }
          }
        }
      }

      private func add(_ continuation: CheckedContinuation<RawResult, Error>) {
        if let result = finalResult {
          continuation.resume(with: result)
        } else {
          waitingContinuations.append(continuation)
        }
      }

      private func finalize(with error: Error?) {
        // Guards against resuming continuations multiple times, which would crash.
        guard finalResult == nil else { return }

        let result: Result<RawResult, Error>

        if let error = error {
          result = .failure(error)
        } else if let last = latestRaw {
          result = .success(last)
        } else {
          result = .failure(
            GenerativeModelSession.GenerationError.decodingFailure(
              GenerativeModelSession.GenerationError.Context(
                debugDescription: "No content generated in stream."
              )
            )
          )
        }

        finalResult = result

        for continuation in waitingContinuations {
          continuation.resume(with: result)
        }
        waitingContinuations.removeAll()
      }
    }
  }

  extension GenerativeModelSession {
    enum ErrorCodes: Int {
      // Generation Errors
      case decodingFailure = 1000

      // Internal Errors
      case typeConversionFailed = 2000
    }

    static let errorDomain = "\(Constants.baseErrorDomain).\(GenerativeModelSession.self)"

    /// An error that occurs during content generation.
    @nonexhaustive
    public enum GenerationError: Error, LocalizedError {
      /// A context providing more information about the generation error.
      public struct Context: Sendable {
        /// A debug description of the error.
        public let debugDescription: String

        init(debugDescription: String) {
          self.debugDescription = debugDescription
        }
      }

      /// The model's response could not be decoded.
      case decodingFailure(GenerativeModelSession.GenerationError.Context)

      case internalError(GenerativeModelSession.GenerationError.Context, underlyingError: any Error)
    }

    enum FunctionCallingError: Error, LocalizedError {
      case invalidFunctionCall
      case maxFunctionCallTurnsExceeded
    }

    struct TypeConversionError: CustomDebugStringConvertible, CustomNSError {
      public static var errorDomain: String { GenerativeModelSession.errorDomain }

      public var errorCode: Int { ErrorCodes.typeConversionFailed.rawValue }

      public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: debugDescription] }

      let debugDescription: String

      init(from fromType: Any.Type, to toType: Any.Type) {
        debugDescription = "Failed to convert from type '\(fromType)' to '\(toType)'."
      }
    }
  }
#endif // compiler(>=6.2.3)
