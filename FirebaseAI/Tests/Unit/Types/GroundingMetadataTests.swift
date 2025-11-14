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
    let groundingChunk = try XCTUnwrap(metadata.groundingChunks.first)
    let webChunk = try XCTUnwrap(groundingChunk.web)
    XCTAssertEqual(webChunk.uri, "uri1")
    XCTAssertEqual(metadata.groundingSupports.count, 1)
    let groundingSupport = try XCTUnwrap(metadata.groundingSupports.first)
    XCTAssertEqual(groundingSupport.segment.startIndex, 0)
    XCTAssertEqual(groundingSupport.segment.partIndex, 0)
    XCTAssertEqual(groundingSupport.segment.endIndex, 10)
    XCTAssertEqual(groundingSupport.segment.text, "text")
    let searchEntryPoint = try XCTUnwrap(metadata.searchEntryPoint)
    XCTAssertEqual(searchEntryPoint.renderedContent, "html")
  }

  func testDecodeGroundingMetadata_missingSegments() throws {
    let json = """
    {
      "groundingSupports": [
        { "segment": { "endIndex": 10, "text": "text" }, "groundingChunkIndices": [0] },
        { "groundingChunkIndices": [0] }
      ],
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let metadata = try decoder.decode(GroundingMetadata.self, from: jsonData)

    XCTAssertEqual(metadata.groundingSupports.count, 1)
    let groundingSupport = try XCTUnwrap(metadata.groundingSupports.first)
    XCTAssertEqual(groundingSupport.segment.startIndex, 0)
    XCTAssertEqual(groundingSupport.segment.partIndex, 0)
    XCTAssertEqual(groundingSupport.segment.endIndex, 10)
    XCTAssertEqual(groundingSupport.segment.text, "text")
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

  func testDecodeSearchEntrypoint_missingRenderedContent() throws {
    let json = "{}"
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    XCTAssertThrowsError(try decoder.decode(
      GroundingMetadata.SearchEntryPoint.self,
      from: jsonData
    ))
  }

  func testDecodeSearchEntrypoint_withRenderedContent() throws {
    let json = """
    { "renderedContent": "html" }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let searchEntrypoint = try decoder.decode(
      GroundingMetadata.SearchEntryPoint.self,
      from: jsonData
    )

    XCTAssertEqual(searchEntrypoint.renderedContent, "html")
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
    let support = try decoder.decode(
      GroundingMetadata.GroundingSupport.Internal.self,
      from: jsonData
    )
    XCTAssertNil(support.segment)
    XCTAssertEqual(support.groundingChunkIndices, [1, 2])
    XCTAssertNil(support.toPublic())
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
