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

import FirebaseAILogic
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class ModalityTokenCountTests: XCTestCase {
  let decoder = JSONDecoder()

  // MARK: - Decoding Tests

  func testDecodeModalityTokenCount_valid() throws {
    let json = """
    {
      "modality": "TEXT",
      "tokenCount": 123
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let tokenCount = try decoder.decode(ModalityTokenCount.self, from: jsonData)

    XCTAssertEqual(tokenCount.modality, .text)
    XCTAssertEqual(tokenCount.modality.rawValue, "TEXT")
    XCTAssertEqual(tokenCount.tokenCount, 123)
  }

  func testDecodeModalityTokenCount_missingTokenCount_defaultsToZero() throws {
    let json = """
    {
      "modality": "AUDIO"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let tokenCount = try decoder.decode(ModalityTokenCount.self, from: jsonData)

    XCTAssertEqual(tokenCount.modality, .audio)
    XCTAssertEqual(tokenCount.modality.rawValue, "AUDIO")
    XCTAssertEqual(tokenCount.tokenCount, 0)
  }

  func testDecodeModalityTokenCount_unrecognizedModalityString_succeeds() throws {
    let newModality = "NEW_MODALITY_NAME"
    let json = """
    {
      "modality": "\(newModality)",
      "tokenCount": 50
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let tokenCount = try decoder.decode(ModalityTokenCount.self, from: jsonData)

    XCTAssertEqual(tokenCount.tokenCount, 50)
    XCTAssertEqual(tokenCount.modality.rawValue, newModality)
  }

  func testDecodeModalityTokenCount_missingModalityKey_throws() throws {
    let json = """
    {
      "tokenCount": 50
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    do {
      _ = try decoder.decode(ModalityTokenCount.self, from: jsonData)
      XCTFail("Expected a DecodingError, but decoding succeeded.")
    } catch let DecodingError.keyNotFound(key, _) {
      XCTAssertEqual(key.stringValue, "modality")
    } catch {
      XCTFail("Expected a DecodingError.keyNotFound, but received \(error)")
    }
  }
}
