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

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class CountTokensRequestTests: XCTestCase {
  let encoder = JSONEncoder()

  let modelResourceName = "models/test-model-name"
  let textPart = TextPart("test-prompt")
  let vertexAPIConfig = FirebaseAI.defaultVertexAIAPIConfig
  let developerAPIConfig = APIConfig(
    service: .googleAI(endpoint: .firebaseProxyProd),
    version: .v1beta
  )
  let requestOptions = RequestOptions()

  override func setUp() {
    encoder.outputFormatting = .init(
      arrayLiteral: .prettyPrinted, .sortedKeys, .withoutEscapingSlashes
    )
  }

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
      apiConfig: vertexAPIConfig,
      apiMethod: .countTokens,
      options: requestOptions
    )
    let request = CountTokensRequest(
      modelResourceName: modelResourceName, generateContentRequest: generateContentRequest
    )

    let jsonData = try encoder.encode(request)

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
      apiConfig: developerAPIConfig,
      apiMethod: .countTokens,
      options: requestOptions
    )
    let request = CountTokensRequest(
      modelResourceName: modelResourceName, generateContentRequest: generateContentRequest
    )

    let jsonData = try encoder.encode(request)

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
}
