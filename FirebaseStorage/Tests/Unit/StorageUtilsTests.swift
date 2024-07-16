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

import FirebaseCore
@testable import FirebaseStorage

import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class StorageUtilsTests: StorageTestHelpers {
  func testCommonExtensionToMIMEType() {
    let extensionToMIMEType = [
      "txt": "text/plain",
      "png": "image/png",
      "mp3": "audio/mpeg",
      "mov": "video/quicktime",
      "gif": "image/gif",
    ]
    for (fileExtension, mimeType) in extensionToMIMEType {
      XCTAssertEqual(StorageUtils.MIMETypeForExtension(fileExtension), mimeType)
    }
  }

  func testParseGoodDataToDict() throws {
    let jsonString = "{\"hello\" : \"world\"}"
    let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
    let jsonDictionary = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String]
    XCTAssertEqual(jsonDictionary, ["hello": "world"])
  }

  func testParseBadDataToDict() throws {
    let jsonString = "Invalid JSON Object"
    let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
    let jsonDictionary = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String]
    XCTAssertNil(jsonDictionary)
  }

  func testParseGoodDictToData() throws {
    let jsonDictionary = ["hello": "world"]
    let expectedData = try XCTUnwrap(try? JSONSerialization.data(withJSONObject: jsonDictionary))
    let jsonString = String(data: expectedData, encoding: .utf8)
    XCTAssertEqual(jsonString, "{\"hello\":\"world\"}")
  }

  func testDefaultRequestForFullPath() throws {
    let ref = rootReference().child("path/to/object")
    let request = StorageUtils.defaultRequestForReference(reference: ref)
    XCTAssertEqual(request.url?.absoluteString,
                   "https://firebasestorage.googleapis.com:443/v0/b/bucket/o/path%2Fto%2Fobject")
  }

  func testDefaultRequestForNoPath() throws {
    let ref = rootReference()
    let request = StorageUtils.defaultRequestForReference(reference: ref)
    XCTAssertEqual(request.url?.absoluteString,
                   "https://firebasestorage.googleapis.com:443/v0/b/bucket/o")
  }
}
