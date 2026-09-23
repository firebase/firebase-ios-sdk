// Copyright 2025 Google LLC
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

import CoreLocation
@testable import FirebaseAILogic
import FirebaseCore
import XCTest

@available(macOS 12.0, watchOS 8.0, *)
final class TemplateGenerativeModelTests: XCTestCase {
  var urlSession: URLSession!
  var model: TemplateGenerativeModel!
  let firebaseInfo = GenerativeModelTestUtil.testFirebaseInfo()
  let apiConfig = FirebaseAI.defaultVertexAIAPIConfig

  override func setUp() {
    super.setUp()
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [MockURLProtocol.self]
    urlSession = URLSession(configuration: configuration)
    model = TemplateGenerativeModel(
      firebaseInfo: firebaseInfo,
      apiConfig: apiConfig,
      tools: nil,
      toolConfig: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
  }

  func testGenerateContent() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-basic-reply-short",
      withExtension: "json",
      subdirectory: "mock-responses/vertexai",
      isTemplateRequest: true
    )

    let response = try await model.generateContent(
      templateID: "test-template",
      inputs: ["name": "test"]
    )

    XCTAssertEqual(response.text, "Mountain View, California")
  }

  func testGenerateContentStream() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-basic-reply-short",
      withExtension: "txt",
      subdirectory: "mock-responses/vertexai",
      isTemplateRequest: true
    )

    let stream = try model.generateContentStream(
      templateID: "test-template",
      inputs: ["name": "test"]
    )

    let content = try await GenerativeModelTestUtil.collectTextFromStream(stream)
    XCTAssertEqual(content, "Cheyenne")
  }

  func testGenerateContent_googleAI() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-basic-reply-short",
      withExtension: "json",
      subdirectory: "mock-responses/googleai",
      isTemplateRequest: true
    )
    model = TemplateGenerativeModel(
      firebaseInfo: firebaseInfo,
      apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta),
      tools: nil,
      toolConfig: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )

    let response = try await model.generateContent(
      templateID: "test-template",
      inputs: ["name": "test"]
    )

    XCTAssertEqual(
      response.text,
      "Google's headquarters, also known as the Googleplex, is located in **Mountain View, California**.\n"
    )
  }

  func testGenerateContentStream_googleAI() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-basic-reply-short",
      withExtension: "txt",
      subdirectory: "mock-responses/googleai",
      isTemplateRequest: true
    )
    model = TemplateGenerativeModel(
      firebaseInfo: firebaseInfo,
      apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta),
      tools: nil,
      toolConfig: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )

    let stream = try model.generateContentStream(
      templateID: "test-template",
      inputs: ["name": "test"]
    )

    let content = try await GenerativeModelTestUtil.collectTextFromStream(stream)
    XCTAssertEqual(content, "The capital of Wyoming is **Cheyenne**.\n")
  }

  func testGenerateContent_success_mapsGrounding_googleAI() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-google-maps-grounding",
      withExtension: "json",
      subdirectory: "mock-responses/googleai",
      isTemplateRequest: true
    )
    let toolConfig = TemplateToolConfig(
      retrievalConfig: RetrievalConfig(
        location: CLLocationCoordinate2D(latitude: 37.7799, longitude: -122.2822)
      )
    )
    model = TemplateGenerativeModel(
      firebaseInfo: firebaseInfo,
      apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta),
      tools: nil,
      toolConfig: toolConfig,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )

    let response = try await model.generateContent(templateID: "test-template",
                                                   inputs: ["name": "test"])

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let groundingMetadata = try XCTUnwrap(candidate.groundingMetadata)

    XCTAssertEqual(groundingMetadata.webSearchQueries, ["pizza near me"])
    XCTAssertEqual(groundingMetadata.groundingChunks.count, 20)
    let firstChunk = try XCTUnwrap(groundingMetadata.groundingChunks.first?.maps)
    XCTAssertEqual(firstChunk.title, "Joe’s Pizza")
    XCTAssertEqual(firstChunk.url, URL(string: "https://maps.google.com/?cid=10332424901773702701"))
    XCTAssertEqual(firstChunk.placeID, "places/ChIJqdNaaBVbwokRLTafYrQlZI8")
  }

  func testGenerateContent_success_mapsGrounding_enterprise() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-google-maps-grounding",
      withExtension: "json",
      subdirectory: "mock-responses/vertexai",
      isTemplateRequest: true
    )
    let toolConfig = TemplateToolConfig(
      retrievalConfig: RetrievalConfig(
        location: CLLocationCoordinate2D(latitude: 37.7799, longitude: -122.2822)
      )
    )
    model = TemplateGenerativeModel(
      firebaseInfo: firebaseInfo,
      apiConfig: FirebaseAI.defaultVertexAIAPIConfig,
      tools: nil,
      toolConfig: toolConfig,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )

    let response = try await model.generateContent(templateID: "test-template",
                                                   inputs: ["name": "test"])

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let groundingMetadata = try XCTUnwrap(candidate.groundingMetadata)

    XCTAssertEqual(groundingMetadata.groundingChunks.count, 20)
    let firstChunk = try XCTUnwrap(groundingMetadata.groundingChunks.first?.maps)
    XCTAssertEqual(firstChunk.title, "Joe’s Pizza")
    XCTAssertEqual(firstChunk.url, URL(string: "https://maps.google.com/?cid=10332424901773702701"))
    XCTAssertEqual(firstChunk.placeID, "places/ChIJqdNaaBVbwokRLTafYrQlZI8")
  }

  // MARK: - Request Body

  /// Captures the decoded request body sent by `model` for a template `generateContent` call.
  private func captureRequestBody(tools: [TemplateTool]?,
                                  toolConfig: TemplateToolConfig? = nil) async throws
    -> [String: Any] {
    let responseHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-basic-reply-short",
      withExtension: "json",
      subdirectory: "mock-responses/vertexai",
      isTemplateRequest: true
    )
    nonisolated(unsafe) var capturedBody: Data?
    MockURLProtocol.requestHandler = { request in
      capturedBody = try request.extractBodyData()
      return try responseHandler(request)
    }
    model = TemplateGenerativeModel(
      firebaseInfo: firebaseInfo,
      apiConfig: apiConfig,
      tools: tools,
      toolConfig: toolConfig,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )

    _ = try await model.generateContent(templateID: "test-template", inputs: ["name": "test"])

    let body = try XCTUnwrap(capturedBody)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
  }

  func testGenerateContent_sendsToolsAndToolConfig() async throws {
    let declaration = FunctionDeclaration(
      name: "fetchWeather",
      description: "Returns the weather.",
      parameters: ["city": .string()]
    )

    let body = try await captureRequestBody(
      tools: [.functionDeclarations([declaration])],
      toolConfig: TemplateToolConfig(retrievalConfig: RetrievalConfig(languageCode: "en_US"))
    )

    let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
    XCTAssertEqual(tools.count, 1)
    let functions = try XCTUnwrap(tools[0]["templateFunctions"] as? [[String: Any]])
    XCTAssertEqual(functions.count, 1)
    XCTAssertEqual(functions[0]["name"] as? String, "fetchWeather")
    XCTAssertNotNil(functions[0]["inputSchema"])
    XCTAssertNil(functions[0]["description"])
    let toolConfig = try XCTUnwrap(body["toolConfig"] as? [String: Any])
    let retrievalConfig = try XCTUnwrap(toolConfig["retrievalConfig"] as? [String: Any])
    XCTAssertEqual(retrievalConfig["languageCode"] as? String, "en_US")
  }

  func testGenerateContent_sendsGoogleMapsTool() async throws {
    let body = try await captureRequestBody(tools: [.googleMaps()])

    let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
    XCTAssertEqual(tools.count, 1)
    XCTAssertNotNil(tools[0]["googleMaps"])
    XCTAssertNil(tools[0]["templateFunctions"])
  }

  func testGenerateContent_withoutTools_omitsToolsKey() async throws {
    let body = try await captureRequestBody(tools: nil)

    XCTAssertNil(body["tools"])
    XCTAssertNil(body["toolConfig"])
  }

  func testGenerateContent_emptyToolsArray_omitsToolsKey() async throws {
    let body = try await captureRequestBody(tools: [])

    XCTAssertNil(body["tools"])
  }
}
