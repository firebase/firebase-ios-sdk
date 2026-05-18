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

  // MARK: - CitationMetadata Encoding

  func testEncodeCitationMetadata() throws {
    let citation = Citation(
      startIndex: expectedStartIndex,
      endIndex: expectedEndIndex,
      uri: expectedURI,
      title: "Test Title",
      license: "Apache-2.0",
      publicationDate: DateComponents(year: 2026, month: 5, day: 18)
    )
    let metadata = CitationMetadata(citations: [citation])
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(metadata)
    let jsonString = try XCTUnwrap(String(data: data, encoding: .utf8))

    XCTAssertEqual(jsonString, """
    {
      "citations" : [
        {
          "endIndex" : 200,
          "license" : "Apache-2.0",
          "publicationDate" : {
            "day" : 18,
            "month" : 5,
            "year" : 2026
          },
          "startIndex" : 100,
          "title" : "Test Title",
          "uri" : "https://example.com/citation-1"
        }
      ]
    }
    """)

    let decodedMetadata = try decoder.decode(CitationMetadata.self, from: data)
    XCTAssertEqual(decodedMetadata.citations.count, 1)
    let decodedCitation = try XCTUnwrap(decodedMetadata.citations.first)
    XCTAssertEqual(decodedCitation.startIndex, expectedStartIndex)
    XCTAssertEqual(decodedCitation.endIndex, expectedEndIndex)
    XCTAssertEqual(decodedCitation.uri, expectedURI)
    XCTAssertEqual(decodedCitation.title, "Test Title")
    XCTAssertEqual(decodedCitation.license, "Apache-2.0")
    XCTAssertEqual(decodedCitation.publicationDate?.year, 2026)
    XCTAssertEqual(decodedCitation.publicationDate?.month, 5)
    XCTAssertEqual(decodedCitation.publicationDate?.day, 18)
  }
}
