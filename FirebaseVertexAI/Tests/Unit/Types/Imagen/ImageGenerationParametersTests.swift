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

import XCTest

@testable import FirebaseVertexAI

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class ImageGenerationParametersTests: XCTestCase {
  let encoder = JSONEncoder()

  override func setUp() {
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
  }

  // MARK: - Encoding Tests

  func testEncodeParameters_allSpecified() throws {
    let sampleCount = 4
    let storageURI = "gs://bucket/folder"
    let negativePrompt = "test-negative-prompt"
    let aspectRatio = "16:9"
    let safetyFilterLevel = "block_low_and_above"
    let personGeneration = "allow_adult"
    let mimeType = "image/png"
    let outputOptions = ImageGenerationOutputOptions(mimeType: mimeType, compressionQuality: nil)
    let addWatermark = false
    let includeRAIReason = true
    let parameters = ImageGenerationParameters(
      sampleCount: sampleCount,
      storageURI: storageURI,
      negativePrompt: negativePrompt,
      aspectRatio: aspectRatio,
      safetyFilterLevel: safetyFilterLevel,
      personGeneration: personGeneration,
      outputOptions: outputOptions,
      addWatermark: addWatermark,
      includeResponsibleAIFilterReason: includeRAIReason
    )

    let jsonData = try encoder.encode(parameters)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "addWatermark" : \(addWatermark),
      "aspectRatio" : "\(aspectRatio)",
      "includeRaiReason" : \(includeRAIReason),
      "negativePrompt" : "\(negativePrompt)",
      "outputOptions" : {
        "mimeType" : "\(mimeType)"
      },
      "personGeneration" : "\(personGeneration)",
      "safetySetting" : "\(safetyFilterLevel)",
      "sampleCount" : \(sampleCount),
      "storageUri" : "\(storageURI)"
    }
    """)
  }

  func testEncodeParameters_someSpecified() throws {
    let sampleCount = 2
    let aspectRatio = "3:4"
    let safetyFilterLevel = "block_medium_and_above"
    let addWatermark = true
    let parameters = ImageGenerationParameters(
      sampleCount: sampleCount,
      storageURI: nil,
      negativePrompt: nil,
      aspectRatio: aspectRatio,
      safetyFilterLevel: safetyFilterLevel,
      personGeneration: nil,
      outputOptions: nil,
      addWatermark: addWatermark,
      includeResponsibleAIFilterReason: nil
    )

    let jsonData = try encoder.encode(parameters)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "addWatermark" : \(addWatermark),
      "aspectRatio" : "\(aspectRatio)",
      "safetySetting" : "\(safetyFilterLevel)",
      "sampleCount" : \(sampleCount)
    }
    """)
  }

  func testEncodeParameters_noneSpecified() throws {
    let parameters = ImageGenerationParameters(
      sampleCount: nil,
      storageURI: nil,
      negativePrompt: nil,
      aspectRatio: nil,
      safetyFilterLevel: nil,
      personGeneration: nil,
      outputOptions: nil,
      addWatermark: nil,
      includeResponsibleAIFilterReason: nil
    )

    let jsonData = try encoder.encode(parameters)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {

    }
    """)
  }
}
