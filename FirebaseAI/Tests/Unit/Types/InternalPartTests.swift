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

@testable import FirebaseAI
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class InternalPartTests: XCTestCase {
  let decoder = JSONDecoder()

  func testDecodeTextPartWithThought() throws {
    let json = """
    {
      "text": "This is a thought.",
      "thought": true
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))
    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertEqual(part.isThought, true)
    guard case let .text(text) = part.data else {
      XCTFail("Decoded part is not a text part.")
      return
    }
    XCTAssertEqual(text, "This is a thought.")
  }

  func testDecodeTextPartWithoutThought() throws {
    let json = """
    {
      "text": "This is not a thought."
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))
    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .text(text) = part.data else {
      XCTFail("Decoded part is not a text part.")
      return
    }
    XCTAssertEqual(text, "This is not a thought.")
  }

  func testDecodeInlineDataPartWithThought() throws {
    let imageBase64 =
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+P+/HgAFhAJ/wlseKgAAAABJRU5ErkJggg=="
    let mimeType = "image/png"
    let json = """
    {
      "inlineData": {
        "mimeType": "\(mimeType)",
        "data": "\(imageBase64)"
      },
      "thought": true
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))
    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertEqual(part.isThought, true)
    guard case let .inlineData(inlineData) = part.data else {
      XCTFail("Decoded part is not an inlineData part.")
      return
    }
    XCTAssertEqual(inlineData.mimeType, mimeType)
    XCTAssertEqual(inlineData.data, Data(base64Encoded: imageBase64))
  }

  // TODO(andrewheard): Add testDecodeInlineDataPartWithoutThought
  // TODO(andrewheard): Add testDecodeFunctionCallPartWithThought
  // TODO(andrewheard): Add testDecodeFunctionCallPartWithThoughtSignature
  // TODO(andrewheard): Add testDecodeFunctionCallPartWithoutThought
}
