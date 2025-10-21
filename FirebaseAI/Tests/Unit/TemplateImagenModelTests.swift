// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law of or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import FirebaseAILogic
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class TemplateImagenModelTests: XCTestCase {
  var urlSession: URLSession!
  var model: TemplateImagenModel!

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
    model = TemplateImagenModel(generativeAIService: generativeAIService, apiConfig: apiConfig)
  }

  func testGenerateImages() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-generate-images-base64",
      withExtension: "json",
      subdirectory: "mock-responses/vertexai",
      isTemplateRequest: true
    )

    let response = try await model.generateImages(
      templateID: "test-template",
      inputs: ["prompt": "a cat picture"]
    )
    XCTAssertEqual(response.images.count, 4)
    XCTAssertNotNil(response.images.first?.data)
  }
}
