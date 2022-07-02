// Copyright 2022 Google LLC
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

import Foundation

import FirebaseStorage

import XCTest

class StorageMetadataTests: XCTestCase {
  func testReflexiveMetadataEquality() {
    let metaDict = ["bucket": "bucket", "name": "/path/to/file"]
    let metadata0 = StorageMetadata(dictionary: metaDict)
    let metadata1 = metadata0
    XCTAssertEqual(metadata0, metadata1)
  }

  func testMetadataEquality() {
    let metaDict = [
      "bucket": "bucket",
      "name": "/path/to/file",
      "md5Hash": "d41d8cd98f00b204e9800998ecf8427e",
    ]
    let metadata0 = StorageMetadata(dictionary: metaDict)
    let metadata1 = StorageMetadata(dictionary: metaDict)
    XCTAssertEqual(metadata0, metadata1)
  }

  func testMetadataMd5Inequality() {
    let metaDict0 = ["md5Hash": "d41d8cd98f00b204e9800998ecf8427e"]
    let metaDict1 = ["md5Hash": "d41d8cd98f00b204e9800998ecf8427f"]
    let metadata0 = StorageMetadata(dictionary: metaDict0)
    let metadata1 = StorageMetadata(dictionary: metaDict1)
    XCTAssertNotEqual(metadata0, metadata1)
  }

  func testMetadataCopy() {
    let metaDict = [
      "bucket": "bucket",
      "name": "/path/to/file",
      "md5Hash": "d41d8cd98f00b204e9800998ecf8427e",
    ]
    let metadata0 = StorageMetadata(dictionary: metaDict)
    let metadata1 = metadata0.copy() as? StorageMetadata
    // Verify that copied object has a new reference.
    XCTAssertFalse(metadata0 === metadata1)
    XCTAssertEqual(metadata0, metadata1)
  }

  func testInitializeNoMetadata() {
    let metadata = StorageMetadata(dictionary: [:])
    XCTAssertNotNil(metadata)
  }

  func testInitializeFullMetadata() {
    let metaDict = [
      "bucket": "bucket",
      "cacheControl": "max-age=3600, no-cache",
      "contentDisposition": "inline",
      "contentEncoding": "gzip",
      "contentLanguage": "en-us",
      "contentType": "application/octet-stream",
      "customMetadata": ["foo": ["bar": "baz"]],
      "generation": "12345",
      "metageneration": "67890",
      "name": "path/to/object",
      "timeCreated": "1992-08-07T17:22:53.108Z",
      "updated": "2016-03-01T20:16:01.673Z",
      "md5Hash": "d41d8cd98f00b204e9800998ecf8427e",
      "size": 1337,
    ] as [String: Any]
    let metadata = StorageMetadata(dictionary: metaDict)
    XCTAssertNotNil(metadata)
    XCTAssertEqual(metadata.bucket, metaDict["bucket"] as? String)
    XCTAssertEqual(metadata.cacheControl, metaDict["cacheControl"] as? String)
    XCTAssertEqual(metadata.contentDisposition, metaDict["contentDisposition"] as? String)
    XCTAssertEqual(metadata.contentEncoding, metaDict["contentEncoding"] as? String)
    XCTAssertEqual(metadata.contentType, metaDict["contentType"] as? String)
    XCTAssertEqual(metadata.customMetadata, metaDict["customMetadata"] as? [String: String])
    XCTAssertEqual(metadata.md5Hash, metaDict["md5Hash"] as? String)
    XCTAssertEqual("\(metadata.generation)", "12345")
    XCTAssertEqual("\(metadata.metageneration)", "67890")
    XCTAssertEqual(metadata.path, metaDict["name"] as? String)
//    XCTAssertEqual([metadata RFC3339StringFromDate:metadata.timeCreated],metaDict["TimeCreated])
//    XCTAssertEqual([metadata RFC3339StringFromDate:metadata.updated],metaDict["Updated])
    XCTAssertEqual(metadata.size, 1337)
  }
}
