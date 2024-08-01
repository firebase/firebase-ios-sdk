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
class StorageComponentTests: StorageTestHelpers {
  /// Test that the objc class is available for the component system to update the user agent.
  func testComponentsBeingRegistered() throws {
    XCTAssertNotNil(NSClassFromString("FIRStorage"))
  }

  /// Tests that a Storage instance can be created properly.
  func testStorageInstanceCreation() throws {
    let app = try XCTUnwrap(app)
    let storage1 = Storage.storage(app: app, url: "gs://foo-bar.appspot.com")
    XCTAssertNotNil(storage1)
  }

  /// Tests that a Storage instances are reused properly.
  func testMultipleComponentInstancesCreated() throws {
    let app = try XCTUnwrap(app)
    let storage1 = Storage.storage(app: app, url: "gs://foo-bar.appspot.com")
    let storage2 = Storage.storage(app: app, url: "gs://foo-bar.appspot.com")

    // Ensure they're the same instance.
    XCTAssert(storage1 === storage2)

    let storage3 = Storage.storage(app: app, url: "gs://foo-baz.appspot.com")
    XCTAssert(storage1 !== storage3)
  }

  /// Test that Storage instances get deallocated.
  func testStorageLifecycle() throws {
    weak var weakApp: FirebaseApp?
    weak var weakStorage: Storage?
    try autoreleasepool {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.projectID = "myProjectID"
      let app1 = FirebaseApp(instanceWithName: "transitory app", options: options)
      weakApp = try XCTUnwrap(app1)
      let storage = Storage(app: app1, bucket: "transitory bucket")
      weakStorage = storage
      XCTAssertNotNil(weakStorage)
    }
    XCTAssertNil(weakApp)
    XCTAssertNil(weakStorage)
  }
}
