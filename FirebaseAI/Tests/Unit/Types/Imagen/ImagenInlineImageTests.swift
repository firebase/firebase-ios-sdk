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
final class ImagenInlineImageTests: XCTestCase {
  let decoder = JSONDecoder()

  func testDecodeImage_bytesBase64Encoded() throws {
    let mimeType = "image/png"
    let bytesBase64Encoded = "dGVzdC1iYXNlNjQtZGF0YQ=="
    let json = """
    {
      "bytesBase64Encoded": "\(bytesBase64Encoded)",
      "mimeType": "\(mimeType)"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let image = try decoder.decode(ImagenInlineImage.self, from: jsonData)

    XCTAssertEqual(image.mimeType, mimeType)
    XCTAssertEqual(image.data.base64EncodedString(), bytesBase64Encoded)
    XCTAssertEqual(image._internalImagenImage.mimeType, mimeType)
    XCTAssertEqual(image._internalImagenImage.bytesBase64Encoded, bytesBase64Encoded)
    XCTAssertNil(image._internalImagenImage.gcsURI)
  }

  func testDecodeImage_missingBytesBase64Encoded_throws() throws {
    let json = """
    {
      "mimeType": "image/jpeg"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    do {
      _ = try decoder.decode(ImagenInlineImage.self, from: jsonData)
      XCTFail("Expected an error; none thrown.")
    } catch let DecodingError.keyNotFound(codingKey, _) {
      let codingKey = try XCTUnwrap(codingKey as? ImagenInlineImage.CodingKeys)
      XCTAssertEqual(codingKey, .bytesBase64Encoded)
    } catch {
      XCTFail("Expected a DecodingError.keyNotFound error; got \(error).")
    }
  }

  func testDecodeImage_missingMimeType_throws() throws {
    let json = """
    {
      "bytesBase64Encoded": "dGVzdC1iYXNlNjQtZGF0YQ=="
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    do {
      _ = try decoder.decode(ImagenInlineImage.self, from: jsonData)
      XCTFail("Expected an error; none thrown.")
    } catch let DecodingError.keyNotFound(codingKey, _) {
      let codingKey = try XCTUnwrap(codingKey as? ImagenInlineImage.CodingKeys)
      XCTAssertEqual(codingKey, .mimeType)
    } catch {
      XCTFail("Expected a DecodingError.keyNotFound error; got \(error).")
    }
  }

  func testDecodeImage_invalidBase64Data_throws() throws {
    let bytesBase64Encoded = "not-a-base64-string"
    let json = """
    {
      "bytesBase64Encoded": "\(bytesBase64Encoded)",
      "mimeType": "image/png"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    do {
      _ = try decoder.decode(ImagenInlineImage.self, from: jsonData)
      XCTFail("Expected an error; none thrown.")
    } catch let DecodingError.dataCorrupted(context) {
      XCTAssertEqual(
        context.debugDescription,
        "Failed to decode data from base64-encoded string: \(bytesBase64Encoded)"
      )
    } catch {
      XCTFail("Expected a DecodingError.dataCorrupted error; got \(error).")
    }
  }
}
