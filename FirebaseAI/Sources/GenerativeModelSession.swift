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

// TODO: Remove the `#if compiler(>=6.2)` when Xcode 26 is the minimum supported version.
#if compiler(>=6.2) && canImport(FoundationModels)
  import Foundation
  import FoundationModels

  /// A session that simplifies interaction with a generative model, particularly for generating
  /// structured data.
  ///
  /// A `GenerativeModelSession` is ideal for single-turn requests to a model, where you want to
  /// decode the model's output into a specific Swift type that conforms to the `Generable`
  /// protocol.
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
  /// let model = // ... a GenerativeModel instance
  /// let session = GenerativeModelSession(model: model)
  /// let prompt = "Generate a user profile for a cat lover who enjoys hiking."
  /// let response = try await session.respond(to: prompt, generating: UserProfile.self)
  ///
  /// print("Username: \(response.content.username)")
  /// print("Bio: \(response.content.bio)")
  /// print("Favorite Topics: \(response.content.favoriteTopics.joined(separator: ", "))")
  /// ```
  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public final class GenerativeModelSession: Sendable {
    let session: Chat

    /// Creates a new `GenerativeModelSession` with the given model.
    ///
    /// **Public Preview**: This API is a public preview and may be subject to change.
    /// - Parameter model: The `GenerativeModel` to use for generating content.
    public init(model: GenerativeModel) {
      session = model.startChat()
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
        schema: nil,
        generating: String.self,
        includeSchemaInPrompt: false,
        options: options
      )
    }

    /// Sends a new prompt to the model and returns a `Response` containing the generated content as
    /// `GeneratedContent`.
    ///
    /// **Public Preview**: This API is a public preview and may be subject to change.
    /// - Parameter prompt: The content to send to the model.
    /// - Parameter schema: The `GenerationSchema` to use for generating the content.
    /// - Parameter includeSchemaInPrompt: Whether to include the schema in the prompt to the model.
    /// - Parameter options: An optional `GenerationConfig` to override the model's default
    /// generation configuration.
    /// - Returns: A `Response` containing the generated content as `GeneratedContent`.
    /// - Throws: A `GenerationError` if the model fails to generate a response.
    @discardableResult
    public nonisolated(nonsending)
    func respond(to prompt: PartsRepresentable..., schema: GenerationSchema,
                 includeSchemaInPrompt: Bool = true, options: GenerationConfig? = nil) async throws
      -> GenerativeModelSession.Response<FirebaseAI.GeneratedContent> {
      return try await respond(
        to: prompt,
        schema: schema,
        generating: FirebaseAI.GeneratedContent.self,
        includeSchemaInPrompt: includeSchemaInPrompt,
        options: options
      )
    }

    /// Sends a new prompt to the model and returns a `Response` containing the generated content as
    /// a `Generable` type.
    ///
    /// **Public Preview**: This API is a public preview and may be subject to change.
    /// - Parameter prompt: The content to send to the model.
    /// - Parameter type: The `Generable` type to decode the response into.
    /// - Parameter includeSchemaInPrompt: Whether to include the schema in the prompt to the model.
    /// - Parameter options: An optional `GenerationConfig` to override the model's default
    /// generation configuration.
    /// - Returns: A `Response` containing the generated content as the specified `Generable` type.
    /// - Throws: A `GenerationError` if the model fails to generate a response.
    @discardableResult
    public nonisolated(nonsending)
    func respond<Content>(to prompt: PartsRepresentable...,
                          generating type: Content.Type = Content.self,
                          includeSchemaInPrompt: Bool = true,
                          options: GenerationConfig? = nil) async throws
      -> GenerativeModelSession.Response<Content> where Content: Generable {
      return try await respond(
        to: prompt,
        schema: Content.generationSchema,
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
    /// - Parameter includeSchemaInPrompt: Whether to include the schema in the prompt to the model.
    /// - Parameter options: An optional `GenerationConfig` to override the model's default
    /// generation configuration.
    /// - Returns: A `ResponseStream` that yields snapshots of the generated content.
    public func streamResponse(to prompt: PartsRepresentable...,
                               schema: GenerationSchema,
                               includeSchemaInPrompt: Bool = true,
                               options: GenerationConfig? = nil)
      -> sending GenerativeModelSession.ResponseStream<
        FirebaseAI.GeneratedContent, FirebaseAI.GeneratedContent
      > {
      return streamResponse(
        to: prompt,
        schema: schema,
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
    /// - Parameter includeSchemaInPrompt: Whether to include the schema in the prompt to the model.
    /// - Parameter options: An optional `GenerationConfig` to override the model's default
    /// generation configuration.
    /// - Returns: A `ResponseStream` that yields snapshots of the generated content.
    public func streamResponse<Content>(to prompt: PartsRepresentable...,
                                        generating type: Content.Type = Content.self,
                                        includeSchemaInPrompt: Bool = true,
                                        options: GenerationConfig? = nil)
      -> sending GenerativeModelSession.ResponseStream<Content, Content.PartiallyGenerated>
      where Content: Generable {
      return streamResponse(
        to: prompt,
        schema: type.generationSchema,
        generating: type,
        includeSchemaInPrompt: includeSchemaInPrompt,
        options: options
      )
    }

    /// Streams the model's response as a `String`.
    ///
    /// **Public Preview**: This API is a public preview and may be subject to change.
    /// - Parameter prompt: The content to send to the model.
    /// - Parameter options: An optional `GenerationConfig` to override the model's default
    /// generation configuration.
    /// - Returns: A `ResponseStream` that yields snapshots of the generated content.
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
    func respond<Content>(to prompt: [PartsRepresentable], schema: GenerationSchema?,
                          generating type: Content.Type, includeSchemaInPrompt: Bool,
                          options: GenerationConfig?) async throws
      -> GenerativeModelSession.Response<Content> {
      let parts = [ModelContent(parts: prompt)]
      let config = try buildConfig(
        options: options,
        schema: schema,
        includeSchemaInPrompt: includeSchemaInPrompt
      )

      let response = try await session.sendMessage(parts, generationConfig: config)
      guard let text = response.text else {
        throw GenerationError.decodingFailure(
          GenerationError.Context(debugDescription: "No text in response: \(response)")
        )
      }
      let generationID = response.responseID.map {
        FirebaseAI.GenerationID(responseID: $0, generationID: GenerationID())
      }

      let rawContent = try Self.makeRawContent(
        from: text,
        generationID: generationID,
        hasSchema: schema != nil
      )
      let content: Content = try Self.resolveContent(from: rawContent)

      return GenerativeModelSession.Response(
        content: content, rawContent: rawContent, rawResponse: response
      )
    }

    private func streamResponse<Content, PartialContent>(to prompt: [PartsRepresentable],
                                                         schema: GenerationSchema?,
                                                         generating type: Content.Type,
                                                         includeSchemaInPrompt: Bool,
                                                         options: GenerationConfig?)
      -> sending GenerativeModelSession.ResponseStream<Content, PartialContent> {
      let parts = [ModelContent(parts: prompt)]
      return GenerativeModelSession.ResponseStream { context in
        do {
          let config = try self.buildConfig(
            options: options,
            schema: schema,
            includeSchemaInPrompt: includeSchemaInPrompt
          )

          let stream = try self.session.sendMessageStream(parts, generationConfig: config)

          var streamedText = ""
          var generationID: FirebaseAI.GenerationID?
          for try await chunk in stream {
            guard let text = chunk.text else {
              throw GenerationError.decodingFailure(
                GenerationError.Context(debugDescription: "No text in response: \(chunk)")
              )
            }
            streamedText.append(text)
            if generationID == nil {
              generationID = chunk.responseID.map {
                FirebaseAI.GenerationID(
                  responseID: $0, generationID: FoundationModels.GenerationID()
                )
              }
            }

            let rawContent = try Self.makeRawContent(
              from: streamedText,
              generationID: generationID,
              hasSchema: schema != nil
            )
            let rawResult = GenerativeModelSession.ResponseStream<Content, PartialContent>
              .RawResult(
                rawContent: rawContent,
                rawResponse: chunk
              )

            await context.yield(rawResult)
          }

          await context.finish()
        } catch {
          await context.finish(throwing: error)
        }
      }
    }

    private func buildConfig(options: GenerationConfig?,
                             schema: GenerationSchema?,
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
                                       hasSchema: Bool) throws -> FirebaseAI.GeneratedContent {
      if hasSchema {
        return try FirebaseAI.GeneratedContent(json: text, id: generationID)
      } else {
        return FirebaseAI.GeneratedContent(kind: .string(text), id: generationID)
      }
    }

    static func resolveContent<T>(from rawContent: FirebaseAI.GeneratedContent) throws -> T {
      if let content = rawContent as? T {
        return content
      } else if let contentMetatype = T
        .self as? (any FoundationModels.ConvertibleFromGeneratedContent.Type),
        let content = try contentMetatype.init(rawContent) as? T {
        return content
      }

      assertionFailure("Unsupported type: \(T.self).")
      // In release builds we throw an error instead of crashing but this state should be
      // unreachable based on the public API.
      throw GenerativeModelSession.ResponseTypeConversionError(
        from: type(of: rawContent), to: T.self
      )
    }
  }

  // MARK: - Response Types

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
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

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
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

        public mutating func next(isolation actor: isolated (any Actor)?) async throws
          -> Snapshot? {
          guard let rawResult = try await rawIterator.next(isolation: actor) else {
            return nil
          }
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

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
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
          return try await withCheckedThrowingContinuation { continuation in
            waitingContinuations.append(continuation)
          }
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

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension GenerativeModelSession {
    enum ErrorCodes: Int {
      // Generation Errors
      case decodingFailure = 1000

      // Internal Errors
      case typeConversionFailed = 2000
    }

    static let errorDomain = "\(Constants.baseErrorDomain).\(GenerativeModelSession.self)"

    /// An error that occurs during content generation.
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
    }

    struct ResponseTypeConversionError: CustomDebugStringConvertible, CustomNSError {
      public static var errorDomain: String { GenerativeModelSession.errorDomain }

      public var errorCode: Int { ErrorCodes.typeConversionFailed.rawValue }

      public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: debugDescription] }

      let debugDescription: String

      init(from fromType: Any.Type, to toType: Any.Type) {
        debugDescription = "Failed to convert from type '\(fromType)' to '\(toType)'."
      }
    }
  }
#endif // compiler(>=6.2) && canImport(FoundationModels)
