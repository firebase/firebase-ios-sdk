// Copyright 2026 Google LLC
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

import FirebaseCore
internal import FirebaseCoreExtension
import Foundation
import XCTest

/// Tests for `ComponentType`, which gets component instances from a component container. They
/// don't use OCMock, so they run unchanged against the Objective-C and Swift implementations of
/// FirebaseCore.
///
/// Ported from FirebaseCore/Tests/Unit/FIRComponentTypeTest.m. Instead of a mock container, the
/// tests use the real container of a configured app, with the components in TestComponents.swift.
///
/// Intentionally dropped: testMacroForwardsCallToContainer. `FIR_COMPONENT` is an Objective-C
/// macro that expands to the same `+[FIRComponentType instanceForProtocol:inContainer:]` call, and
/// Swift can't use macros.
final class ComponentTypeTests: CoreTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    registerTestLibraries()
  }

  func testForwardsCallToContainer() throws {
    let app = try configureApp(named: "testComponentType")
    let creations = CoreTestUncachedLibrary.creations.count

    // The component isn't cached, so each call reaches the container's creation block.
    let first = try XCTUnwrap(app.uncachedTestComponent)
    let second = try XCTUnwrap(app.uncachedTestComponent)

    XCTAssertFalse(first === second)
    XCTAssertTrue(first is CoreTestUncachedInstance)
    XCTAssertEqual(CoreTestUncachedLibrary.creations.count, creations + 2)
  }

  func testReturnsContainerInstance() throws {
    let app = try configureApp(named: "testComponentType")
    let fromContainer = app.container.instance(for: CoreTestCachedComponent.self) as AnyObject?

    let fromComponentType = try XCTUnwrap(app.cachedTestComponent)

    XCTAssertTrue(fromComponentType === fromContainer)
  }

  func testReturnsNilForUnregisteredProtocol() throws {
    let app = try configureApp(named: "testComponentType")
    XCTAssertNil(app.unregisteredTestComponent)
    XCTAssertNil(app.container.instance(for: CoreTestUnregisteredComponent.self))
  }

  func testUsesTheGivenContainer() throws {
    let app1 = try configureApp(named: "testComponentType1")
    let app2 = try configureApp(named: "testComponentType2")

    let instance1 = try XCTUnwrap(app1.cachedTestComponent)
    let instance2 = try XCTUnwrap(app2.cachedTestComponent)

    XCTAssertFalse(instance1 === instance2)
    XCTAssertTrue(instance1 === app1.container.instance(for: CoreTestCachedComponent.self)
      as AnyObject?)
    XCTAssertTrue(instance2 === app2.container.instance(for: CoreTestCachedComponent.self)
      as AnyObject?)
  }
}
