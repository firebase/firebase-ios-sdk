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

@testable import FirebaseAI

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class GroundingMetadataTests: XCTestCase {
  let decoder = JSONDecoder()

  func testDecodeGroundingMetadata_allFields() throws {
    let json = """
    {
      "webSearchQueries": ["query1", "query2"],
      "groundingChunks": [
        { "web": { "uri": "uri1", "title": "title1" } }
      ],
      "groundingSupports": [
        { "segment": { "endIndex": 10, "text": "text" }, "groundingChunkIndices": [0] }
      ],
      "searchEntryPoint": { "renderedContent": "html" }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let metadata = try decoder.decode(GroundingMetadata.self, from: jsonData)

    XCTAssertEqual(metadata.webSearchQueries, ["query1", "query2"])
    XCTAssertEqual(metadata.groundingChunks.count, 1)
    XCTAssertEqual(metadata.groundingChunks.first?.web?.uri, "uri1")
    XCTAssertEqual(metadata.groundingSupports.count, 1)
    XCTAssertEqual(metadata.groundingSupports.first?.segment?.startIndex, 0)
    XCTAssertEqual(metadata.groundingSupports.first?.segment?.partIndex, 0)
    XCTAssertEqual(metadata.groundingSupports.first?.segment?.endIndex, 10)
    XCTAssertEqual(metadata.groundingSupports.first?.segment?.text, "text")
    XCTAssertEqual(metadata.searchEntryPoint?.renderedContent, "html")
  }

  func testDecodeGroundingMetadata_missingOptionals() throws {
    let json = "{}"
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let metadata = try decoder.decode(GroundingMetadata.self, from: jsonData)

    XCTAssertTrue(metadata.webSearchQueries.isEmpty)
    XCTAssertTrue(metadata.groundingChunks.isEmpty)
    XCTAssertTrue(metadata.groundingSupports.isEmpty)
    XCTAssertNil(metadata.searchEntryPoint)
  }

  func testDecodeGroundingChunk_withoutWeb() throws {
    let json = "{}"
    let jsonData = try XCTUnwrap(json.data(using: .utf8))
    let chunk = try decoder.decode(GroundingMetadata.GroundingChunk.self, from: jsonData)
    XCTAssertNil(chunk.web)
  }

  func testDecodeWebGroundingChunk_withDomain() throws {
    let json = """
    { "uri": "uri1", "title": "title1", "domain": "example.com" }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))
    let webChunk = try decoder.decode(GroundingMetadata.WebGroundingChunk.self, from: jsonData)
    XCTAssertEqual(webChunk.uri, "uri1")
    XCTAssertEqual(webChunk.title, "title1")
    XCTAssertEqual(webChunk.domain, "example.com")
  }

  func testDecodeGroundingSupport_withoutSegment() throws {
    let json = """
    { "groundingChunkIndices": [1, 2] }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))
    let support = try decoder.decode(GroundingMetadata.GroundingSupport.self, from: jsonData)
    XCTAssertNil(support.segment)
    XCTAssertEqual(support.groundingChunkIndices, [1, 2])
  }

  func testDecodeSegment_defaults() throws {
    let json = "{}"
    let jsonData = try XCTUnwrap(json.data(using: .utf8))
    let segment = try decoder.decode(Segment.self, from: jsonData)
    XCTAssertEqual(segment.partIndex, 0)
    XCTAssertEqual(segment.startIndex, 0)
    XCTAssertEqual(segment.endIndex, 0)
    XCTAssertEqual(segment.text, "")
  }
}
