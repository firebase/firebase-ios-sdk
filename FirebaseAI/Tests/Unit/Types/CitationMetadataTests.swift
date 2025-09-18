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

import XCTest

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class CitationMetadataTests: XCTestCase {
  let decoder = JSONDecoder()

  let expectedStartIndex = 100
  let expectedEndIndex = 200
  let expectedURI = "https://example.com/citation-1"
  lazy var citationJSON = """
  {
    "startIndex" : \(expectedStartIndex),
    "endIndex" : \(expectedEndIndex),
    "uri" : "\(expectedURI)"
  }
  """
  lazy var expectedCitation = Citation(
    startIndex: expectedStartIndex,
    endIndex: expectedEndIndex,
    uri: expectedURI
  )

  // MARK: - Google AI Format Decoding

  func testDecodeCitationMetadata_googleAIFormat() throws {
    let json = """
    {
      "citationSources": [\(citationJSON)]
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let citationMetadata = try decoder.decode(
      CitationMetadata.self,
      from: jsonData
    )

    XCTAssertEqual(citationMetadata.citations.count, 1)
    let citation = try XCTUnwrap(citationMetadata.citations.first)
    XCTAssertEqual(citation, expectedCitation)
  }

  // MARK: - Vertex AI Format Decoding

  func testDecodeCitationMetadata_vertexAIFormat() throws {
    let json = """
    {
      "citations": [\(citationJSON)]
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let citationMetadata = try decoder.decode(
      CitationMetadata.self,
      from: jsonData
    )

    XCTAssertEqual(citationMetadata.citations.count, 1)
    let citation = try XCTUnwrap(citationMetadata.citations.first)
    XCTAssertEqual(citation, expectedCitation)
  }
}
