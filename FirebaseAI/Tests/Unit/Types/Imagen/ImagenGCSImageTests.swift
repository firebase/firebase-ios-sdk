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
final class ImagenGCSImageTests: XCTestCase {
  let decoder = JSONDecoder()

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

    let image = try decoder.decode(ImagenGCSImage.self, from: jsonData)

    XCTAssertEqual(image.mimeType, mimeType)
    XCTAssertEqual(image.gcsURI, gcsURI)
    XCTAssertEqual(image._internalImagenImage.mimeType, mimeType)
    XCTAssertEqual(image._internalImagenImage.gcsURI, gcsURI)
    XCTAssertNil(image._internalImagenImage.bytesBase64Encoded)
  }

  func testDecodeImage_missingGCSURI_throws() throws {
    let json = """
    {
      "mimeType": "image/jpeg"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    do {
      _ = try decoder.decode(ImagenGCSImage.self, from: jsonData)
      XCTFail("Expected an error; none thrown.")
    } catch let DecodingError.keyNotFound(codingKey, _) {
      let codingKey = try XCTUnwrap(codingKey as? ImagenGCSImage.CodingKeys)
      XCTAssertEqual(codingKey, .gcsURI)
    } catch {
      XCTFail("Expected a DecodingError.keyNotFound error; got \(error).")
    }
  }

  func testDecodeImage_missingMimeType_throws() throws {
    let json = """
    {
      "gcsUri": "gs://test-bucket/images/123456789/sample_0.png"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    do {
      _ = try decoder.decode(ImagenGCSImage.self, from: jsonData)
      XCTFail("Expected an error; none thrown.")
    } catch let DecodingError.keyNotFound(codingKey, _) {
      let codingKey = try XCTUnwrap(codingKey as? ImagenGCSImage.CodingKeys)
      XCTAssertEqual(codingKey, .mimeType)
    } catch {
      XCTFail("Expected a DecodingError.keyNotFound error; got \(error).")
    }
  }
}
