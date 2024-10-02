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
class StorageTests: XCTestCase {
  override class func setUp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID"
    FirebaseApp.configure(name: "test-StorageTests", options: options)
  }

  func testBucketNotEnforced() throws {
    let app = try getApp(bucket: "")
    let storage = Storage.storage(app: app)
    _ = storage.reference(forURL: "gs://benwu-test1.storage.firebase.com/child")
    _ = storage.reference(forURL: "gs://benwu-test2.storage.firebase.com/child")
  }

  func testBucketEnforced() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app, url: "gs://benwu-test1.storage.firebase.com")
    let url = try XCTUnwrap(URL(string: "gs://benwu-test2.storage.firebase.com/child"))
    XCTAssertThrowsError(try storage.reference(for: url), "This was supposed to fail.") { error in
      XCTAssertEqual(
        "\(error)",
        "bucketMismatch(message: \"Provided bucket: `benwu-test2.storage.firebase.com` does not match the " +
          "Storage bucket of the current instance: `benwu-test1.storage.firebase.com`\")"
      )
    }
  }

  func testInitWithCustomURL() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app, url: "gs://foo-bar.appspot.com")
    XCTAssertEqual("gs://foo-bar.appspot.com/", storage.reference().description)
    let storage2 = Storage.storage(app: app, url: "gs://foo-bar.appspot.com/")
    XCTAssertEqual("gs://foo-bar.appspot.com/", storage2.reference().description)
  }

  func SKIPtestInitWithWrongScheme() throws {
    let app = try getApp(bucket: "bucket")
    XCTAssertThrowsObjCException {
      _ = Storage.storage(app: app, url: "http://foo-bar.appspot.com")
    }
  }

  func SKIPtestInitWithNoScheme() throws {
    let app = try getApp(bucket: "bucket")
    XCTAssertThrowsObjCException {
      _ = Storage.storage(app: app, url: "foo-bar.appspot.com")
    }
  }

  func testInitWithoutURL() throws {
    let app = try getApp(bucket: "bucket")
    XCTAssertNoThrowObjCException {
      _ = Storage.storage(app: app)
    }
  }

  func SKIPtestInitWithPath() throws {
    let app = try getApp(bucket: "bucket")
    XCTAssertThrowsObjCException {
      _ = Storage.storage(app: app, url: "gs://foo-bar.appspot.com/child")
    }
  }

  func testInitWithDefaultAndCustomURL() throws {
    let app = try getApp(bucket: "bucket")
    let defaultInstance = Storage.storage(app: app)
    let customInstance = Storage.storage(app: app, url: "gs://foo-bar.appspot.com")
    XCTAssertEqual("gs://foo-bar.appspot.com/", customInstance.reference().description)
    XCTAssertEqual("gs://bucket/", defaultInstance.reference().description)
  }

  func testStorageDefaultApp() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app)
    XCTAssertEqual(storage.app.name, app.name)
  }

  func SKIPtestStorageNoBucketInConfig() throws {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID"
    let name = "StorageTestsNil"
    let app = FirebaseApp(instanceWithName: name, options: options)
    XCTAssertThrowsObjCException {
      _ = Storage.storage(app: app)
    }
  }

  func testStorageEmptyBucketInConfig() throws {
    let app = try getApp(bucket: "")
    let storage = Storage.storage(app: app)
    let ref = storage.reference(forURL: "gs://bucket/path/to/object")
    XCTAssertEqual(ref.bucket, "bucket")
  }

  func testStorageWrongBucketInConfig() throws {
    let app = try getApp(bucket: "notMyBucket")
    let storage = Storage.storage(app: app)
    let url = try XCTUnwrap(URL(string: "gs://bucket/path/to/object"))
    XCTAssertThrowsError(try storage.reference(for: url), "This was supposed to fail.") { error in
      XCTAssertEqual(
        "\(error)",
        "bucketMismatch(message: \"Provided bucket: `bucket` does not match the " +
          "Storage bucket of the current instance: `notMyBucket`\")"
      )
    }
  }

  func testUseEmulator() throws {
    let app = try getApp(bucket: "bucket-for-testUseEmulator")
    let storage = Storage.storage(app: app)
    storage.useEmulator(withHost: "localhost", port: 8080)
    XCTAssertNoThrow(storage.reference())
  }

  func SKIPtestUseEmulatorValidatesHost() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app, url: "gs://foo-bar.appspot.com")
    XCTAssertThrowsObjCException {
      storage.useEmulator(withHost: "", port: 8080)
    }
  }

  func SKIPtestUseEmulatorValidatesPort() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app, url: "gs://foo-bar.appspot.com")
    XCTAssertThrowsObjCException {
      storage.useEmulator(withHost: "localhost", port: -1)
    }
  }

  func SKIPtestUseEmulatorCannotBeCalledAfterObtainingReference() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app, url: "gs://benwu-test1.storage.firebase.com")
    _ = storage.reference()
    XCTAssertThrowsObjCException {
      storage.useEmulator(withHost: "localhost", port: 8080)
    }
  }

  func testRefDefaultApp() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage(app: app, bucket: "bucket")
    let convenienceRef = storage.reference(forURL: "gs://bucket/path/to/object")
    let path = StoragePath(with: "bucket", object: "path/to/object")
    let builtRef = StorageReference(storage: storage, path: path)
    XCTAssertEqual(convenienceRef.description, builtRef.description)
    XCTAssertEqual(convenienceRef.storage.app, builtRef.storage.app)
  }

  func testRefCustomApp() throws {
    let secondApp = try getApp(bucket: "bucket2")
    let storage2 = Storage.storage(app: secondApp)
    let convenienceRef = storage2.reference(forURL: "gs://bucket2/path/to/object")
    let path = StoragePath(with: "bucket2", object: "path/to/object")
    let builtRef = StorageReference(storage: storage2, path: path)
    XCTAssertEqual(convenienceRef.description, builtRef.description)
    XCTAssertEqual(convenienceRef.storage.app, builtRef.storage.app)
  }

  func testRootRefDefaultApp() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app)
    let convenienceRef = storage.reference()
    let path = StoragePath(with: "bucket")
    let builtRef = StorageReference(storage: storage, path: path)
    XCTAssertEqual(convenienceRef.description, builtRef.description)
    XCTAssertEqual(convenienceRef.storage.app, builtRef.storage.app)
  }

  func testRefWithPathDefaultApp() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app)
    let convenienceRef = storage.reference(forURL: "gs://bucket/path/to/object")
    let path = StoragePath(with: "bucket", object: "path/to/object")
    let builtRef = StorageReference(storage: storage, path: path)
    XCTAssertEqual(convenienceRef.description, builtRef.description)
    XCTAssertEqual(convenienceRef.storage.app, builtRef.storage.app)
  }

  func testEqual() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app)
    let copy = try XCTUnwrap(storage.copy() as? Storage)
    XCTAssertEqual(storage.app.name, copy.app.name)
    XCTAssertEqual(storage.hash, copy.hash)
  }

  func testNotEqual() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app)
    let secondApp = try getApp(bucket: "bucket2")
    let storage2 = Storage.storage(app: secondApp)
    XCTAssertNotEqual(storage, storage2)
    XCTAssertNotEqual(storage.hash, storage2.hash)
  }

  func testHash() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app)
    let copy = try XCTUnwrap(storage.copy() as? Storage)
    XCTAssertEqual(storage.app.name, copy.app.name)
  }

  func testTranslateRetryTime() {
    // The 1st retry attempt runs after 1 second.
    // The 2nd retry attempt is delayed by 2 seconds (3s total)
    // The 3rd retry attempt is delayed by 4 seconds (7s total)
    // The 4th retry attempt is delayed by 8 seconds (15s total)
    // The 5th retry attempt is delayed by 16 seconds (31s total)
    // The 6th retry attempt is delayed by 32 seconds (63s total)
    // Thus, we should exit just between the 5th and 6th retry attempt and cut off before 32s.
    XCTAssertEqual(1.0, Storage.computeRetryInterval(fromRetryTime: 1.0))
    XCTAssertEqual(2.0, Storage.computeRetryInterval(fromRetryTime: 2.0))
    XCTAssertEqual(4.0, Storage.computeRetryInterval(fromRetryTime: 4.0))
    XCTAssertEqual(8.0, Storage.computeRetryInterval(fromRetryTime: 10.0))
    XCTAssertEqual(16.0, Storage.computeRetryInterval(fromRetryTime: 20.0))
    XCTAssertEqual(16.0, Storage.computeRetryInterval(fromRetryTime: 30.0))
    XCTAssertEqual(32.0, Storage.computeRetryInterval(fromRetryTime: 40.0))
    XCTAssertEqual(32.0, Storage.computeRetryInterval(fromRetryTime: 50.0))
    XCTAssertEqual(32.0, Storage.computeRetryInterval(fromRetryTime: 60.0))
  }

  func testRetryTimeChange() throws {
    let app = try getApp(bucket: "")
    let storage = Storage.storage(app: app)
    XCTAssertEqual(storage.maxOperationRetryInterval, 64)
    storage.maxOperationRetryTime = 11
    XCTAssertEqual(storage.maxOperationRetryTime, 11)
    XCTAssertEqual(storage.maxOperationRetryInterval, 8)
  }

  // MARK: Private Helpers

  // Cache the app associated with each Storage bucket
  private static var appDictionary: [String: FirebaseApp] = [:]

  private func getApp(bucket: String) throws -> FirebaseApp {
    let savedApp = StorageTests.appDictionary[bucket]
    guard savedApp == nil else {
      return try XCTUnwrap(savedApp)
    }
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID"
    options.storageBucket = bucket
    let name = "StorageTests\(bucket)"
    let app = FirebaseApp(instanceWithName: name, options: options)
    StorageTests.appDictionary[bucket] = app
    return app
  }

  private func XCTAssertThrowsObjCException(_ closure: @escaping () -> Void) {
    XCTAssertThrowsError(try ExceptionCatcher.catchException(closure))
  }

  private func XCTAssertNoThrowObjCException(_ closure: @escaping () -> Void) {
    XCTAssertNoThrow(try ExceptionCatcher.catchException(closure))
  }
}
