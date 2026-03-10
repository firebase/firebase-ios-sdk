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
final class ImageGenerationParametersTests: XCTestCase {
  let encoder = JSONEncoder()

  override func setUp() {
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
  }

  func testDefaultParameters_noneSpecified() throws {
    let expectedParameters = ImageGenerationParameters(
      sampleCount: 1,
      storageURI: nil,
      negativePrompt: nil,
      aspectRatio: nil,
      sampleImageSize: nil,
      safetyFilterLevel: nil,
      personGeneration: nil,
      outputOptions: nil,
      addWatermark: nil,
      includeResponsibleAIFilterReason: true,
      includeSafetyAttributes: true
    )

    let parameters = ImagenModel.imageGenerationParameters(
      storageURI: nil,
      generationConfig: nil,
      safetySettings: nil
    )

    XCTAssertEqual(parameters, expectedParameters)
  }

  func testDefaultParameters_includeStorageURI() throws {
    let storageURI = "gs://test-bucket/path"
    let expectedParameters = ImageGenerationParameters(
      sampleCount: 1,
      storageURI: storageURI,
      negativePrompt: nil,
      aspectRatio: nil,
      sampleImageSize: nil,
      safetyFilterLevel: nil,
      personGeneration: nil,
      outputOptions: nil,
      addWatermark: nil,
      includeResponsibleAIFilterReason: true,
      includeSafetyAttributes: true
    )

    let parameters = ImagenModel.imageGenerationParameters(
      storageURI: storageURI,
      generationConfig: nil,
      safetySettings: nil
    )

    XCTAssertEqual(parameters, expectedParameters)
  }

  func testParameters_includeGenerationConfig() throws {
    let sampleCount = 2
    let negativePrompt = "test-negative-prompt"
    let compressionQuality = 80
    let imageFormat = ImagenImageFormat.jpeg(compressionQuality: compressionQuality)
    let aspectRatio = ImagenAspectRatio.landscape16x9
    let addWatermark = true
    let generationConfig = ImagenGenerationConfig(
      negativePrompt: negativePrompt,
      numberOfImages: sampleCount,
      aspectRatio: aspectRatio,
      imageSize: nil,
      imageFormat: imageFormat,
      addWatermark: addWatermark
    )
    let expectedParameters = ImageGenerationParameters(
      sampleCount: sampleCount,
      storageURI: nil,
      negativePrompt: negativePrompt,
      aspectRatio: aspectRatio.rawValue,
      sampleImageSize: nil,
      safetyFilterLevel: nil,
      personGeneration: nil,
      outputOptions: ImageGenerationOutputOptions(
        mimeType: imageFormat.mimeType,
        compressionQuality: imageFormat.compressionQuality
      ),
      addWatermark: addWatermark,
      includeResponsibleAIFilterReason: true,
      includeSafetyAttributes: true
    )

    let parameters = ImagenModel.imageGenerationParameters(
      storageURI: nil,
      generationConfig: generationConfig,
      safetySettings: nil
    )

    XCTAssertEqual(parameters, expectedParameters)
    XCTAssertEqual(parameters.aspectRatio, "16:9")
  }

  func testDefaultParameters_includeSafetySettings() throws {
    let safetyFilterLevel = ImagenSafetyFilterLevel.blockOnlyHigh
    let personFilterLevel = ImagenPersonFilterLevel.allowAll
    let safetySettings = ImagenSafetySettings(
      safetyFilterLevel: safetyFilterLevel,
      personFilterLevel: personFilterLevel
    )
    let expectedParameters = ImageGenerationParameters(
      sampleCount: 1,
      storageURI: nil,
      negativePrompt: nil,
      aspectRatio: nil,
      sampleImageSize: nil,
      safetyFilterLevel: safetyFilterLevel.rawValue,
      personGeneration: personFilterLevel.rawValue,
      outputOptions: nil,
      addWatermark: nil,
      includeResponsibleAIFilterReason: true,
      includeSafetyAttributes: true
    )

    let parameters = ImagenModel.imageGenerationParameters(
      storageURI: nil,
      generationConfig: nil,
      safetySettings: safetySettings
    )

    XCTAssertEqual(parameters, expectedParameters)
    XCTAssertEqual(parameters.safetyFilterLevel, "block_only_high")
    XCTAssertEqual(parameters.personGeneration, "allow_all")
  }

  func testParameters_includeAll() throws {
    let storageURI = "gs://test-bucket/path"
    let sampleCount = 4
    let negativePrompt = "test-negative-prompt"
    let imageFormat = ImagenImageFormat.png()
    let aspectRatio = ImagenAspectRatio.portrait3x4
    let addWatermark = false
    let generationConfig = ImagenGenerationConfig(
      negativePrompt: negativePrompt,
      numberOfImages: sampleCount,
      aspectRatio: aspectRatio,
      imageSize: nil,
      imageFormat: imageFormat,
      addWatermark: addWatermark
    )
    let safetyFilterLevel = ImagenSafetyFilterLevel.blockNone
    let personFilterLevel = ImagenPersonFilterLevel.blockAll
    let safetySettings = ImagenSafetySettings(
      safetyFilterLevel: safetyFilterLevel,
      personFilterLevel: personFilterLevel
    )
    let expectedParameters = ImageGenerationParameters(
      sampleCount: sampleCount,
      storageURI: storageURI,
      negativePrompt: negativePrompt,
      aspectRatio: aspectRatio.rawValue,
      sampleImageSize: nil,
      safetyFilterLevel: safetyFilterLevel.rawValue,
      personGeneration: personFilterLevel.rawValue,
      outputOptions: ImageGenerationOutputOptions(
        mimeType: imageFormat.mimeType,
        compressionQuality: imageFormat.compressionQuality
      ),
      addWatermark: addWatermark,
      includeResponsibleAIFilterReason: true,
      includeSafetyAttributes: true
    )

    let parameters = ImagenModel.imageGenerationParameters(
      storageURI: storageURI,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )

    XCTAssertEqual(parameters, expectedParameters)
    XCTAssertEqual(parameters.aspectRatio, "3:4")
    XCTAssertEqual(parameters.safetyFilterLevel, "block_none")
    XCTAssertEqual(parameters.personGeneration, "dont_allow")
    XCTAssertEqual(parameters.outputOptions?.mimeType, "image/png")
    XCTAssertNil(parameters.outputOptions?.compressionQuality)
  }

  func testParameters_includeImageSize() throws {
    let sampleCount = 2
    let negativePrompt = "test-negative-prompt-image-size"
    let imageFormat = ImagenImageFormat.png()
    let imageSize = ImageConfig.ImageSize.size2K
    let addWatermark = true
    let generationConfig = ImagenGenerationConfig(
      negativePrompt: negativePrompt,
      numberOfImages: sampleCount,
      imageSize: imageSize,
      imageFormat: imageFormat,
      addWatermark: addWatermark
    )
    let expectedParameters = ImageGenerationParameters(
      sampleCount: sampleCount,
      storageURI: nil,
      negativePrompt: negativePrompt,
      aspectRatio: nil,
      sampleImageSize: imageSize.rawValue,
      safetyFilterLevel: nil,
      personGeneration: nil,
      outputOptions: ImageGenerationOutputOptions(
        mimeType: imageFormat.mimeType,
        compressionQuality: imageFormat.compressionQuality
      ),
      addWatermark: addWatermark,
      includeResponsibleAIFilterReason: true,
      includeSafetyAttributes: true
    )

    let parameters = ImagenModel.imageGenerationParameters(
      storageURI: nil,
      generationConfig: generationConfig,
      safetySettings: nil
    )

    XCTAssertEqual(parameters, expectedParameters)
    XCTAssertEqual(parameters.sampleImageSize, "2K")
    XCTAssertNil(parameters.aspectRatio)
  }

  func testParameters_includeAspectRatioAndImageSize() throws {
    let sampleCount = 3
    let negativePrompt = "test-negative-prompt-aspect-ratio-and-image-size"
    let imageFormat = ImagenImageFormat.jpeg(compressionQuality: 70)
    let aspectRatio = ImageConfig.AspectRatio.portrait9x16
    let imageSize = ImageConfig.ImageSize.size4K
    let addWatermark = false
    let generationConfig = ImagenGenerationConfig(
      negativePrompt: negativePrompt,
      numberOfImages: sampleCount,
      aspectRatio: aspectRatio,
      imageSize: imageSize,
      imageFormat: imageFormat,
      addWatermark: addWatermark
    )
    let expectedParameters = ImageGenerationParameters(
      sampleCount: sampleCount,
      storageURI: nil,
      negativePrompt: negativePrompt,
      aspectRatio: aspectRatio.rawValue,
      sampleImageSize: imageSize.rawValue,
      safetyFilterLevel: nil,
      personGeneration: nil,
      outputOptions: ImageGenerationOutputOptions(
        mimeType: imageFormat.mimeType,
        compressionQuality: imageFormat.compressionQuality
      ),
      addWatermark: addWatermark,
      includeResponsibleAIFilterReason: true,
      includeSafetyAttributes: true
    )

    let parameters = ImagenModel.imageGenerationParameters(
      storageURI: nil,
      generationConfig: generationConfig,
      safetySettings: nil
    )

    XCTAssertEqual(parameters, expectedParameters)
    XCTAssertEqual(parameters.aspectRatio, "9:16")
    XCTAssertEqual(parameters.sampleImageSize, "4K")
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
    let includeSafetyAttributes = true
    let parameters = ImageGenerationParameters(
      sampleCount: sampleCount,
      storageURI: storageURI,
      negativePrompt: negativePrompt,
      aspectRatio: aspectRatio,
      sampleImageSize: nil,
      safetyFilterLevel: safetyFilterLevel,
      personGeneration: personGeneration,
      outputOptions: outputOptions,
      addWatermark: addWatermark,
      includeResponsibleAIFilterReason: includeRAIReason,
      includeSafetyAttributes: includeSafetyAttributes
    )

    let jsonData = try encoder.encode(parameters)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "addWatermark" : \(addWatermark),
      "aspectRatio" : "\(aspectRatio)",
      "includeRaiReason" : \(includeRAIReason),
      "includeSafetyAttributes" : \(includeSafetyAttributes),
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
      sampleImageSize: nil,
      safetyFilterLevel: safetyFilterLevel,
      personGeneration: nil,
      outputOptions: nil,
      addWatermark: addWatermark,
      includeResponsibleAIFilterReason: nil,
      includeSafetyAttributes: nil
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
      sampleImageSize: nil,
      safetyFilterLevel: nil,
      personGeneration: nil,
      outputOptions: nil,
      addWatermark: nil,
      includeResponsibleAIFilterReason: nil,
      includeSafetyAttributes: nil
    )

    let jsonData = try encoder.encode(parameters)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {

    }
    """)
  }
}
