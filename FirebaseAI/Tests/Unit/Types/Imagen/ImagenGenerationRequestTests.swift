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

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class ImagenGenerationRequestTests: XCTestCase {
  let encoder = JSONEncoder()
  let requestOptions = RequestOptions(timeout: 30.0)
  let modelName = "test-model-name"
  let sampleCount = 4
  let aspectRatio = "16:9"
  let safetyFilterLevel = "block_low_and_above"
  let includeResponsibleAIFilterReason = true
  let includeSafetyAttributes = true
  lazy var parameters = ImageGenerationParameters(
    sampleCount: sampleCount,
    storageURI: nil,
    negativePrompt: nil,
    aspectRatio: aspectRatio,
    safetyFilterLevel: safetyFilterLevel,
    personGeneration: nil,
    outputOptions: nil,
    addWatermark: nil,
    includeResponsibleAIFilterReason: includeResponsibleAIFilterReason,
    includeSafetyAttributes: includeSafetyAttributes
  )
  let apiConfig = FirebaseAI.defaultVertexAIAPIConfig

  let instance = ImageGenerationInstance(prompt: "test-prompt")

  override func setUp() {
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
  }

  func testInitializeRequest_inlineDataImage() throws {
    let request = ImagenGenerationRequest<ImagenInlineImage>(
      model: modelName,
      apiConfig: apiConfig,
      options: requestOptions,
      instances: [instance],
      parameters: parameters
    )

    XCTAssertEqual(request.model, modelName)
    XCTAssertEqual(request.options, requestOptions)
    XCTAssertEqual(request.instances, [instance])
    XCTAssertEqual(request.parameters, parameters)
    XCTAssertEqual(
      request.url,
      URL(string:
        "\(apiConfig.service.endpoint.rawValue)/\(apiConfig.version.rawValue)/\(modelName):predict")
    )
  }

  func testInitializeRequest_fileDataImage() throws {
    let request = ImagenGenerationRequest<ImagenGCSImage>(
      model: modelName,
      apiConfig: apiConfig,
      options: requestOptions,
      instances: [instance],
      parameters: parameters
    )

    XCTAssertEqual(request.model, modelName)
    XCTAssertEqual(request.options, requestOptions)
    XCTAssertEqual(request.instances, [instance])
    XCTAssertEqual(request.parameters, parameters)
    XCTAssertEqual(
      request.url,
      URL(string:
        "\(apiConfig.service.endpoint.rawValue)/\(apiConfig.version.rawValue)/\(modelName):predict")
    )
  }

  // MARK: - Encoding Tests

  func testEncodeRequest_inlineDataImage() throws {
    let request = ImagenGenerationRequest<ImagenInlineImage>(
      model: modelName,
      apiConfig: apiConfig,
      options: RequestOptions(),
      instances: [instance],
      parameters: parameters
    )

    let jsonData = try encoder.encode(request)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "instances" : [
        {
          "prompt" : "\(instance.prompt)"
        }
      ],
      "parameters" : {
        "aspectRatio" : "\(aspectRatio)",
        "includeRaiReason" : \(includeResponsibleAIFilterReason),
        "includeSafetyAttributes" : \(includeSafetyAttributes),
        "safetySetting" : "\(safetyFilterLevel)",
        "sampleCount" : \(sampleCount)
      }
    }
    """)
  }

  func testEncodeRequest_fileDataImage() throws {
    let request = ImagenGenerationRequest<ImagenGCSImage>(
      model: modelName,
      apiConfig: apiConfig,
      options: RequestOptions(),
      instances: [instance],
      parameters: parameters
    )

    let jsonData = try encoder.encode(request)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "instances" : [
        {
          "prompt" : "\(instance.prompt)"
        }
      ],
      "parameters" : {
        "aspectRatio" : "\(aspectRatio)",
        "includeRaiReason" : \(includeResponsibleAIFilterReason),
        "includeSafetyAttributes" : \(includeSafetyAttributes),
        "safetySetting" : "\(safetyFilterLevel)",
        "sampleCount" : \(sampleCount)
      }
    }
    """)
  }
}
