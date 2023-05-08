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

class StorageComponentTests: StorageTestHelpers {
  // MARK: Interoperability Tests

  /// Tests that the right number of components are being provided for the container.
  func testComponentsBeingRegistered() throws {
    let components = StorageComponent.componentsToRegister()
    XCTAssert(components.count == 1)
  }

  /// Tests that a Storage instance can be created properly by the StorageComponent.
  func testStorageInstanceCreation() throws {
    let app = try XCTUnwrap(StorageComponentTests.app)
    let component = StorageComponent(app: app)
    let storage = component.storage(for: "someBucket", app: app)
    XCTAssertNotNil(storage)
  }

  /// Tests that the component container caches instances of StorageComponent.
  func testMultipleComponentInstancesCreated() throws {
    let registrants = NSMutableSet(array: [StorageComponent.self])
    let container = FirebaseComponentContainer(
      app: StorageTestHelpers.app,
      registrants: registrants
    )

    let provider1 = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
                                                            in: container)
    XCTAssertNotNil(provider1)

    let provider2 = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
                                                            in: container)
    XCTAssertNotNil(provider2)

    // Ensure they're the same instance.
    XCTAssert(provider1 === provider2)
  }

  /// Tests that instances of Storage created are different.
  func testMultipleStorageInstancesCreated() throws {
    let app = try XCTUnwrap(StorageComponentTests.app)
    let registrants = NSMutableSet(array: [StorageComponent.self])
    let container = FirebaseComponentContainer(app: app, registrants: registrants)

    let provider = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
                                                           in: container)
    XCTAssertNotNil(provider)

    let storage1 = provider.storage(for: "randomBucket", app: app)
    let storage2 = provider.storage(for: "randomBucket", app: app)
    XCTAssertNotNil(storage1)

    // Ensure they're the same instance.
    XCTAssert(storage1 === storage2)

    let storage3 = provider.storage(for: "differentBucket", app: app)
    XCTAssertNotNil(storage3)

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
