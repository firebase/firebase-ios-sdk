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

import FirebaseAI
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class CitationMetadataTests: XCTestCase {
  let decoder = JSONDecoder()

  // MARK: - Google AI Format Decoding

  func testDecodeCitationMetadata_googleAIFormat() throws {
    let json = """
    {
      "citationSources": [
        {
          "startIndex": 100,
          "endIndex": 200,
          "uri": "https://example.com/citation-1"
        }
      ]
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let citationMetadata = try decoder.decode(
      CitationMetadata.self,
      from: jsonData
    )

    XCTAssertEqual(citationMetadata.citations.count, 1)
    let citation = try XCTUnwrap(citationMetadata.citations.first)
    XCTAssertEqual(citation.startIndex, 100)
    XCTAssertEqual(citation.endIndex, 200)
    XCTAssertEqual(citation.uri, "https://example.com/citation-1")
    XCTAssertNil(citation.license)
    XCTAssertNil(citation.publicationDate)
    XCTAssertNil(citation.title)
  }

  // MARK: - Vertex AI Format Decoding

  func testDecodeCitationMetadata_vertexAIFormat_basic() throws {
    let json = """
    {
      "citations": [
        {
          "startIndex": 100,
          "endIndex": 200,
          "uri": "https://example.com/citation-1"
        }
      ]
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let citationMetadata = try decoder.decode(
      CitationMetadata.self,
      from: jsonData
    )

    XCTAssertEqual(citationMetadata.citations.count, 1)
    let citation = try XCTUnwrap(citationMetadata.citations.first)
    XCTAssertEqual(citation.startIndex, 100)
    XCTAssertEqual(citation.endIndex, 200)
    XCTAssertEqual(citation.uri, "https://example.com/citation-1")
    XCTAssertNil(citation.license)
    XCTAssertNil(citation.publicationDate)
    XCTAssertNil(citation.title)
  }
}
