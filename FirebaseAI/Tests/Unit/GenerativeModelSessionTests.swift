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

#if compiler(>=6.2.3) && canImport(FoundationModels)
  import FoundationModels
  import XCTest

  @testable import FirebaseAILogic

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  final class GenerativeModelSessionTests: XCTestCase {
    let testPrompt = "What sorts of questions can I ask you?"
    let testModelName = "test-model"
    let testModelResourceName = "projects/test-project-id/models/test-model"
    let apiConfig = FirebaseAI.defaultVertexAIAPIConfig

    let googleAISubdirectory = "mock-responses/googleai"

    var urlSession: URLSession!

    override func setUp() async throws {
      // Skip tests on platforms that do not support Foundation Models. This is a
      // workaround for XCTest ignoring the `@available` attributes. See
      // https://stackoverflow.com/q/59645536 for more details.
      try XCTSkipFoundationModelsUnsupported()

      let configuration = URLSessionConfiguration.default
      configuration.protocolClasses = [MockURLProtocol.self]
      urlSession = try XCTUnwrap(URLSession(configuration: configuration))
    }

    override func tearDown() {
      MockURLProtocol.requestHandler = nil
    }

    @Generable
    struct Empty {}

    struct CurrentTimeTool: FoundationModels.Tool {
      let name = "now"
      let description = "Returns the current time in ISO 8601 format."

      static let currentTime = "13:30:00-07:00" // 1:30 PM, PDT

      func call(arguments: Empty) async throws -> String {
        return CurrentTimeTool.currentTime
      }
    }

    func testRespondTo_functionCall() async throws {
      MockURLProtocol.requestHandlersQueue = try [
        GenerativeModelTestUtil.httpRequestHandler(
          forResource: "unary-success-thinking-function-call-thought-summary-signature",
          withExtension: "json",
          subdirectory: googleAISubdirectory
        ),
        GenerativeModelTestUtil.httpRequestHandler(
          forResource: "unary-success-thinking-reply-thought-summary",
          withExtension: "json",
          subdirectory: googleAISubdirectory
        ),
      ]
      let currentTimeTool = CurrentTimeTool()
      let model = try mockGeminiModel()
      let session = GenerativeModelSession(
        model: model,
        tools: [.autoFunctionDeclaration(currentTimeTool)],
        instructions: nil
      )

      let response = try await session.respond(to: testPrompt)

      XCTAssertEqual(response.content, "Mountain View")
      var functionCalls = [FunctionCall]()
      var functionResponses = [FunctionResponse]()
      let modelSession = try XCTUnwrap(
        session.sessionManager.getOrStartSession(instructions: nil)
      )
      let geminiSession = try XCTUnwrap(modelSession as? GeminiModelSession)
      for content in geminiSession.chat.history {
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

    func testRespondTo_functionCall_sequentialCalls() async throws {
      MockURLProtocol.requestHandlersQueue = try Array(
        repeating: GenerativeModelTestUtil.httpRequestHandler(
          forResource: "unary-success-thinking-function-call-thought-summary-signature",
          withExtension: "json",
          subdirectory: googleAISubdirectory
        ),
        count: GenerativeModelSession.maxAutoFunctionCallTurns
      )
      try MockURLProtocol.requestHandlersQueue.append(GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-thinking-reply-thought-summary", withExtension: "json",
        subdirectory: googleAISubdirectory
      ))
      let currentTimeTool = CurrentTimeTool()
      let model = try mockGeminiModel()
      let session = GenerativeModelSession(
        model: model,
        tools: [.autoFunctionDeclaration(currentTimeTool)],
        instructions: nil
      )

      let response = try await session.respond(to: testPrompt)

      XCTAssertEqual(response.content, "Mountain View")
      var functionCalls = [FunctionCall]()
      var functionResponses = [FunctionResponse]()
      let modelSession = try XCTUnwrap(
        session.sessionManager.getOrStartSession(instructions: nil)
      )
      let geminiSession = try XCTUnwrap(modelSession as? GeminiModelSession)
      for content in geminiSession.chat.history {
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
      XCTAssertEqual(functionCalls.count, GenerativeModelSession.maxAutoFunctionCallTurns)
      let functionCall = try XCTUnwrap(functionCalls.first)
      XCTAssertNil(functionCall.id)
      XCTAssertEqual(functionCall.name, currentTimeTool.name)
      XCTAssertEqual(functionCall.args, [:])
      XCTAssertEqual(functionResponses.count, GenerativeModelSession.maxAutoFunctionCallTurns)
      let functionResponse = try XCTUnwrap(functionResponses.first)
      XCTAssertNil(functionResponse.id)
      XCTAssertEqual(functionResponse.name, functionCall.name)
      XCTAssertEqual(functionResponse.response, ["result": .string(CurrentTimeTool.currentTime)])
    }

    func testRespondTo_functionCall_maxFunctionCallTurnsExceeded() async throws {
      let functionCallCount = GenerativeModelSession.maxAutoFunctionCallTurns + 1
      MockURLProtocol.requestHandlersQueue = try Array(
        repeating: GenerativeModelTestUtil.httpRequestHandler(
          forResource: "unary-success-thinking-function-call-thought-summary-signature",
          withExtension: "json",
          subdirectory: googleAISubdirectory
        ),
        count: functionCallCount
      )
      try MockURLProtocol.requestHandlersQueue.append(GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-thinking-reply-thought-summary", withExtension: "json",
        subdirectory: googleAISubdirectory
      ))
      let currentTimeTool = CurrentTimeTool()
      let model = try mockGeminiModel()
      let session = GenerativeModelSession(
        model: model,
        tools: [.autoFunctionDeclaration(currentTimeTool)],
        instructions: nil
      )

      await XCTAssertThrowsError {
        try await session.respond(to: testPrompt)
      } errorHandler: { error in
        guard case let GenerativeModelSession.GenerationError.internalError(
          context,
          underlyingError: underlyingError
        ) = error, let functionCallingError =
          underlyingError as? GenerativeModelSession.FunctionCallingError else {
          return XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertContains(
          context.debugDescription,
          "\(GenerativeModelSession.maxAutoFunctionCallTurns)"
        )
        XCTAssertEqual(
          functionCallingError,
          GenerativeModelSession.FunctionCallingError.maxFunctionCallTurnsExceeded
        )
      }

      var functionCalls = [FunctionCall]()
      var functionResponses = [FunctionResponse]()
      let modelSession = try XCTUnwrap(
        session.sessionManager.getOrStartSession(instructions: nil)
      )
      let geminiSession = try XCTUnwrap(modelSession as? GeminiModelSession)
      for content in geminiSession.chat.history {
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
      XCTAssertEqual(functionCalls.count, functionCallCount)
      let functionCall = try XCTUnwrap(functionCalls.first)
      XCTAssertNil(functionCall.id)
      XCTAssertEqual(functionCall.name, currentTimeTool.name)
      XCTAssertEqual(functionCall.args, [:])
      XCTAssertEqual(functionResponses.count, GenerativeModelSession.maxAutoFunctionCallTurns)
      let functionResponse = try XCTUnwrap(functionResponses.first)
      XCTAssertNil(functionResponse.id)
      XCTAssertEqual(functionResponse.name, functionCall.name)
      XCTAssertEqual(functionResponse.response, ["result": .string(CurrentTimeTool.currentTime)])
    }

    func testRespondTo_withOptions() async throws {
      let config = GenerationConfig(temperature: 0.5, responseMIMEType: "application/json")
      let bundle = BundleTestUtil.bundle()
      let fileURL = try XCTUnwrap(bundle.url(
        forResource: "unary-success-thinking-reply-thought-summary",
        withExtension: "json",
        subdirectory: googleAISubdirectory
      ))
      MockURLProtocol.requestHandler = { request in
        let requestBody = try XCTUnwrap(request.extractBodyData(), "Empty request body.")
        let requestURL = try XCTUnwrap(request.url)
        let response = try XCTUnwrap(HTTPURLResponse(
          url: requestURL,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        ))

        let json = try JSONDecoder().decode(JSONObject.self, from: requestBody)
        guard case let .object(generationConfig) = json["generationConfig"] else {
          XCTFail("Expected an object for JSON key 'generationConfig', got: \(json)")
          return (response, nil)
        }
        guard case let .number(temperature) = generationConfig["temperature"] else {
          XCTFail("Expected a number for JSON key 'temperature', got: \(json)")
          return (response, nil)
        }
        XCTAssertEqual(Float(temperature), config.temperature)
        guard case let .string(responseMIMEType) = generationConfig["responseMimeType"] else {
          XCTFail("Expected a string for JSON key 'responseMimeType', got: \(json)")
          return (response, nil)
        }
        XCTAssertEqual(responseMIMEType, config.responseMIMEType)

        return (response, fileURL.lines)
      }
      let model = try mockGeminiModel()
      let session = GenerativeModelSession(model: model, tools: nil, instructions: nil)

      let response = try await session.respond(to: testPrompt, options: .gemini(config))

      XCTAssertEqual(response.content, "Mountain View")
    }

    func testStreamResponseTo_functionCall() async throws {
      MockURLProtocol.requestHandlersQueue = try [
        GenerativeModelTestUtil.httpRequestHandler(
          forResource: "streaming-success-thinking-function-call-thought-summary-signature",
          withExtension: "txt",
          subdirectory: googleAISubdirectory
        ),
        GenerativeModelTestUtil.httpRequestHandler(
          forResource: "streaming-success-thinking-reply-thought-summary",
          withExtension: "txt",
          subdirectory: googleAISubdirectory
        ),
      ]
      let currentTimeTool = CurrentTimeTool()
      let model = try mockGeminiModel()
      let session = GenerativeModelSession(
        model: model,
        tools: [.autoFunctionDeclaration(currentTimeTool)],
        instructions: nil
      )

      let stream = session.streamResponse(to: testPrompt)
      let response = try await stream.collect()

      XCTAssertContains(response.content, """
      gas molecules in Earth's atmosphere scatter blue light from the sun more efficiently than \
      other colors. Blue light has shorter
      """)
      var functionCalls = [FunctionCall]()
      var functionResponses = [FunctionResponse]()
      let modelSession = try XCTUnwrap(
        session.sessionManager.getOrStartSession(instructions: nil)
      )
      let geminiSession = try XCTUnwrap(modelSession as? GeminiModelSession)
      for content in geminiSession.chat.history {
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

    func testStreamResponseTo_functionCall_sequentialCalls() async throws {
      MockURLProtocol.requestHandlersQueue = try Array(
        repeating: GenerativeModelTestUtil.httpRequestHandler(
          forResource: "streaming-success-thinking-function-call-thought-summary-signature",
          withExtension: "txt",
          subdirectory: googleAISubdirectory
        ),
        count: GenerativeModelSession.maxAutoFunctionCallTurns
      )
      try MockURLProtocol.requestHandlersQueue.append(GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-success-thinking-reply-thought-summary",
        withExtension: "txt",
        subdirectory: googleAISubdirectory
      ))
      let currentTimeTool = CurrentTimeTool()
      let model = try mockGeminiModel()
      let session = GenerativeModelSession(
        model: model,
        tools: [.autoFunctionDeclaration(currentTimeTool)],
        instructions: nil
      )

      let stream = session.streamResponse(to: testPrompt)
      let response = try await stream.collect()

      XCTAssertContains(response.content, """
      gas molecules in Earth's atmosphere scatter blue light from the sun more efficiently than \
      other colors. Blue light has shorter
      """)
      var functionCalls = [FunctionCall]()
      var functionResponses = [FunctionResponse]()
      let modelSession = try XCTUnwrap(
        session.sessionManager.getOrStartSession(instructions: nil)
      )
      let geminiSession = try XCTUnwrap(modelSession as? GeminiModelSession)
      for content in geminiSession.chat.history {
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
      XCTAssertEqual(functionCalls.count, GenerativeModelSession.maxAutoFunctionCallTurns)
      let functionCall = try XCTUnwrap(functionCalls.first)
      XCTAssertNil(functionCall.id)
      XCTAssertEqual(functionCall.name, currentTimeTool.name)
      XCTAssertEqual(functionCall.args, [:])
      XCTAssertEqual(functionResponses.count, GenerativeModelSession.maxAutoFunctionCallTurns)
      let functionResponse = try XCTUnwrap(functionResponses.first)
      XCTAssertNil(functionResponse.id)
      XCTAssertEqual(functionResponse.name, functionCall.name)
      XCTAssertEqual(functionResponse.response, ["result": .string(CurrentTimeTool.currentTime)])
    }

    func testStreamResponseTo_functionCall_maxFunctionCallTurnsExceeded() async throws {
      let functionCallCount = GenerativeModelSession.maxAutoFunctionCallTurns + 1
      MockURLProtocol.requestHandlersQueue = try Array(
        repeating: GenerativeModelTestUtil.httpRequestHandler(
          forResource: "streaming-success-thinking-function-call-thought-summary-signature",
          withExtension: "txt",
          subdirectory: googleAISubdirectory
        ),
        count: functionCallCount
      )
      try MockURLProtocol.requestHandlersQueue.append(GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-success-thinking-reply-thought-summary",
        withExtension: "txt",
        subdirectory: googleAISubdirectory
      ))
      let currentTimeTool = CurrentTimeTool()
      let model = try mockGeminiModel()
      let session = GenerativeModelSession(
        model: model,
        tools: [.autoFunctionDeclaration(currentTimeTool)],
        instructions: nil
      )

      await XCTAssertThrowsError {
        let stream = session.streamResponse(to: testPrompt)
        _ = try await stream.collect()
      } errorHandler: { error in
        guard case let GenerativeModelSession.GenerationError.internalError(
          context,
          underlyingError: underlyingError
        ) = error, let functionCallingError =
          underlyingError as? GenerativeModelSession.FunctionCallingError else {
          return XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertContains(
          context.debugDescription,
          "\(GenerativeModelSession.maxAutoFunctionCallTurns)"
        )
        XCTAssertEqual(
          functionCallingError,
          GenerativeModelSession.FunctionCallingError.maxFunctionCallTurnsExceeded
        )
      }

      var functionCalls = [FunctionCall]()
      var functionResponses = [FunctionResponse]()
      let modelSession = try XCTUnwrap(
        session.sessionManager.getOrStartSession(instructions: nil)
      )
      let geminiSession = try XCTUnwrap(modelSession as? GeminiModelSession)
      for content in geminiSession.chat.history {
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
      XCTAssertEqual(functionCalls.count, functionCallCount)
      let functionCall = try XCTUnwrap(functionCalls.first)
      XCTAssertNil(functionCall.id)
      XCTAssertEqual(functionCall.name, currentTimeTool.name)
      XCTAssertEqual(functionCall.args, [:])
      XCTAssertEqual(functionResponses.count, GenerativeModelSession.maxAutoFunctionCallTurns)
      let functionResponse = try XCTUnwrap(functionResponses.first)
      XCTAssertNil(functionResponse.id)
      XCTAssertEqual(functionResponse.name, functionCall.name)
      XCTAssertEqual(functionResponse.response, ["result": .string(CurrentTimeTool.currentTime)])
    }

    // MARK: - Helper Utilities

    func mockGeminiModel(modelName: String? = nil, modelResourceName: String? = nil,
                         firebaseInfo: FirebaseInfo? = nil, apiConfig: APIConfig? = nil,
                         safetySettings: [SafetySetting]? = nil,
                         requestOptions: RequestOptions? = nil, urlSession: URLSession? = nil)
      throws -> GeminiModel {
      return GeminiModel(
        modelName: modelName ?? testModelName,
        modelResourceName: modelResourceName ?? testModelResourceName,
        firebaseInfo: firebaseInfo ?? GenerativeModelTestUtil.testFirebaseInfo(),
        apiConfig: apiConfig ?? self.apiConfig,
        safetySettings: safetySettings,
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
#endif // compiler(>=6.2.3) && canImport(FoundationModels)
