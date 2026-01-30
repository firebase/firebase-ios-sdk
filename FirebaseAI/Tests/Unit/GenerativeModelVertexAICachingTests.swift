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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
import XCTest

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class GenerativeModelImplicitCachingTests: XCTestCase {
  let testPrompt = "What sorts of questions can I ask you?"
  let testModelName = "test-model"
  let testModelResourceName =
    "projects/test-project-id/locations/test-location/publishers/google/models/test-model"
  let apiConfig = FirebaseAI.defaultVertexAIAPIConfig

  let vertexSubdirectory = "mock-responses/vertexai"

  var urlSession: URLSession!
  var model: GenerativeModel!

  override func setUp() async throws {
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [MockURLProtocol.self]
    urlSession = try XCTUnwrap(URLSession(configuration: configuration))
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
  }

  override func tearDown() {
    MockURLProtocol.requestHandler = nil
  }

  func testGenerateContent_success_implicitCaching() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-implicit-caching",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let finishReason = try XCTUnwrap(candidate.finishReason)
    XCTAssertEqual(finishReason, .stop)

    let usageMetadata = try XCTUnwrap(response.usageMetadata)
    XCTAssertEqual(usageMetadata.promptTokenCount, 12013)
    XCTAssertEqual(usageMetadata.candidatesTokenCount, 15)
    XCTAssertEqual(usageMetadata.totalTokenCount, 12101)

    // Validate implicit caching fields
    XCTAssertEqual(usageMetadata.cachedContentTokenCount, 11243)
    XCTAssertEqual(usageMetadata.promptTokensDetails.count, 1)
    let detail = try XCTUnwrap(usageMetadata.promptTokensDetails.first)
    XCTAssertEqual(detail.modality, .text)
    XCTAssertEqual(detail.tokenCount, 12013)
    XCTAssertEqual(usageMetadata.thoughtsTokenCount, 73)
  }
}
