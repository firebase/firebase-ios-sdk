
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

@testable import FirebaseAI
import FirebaseCore
import XCTest

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
      forResource: "unary-success-response",
      withExtension: "json",
      subdirectory: "mock-responses",
      isTemplateRequest: true
    )

    let response = try await model.generateContent(
      template: "test-template",
      variables: ["name": "test"]
    )
    XCTAssertEqual(response.text, "Hello, world!")
  }
}
