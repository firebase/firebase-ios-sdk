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

import Foundation
import XCTest

@testable import FirebaseVertexAI

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class CountTokensRequestTests: XCTestCase {
  let modelResourceName = "models/test-model-name"
  let textPart = TextPart("test-prompt")
  let vertexEncoder = CountTokensRequestTests.encoder(
    apiConfig: APIConfig(service: .vertexAI, version: .v1beta)
  )
  let developerEncoder = CountTokensRequestTests.encoder(
    apiConfig: APIConfig(service: .developer(endpoint: .firebaseVertexAIProd), version: .v1beta)
  )
  let requestOptions = RequestOptions()

  // MARK: CountTokensRequest Encoding

  func testEncodeCountTokensRequest_vertexAI_minimal() throws {
    let content = ModelContent(role: nil, parts: [textPart])
    let generateContentRequest = GenerateContentRequest(
      model: modelResourceName,
      contents: [content],
      generationConfig: nil,
      safetySettings: nil,
      tools: nil,
      toolConfig: nil,
      systemInstruction: nil,
      apiMethod: .countTokens,
      options: requestOptions
    )
    let request = CountTokensRequest(generateContentRequest: generateContentRequest)

    let jsonData = try vertexEncoder.encode(request)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "contents" : [
        {
          "parts" : [
            {
              "text" : "\(textPart.text)"
            }
          ]
        }
      ]
    }
    """)
  }

  func testEncodeCountTokensRequest_developerAPI_minimal() throws {
    let content = ModelContent(role: nil, parts: [textPart])
    let generateContentRequest = GenerateContentRequest(
      model: modelResourceName,
      contents: [content],
      generationConfig: nil,
      safetySettings: nil,
      tools: nil,
      toolConfig: nil,
      systemInstruction: nil,
      apiMethod: .countTokens,
      options: requestOptions
    )
    let request = CountTokensRequest(generateContentRequest: generateContentRequest)

    let jsonData = try developerEncoder.encode(request)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "generateContentRequest" : {
        "contents" : [
          {
            "parts" : [
              {
                "text" : "\(textPart.text)"
              }
            ]
          }
        ],
        "model" : "\(modelResourceName)"
      }
    }
    """)
  }

  static func encoder(apiConfig: APIConfig) -> JSONEncoder {
    let encoder = JSONEncoder(apiConfig: apiConfig)
    encoder.outputFormatting = .init(
      arrayLiteral: .prettyPrinted, .sortedKeys, .withoutEscapingSlashes
    )
    return encoder
  }
}
