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
    public final nonisolated(nonsending)
    func respond(to prompt: PartsRepresentable..., options: GenerationConfig? = nil) async throws
      -> GenerativeModelSession.Response<String> {
      let parts = [ModelContent(parts: prompt)]

      var config = GenerationConfig.merge(
        session.generationConfig, with: options
      ) ?? GenerationConfig()
      config.responseModalities = nil // Override to the default (text only)
      config.candidateCount = nil // Override to the default (one candidate)

      let response = try await session.sendMessage(parts, generationConfig: config)
      guard let text = response.text else {
        throw GenerationError.decodingFailure(
          GenerationError.Context(debugDescription: "No text in response: \(response)")
        )
      }
      let generatedContent = GeneratedContent(kind: .string(text))

      return GenerativeModelSession.Response(
        content: text, rawContent: generatedContent, rawResponse: response
      )
    }

    @discardableResult
    public final nonisolated(nonsending)
    func respond(to prompt: PartsRepresentable..., schema: GenerationSchema,
                 includeSchemaInPrompt: Bool = true, options: GenerationConfig? = nil) async throws
      -> GenerativeModelSession.Response<GeneratedContent> {
      let parts = [ModelContent(parts: prompt)]
      var config = GenerationConfig.merge(
        session.generationConfig, with: options
      ) ?? GenerationConfig()
      config.responseMIMEType = "application/json"
      config.responseJSONSchema = includeSchemaInPrompt ? try schema.toGeminiJSONSchema() : nil
      config.responseSchema = nil // `responseSchema` must not be set with `responseJSONSchema`
      config.responseModalities = nil // Override to the default (text only)
      config.candidateCount = nil // Override to the default (one candidate)

      let response = try await session.sendMessage(parts, generationConfig: config)
      guard let text = response.text else {
        throw GenerationError.decodingFailure(
          GenerationError.Context(debugDescription: "No text in response: \(response)")
        )
      }
      let generatedContent = try GeneratedContent(json: text)

      return GenerativeModelSession.Response(
        content: generatedContent, rawContent: generatedContent, rawResponse: response
      )
    }

    @discardableResult
    public final nonisolated(nonsending)
    func respond<Content>(to prompt: PartsRepresentable...,
                          generating type: Content.Type = Content.self,
                          includeSchemaInPrompt: Bool = true,
                          options: GenerationConfig? = nil) async throws
      -> GenerativeModelSession.Response<Content> where Content: Generable {
      let response = try await respond(
        to: prompt,
        schema: type.generationSchema,
        includeSchemaInPrompt: includeSchemaInPrompt,
        options: options
      )

      let content = try Content(response.rawContent)

      return GenerativeModelSession.Response(
        content: content, rawContent: response.rawContent, rawResponse: response.rawResponse
      )
    }

    public final func streamResponse(to prompt: PartsRepresentable...,
                                     schema: GenerationSchema,
                                     includeSchemaInPrompt: Bool = true,
                                     options: GenerationConfig? = nil)
      -> sending GenerativeModelSession.ResponseStream<GeneratedContent> {
      let parts = [ModelContent(parts: prompt)]
      return GenerativeModelSession.ResponseStream { context in
        do {
          var config = GenerationConfig.merge(
            self.session.generationConfig, with: options
          ) ?? GenerationConfig()
          config.responseMIMEType = "application/json"
          config.responseJSONSchema = includeSchemaInPrompt ? try schema.toGeminiJSONSchema() : nil
          config.responseSchema = nil // `responseSchema` must not be set with `responseJSONSchema`
          config.responseModalities = nil // Override to the default (text only)
          config.candidateCount = nil // Override to the default (one candidate)

          let stream = try self.session.sendMessageStream(parts, generationConfig: config)

          var json = ""
          for try await chunk in stream {
            guard let text = chunk.text else {
              throw GenerationError.decodingFailure(
                GenerationError.Context(debugDescription: "No text in response: \(chunk)")
              )
            }
            json.append(text)

            let generatedContent = try GeneratedContent(json: json)

            let rawResult = GenerativeModelSession.ResponseStream<GeneratedContent>.RawResult(
              rawContent: generatedContent,
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

    public enum GenerationError: Error, LocalizedError {
      public struct Context: Sendable {
        public let debugDescription: String

        init(debugDescription: String) {
          self.debugDescription = debugDescription
        }
      }

      case decodingFailure(GenerativeModelSession.GenerationError.Context)
    }
  }

  // MARK: - Response Types

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public extension GenerativeModelSession {
    struct Response<Content> where Content: Generable {
      public let content: Content
      public let rawContent: GeneratedContent
      public let rawResponse: GenerateContentResponse
    }
  }

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public extension GenerativeModelSession {
    struct ResponseStream<Content>: AsyncSequence where Content: Generable {
      public typealias Element = Snapshot

      public struct Snapshot {
        public let content: Content.PartiallyGenerated
        public let rawContent: GeneratedContent
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
          let partialContent = try Content.PartiallyGenerated(rawResult.rawContent)

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
        let content = try Content(finalResult.rawContent)

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
      let rawContent: GeneratedContent
      let rawResponse: GenerateContentResponse
    }

    actor StreamContext {
      private let continuation: AsyncThrowingStream<RawResult, Error>.Continuation
      private var _finalResult: Result<RawResult, Error>?
      private var _waitingContinuations: [CheckedContinuation<RawResult, Error>] = []
      private var _latestRaw: RawResult?

      init(continuation: AsyncThrowingStream<RawResult, Error>.Continuation) {
        self.continuation = continuation
      }

      func yield(_ rawResult: RawResult) {
        _latestRaw = rawResult
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
          if let result = _finalResult {
            return try result.get()
          }
          return try await withCheckedThrowingContinuation { continuation in
            _waitingContinuations.append(continuation)
          }
        }
      }

      private func finalize(with error: Error?) {
        let result: Result<RawResult, Error>

        if let error = error {
          result = .failure(error)
        } else if let last = _latestRaw {
          result = .success(last)
        } else {
          result = .failure(ResponseStreamError.noContentGenerated)
        }

        _finalResult = result

        for continuation in _waitingContinuations {
          continuation.resume(with: result)
        }
        _waitingContinuations.removeAll()
      }
    }

    enum ResponseStreamError: Error {
      case noContentGenerated
    }
  }
#endif // compiler(>=6.2) && canImport(FoundationModels)
