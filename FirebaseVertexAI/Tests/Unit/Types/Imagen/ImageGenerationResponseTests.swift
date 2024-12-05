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
final class ImageGenerationResponseTests: XCTestCase {
  let decoder = JSONDecoder()

  // MARK: - Image Decoding

  func testDecodeImage_bytesBase64Encoded() throws {
    let mimeType = "image/png"
    let bytesBase64Encoded = "test-base64-bytes"
    let json = """
    {
      "bytesBase64Encoded": "\(bytesBase64Encoded)",
      "mimeType": "\(mimeType)"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let image = try decoder.decode(ImageGenerationResponse.Image.self, from: jsonData)

    XCTAssertEqual(image.mimeType, mimeType)
    XCTAssertEqual(image.bytesBase64Encoded, bytesBase64Encoded)
    XCTAssertNil(image.gcsURI)
  }

  func testDecodeImage_gcsURI() throws {
    let gcsURI = "gs://test-bucket/images/123456789/sample_0.png"
    let mimeType = "image/jpeg"
    let json = """
    {
      "mimeType": "\(mimeType)",
      "gcsUri": "\(gcsURI)"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let image = try decoder.decode(ImageGenerationResponse.Image.self, from: jsonData)

    XCTAssertEqual(image.mimeType, mimeType)
    XCTAssertEqual(image.gcsURI, gcsURI)
    XCTAssertNil(image.bytesBase64Encoded)
  }

  func testDecodeImage_missingBytesBase64EncodedAndGCSURI_throws() throws {
    let json = """
    {
      "mimeType": "image/jpeg"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    do {
      _ = try decoder.decode(ImageGenerationResponse.Image.self, from: jsonData)
      XCTFail("Expected an error; none thrown.")
    } catch let DecodingError.dataCorrupted(context) {
      let codingPath = try XCTUnwrap(context
        .codingPath as? [ImageGenerationResponse.Image.CodingKeys])
      XCTAssertEqual(codingPath, [.bytesBase64Encoded, .gcsURI])
      XCTAssertTrue(context.debugDescription.contains("both are nil"))
    } catch {
      XCTFail("Expected a DecodingError.dataCorrupted error; got \(error).")
    }
  }

  func testDecodeImage_bothBytesBase64EncodedAndGCSURI_throws() throws {
    let json = """
    {
      "bytesBase64Encoded": "test-base64-bytes",
      "mimeType": "image/png",
      "gcsUri": "gs://test-bucket/images/123456789/sample_0.png"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    do {
      _ = try decoder.decode(ImageGenerationResponse.Image.self, from: jsonData)
      XCTFail("Expected an error; none thrown.")
    } catch let DecodingError.dataCorrupted(context) {
      let codingPath = try XCTUnwrap(context
        .codingPath as? [ImageGenerationResponse.Image.CodingKeys])
      XCTAssertEqual(codingPath, [.bytesBase64Encoded, .gcsURI])
      XCTAssertTrue(context.debugDescription.contains("both are specified"))
    } catch {
      XCTFail("Expected a DecodingError.dataCorrupted error; got \(error).")
    }
  }

  // MARK: - RAI Filtered Reason Decoding

  func testDecodeRAIFilteredReason() throws {
    let raiFilteredReason = """
    Unable to show generated images. All images were filtered out because they violated Vertex \
    AI's usage guidelines. You will not be charged for blocked images. Try rephrasing the prompt. \
    If you think this was an error, send feedback. Support codes: 1234567
    """
    let json = """
    {
      "raiFilteredReason": "\(raiFilteredReason)"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let filterReason = try decoder.decode(
      ImageGenerationResponse.RAIFilteredReason.self,
      from: jsonData
    )

    XCTAssertEqual(filterReason.raiFilteredReason, raiFilteredReason)
  }

  func testDecodeRAIFilteredReason_reasonNotSpecified_throws() throws {
    let json = """
    {
      "otherField": "test-value"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    do {
      _ = try decoder.decode(ImageGenerationResponse.RAIFilteredReason.self, from: jsonData)
      XCTFail("Expected an error; none thrown.")
    } catch let DecodingError.keyNotFound(codingKey, _) {
      let codingKey = try XCTUnwrap(
        codingKey as? ImageGenerationResponse.RAIFilteredReason.CodingKeys
      )
      XCTAssertEqual(codingKey, .raiFilteredReason)
    } catch {
      XCTFail("Expected a DecodingError.keyNotFound error; got \(error).")
    }
  }

  // MARK: - Image Generation Response Decoding

  func testDecodeResponse_oneBase64Image_noneFiltered() throws {
    let mimeType = "image/png"
    let bytesBase64Encoded = "test-base64-bytes"
    let image = ImageGenerationResponse.Image(
      mimeType: mimeType,
      bytesBase64Encoded: bytesBase64Encoded,
      gcsURI: nil
    )
    let json = """
    {
      "predictions": [
        {
          "bytesBase64Encoded": "\(bytesBase64Encoded)",
          "mimeType": "\(mimeType)"
        },
      ]
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let response = try decoder.decode(ImageGenerationResponse.self, from: jsonData)

    XCTAssertEqual(response.images, [image])
    XCTAssertNil(response.raiFilteredReason)
  }

  func testDecodeResponse_multipleBase64Images_noneFiltered() throws {
    let mimeType = "image/png"
    let bytesBase64Encoded1 = "test-base64-bytes-1"
    let bytesBase64Encoded2 = "test-base64-bytes-2"
    let bytesBase64Encoded3 = "test-base64-bytes-3"
    let image1 = ImageGenerationResponse.Image(
      mimeType: mimeType,
      bytesBase64Encoded: bytesBase64Encoded1,
      gcsURI: nil
    )
    let image2 = ImageGenerationResponse.Image(
      mimeType: mimeType,
      bytesBase64Encoded: bytesBase64Encoded2,
      gcsURI: nil
    )
    let image3 = ImageGenerationResponse.Image(
      mimeType: mimeType,
      bytesBase64Encoded: bytesBase64Encoded3,
      gcsURI: nil
    )
    let json = """
    {
      "predictions": [
        {
          "bytesBase64Encoded": "\(bytesBase64Encoded1)",
          "mimeType": "\(mimeType)"
        },
        {
          "bytesBase64Encoded": "\(bytesBase64Encoded2)",
          "mimeType": "\(mimeType)"
        },
        {
          "bytesBase64Encoded": "\(bytesBase64Encoded3)",
          "mimeType": "\(mimeType)"
        },
      ]
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let response = try decoder.decode(ImageGenerationResponse.self, from: jsonData)

    XCTAssertEqual(response.images, [image1, image2, image3])
    XCTAssertNil(response.raiFilteredReason)
  }

  func testDecodeResponse_multipleBase64Images_someFiltered() throws {
    let mimeType = "image/png"
    let bytesBase64Encoded1 = "test-base64-bytes-1"
    let bytesBase64Encoded2 = "test-base64-bytes-2"
    let image1 = ImageGenerationResponse.Image(
      mimeType: mimeType,
      bytesBase64Encoded: bytesBase64Encoded1,
      gcsURI: nil
    )
    let image2 = ImageGenerationResponse.Image(
      mimeType: mimeType,
      bytesBase64Encoded: bytesBase64Encoded2,
      gcsURI: nil
    )
    let raiFilteredReason = """
    Your current safety filter threshold filtered out 2 generated images. You will not be charged \
    for blocked images. Try rephrasing the prompt. If you think this was an error, send feedback.
    """
    let json = """
    {
      "predictions": [
        {
          "bytesBase64Encoded": "\(bytesBase64Encoded1)",
          "mimeType": "\(mimeType)"
        },
        {
          "bytesBase64Encoded": "\(bytesBase64Encoded2)",
          "mimeType": "\(mimeType)"
        },
        {
          "raiFilteredReason": "\(raiFilteredReason)"
        },
      ]
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let response = try decoder.decode(ImageGenerationResponse.self, from: jsonData)

    XCTAssertEqual(response.images, [image1, image2])
    XCTAssertEqual(response.raiFilteredReason, raiFilteredReason)
  }

  func testDecodeResponse_multipleGCSImages_noneFiltered() throws {
    let mimeType = "image/png"
    let gcsURI1 = "gs://test-bucket/images/123456789/sample_0.png"
    let gcsURI2 = "gs://test-bucket/images/123456789/sample_1.png"
    let image1 = ImageGenerationResponse.Image(
      mimeType: mimeType,
      bytesBase64Encoded: nil,
      gcsURI: gcsURI1
    )
    let image2 = ImageGenerationResponse.Image(
      mimeType: mimeType,
      bytesBase64Encoded: nil,
      gcsURI: gcsURI2
    )
    let json = """
    {
      "predictions": [
        {
          "gcsUri": "\(gcsURI1)",
          "mimeType": "\(mimeType)"
        },
        {
          "gcsUri": "\(gcsURI2)",
          "mimeType": "\(mimeType)"
        },
      ]
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let response = try decoder.decode(ImageGenerationResponse.self, from: jsonData)

    XCTAssertEqual(response.images, [image1, image2])
    XCTAssertNil(response.raiFilteredReason)
  }

  func testDecodeResponse_noImages_allFiltered() throws {
    let raiFilteredReason = """
    Unable to show generated images. All images were filtered out because they violated Vertex \
    AI's usage guidelines. You will not be charged for blocked images. Try rephrasing the prompt. \
    If you think this was an error, send feedback. Support codes: 1234567
    """
    let json = """
    {
      "predictions": [
        {
          "raiFilteredReason": "\(raiFilteredReason)"
        },
      ]
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let response = try decoder.decode(ImageGenerationResponse.self, from: jsonData)

    XCTAssertEqual(response.images, [])
    XCTAssertEqual(response.raiFilteredReason, raiFilteredReason)
  }

  func testDecodeResponse_noImagesAnd_noFilteredReason() throws {
    let json = "{}"
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let response = try decoder.decode(ImageGenerationResponse.self, from: jsonData)

    XCTAssertEqual(response.images, [])
    XCTAssertNil(response.raiFilteredReason)
  }

  func testDecodeResponse_multipleFilterReasons_returnsFirst() throws {
    let raiFilteredReason1 = "filtered-reason-1"
    let raiFilteredReason2 = "filtered-reason-2"
    let json = """
    {
      "predictions": [
        {
          "raiFilteredReason": "\(raiFilteredReason1)"
        },
        {
          "raiFilteredReason": "\(raiFilteredReason2)"
        },
      ]
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let response = try decoder.decode(ImageGenerationResponse.self, from: jsonData)

    XCTAssertEqual(response.images, [])
    XCTAssertEqual(response.raiFilteredReason, raiFilteredReason1)
    XCTAssertNotEqual(response.raiFilteredReason, raiFilteredReason2)
  }

  func testDecodeResponse_unknownPrediction() throws {
    let json = """
    {
      "predictions": [
        {
          "someField": "some-value"
        },
      ]
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let response = try decoder.decode(ImageGenerationResponse.self, from: jsonData)

    XCTAssertEqual(response.images, [])
    XCTAssertNil(response.raiFilteredReason)
  }
}
