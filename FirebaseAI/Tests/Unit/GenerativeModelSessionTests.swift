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

#if compiler(>=6.2) && canImport(FoundationModels)
  import FoundationModels
  import XCTest

  @testable import FirebaseAILogic

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  final class GenerativeModelSessionTests: XCTestCase {
    let testPrompt = "What sorts of questions can I ask you?"
    let testModelName = "test-model"
    let testModelResourceName =
      "projects/test-project-id/locations/test-location/publishers/google/models/test-model"
    let apiConfig = FirebaseAI.defaultVertexAIAPIConfig

    let vertexSubdirectory = "mock-responses/vertexai"

    var urlSession: URLSession!

    override func setUp() async throws {
      let configuration = URLSessionConfiguration.default
      configuration.protocolClasses = [MockURLProtocol.self]
      urlSession = try XCTUnwrap(URLSession(configuration: configuration))
    }

    override func tearDown() {
      MockURLProtocol.requestHandler = nil
    }

    @Generable
    struct Empty {}

    func testRespondTo_functionCall_emptyArguments() async throws {
      struct CurrentTimeTool: FoundationModels.Tool {
        let name = "current_time"
        let description = "Returns the current time in ISO 8601 format."

        static let currentTime = "13:30:00-07:00" // 1:30 PM, PDT

        func call(arguments: Empty) async throws -> String {
          return CurrentTimeTool.currentTime
        }
      }
      MockURLProtocol.requestHandlersQueue = try [
        GenerativeModelTestUtil.httpRequestHandler(
          forResource: "unary-success-function-call-empty-arguments", withExtension: "json",
          subdirectory: vertexSubdirectory
        ),
        GenerativeModelTestUtil.httpRequestHandler(
          forResource: "unary-success-basic-reply-short", withExtension: "json",
          subdirectory: vertexSubdirectory
        ),
      ]
      let currentTimeTool = CurrentTimeTool()
      let model = try mockGenerativeModel(tools: .autoFunctionDeclaration(CurrentTimeTool()))
      let session = GenerativeModelSession(model: model)

      let response = try await session.respond(to: testPrompt)

      XCTAssertEqual(response.content, "Mountain View, California")
      var functionCalls = [FunctionCall]()
      var functionResponses = [FunctionResponse]()
      for content in session.session.history {
        for part in content.internalParts {
          switch part.data {
          case let .functionCall(functionCall):
            functionCalls.append(functionCall)
          case let .functionResponse(functionResponse):
            functionResponses.append(functionResponse)
          default:
            continue
          }
        }
      }
      XCTAssertEqual(functionCalls.count, 1)
      let functionCall = try XCTUnwrap(functionCalls.first)
      XCTAssertNil(functionCall.id)
      XCTAssertEqual(functionCall.name, currentTimeTool.name)
      XCTAssertEqual(functionCall.args, [:])
      XCTAssertEqual(functionResponses.count, 1)
      let functionResponse = try XCTUnwrap(functionResponses.first)
      XCTAssertNil(functionResponse.id)
      XCTAssertEqual(functionResponse.name, functionCall.name)
      XCTAssertEqual(functionResponse.response, ["result": .string(CurrentTimeTool.currentTime)])
    }

    // MARK: - Helper Utilities

    func mockGenerativeModel(modelName: String? = nil, modelResourceName: String? = nil,
                             firebaseInfo: FirebaseInfo? = nil, apiConfig: APIConfig? = nil,
                             tools: ToolRepresentable..., requestOptions: RequestOptions? = nil,
                             urlSession: URLSession? = nil) throws -> GenerativeModel {
      return GenerativeModel(
        modelName: modelName ?? testModelName,
        modelResourceName: modelResourceName ?? testModelResourceName,
        firebaseInfo: firebaseInfo ?? GenerativeModelTestUtil.testFirebaseInfo(),
        apiConfig: apiConfig ?? self.apiConfig,
        tools: tools.isEmpty ? nil : tools.asFirebaseTools(),
        requestOptions: requestOptions ?? RequestOptions(),
        urlSession: urlSession ?? self.urlSession
      )
    }
  }

  extension [any ToolRepresentable] {
    func asFirebaseTools() -> [FirebaseAILogic.Tool] {
      return self.map { $0.toolRepresentation }
    }
  }
#endif // compiler(>=6.2) && canImport(FoundationModels)
