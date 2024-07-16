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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import SharedTestUtilities

import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class StorageReferenceTests: XCTestCase {
  override class func setUp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID-Ref"
    FirebaseApp.configure(name: "test-StorageReference", options: options)
  }

  var storage: Storage?
  override func setUp() {
    guard let app = try? getApp(bucket: "bucket") else {
      fatalError("")
    }
    storage = Storage.storage(app: app)
  }

  func testRoot() throws {
    let ref = storage!.reference(forURL: "gs://bucket/path/to/object")
    XCTAssertEqual(ref.root().description, "gs://bucket/")
  }

  func testRootWithURLAPI() throws {
    let url = try XCTUnwrap(URL(string: "gs://bucket/path/to/object"))
    let ref = try storage!.reference(for: url)
    XCTAssertEqual(ref.root().description, "gs://bucket/")
  }

  func testRootWithNoPath() throws {
    let ref = storage!.reference(forURL: "gs://bucket/")
    XCTAssertEqual(ref.root().description, "gs://bucket/")
  }

  func testMismatchedBucket() throws {
    do {
      let url = try XCTUnwrap(URL(string: "gs://bcket/"))
      _ = try storage!.reference(for: url)
    } catch let StorageError.bucketMismatch(string) {
      XCTAssertEqual(string, "Provided bucket: `bcket` does not match the Storage " +
        "bucket of the current instance: `bucket`")
      return
    }
    XCTFail()
  }

  func testMismatchedBucket2() throws {
    let url = try XCTUnwrap(URL(string: "gs://bcket/"))
    XCTAssertThrowsError(try storage!.reference(for: url), "This was supposed to fail.") { error in
      XCTAssertEqual(
        "\(error)",
        "bucketMismatch(message: \"Provided bucket: `bcket` does not match the Storage " +
          "bucket of the current instance: `bucket`\")"
      )
    }
  }

  func testBadBucketScheme() throws {
    do {
      let url = try XCTUnwrap(URL(string: "htttp://bucket/"))
      _ = try storage!.reference(for: url)
    } catch let StorageError.pathError(string) {
      XCTAssertEqual(
        string,
        "Internal error: URL scheme must be one of gs://, http://, or https://"
      )
      return
    }
    XCTFail()
  }

  func testBadBucketScheme2() throws {
    let url = try XCTUnwrap(URL(string: "htttp://bucket/"))
    XCTAssertThrowsError(try storage!.reference(for: url), "This was supposed to fail.") { error in
      XCTAssertEqual("\(error)",
                     "pathError(message: \"Internal error: URL scheme must be one of gs://, " +
                       "http://, or https://\")")
    }
  }

  func testSingleChild() throws {
    let ref = storage!.reference(forURL: "gs://bucket/")
    let childRef = ref.child("path")
    XCTAssertEqual(childRef.description, "gs://bucket/path")
  }

  func testMultipleChildrenSingleString() throws {
    let ref = storage!.reference(forURL: "gs://bucket/")
    let childRef = ref.child("path/to/object")
    XCTAssertEqual(childRef.description, "gs://bucket/path/to/object")
  }

  func testMultipleChildrenMultipleStrings() throws {
    let ref = storage!.reference(forURL: "gs://bucket/")
    let childRef = ref.child("path").child("to").child("object")
    XCTAssertEqual(childRef.description, "gs://bucket/path/to/object")
  }

  func testSameChildDifferentRef() throws {
    let ref = storage!.reference(forURL: "gs://bucket/")
    let firstRef = ref.child("1")
    let secondRef = ref.child("1")
    XCTAssertEqual(ref.description, "gs://bucket/")
    XCTAssertTrue(firstRef == secondRef)
    XCTAssertFalse(firstRef === secondRef)
  }

  func testDifferentChildDifferentRef() throws {
    let ref = storage!.reference(forURL: "gs://bucket/")
    let firstRef = ref.child("1")
    let secondRef = ref.child("2")
    XCTAssertEqual(ref.description, "gs://bucket/")
    XCTAssertFalse(firstRef == secondRef)
    XCTAssertFalse(firstRef === secondRef)
  }

  func testChildWithTrailingSlash() throws {
    let ref = storage!.reference(forURL: "gs://bucket/path/to/object/")
    XCTAssertEqual(ref.description, "gs://bucket/path/to/object")
  }

  func testChildWithLeadingSlash() throws {
    let ref = storage!.reference(forURL: "gs://bucket//path/to/object/")
    XCTAssertEqual(ref.description, "gs://bucket/path/to/object")
  }

  func testChildCompressSlashes() throws {
    let ref = storage!.reference(forURL: "gs://bucket//path/////to////object////")
    XCTAssertEqual(ref.description, "gs://bucket/path/to/object")
  }

  func testParent() throws {
    let ref = storage!.reference(forURL: "gs://bucket//path/to/object/")
    let parentRef = try XCTUnwrap(ref.parent())
    XCTAssertEqual(parentRef.description, "gs://bucket/path/to")
  }

  func testParentToRoot() throws {
    let ref = storage!.reference(forURL: "gs://bucket/path")
    let parentRef = try XCTUnwrap(ref.parent())
    XCTAssertEqual(parentRef.description, "gs://bucket/")
  }

  func testParentToRootTrailingSlash() throws {
    let ref = storage!.reference(forURL: "gs://bucket/path/")
    let parentRef = try XCTUnwrap(ref.parent())
    XCTAssertEqual(parentRef.description, "gs://bucket/")
  }

  func testParentAtRoot() throws {
    let ref = storage!.reference(forURL: "gs://bucket/")
    XCTAssertNil(ref.parent())
  }

  func testBucket() throws {
    let ref = storage!.reference(forURL: "gs://bucket//path/to/object/")
    XCTAssertEqual(ref.bucket, "bucket")
  }

  func testName() throws {
    let ref = storage!.reference(forURL: "gs://bucket/path/to/object/")
    XCTAssertEqual(ref.name, "object")
  }

  func testNameNoObject() throws {
    let ref = storage!.reference(forURL: "gs://bucket/")
    XCTAssertEqual(ref.name, "")
  }

  func testFullPath() throws {
    let ref = storage!.reference(forURL: "gs://bucket/path/to/object/")
    XCTAssertEqual(ref.fullPath, "path/to/object")
  }

  func testFullPathNoObject() throws {
    let ref = storage!.reference(forURL: "gs://bucket/")
    XCTAssertEqual(ref.fullPath, "")
  }

  func testCopy() throws {
    let ref = storage!.reference(forURL: "gs://bucket/")
    let copiedRef = ref.copy() as? StorageReference
    XCTAssertTrue(ref == copiedRef)
    XCTAssertFalse(ref === copiedRef)
  }

  func testReferenceWithNonExistentFileFailsWithCompletionResult() throws {
    let tempFilePath = NSTemporaryDirectory().appending("temp.data")
    let ref = storage!.reference(withPath: tempFilePath)
    let dummyFileURL = try XCTUnwrap(URL(string: "some_non_existing-folder/file.data"))
    let expectation = self.expectation(description: #function)

    ref.putFile(from: dummyFileURL) { result in
      expectation.fulfill()
      switch result {
      case .success:
        XCTFail("Unexpected success.", file: #file, line: #line)
      case let .failure(error):
        switch error {
        case let StorageError.unknown(message, _):
          let expectedDescription = "File at URL: \(dummyFileURL.absoluteString) " +
            "is not reachable. Ensure file URL is not a directory, symbolic link, or invalid url."
          XCTAssertEqual(expectedDescription, message)
        default:
          XCTFail("Failed to match expected Internal Error")
        }
      }
    }
    waitForExpectations(timeout: 0.5)
  }

  func testReferenceWithNonExistentFileFailsWithCompletionCallback() throws {
    let tempFilePath = NSTemporaryDirectory().appending("temp.data")
    let ref = storage!.reference(withPath: tempFilePath)
    let dummyFileURL = try XCTUnwrap(URL(string: "some_non_existing-folder/file.data"))
    let expectation = self.expectation(description: #function)

    ref.putFile(from: dummyFileURL) { metadata, error in
      expectation.fulfill()
      XCTAssertNil(metadata)
      let nsError = (error as? NSError)!
      XCTAssertEqual(nsError.code, StorageErrorCode.unknown.rawValue)
      let expectedDescription = "File at URL: \(dummyFileURL.absoluteString) " +
        "is not reachable. Ensure file URL is not a directory, symbolic link, or invalid url."
      XCTAssertEqual(expectedDescription, nsError.localizedDescription)
      XCTAssertEqual(nsError.domain, StorageErrorDomain)
    }
    waitForExpectations(timeout: 0.5)
  }

  func testReferenceWithNilFileFailsWithCompletionCallback() throws {
    let tempFilePath = NSTemporaryDirectory().appending("temp.data")
    let ref = storage!.reference(withPath: tempFilePath)
    let dummyFileURL = try XCTUnwrap(URL(string: "bad-url"))
    let expectation = self.expectation(description: #function)

    ref.putFile(from: dummyFileURL) { metadata, error in
      expectation.fulfill()
      XCTAssertNil(metadata)
      let nsError = (error as? NSError)!
      XCTAssertEqual(nsError.code, StorageErrorCode.unknown.rawValue)
      let expectedDescription = "File at URL: \(dummyFileURL.absoluteString) " +
        "is not reachable. Ensure file URL is not a directory, symbolic link, or invalid url."
      XCTAssertEqual(expectedDescription, nsError.localizedDescription)
      XCTAssertEqual(nsError.domain, StorageErrorDomain)
    }
    waitForExpectations(timeout: 1.0)
  }

  // MARK: Private Helpers

  // Cache the app associated with each Storage bucket
  private static var appDictionary: [String: FirebaseApp] = [:]

  private func getApp(bucket: String) throws -> FirebaseApp {
    let savedApp = StorageReferenceTests.appDictionary[bucket]
    guard savedApp == nil else {
      return try XCTUnwrap(savedApp)
    }
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID"
    options.storageBucket = bucket
    let name = "StorageTests\(bucket)"
    let app = FirebaseApp(instanceWithName: name, options: options)
    StorageReferenceTests.appDictionary[bucket] = app
    return app
  }
}
