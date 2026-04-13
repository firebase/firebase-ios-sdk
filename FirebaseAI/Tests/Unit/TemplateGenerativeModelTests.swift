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

  override func setUp() {
    super.setUp()
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [MockURLProtocol.self]
    urlSession = URLSession(configuration: configuration)
    let firebaseInfo = GenerativeModelTestUtil.testFirebaseInfo()
    let generativeAIService = GenerativeAIService(
      firebaseInfo: firebaseInfo,
      urlSession: urlSession
    )
    let apiConfig = APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta)
    model = TemplateGenerativeModel(generativeAIService: generativeAIService, apiConfig: apiConfig)
  }

  func testGenerateContent() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-basic-reply-short",
      withExtension: "json",
      subdirectory: "mock-responses/googleai",
      isTemplateRequest: true
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

  func testGenerateContentStream() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-basic-reply-short",
      withExtension: "txt",
      subdirectory: "mock-responses/googleai",
      isTemplateRequest: true
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

    let firebaseInfo = GenerativeModelTestUtil.testFirebaseInfo()
    let generativeAIService = GenerativeAIService(
      firebaseInfo: firebaseInfo,
      urlSession: urlSession
    )
    let apiConfig = APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta)
    let model = TemplateGenerativeModel(
      generativeAIService: generativeAIService,
      apiConfig: apiConfig
    )

    let toolConfig = TemplateToolConfig(
      retrievalConfig: RetrievalConfig(
        location: CLLocationCoordinate2D(latitude: 37.7799, longitude: -122.2822)
      )
    )
    let response = try await model.generateContent(
      templateID: "test-template",
      inputs: ["name": "test"],
      toolConfig: toolConfig
    )

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

  func testGenerateContent_success_mapsGrounding_vertexAI() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-google-maps-grounding",
      withExtension: "json",
      subdirectory: "mock-responses/vertexai",
      isTemplateRequest: true
    )

    let firebaseInfo = GenerativeModelTestUtil.testFirebaseInfo()
    let generativeAIService = GenerativeAIService(
      firebaseInfo: firebaseInfo,
      urlSession: urlSession
    )
    let apiConfig = APIConfig(
      service: .vertexAI(endpoint: .firebaseProxyProd, location: "us-central1"),
      version: .v1beta
    )
    let model = TemplateGenerativeModel(
      generativeAIService: generativeAIService,
      apiConfig: apiConfig
    )

    let toolConfig = TemplateToolConfig(
      retrievalConfig: RetrievalConfig(
        location: CLLocationCoordinate2D(latitude: 37.7799, longitude: -122.2822)
      )
    )
    let response = try await model.generateContent(
      templateID: "test-template",
      inputs: ["name": "test"],
      toolConfig: toolConfig
    )

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let groundingMetadata = try XCTUnwrap(candidate.groundingMetadata)

    XCTAssertEqual(groundingMetadata.groundingChunks.count, 20)
    let firstChunk = try XCTUnwrap(groundingMetadata.groundingChunks.first?.maps)
    XCTAssertEqual(firstChunk.title, "Joe’s Pizza")
    XCTAssertEqual(firstChunk.url, URL(string: "https://maps.google.com/?cid=10332424901773702701"))
    XCTAssertEqual(firstChunk.placeID, "places/ChIJqdNaaBVbwokRLTafYrQlZI8")
  }
}
