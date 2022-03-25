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

class StorageComponentTests: XCTestCase {
  static var app: FirebaseApp?

  override class func setUp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID"
    FirebaseApp.configure(name: "test", options: options)
    app = try! XCTUnwrap(FirebaseApp.app(name: "test"))
  }

  // MARK: Interoperability Tests

  /// Tests that the right number of components are being provided for the container.
  func testComponentsBeingRegistered() throws {
    let components = StorageComponent.componentsToRegister()
    XCTAssert(components.count == 1)
  }

  /// Tests that the right number of components are being provided for the container.
  func testStorageInstanceCreation() throws {
    let component = StorageComponent(app: StorageComponentTests.app!)
    let storage = component.storage(for: "someBucket")
    XCTAssertNotNil(storage)
  }

  /// Tests that the component container caches instances of FIRStorageComponent.
  func testMultipleComponentInstancesCreated() throws {
    let app = try XCTUnwrap(StorageComponentTests.app)
    var registrants = [StorageComponent.self]
//    let container = FirebaseComponentContainer(app: app, components: registrants)
//
//    let provider1 = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
//                                                           in: app.container)
//    XCTAssertNotNil(provider1)
//
//    let provider2 = ComponentType<StorageProvider>.instance(for: StorageProvider.self,
//                                                           in: app.container)
//    XCTAssertNotNil(provider2)
//
//    // Ensure they're the same instance.
//    XCTAssertEqual(provider1, provider2)
  }

//
//  /// Tests that instances of FIRStorage created are different.
//  - (void)testMultipleStorageInstancesCreated {
//    // Get a mocked app, but don't use the default helper since is uses this class in the
//    // implementation.
//    id app = [self appMockWithOptions];
//    NSMutableSet *registrants = [NSMutableSet setWithObject:[FIRStorageComponent class]];
//    FIRComponentContainer *container = [[FIRComponentContainer alloc] initWithApp:app
//                                                                      registrants:registrants];
//    id<FIRStorageMultiBucketProvider> provider =
//        FIR_COMPONENT(FIRStorageMultiBucketProvider, container);
//    XCTAssertNotNil(provider);
//
//    FIRStorage *storage1 = [provider storageForBucket:@"randomBucket"];
//    XCTAssertNotNil(storage1);
//    FIRStorage *storage2 = [provider storageForBucket:@"randomBucket"];
//    XCTAssertNotNil(storage2);
//
//    // Ensure that they're the same instance
//    XCTAssertEqual(storage1, storage2);
//    XCTAssertEqualObjects(storage1, storage2);
//
//    // Create another bucket with a different provider from above.
//    FIRStorage *storage3 = [provider storageForBucket:@"differentBucket"];
//    XCTAssertNotNil(storage3);
//
//    // Ensure it's a different object.
//    XCTAssertNotEqualObjects(storage2, storage3);
//  }
}
