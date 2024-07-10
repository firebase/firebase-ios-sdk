// Copyright 2024 Google LLC
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

import FirebaseVertexAI
import Foundation
import XCTest

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class GenerationConfigTests: XCTestCase {
  let encoder = JSONEncoder()

  override func setUp() {
    encoder.outputFormatting = .init(
      arrayLiteral: .prettyPrinted, .sortedKeys, .withoutEscapingSlashes
    )
  }

  // MARK: GenerationConfig Encoding

  func testEncodeGenerationConfig_default() throws {
    let generationConfig = GenerationConfig()

    let jsonData = try encoder.encode(generationConfig)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {

    }
    """)
  }

  func testEncodeGenerationConfig_allOptions() throws {
    let temperature: Float = 0.5
    let topP: Float = 0.75
    let topK = 40
    let candidateCount = 2
    let maxOutputTokens = 256
    let stopSequences = ["END", "DONE"]
    let responseMIMEType = "text/plain"
    let generationConfig = GenerationConfig(
      temperature: temperature,
      topP: topP,
      topK: topK,
      candidateCount: candidateCount,
      maxOutputTokens: maxOutputTokens,
      stopSequences: stopSequences,
      responseMIMEType: responseMIMEType
    )

    let jsonData = try encoder.encode(generationConfig)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "candidateCount" : \(candidateCount),
      "maxOutputTokens" : \(maxOutputTokens),
      "responseMIMEType" : "\(responseMIMEType)",
      "stopSequences" : [
        "END",
        "DONE"
      ],
      "temperature" : \(temperature),
      "topK" : \(topK),
      "topP" : \(topP)
    }
    """)
  }

  func testEncodeGenerationConfig_responseMIMEType() throws {
    let mimeType = "image/jpeg"
    let generationConfig = GenerationConfig(responseMIMEType: mimeType)

    let jsonData = try encoder.encode(generationConfig)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "responseMIMEType" : "\(mimeType)"
    }
    """)
  }
}
