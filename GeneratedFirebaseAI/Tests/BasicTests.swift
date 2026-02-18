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

import Foundation
import XCTest

@testable import GeneratedFirebaseAI

#if os(Linux)
  import FoundationNetworking
#endif

// TODO: Migrate to using test server
class BasicTests: XCTestCase {
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
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
      )!
      return (response, mockJSON)
    }
    let api = try APIClient(
      backend: .googleAI(version: .v1beta, direct: true),
      authentication: .apiKey(TestConstants.APIKey),
      urlSession: session
    )
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
