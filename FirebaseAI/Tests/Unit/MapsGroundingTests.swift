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

@testable import FirebaseAILogic
import FirebaseCore
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class MapsGroundingTests: XCTestCase {
  private var model: GenerativeModel!
  private let testModelName = "gemini-1.5-flash-001"
  private let testProjectID = "my-project-id"
  private let testAPIKey = "my-api-key"

  override func setUp() async throws {
    let options = FirebaseOptions(googleAppID: "1:123456789:ios:abcdef", gcmSenderID: "123456789")
    options.projectID = testProjectID
    options.apiKey = testAPIKey
    if FirebaseApp.app(name: "test") == nil {
      FirebaseApp.configure(name: "test", options: options)
    }
    let app = FirebaseApp.app(name: "test")!
    let firebaseInfo = FirebaseInfo(
      appCheck: nil,
      auth: nil,
      projectID: testProjectID,
      apiKey: testAPIKey,
      firebaseAppID: app.options.googleAppID,
      firebaseApp: app,
      useLimitedUseAppCheckTokens: false
    )

    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: "projects/\(testProjectID)/models/\(testModelName)",
      firebaseInfo: firebaseInfo,
      apiConfig: Backend.googleAI().apiConfig,
      tools: [.googleMaps()],
      requestOptions: RequestOptions()
    )
  }

  override func tearDown() {
    let app = FirebaseApp.app(name: "test")
    app?.delete { _ in }
  }

  func testRequestEncoding() throws {
    let testPrompt = "Where is a good place to grab a coffee near Arlington, MA?"
    let request = GenerateContentRequest(
      model: model.modelResourceName,
      contents: [ModelContent(role: "user", parts: [TextPart(testPrompt)])],
      generationConfig: nil,
      safetySettings: nil,
      tools: model.tools,
      toolConfig: nil,
      systemInstruction: nil,
      apiConfig: model.apiConfig,
      apiMethod: .generateContent,
      options: model.requestOptions
    )

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let requestData = try encoder.encode(request)
    let requestJSON = try XCTUnwrap(JSONSerialization
      .jsonObject(with: requestData) as? [String: Any])
    let tools = try XCTUnwrap(requestJSON["tools"] as? [[String: Any]])
    XCTAssertEqual(tools.count, 1)
    let maps = try XCTUnwrap(tools[0]["google_maps"] as? [String: Any])
    XCTAssertTrue(maps.isEmpty)
  }

  func testResponseDecoding() throws {
    let responseText = """
    {
      "candidates": [
        {
          "content": {
            "parts": [
              {
                "text": "Sure, there are a few great coffee shops in Arlington, MA. One that stands out is located at [placeId: ChIJyZ2y_wJz44kR5w8oQ8oQ8oQ]."
              }
            ]
          },
          "groundingMetadata": {
            "groundingChunks": [
              {
                "maps": {
                  "uri": "https://maps.google.com/?q=ChIJyZ2y_wJz44kR5w8oQ8oQ8oQ",
                  "title": "Kickstand Cafe",
                  "placeId": "ChIJyZ2y_wJz44kR5w8oQ8oQ8oQ"
                }
              }
            ]
          }
        }
      ]
    }
    """
    let responseData = try XCTUnwrap(responseText.data(using: .utf8))
    let response = try JSONDecoder().decode(GenerateContentResponse.self, from: responseData)

    let candidate = try XCTUnwrap(response.candidates.first)
    let groundingMetadata = try XCTUnwrap(candidate.groundingMetadata)
    let chunk = try XCTUnwrap(groundingMetadata.groundingChunks.first)
    let mapsChunk = try XCTUnwrap(chunk.maps)

    XCTAssertEqual(mapsChunk.uri, "https://maps.google.com/?q=ChIJyZ2y_wJz44kR5w8oQ8oQ8oQ")
    XCTAssertEqual(mapsChunk.title, "Kickstand Cafe")
    XCTAssertEqual(mapsChunk.placeID, "ChIJyZ2y_wJz44kR5w8oQ8oQ8oQ")
  }
}
