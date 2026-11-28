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
import FirebaseCoreTestHooks
import Foundation
import XCTest

/// Tests for FIRComponentContainer, which creates and caches the components that libraries
/// register. They don't use OCMock, so they run unchanged against the Objective-C and Swift
/// implementations of FirebaseCore.
///
/// Ported from FirebaseCore/Tests/Unit/FIRComponentContainerTest.m. Each test builds a container
/// with its own set of registrants, the Swift libraries in TestComponents.swift, so the global
/// registrants don't affect it.
final class ComponentContainerTests: CoreTestCase {
  /// Keeps the container's app alive, since the container only holds it weakly.
  private var hostApp: FirebaseApp?

  override func tearDown() {
    hostApp = nil
    super.tearDown()
  }

  // MARK: - Registration

  func testRegisteringConformingClass() {
    let registrants = NSMutableSet()
    FirebaseComponentContainer.registerAsComponentRegistrant(CoreTestUncachedLibrary.self,
                                                             in: registrants)
    XCTAssertTrue(registrants.contains(CoreTestUncachedLibrary.self))
  }

  func testComponentsPopulatedOnInit() {
    let container = makeContainer(registrants: [CoreTestUncachedLibrary.self])
    XCTAssertNotNil(container.components[NSStringFromProtocol(CoreTestUncachedComponent.self)])
    XCTAssertEqual(container.components.count, 1)
    XCTAssertTrue(container.app === hostApp)
  }

  func testProtocolAlreadyRegistered() {
    // Two libraries provide the same protocol. Only one is stored, and an error is logged.
    let container = makeContainer(registrants: [CoreTestUncachedLibrary.self,
                                                CoreTestDuplicateLibrary.self])
    XCTAssertEqual(container.components.count, 1)
  }

  // MARK: - Caching

  func testInstanceCached() throws {
    let container = makeContainer(registrants: [CoreTestCachedLibrary.self])
    let instance1 = try XCTUnwrap(cachedComponent(in: container))
    let instance2 = try XCTUnwrap(cachedComponent(in: container))
    XCTAssertTrue(instance1 === instance2)
    XCTAssertEqual(container.cachedInstances.count, 1)
  }

  func testInstanceNotCached() throws {
    let container = makeContainer(registrants: [CoreTestUncachedLibrary.self])
    let instance1 = try XCTUnwrap(uncachedComponent(in: container))
    let instance2 = try XCTUnwrap(uncachedComponent(in: container))
    XCTAssertFalse(instance1 === instance2)
    XCTAssertEqual(container.cachedInstances.count, 0)
  }

  func testRemoveAllCachedInstances() throws {
    let container = makeContainer(registrants: [
      CoreTestUncachedLibrary.self, CoreTestCachedLibrary.self, CoreTestEagerLibrary.self,
      CoreTestDependentLibrary.self,
    ])
    let cachedInstance1 = try XCTUnwrap(cachedComponent(in: container) as? CoreTestCachedInstance)
    let eagerInstance1 = try XCTUnwrap(eagerComponent(in: container))
    XCTAssertEqual(container.cachedInstances.count, 2)

    container.removeAllCachedInstances()

    XCTAssertEqual(container.cachedInstances.count, 0)
    // New: the container tells cached instances that their app will be deleted.
    XCTAssertEqual(cachedInstance1.appWillBeDeletedCalls.count, 1)
    // New instances are created afterwards.
    XCTAssertFalse(try XCTUnwrap(cachedComponent(in: container)) === cachedInstance1)
    XCTAssertFalse(try XCTUnwrap(eagerComponent(in: container)) === eagerInstance1)
  }

  func testRemoveAllComponents() throws {
    let container = makeContainer(registrants: [
      CoreTestUncachedLibrary.self, CoreTestCachedLibrary.self, CoreTestEagerLibrary.self,
      CoreTestDependentLibrary.self,
    ])
    XCTAssertNotNil(cachedComponent(in: container))
    XCTAssertNotNil(eagerComponent(in: container))
    XCTAssertEqual(container.cachedInstances.count, 2)

    container.removeAllComponents()
    container.removeAllCachedInstances()

    // No new instances are created.
    XCTAssertNil(cachedComponent(in: container))
    XCTAssertNil(eagerComponent(in: container))
    XCTAssertNil(uncachedComponent(in: container))
    XCTAssertEqual(container.components.count, 0)
  }

  // MARK: - Eager instantiation

  func testEagerInstantiation() {
    let creations = CoreTestEagerLibrary.creations.count
    let container = makeContainer(registrants: [CoreTestEagerLibrary.self])
    XCTAssertNotNil(container.cachedInstances[NSStringFromProtocol(CoreTestEagerComponent.self)])
    XCTAssertEqual(CoreTestEagerLibrary.creations.count, creations + 1)
  }

  func testEagerInDefaultAppInstantiation() {
    // New: components that are eager only in the default app are lazy in other apps.
    let key = NSStringFromProtocol(CoreTestEagerInDefaultAppComponent.self)
    let creations = CoreTestEagerInDefaultAppLibrary.creations.count

    let otherContainer = makeContainer(registrants: [CoreTestEagerInDefaultAppLibrary.self])
    XCTAssertNil(otherContainer.cachedInstances[key])
    XCTAssertEqual(CoreTestEagerInDefaultAppLibrary.creations.count, creations)

    let defaultContainer = makeContainer(registrants: [CoreTestEagerInDefaultAppLibrary.self],
                                         appName: CoreContract.defaultAppName)
    XCTAssertNotNil(defaultContainer.cachedInstances[key])
    XCTAssertEqual(CoreTestEagerInDefaultAppLibrary.creations.count, creations + 1)
  }

  // MARK: - Dependencies

  func testDependencyDoesNotBlock() throws {
    // A component that gets another component from the container while it's created.
    let container = makeContainer(registrants: [CoreTestCachedLibrary.self,
                                                CoreTestDependentLibrary.self])
    XCTAssertEqual(container.components.count, 2)

    let instance = try XCTUnwrap(dependentComponent(in: container))
    XCTAssertNotNil(instance.dependency)
    XCTAssertTrue(instance.dependency === cachedComponent(in: container))
  }

  func testRemovingCachedInstancesWithDependencyDoesNotBlock() throws {
    let container = makeContainer(registrants: [CoreTestCachedLibrary.self,
                                                CoreTestDependentLibrary.self])
    let instance = try XCTUnwrap(dependentComponent(in: container))
    XCTAssertNotNil(instance.dependency)
    // Both the instance and its dependency are cached.
    XCTAssertEqual(container.cachedInstances.count, 2)

    container.removeAllCachedInstances()
    XCTAssertEqual(container.cachedInstances.count, 0)
  }

  // MARK: - Helpers

  /// Creates a container with the given registrants for a new app, as FIRApp does, including eager
  /// instantiation.
  private func makeContainer(registrants: [Library.Type],
                             appName: String = "fake_app") -> FirebaseComponentContainer {
    let app = FirebaseApp(instanceWithName: appName, options: makeAppOptions())
    hostApp = app
    let allRegistrants = NSMutableSet()
    for registrant in registrants {
      FirebaseComponentContainer.registerAsComponentRegistrant(registrant, in: allRegistrants)
    }
    let container = FirebaseComponentContainer(app: app, registrants: allRegistrants)
    app.container = container
    container.instantiateEagerComponents()
    return container
  }

  private func cachedComponent(in container: FirebaseComponentContainer)
    -> CoreTestCachedComponent? {
    ComponentType<CoreTestCachedComponent>.instance(for: CoreTestCachedComponent.self,
                                                    in: container)
  }

  private func uncachedComponent(in container: FirebaseComponentContainer)
    -> CoreTestUncachedComponent? {
    ComponentType<CoreTestUncachedComponent>.instance(for: CoreTestUncachedComponent.self,
                                                      in: container)
  }

  private func eagerComponent(in container: FirebaseComponentContainer)
    -> CoreTestEagerComponent? {
    ComponentType<CoreTestEagerComponent>.instance(for: CoreTestEagerComponent.self,
                                                   in: container)
  }

  private func dependentComponent(in container: FirebaseComponentContainer)
    -> CoreTestDependentComponent? {
    ComponentType<CoreTestDependentComponent>.instance(for: CoreTestDependentComponent.self,
                                                       in: container)
  }
}
