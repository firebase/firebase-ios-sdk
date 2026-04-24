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

      func _respond(to prompt: [any Part], schema: FirebaseAI.GenerationSchema?,
                    includeSchemaInPrompt: Bool,
                    options: any GenerationOptionsRepresentable)
        async throws -> _ModelSessionResponse {
        fatalError("Not implemented")
      }

      func _streamResponse(to prompt: [any Part], schema: FirebaseAI.GenerationSchema?,
                           includeSchemaInPrompt: Bool,
                           options: any GenerationOptionsRepresentable)
        -> sending AsyncThrowingStream<_ModelSessionResponse, any Error> {
        fatalError("Not implemented")
      }
    }

    func testStartSession_bothSucceed() throws {
      let session1 = MockSession()
      let session2 = MockSession()
      let model1 = MockModel(_modelName: "model1") { session1 }
      let model2 = MockModel(_modelName: "model2") { session2 }
      let hybridModel = HybridModel(primary: model1, secondary: model2)

      let session = try hybridModel._startSession(tools: nil, instructions: nil)

      XCTAssertTrue(session is HybridModelSession)
    }

    func testStartSession_primaryFails_secondarySucceeds() throws {
      let session2 = MockSession()
      let model1 = MockModel(_modelName: "model1") { throw NSError(domain: "test", code: 1) }
      let model2 = MockModel(_modelName: "model2") { session2 }
      let hybridModel = HybridModel(primary: model1, secondary: model2)

      let session = try hybridModel._startSession(tools: nil, instructions: nil)

      XCTAssertTrue(session is MockSession)
    }

    func testStartSession_primarySucceeds_secondaryFails() throws {
      let session1 = MockSession()
      let model1 = MockModel(_modelName: "model1") { session1 }
      let model2 = MockModel(_modelName: "model2") { throw NSError(domain: "test", code: 2) }
      let hybridModel = HybridModel(primary: model1, secondary: model2)

      let session = try hybridModel._startSession(tools: nil, instructions: nil)

      XCTAssertTrue(session is MockSession)
    }

    func testStartSession_bothFail() throws {
      let model1 = MockModel(_modelName: "model1") {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error 1"])
      }
      let model2 = MockModel(_modelName: "model2") {
        throw NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error 2"])
      }
      let hybridModel = HybridModel(primary: model1, secondary: model2)

      XCTAssertThrowsError(try hybridModel._startSession(tools: nil, instructions: nil)) { error in
        guard case let GenerativeModelSession.GenerationError.assetsUnavailable(context)
          = error else {
          return XCTFail("Unexpected error type: \(error)")
        }
        XCTAssertTrue(context.debugDescription.contains("Error 1"))
        XCTAssertTrue(context.debugDescription.contains("Error 2"))
      }
    }
  }
#endif // compiler(>=6.2.3)
