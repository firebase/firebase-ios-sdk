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
final class ImagenGenerationResponseTests: XCTestCase {
  let decoder = JSONDecoder()

  func testDecodeResponse_oneBase64Image_noneFiltered() throws {
    let mimeType = "image/png"
    let bytesBase64Encoded = "dGVzdC1iYXNlNjQtZGF0YQ=="
    let image = try ImagenInlineImage(
      mimeType: mimeType, data: XCTUnwrap(Data(base64Encoded: bytesBase64Encoded))
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

    let response = try decoder.decode(
      ImagenGenerationResponse<ImagenInlineImage>.self,
      from: jsonData
    )

    XCTAssertEqual(response.images, [image])
    XCTAssertNil(response.filteredReason)
  }

  func testDecodeResponse_multipleBase64Images_noneFiltered() throws {
    let mimeType = "image/png"
    let bytesBase64Encoded1 = "dGVzdC1iYXNlNjQtYnl0ZXMtMQ=="
    let bytesBase64Encoded2 = "dGVzdC1iYXNlNjQtYnl0ZXMtMg=="
    let bytesBase64Encoded3 = "dGVzdC1iYXNlNjQtYnl0ZXMtMw=="
    let image1 = try ImagenInlineImage(
      mimeType: mimeType, data: XCTUnwrap(Data(base64Encoded: bytesBase64Encoded1))
    )
    let image2 = try ImagenInlineImage(
      mimeType: mimeType, data: XCTUnwrap(Data(base64Encoded: bytesBase64Encoded2))
    )
    let image3 = try ImagenInlineImage(
      mimeType: mimeType, data: XCTUnwrap(Data(base64Encoded: bytesBase64Encoded3))
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

    let response = try decoder.decode(
      ImagenGenerationResponse<ImagenInlineImage>.self,
      from: jsonData
    )

    XCTAssertEqual(response.images, [image1, image2, image3])
    XCTAssertNil(response.filteredReason)
  }

  func testDecodeResponse_multipleBase64Images_someFiltered() throws {
    let mimeType = "image/png"
    let bytesBase64Encoded1 = "dGVzdC1iYXNlNjQtYnl0ZXMtMQ=="
    let bytesBase64Encoded2 = "dGVzdC1iYXNlNjQtYnl0ZXMtMg=="
    let image1 = try ImagenInlineImage(
      mimeType: mimeType, data: XCTUnwrap(Data(base64Encoded: bytesBase64Encoded1))
    )
    let image2 = try ImagenInlineImage(
      mimeType: mimeType, data: XCTUnwrap(Data(base64Encoded: bytesBase64Encoded2))
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

    let response = try decoder.decode(
      ImagenGenerationResponse<ImagenInlineImage>.self,
      from: jsonData
    )

    XCTAssertEqual(response.images, [image1, image2])
    XCTAssertEqual(response.filteredReason, raiFilteredReason)
  }

  func testDecodeResponse_multipleGCSImages_noneFiltered() throws {
    let mimeType = "image/png"
    let gcsURI1 = "gs://test-bucket/images/123456789/sample_0.png"
    let gcsURI2 = "gs://test-bucket/images/123456789/sample_1.png"
    let image1 = ImagenGCSImage(mimeType: mimeType, gcsURI: gcsURI1)
    let image2 = ImagenGCSImage(mimeType: mimeType, gcsURI: gcsURI2)
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

    let response = try decoder.decode(
      ImagenGenerationResponse<ImagenGCSImage>.self,
      from: jsonData
    )

    XCTAssertEqual(response.images, [image1, image2])
    XCTAssertNil(response.filteredReason)
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

    do {
      let response = try decoder.decode(
        ImagenGenerationResponse<ImagenGCSImage>.self,
        from: jsonData
      )
      XCTFail("Expected a ImagenImagesBlockedError, got response: \(response)")
    } catch let error as ImagenImagesBlockedError {
      XCTAssertEqual(error.message, raiFilteredReason)
    } catch {
      XCTFail("Expected an ImagenImagesBlockedError, got error: \(error)")
    }
  }

  func testDecodeResponse_noImagesAnd_noFilteredReason() throws {
    let json = "{}"
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    do {
      let response = try decoder.decode(
        ImagenGenerationResponse<ImagenInlineImage>.self,
        from: jsonData
      )
      XCTFail("Expected a DecodingError, got response: \(response)")
    } catch let DecodingError.keyNotFound(codingKey, _) {
      XCTAssertEqual(codingKey.stringValue, "predictions")
    } catch {
      XCTFail("Expected a DecodingError.keyNotFound, got error: \(error)")
    }
  }

  func testDecodeResponse_multipleFilterReasons_concatenatesReasons() throws {
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

    do {
      let response = try decoder.decode(
        ImagenGenerationResponse<ImagenGCSImage>.self,
        from: jsonData
      )
      XCTFail("Expected an ImagenImagesBlockedError, got response: \(response)")
    } catch let error as ImagenImagesBlockedError {
      XCTAssertEqual(error.message, "\(raiFilteredReason1)\n\(raiFilteredReason2)")
    } catch {
      XCTFail("Expected an ImagenImagesBlockedError, got error: \(error)")
    }
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

    do {
      let response = try decoder.decode(
        ImagenGenerationResponse<ImagenGCSImage>.self,
        from: jsonData
      )
      XCTFail("Expected a DecodingError.dataCorrupted, got response: \(response)")
    } catch let DecodingError.dataCorrupted(context) {
      XCTAssertEqual(context.debugDescription, "No images or filtered reasons in response.")
    } catch {
      XCTFail("Expected a DecodingError.dataCorrupted, got error: \(error)")
    }
  }
}
