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

@testable import FirebaseStorage
import Foundation
import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class StoragePathTests: XCTestCase {
  func testGSURI() throws {
    let path = try StoragePath.path(string: "gs://bucket/path/to/object")
    XCTAssertEqual(path.bucket, "bucket")
    XCTAssertEqual(path.object, "path/to/object")
  }

  func testHTTPURL() throws {
    let httpURL = "http://firebasestorage.googleapis" +
      ".com/v0/b/bucket/o/path/to/object?token=signed_url_params"
    let path = try StoragePath.path(string: httpURL)
    XCTAssertEqual(path.bucket, "bucket")
    XCTAssertEqual(path.object, "path/to/object")
  }

  func testEmulatorURL() throws {
    let path = try StoragePath.path(string: "http://localhost:8070/v0/b/bucket")
    XCTAssertEqual(path.bucket, "bucket")
    XCTAssertNil(path.object)
  }

  func testGSURINoPath() throws {
    let path = try StoragePath.path(string: "gs://bucket/")
    XCTAssertEqual(path.bucket, "bucket")
    XCTAssertNil(path.object)
  }

  func testHTTPURLNoPath() throws {
    let httpURL = "http://firebasestorage.googleapis.com/v0/b/bucket/"
    let path = try StoragePath.path(string: httpURL)
    XCTAssertEqual(path.bucket, "bucket")
    XCTAssertNil(path.object)
  }

  func testGSURINoTrailingSlash() throws {
    let path = try StoragePath.path(string: "gs://bucket")
    XCTAssertEqual(path.bucket, "bucket")
    XCTAssertNil(path.object)
  }

  func testHTTPURLNoTrailingSlash() throws {
    let httpURL = "http://firebasestorage.googleapis.com/v0/b/bucket"
    let path = try StoragePath.path(string: httpURL)
    XCTAssertEqual(path.bucket, "bucket")
    XCTAssertNil(path.object)
  }

  func testGSURIPercentEncoding() throws {
    let path = try StoragePath.path(string: "gs://bucket/?/%/#")
    XCTAssertEqual(path.bucket, "bucket")
    XCTAssertEqual(path.object, "?/%/#")
  }

  func testHTTPURLPercentEncoding() throws {
    let httpURL =
      "http://firebasestorage.googleapis.com/v0/b/bucket/o/%3F/%25/%23?token=signed_url_params"
    let path = try StoragePath.path(string: httpURL)
    XCTAssertEqual(path.bucket, "bucket")
    XCTAssertEqual(path.object, "?/%/#")
  }

  func testHTTPURLNoToken() throws {
    let httpURL = "http://firebasestorage.googleapis.com/v0/b/bucket/o/%23hashtag/no/token"
    let path = try StoragePath.path(string: httpURL)
    XCTAssertEqual(path.bucket, "bucket")
    XCTAssertEqual(path.object, "#hashtag/no/token")
  }

  func testGSURIThrowsOnNoBucket() {
    XCTAssertThrowsError(try StoragePath.path(string: "gs://"))
  }

  func testHTTPURLThrowsOnNoBucket() {
    XCTAssertThrowsError(try StoragePath.path(string: "http://firebasestorage.googleapis.com/"))
  }

  func testThrowsOnInvalidScheme() {
    let ftpURL = "ftp://firebasestorage.googleapis.com/v0/b/bucket/o/path/to/object"
    XCTAssertThrowsError(try StoragePath.path(string: ftpURL))
  }

  func testHTTPURLIncorrectSchema() {
    let httpURL = "http://foo.google.com/v1/b/bucket/o/%3F/%25/%23?token=signed_url_params"
    XCTAssertThrowsError(try StoragePath.path(string: httpURL))
  }

  func testChildToRoot() {
    let path = StoragePath(with: "bucket")
    let childPath = path.child("object")
    XCTAssertEqual(childPath.stringValue(), "gs://bucket/object")
  }

  func testChildByAppendingNoPathToRoot() {
    let path = StoragePath(with: "bucket")
    let childPath = path.child("")
    XCTAssertEqual(childPath.stringValue(), "gs://bucket/")
  }

  func testChildByAppendingLeadingSlashChildToRoot() {
    let path = StoragePath(with: "bucket")
    let childPath = path.child("/object")
    XCTAssertEqual(childPath.stringValue(), "gs://bucket/object")
  }

  func testChildByAppendingTrailingSlashChildToRoot() {
    let path = StoragePath(with: "bucket")
    let childPath = path.child("object/")
    XCTAssertEqual(childPath.stringValue(), "gs://bucket/object")
  }

  func testChildByAppendingLeadingAndTrailingSlashChildToRoot() {
    let path = StoragePath(with: "bucket")
    let childPath = path.child("/object/")
    XCTAssertEqual(childPath.stringValue(), "gs://bucket/object")
  }

  func testChildByAppendingMultipleChildrenToRoot() {
    let path = StoragePath(with: "bucket")
    let childPath = path.child("path/to/object/")
    XCTAssertEqual(childPath.stringValue(), "gs://bucket/path/to/object")
  }

  func testChildByAppendingMultipleChildrenWithMultipleSlashesToRoot() {
    let path = StoragePath(with: "bucket")
    let childPath = path.child("/path///to////object////////")
    XCTAssertEqual(childPath.stringValue(), "gs://bucket/path/to/object")
  }

  func testChildByAppendingMultipleSeparateChildren() {
    let path = StoragePath(with: "bucket")
    let childPath = path.child("/path").child("to/").child("object")
    XCTAssertEqual(childPath.stringValue(), "gs://bucket/path/to/object")
  }

  func testChildByAppendingOnlySlashesToRoot() {
    let path = StoragePath(with: "bucket")
    let childPath = path.child("//////////")
    XCTAssertEqual(childPath.stringValue(), "gs://bucket/")
  }

  func testParentAtRoot() {
    let path = StoragePath(with: "bucket")
    let parent = path.parent()
    XCTAssertNil(parent)
  }

  func testParentChildPath() {
    let path = StoragePath(with: "bucket", object: "path/to/object")
    let parent = path.parent()
    XCTAssertEqual(parent?.stringValue(), "gs://bucket/path/to")
  }

  func testParentChildPathSlashes() {
    let path = StoragePath(with: "bucket", object: "path/to////")
    let parent = path.parent()
    XCTAssertEqual(parent?.stringValue(), "gs://bucket/path")
  }

  func testParentChildPathOnlySlashes() {
    let path = StoragePath(with: "bucket", object: "/////")
    let parent = path.parent()
    XCTAssertNil(parent)
  }

  func testRootAtRoot() {
    let path = StoragePath(with: "bucket")
    let root = path.root()
    XCTAssertEqual(root.stringValue(), "gs://bucket/")
  }

  func testRootAtChildPath() {
    let path = StoragePath(with: "bucket", object: "path/to/object")
    let root = path.root()
    XCTAssertEqual(root.stringValue(), "gs://bucket/")
  }

  func testRootAtSlashPath() {
    let path = StoragePath(with: "bucket", object: "/////")
    let root = path.root()
    XCTAssertEqual(root.stringValue(), "gs://bucket/")
  }

  func testCopy() {
    let path = StoragePath(with: "bucket", object: "object")
    let copiedPath = path.copy() as? StoragePath
    XCTAssertTrue(path == copiedPath)
    XCTAssertFalse(path === copiedPath)
  }

  func testCopyNoBucket() {
    let path = StoragePath(with: "", object: "object")
    let copiedPath = path.copy() as? StoragePath
    XCTAssertTrue(path == copiedPath)
    XCTAssertFalse(path === copiedPath)
  }

  func testCopyNoObject() {
    let path = StoragePath(with: "bucket")
    let copiedPath = path.copy() as? StoragePath
    XCTAssertTrue(path == copiedPath)
    XCTAssertFalse(path === copiedPath)
  }

  func testCopyNothing() {
    let path = StoragePath(with: "")
    let copiedPath = path.copy() as? StoragePath
    XCTAssertTrue(path == copiedPath)
    XCTAssertFalse(path === copiedPath)
  }
}
