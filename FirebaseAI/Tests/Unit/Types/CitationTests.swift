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
final class CitationTests: XCTestCase {
  let decoder = JSONDecoder()

  // MARK: - Decoding Tests

  func testDecodeCitation_minimalParameters() throws {
    let expectedEndIndex = 150
    let json = """
    {
      "endIndex" : \(expectedEndIndex)
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let citation = try decoder.decode(Citation.self, from: jsonData)

    XCTAssertEqual(citation.startIndex, 0, "Omitted startIndex should be decoded as 0.")
    XCTAssertEqual(citation.endIndex, expectedEndIndex)
    XCTAssertNil(citation.uri)
    XCTAssertNil(citation.title)
    XCTAssertNil(citation.license)
    XCTAssertNil(citation.publicationDate)
  }

  func testDecodeCitation_allParameters() throws {
    let expectedStartIndex = 100
    let expectedEndIndex = 200
    let expectedURI = "https://example.com/citation-1"
    let expectedTitle = "Example Citation Title"
    let expectedLicense = "mit"
    let expectedYear = 2023
    let expectedMonth = 10
    let expectedDay = 26
    let json = """
    {
      "startIndex" : \(expectedStartIndex),
      "endIndex" : \(expectedEndIndex),
      "uri" : "\(expectedURI)",
      "title" : "\(expectedTitle)",
      "license" : "\(expectedLicense)",
      "publicationDate" : {
        "year" : \(expectedYear),
        "month" : \(expectedMonth),
        "day" : \(expectedDay)
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let citation = try decoder.decode(Citation.self, from: jsonData)

    XCTAssertEqual(citation.startIndex, expectedStartIndex)
    XCTAssertEqual(citation.endIndex, expectedEndIndex)
    XCTAssertEqual(citation.uri, expectedURI)
    XCTAssertEqual(citation.title, expectedTitle)
    XCTAssertEqual(citation.license, expectedLicense)
    let publicationDate = try XCTUnwrap(citation.publicationDate)
    XCTAssertEqual(publicationDate.year, expectedYear)
    XCTAssertEqual(publicationDate.month, expectedMonth)
    XCTAssertEqual(publicationDate.day, expectedDay)
  }

  func testDecodeCitation_emptyStringsForOptionals_setsToNil() throws {
    let expectedEndIndex = 300
    let json = """
    {
      "endIndex" : \(expectedEndIndex),
      "uri" : "",
      "title" : "",
      "license" : ""
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let citation = try decoder.decode(Citation.self, from: jsonData)

    XCTAssertEqual(citation.startIndex, 0, "Omitted startIndex should be decoded as 0.")
    XCTAssertEqual(citation.endIndex, expectedEndIndex)
    XCTAssertNil(citation.uri, "Empty URI string should be decoded as nil.")
    XCTAssertNil(citation.title, "Empty title string should be decoded as nil.")
    XCTAssertNil(citation.license, "Empty license string should be decoded as nil.")
    XCTAssertNil(citation.publicationDate)
  }

  func testDecodeCitation_missingEndIndex_throws() throws {
    let json = """
    {
      "startIndex" : 10
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    XCTAssertThrowsError(try decoder.decode(Citation.self, from: jsonData))
  }
}
