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

#if compiler(>=6.2.3)
  import XCTest

  @testable import FirebaseAILogic

  final class HybridModelTests: XCTestCase {
    struct MockModel: LanguageModel {
      let _modelName: String
      let startSessionHandler: @Sendable () throws -> any _ModelSession

      func _startSession(tools: [any ToolRepresentable]?,
                         instructions: String?) throws -> any _ModelSession {
        return try startSessionHandler()
      }
    }

    struct MockSession: _ModelSession {
      var _hasHistory: Bool = false
      let respondHandler: @Sendable () async throws -> _ModelSessionResponse
      let streamHandler: @Sendable () -> AsyncThrowingStream<_ModelSessionResponse, any Error>

      init(_hasHistory: Bool = false,
           respondHandler: @escaping @Sendable () async throws
             -> _ModelSessionResponse = { fatalError("Not implemented") },
           streamHandler: @escaping @Sendable ()
             -> AsyncThrowingStream<_ModelSessionResponse, any Error> = {
               fatalError("Not implemented")
             }) {
        self._hasHistory = _hasHistory
        self.respondHandler = respondHandler
        self.streamHandler = streamHandler
      }

      func _respond(to prompt: [any Part], schema: FirebaseAI.GenerationSchema?,
                    includeSchemaInPrompt: Bool,
                    options: any GenerationOptionsRepresentable)
        async throws -> _ModelSessionResponse {
        return try await respondHandler()
      }

      @available(macOS 12.0, watchOS 8.0, *)
      func _streamResponse(to prompt: [any Part], schema: FirebaseAI.GenerationSchema?,
                           includeSchemaInPrompt: Bool,
                           options: any GenerationOptionsRepresentable)
        -> sending AsyncThrowingStream<_ModelSessionResponse, any Error> {
        return streamHandler()
      }
    }

    func testStartSession_bothSucceed() async throws {
      let session1 = MockSession(
        respondHandler: {
          _ModelSessionResponse(
            rawContent: FirebaseAI.GeneratedContent(kind: .string("primary"), isComplete: true),
            rawResponse: GenerateContentResponse(candidates: [])
          )
        }
      )
      let session2 = MockSession(
        respondHandler: {
          _ModelSessionResponse(
            rawContent: FirebaseAI.GeneratedContent(kind: .string("secondary"), isComplete: true),
            rawResponse: GenerateContentResponse(candidates: [])
          )
        }
      )
      let model1 = MockModel(_modelName: "model1") { session1 }
      let model2 = MockModel(_modelName: "model2") { session2 }
      let hybridModel = HybridModel(primary: model1, secondary: model2)

      let session = try hybridModel._startSession(tools: nil, instructions: nil)

      XCTAssertTrue(session is HybridModelSession)

      // Verify that calling respond uses the primary session.
      let response = try await session._respond(
        to: [],
        schema: nil,
        includeSchemaInPrompt: false,
        options: ResponseGenerationOptions.default
      )
      guard case let .string(text) = response.rawContent.kind else {
        return XCTFail("Unexpected content kind")
      }
      XCTAssertEqual(text, "primary")
    }

    func testStartSession_primaryFails_secondarySucceeds() async throws {
      let session2 = MockSession(
        respondHandler: {
          _ModelSessionResponse(
            rawContent: FirebaseAI.GeneratedContent(kind: .string("secondary"), isComplete: true),
            rawResponse: GenerateContentResponse(candidates: [])
          )
        }
      )
      let model1 = MockModel(_modelName: "model1") { throw NSError(domain: "test", code: 1) }
      let model2 = MockModel(_modelName: "model2") { session2 }
      let hybridModel = HybridModel(primary: model1, secondary: model2)

      let session = try hybridModel._startSession(tools: nil, instructions: nil)

      XCTAssertTrue(session is HybridModelSession)

      // Verify that calling respond falls back to the secondary session.
      let response = try await session._respond(
        to: [],
        schema: nil,
        includeSchemaInPrompt: false,
        options: ResponseGenerationOptions.default
      )
      guard case let .string(text) = response.rawContent.kind else {
        return XCTFail("Unexpected content kind")
      }
      XCTAssertEqual(text, "secondary")
    }

    func testStartSession_primarySucceeds_secondaryFails() async throws {
      let session1 = MockSession(
        respondHandler: {
          _ModelSessionResponse(
            rawContent: FirebaseAI.GeneratedContent(kind: .string("primary"), isComplete: true),
            rawResponse: GenerateContentResponse(candidates: [])
          )
        }
      )
      let model1 = MockModel(_modelName: "model1") { session1 }
      let model2 = MockModel(_modelName: "model2") { throw NSError(domain: "test", code: 2) }
      let hybridModel = HybridModel(primary: model1, secondary: model2)

      let session = try hybridModel._startSession(tools: nil, instructions: nil)

      XCTAssertTrue(session is HybridModelSession)

      // Verify that calling respond uses the primary session.
      let response = try await session._respond(
        to: [],
        schema: nil,
        includeSchemaInPrompt: false,
        options: ResponseGenerationOptions.default
      )
      guard case let .string(text) = response.rawContent.kind else {
        return XCTFail("Unexpected content kind")
      }
      XCTAssertEqual(text, "primary")
    }

    func testStartSession_bothFail() async throws {
      let model1 = MockModel(_modelName: "model1") {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error 1"])
      }
      let model2 = MockModel(_modelName: "model2") {
        throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error 2"])
      }
      let hybridModel = HybridModel(primary: model1, secondary: model2)

      let session = try hybridModel._startSession(tools: nil, instructions: nil)

      XCTAssertTrue(session is HybridModelSession)

      // Verify that calling respond throws an error.
      do {
        _ = try await session._respond(
          to: [],
          schema: nil,
          includeSchemaInPrompt: false,
          options: ResponseGenerationOptions.default
        )
        XCTFail("Expected error but succeeded")
      } catch {
        let nsError = error as NSError
        XCTAssertEqual(nsError.code, 2) // Error from model2
      }
    }

    func testStartSession_lazyInitialization() async throws {
      final class CallTracker: @unchecked Sendable {
        var count = 0
      }
      let tracker1 = CallTracker()
      let tracker2 = CallTracker()
      let model1 = MockModel(_modelName: "model1") {
        tracker1.count += 1
        return MockSession(
          respondHandler: {
            _ModelSessionResponse(
              rawContent: FirebaseAI.GeneratedContent(kind: .string("primary"), isComplete: true),
              rawResponse: GenerateContentResponse(candidates: [])
            )
          }
        )
      }
      let model2 = MockModel(_modelName: "model2") {
        tracker2.count += 1
        return MockSession()
      }
      let hybridModel = HybridModel(primary: model1, secondary: model2)

      let session = try hybridModel._startSession(tools: nil, instructions: nil)

      XCTAssertTrue(session is HybridModelSession)
      XCTAssertEqual(tracker1.count, 0)
      XCTAssertEqual(tracker2.count, 0)

      // Verify that calling respond creates the primary session lazily.
      _ = try await session._respond(
        to: [],
        schema: nil,
        includeSchemaInPrompt: false,
        options: ResponseGenerationOptions.default
      )

      XCTAssertEqual(tracker1.count, 1)
      XCTAssertEqual(tracker2.count, 0)
    }

    @available(macOS 12.0, watchOS 8.0, *)
    func testStreamResponse_bothSucceed() async throws {
      // Skip this test on platforms that do not support streaming with `_streamResponse)`. This is
      // a workaround for XCTest ignoring the `@available` attributes. See
      // https://stackoverflow.com/q/59645536 for more details.
      try XCTSkipStreamingUnsupported()

      let session1 = MockSession(
        streamHandler: {
          AsyncThrowingStream { continuation in
            continuation.yield(
              _ModelSessionResponse(
                rawContent: FirebaseAI.GeneratedContent(kind: .string("primary"), isComplete: true),
                rawResponse: GenerateContentResponse(candidates: [])
              )
            )
            continuation.finish()
          }
        }
      )
      let session2 = MockSession(
        streamHandler: {
          AsyncThrowingStream { continuation in
            continuation.yield(
              _ModelSessionResponse(
                rawContent: FirebaseAI.GeneratedContent(
                  kind: .string("secondary"),
                  isComplete: true
                ),
                rawResponse: GenerateContentResponse(candidates: [])
              )
            )
            continuation.finish()
          }
        }
      )
      let model1 = MockModel(_modelName: "model1") { session1 }
      let model2 = MockModel(_modelName: "model2") { session2 }
      let hybridModel = HybridModel(primary: model1, secondary: model2)

      let session = try hybridModel._startSession(tools: nil, instructions: nil)

      XCTAssertTrue(session is HybridModelSession)

      let stream = session._streamResponse(
        to: [],
        schema: nil,
        includeSchemaInPrompt: false,
        options: ResponseGenerationOptions.default
      )

      var receivedTexts = [String]()
      for try await response in stream {
        guard case let .string(text) = response.rawContent.kind else {
          return XCTFail("Unexpected content kind")
        }
        receivedTexts.append(text)
      }

      XCTAssertEqual(receivedTexts, ["primary"])
    }

    @available(macOS 12.0, watchOS 8.0, *)
    func testStreamResponse_primaryFails_secondarySucceeds() async throws {
      // Skip this test on platforms that do not support streaming with `_streamResponse)`. This is
      // a workaround for XCTest ignoring the `@available` attributes. See
      // https://stackoverflow.com/q/59645536 for more details.
      try XCTSkipStreamingUnsupported()

      let session2 = MockSession(
        streamHandler: {
          AsyncThrowingStream { continuation in
            continuation.yield(
              _ModelSessionResponse(
                rawContent: FirebaseAI.GeneratedContent(
                  kind: .string("secondary"),
                  isComplete: true
                ),
                rawResponse: GenerateContentResponse(candidates: [])
              )
            )
            continuation.finish()
          }
        }
      )
      let model1 = MockModel(_modelName: "model1") {
        let session = MockSession(
          streamHandler: {
            AsyncThrowingStream { continuation in
              continuation.finish(throwing: NSError(domain: "test", code: 1))
            }
          }
        )
        return session
      }
      let model2 = MockModel(_modelName: "model2") { session2 }
      let hybridModel = HybridModel(primary: model1, secondary: model2)

      let session = try hybridModel._startSession(tools: nil, instructions: nil)

      XCTAssertTrue(session is HybridModelSession)

      let stream = session._streamResponse(
        to: [],
        schema: nil,
        includeSchemaInPrompt: false,
        options: ResponseGenerationOptions.default
      )

      var receivedTexts = [String]()
      for try await response in stream {
        guard case let .string(text) = response.rawContent.kind else {
          return XCTFail("Unexpected content kind")
        }
        receivedTexts.append(text)
      }

      XCTAssertEqual(receivedTexts, ["secondary"])
    }
  }
#endif // compiler(>=6.2.3)
