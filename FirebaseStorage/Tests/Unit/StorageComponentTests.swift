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
    let component = StorageComponent(app: StorageComponentTests.app)
    let storage = component.storage(for: "someBucket")
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
    let registrants = NSMutableSet(array: [StorageComponent.self])
    let container = FirebaseComponentContainer(
      app: StorageComponentTests.app,
      registrants: registrants
    )

    let provider = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
                                                           in: container)
    XCTAssertNotNil(provider)

    let storage1 = provider.storage(for: "randomBucket")
    let storage2 = provider.storage(for: "randomBucket")
    XCTAssertNotNil(storage1)

    // Ensure they're the same instance.
    XCTAssert(storage1 === storage2)

    let storage3 = provider.storage(for: "differentBucket")
    XCTAssertNotNil(storage3)

    XCTAssert(storage1 !== storage3)
  }
}
