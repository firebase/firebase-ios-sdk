import XCTest
import Foundation
#if os(Linux)
import FoundationNetworking
#endif
@testable import GeneratedFirebaseAI

class BasicTests: XCTestCase {
  // TODO(daymxn): Fix tests once we get the conversion layer working.
  func fetchAPIKey() -> String {
    // TODO(daymxn): Add a default API key when we add the conversion layer tests.
    // May need to provision one for CI.
    guard let apiKey = ProcessInfo.processInfo.environment["API_KEY"] else {
      fatalError("Please set an API_KEY environment variable for the Google AI backend tests.")
    }
    return apiKey
  }

  func testListModels() async throws {
    let mockJSON = """
    {
      "models": [
        {
          "name": "models/gemini-3-pro-preview",
          "displayName": "Gemini 3",
          "createTime": "2025-11-07T19:06:16.769147Z",
        }
      ]
    }
    """.data(using: .utf8)!

    let session = mockURLSession { request in
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, mockJSON)
    }

    let api = APIClient(backend: .googleAI(),
                        authentication: .apiKey("mock-key"),
                        urlSession: session)
    let models = Models(apiClient: api)

    let response = try await models.listInternal(params: ListModelsParameters(config: ListModelsConfig(filter: "gemini-3")))

    XCTAssertNotNil(response.models)
    XCTAssertEqual(response.models?.first?.displayName, "Gemini 3")
  }

  func testGenerateContent() async throws {

    let mockJSON = """
    {
      "candidates": [
        {
          "content": {
            "parts": [{ "text": "I am doing great, thanks!" }],
            "role": "model"
          },
          "finishReason": "STOP"
        }
      ],
      "usageMetadata": {
        "promptTokenCount": 5,
        "candidatesTokenCount": 10,
        "totalTokenCount": 7
      }
    }
    """.data(using: .utf8)!

    let session = mockURLSession { request in
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, mockJSON)
    }

    let api = APIClient(backend: .googleAI(),
                        authentication: .apiKey("mock-key"),
                        urlSession: session)
    let models = Models(apiClient: api)

    let content = [Content(parts: [Part(text: "How are you?")], role: "user")]
    let params = GenerateContentParameters(
      model: "gemini-3-pro-preview",
      contents: content
    )

    let response = try await models.generateContentInternal(params: params)

    let firstCandidate = response.candidates?.first
    XCTAssertNotNil(firstCandidate)
    XCTAssertEqual(firstCandidate?.content?.parts?.first?.text, "I am doing great, thanks!")
    XCTAssertEqual(response.usageMetadata?.totalTokenCount, 7)
  }

  // TODO(daymxn): Add tests for other features.
}
