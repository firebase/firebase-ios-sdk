// Copyright 2024 Google LLC
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
@testable import FirebaseVertexAI

import SharedTestUtilities

import XCTest

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
class VertexComponentTests: XCTestCase {
  static var app: FirebaseApp!

  override class func setUp() {
    super.setUp()
    if app == nil {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.projectID = "myProjectID"
      FirebaseApp.configure(options: options)
      app = FirebaseApp(instanceWithName: "test", options: options)
    }
  }

  // MARK: Interoperability Tests

  /// Tests that the right number of components are being provided for the container.
  func testComponentsBeingRegistered() throws {
    let components = VertexAIComponent.componentsToRegister()
    XCTAssert(components.count == 1)
  }

  /// Tests that a vertex instance can be created properly by the VertexAIComponent.
  func testVertexInstanceCreation() throws {
    let app = try XCTUnwrap(VertexComponentTests.app)
    let component = VertexAIComponent(app: app)
    let vertex = component.vertexAI("my-location")
    XCTAssertNotNil(vertex)
  }

  /// Tests that the component container caches instances of VertexAIComponent.
  func testMultipleComponentInstancesCreated() throws {
    let registrants = NSMutableSet(array: [VertexAIComponent.self])
    let container = FirebaseComponentContainer(
      app: VertexComponentTests.app,
      registrants: registrants
    )

    let provider1 = ComponentType<VertexAIProvider>.instance(for: VertexAIProvider.self,
                                                             in: container)
    XCTAssertNotNil(provider1)

    let provider2 = ComponentType<VertexAIProvider>.instance(for: VertexAIProvider.self,
                                                             in: container)
    XCTAssertNotNil(provider2)

    // Ensure they're the same instance.
    XCTAssert(provider1 === provider2)
  }

  /// Tests that instances of vertex created are different.
  func testMultipleVertexInstancesCreated() throws {
    let app = try XCTUnwrap(VertexComponentTests.app)
    let registrants = NSMutableSet(array: [VertexAIComponent.self])
    let container = FirebaseComponentContainer(app: app, registrants: registrants)

    let provider = ComponentType<VertexAIProvider>.instance(for: VertexAIProvider.self,
                                                            in: container)
    XCTAssertNotNil(provider)

    let vertex1 = provider?.vertexAI("randomLocation")
    let vertex2 = provider?.vertexAI("randomLocation")
    XCTAssertNotNil(vertex1)

    // Ensure they're the same instance.
    XCTAssert(vertex1 === vertex2)

    let vertex3 = provider?.vertexAI("differentLocation")
    XCTAssertNotNil(vertex3)

    XCTAssert(vertex1 !== vertex3)
  }

  /// Test that vertex instances get deallocated.
  func testVertexLifecycle() throws {
    weak var weakApp: FirebaseApp?
    weak var weakVertex: VertexAI?
    try autoreleasepool {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.projectID = "myProjectID"
      let app1 = FirebaseApp(instanceWithName: "transitory app", options: options)
      weakApp = try XCTUnwrap(app1)
      let vertex = VertexAI(app: app1, location: "transitory location")
      weakVertex = vertex
      XCTAssertNotNil(weakVertex)
    }
    XCTAssertNil(weakApp)
    XCTAssertNil(weakVertex)
  }
}
