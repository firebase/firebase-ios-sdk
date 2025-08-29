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
final class RAIFilteredReasonTests: XCTestCase {
  let decoder = JSONDecoder()

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
      RAIFilteredReason.self,
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
      _ = try decoder.decode(RAIFilteredReason.self, from: jsonData)
      XCTFail("Expected an error; none thrown.")
    } catch let DecodingError.keyNotFound(codingKey, _) {
      let codingKey = try XCTUnwrap(
        codingKey as? RAIFilteredReason.CodingKeys
      )
      XCTAssertEqual(codingKey, .raiFilteredReason)
    } catch {
      XCTFail("Expected a DecodingError.keyNotFound error; got \(error).")
    }
  }
}
