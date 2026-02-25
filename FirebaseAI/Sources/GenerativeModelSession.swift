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

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public final class GenerativeModelSession: Sendable {
    let session: Chat

    public init(model: GenerativeModel) {
      session = model.startChat()
    }

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

    public enum GenerationError: Error, LocalizedError {
      public struct Context: Sendable {
        public let debugDescription: String

        init(debugDescription: String) {
          self.debugDescription = debugDescription
        }
      }

      case decodingFailure(GenerativeModelSession.GenerationError.Context)
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

      let rawContent = try Self.makeRawContent(from: text, hasSchema: schema != nil)
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
          for try await chunk in stream {
            guard let text = chunk.text else {
              throw GenerationError.decodingFailure(
                GenerationError.Context(debugDescription: "No text in response: \(chunk)")
              )
            }
            streamedText.append(text)

            let rawContent = try Self.makeRawContent(from: streamedText, hasSchema: schema != nil)
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

    private static func makeRawContent(from text: String, hasSchema: Bool) throws -> FirebaseAI
      .GeneratedContent {
      if hasSchema {
        return try FirebaseAI.GeneratedContent(json: text)
      } else {
        return FirebaseAI.GeneratedContent(kind: .string(text))
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
      throw GenerativeModelSession.ResponseStreamError.noContentGenerated
    }
  }

  // MARK: - Response Types

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public extension GenerativeModelSession {
    struct Response<Content> {
      public let content: Content
      public let rawContent: FirebaseAI.GeneratedContent
      public let rawResponse: GenerateContentResponse
    }
  }

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public extension GenerativeModelSession {
    struct ResponseStream<Content, PartialContent>: AsyncSequence {
      public typealias Element = Snapshot

      public struct Snapshot {
        public let content: PartialContent
        public let rawContent: FirebaseAI.GeneratedContent
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

    enum ResponseStreamError: Error {
      case noContentGenerated
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
          result = .failure(GenerativeModelSession.ResponseStreamError.noContentGenerated)
        }

        finalResult = result

        for continuation in waitingContinuations {
          continuation.resume(with: result)
        }
        waitingContinuations.removeAll()
      }
    }
  }
#endif // compiler(>=6.2) && canImport(FoundationModels)
