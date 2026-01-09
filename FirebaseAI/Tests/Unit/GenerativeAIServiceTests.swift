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
final class GenerativeAIServiceTests: XCTestCase {
  let testModelName = "test-model"
  let testModelResourceName =
    "projects/test-project-id/locations/test-location/publishers/google/models/test-model"
  let apiConfig = FirebaseAI.defaultVertexAIAPIConfig

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

  func testGenerateContent_failure_unrecognizedErrorPayload() async throws {
    let expectedStatusCode = 500
    let responseBody = "Internal Server Error"

    // We need to construct the handler to return specific data
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: tempURL)
    }

    MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: expectedStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!

        try responseBody.write(to: tempURL, atomically: true, encoding: .utf8)
        let stream = URL(fileURLWithPath: tempURL.path).lines
        return (response, stream)
    }

    do {
      _ = try await model.generateContent("test")
      XCTFail("Should throw GenerateContentError.internalError; no error thrown.")
    } catch let GenerateContentError.internalError(underlying: error) {
      guard let unrecognizedError = error as? UnrecognizedRPCError else {
        XCTFail("Expected UnrecognizedRPCError, got: \(error)")
        return
      }
      // MockURLProtocol appends a newline to the response.
      XCTAssertEqual(unrecognizedError.responseBody, responseBody + "\n")
    } catch {
      XCTFail("Should throw GenerateContentError.internalError; error thrown: \(error)")
    }
  }
}
