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

// Libraries that register components with FirebaseCore, the way Swift products do. They replace
// the classes in FirebaseCore/Tests/Unit/FIRTestComponents.

/// A lazily created component that asks to be cached.
@objc protocol CoreTestCachedComponent {}

/// A component that's created eagerly, when an app is configured, and cached.
@objc protocol CoreTestEagerComponent {}

/// A lazily created component that isn't cached, so each request creates a new instance.
@objc protocol CoreTestUncachedComponent {}

/// A component that no library registers.
@objc protocol CoreTestUnregisteredComponent {}

/// A cached component that gets a `CoreTestCachedComponent` from its container when it's created.
@objc protocol CoreTestDependentComponent {
  var dependency: CoreTestCachedComponent? { get }
}

/// A cached component that's created eagerly only for the default app.
@objc protocol CoreTestEagerInDefaultAppComponent {}

/// A thread-safe counter, for example of the instances that a creation block creates.
final class CreationCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var _count = 0

  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return _count
  }

  func increment() {
    lock.lock()
    defer { lock.unlock() }
    _count += 1
  }
}

final class CoreTestCachedInstance: NSObject, CoreTestCachedComponent,
  ComponentLifecycleMaintainer {
  /// The number of times the container told this instance that its app will be deleted.
  let appWillBeDeletedCalls = CreationCounter()

  func appWillBeDeleted(_ app: FirebaseApp) {
    appWillBeDeletedCalls.increment()
  }
}

final class CoreTestEagerInstance: NSObject, CoreTestEagerComponent {}

final class CoreTestUncachedInstance: NSObject, CoreTestUncachedComponent {}

final class CoreTestDependentInstance: NSObject, CoreTestDependentComponent {
  let dependency: CoreTestCachedComponent?

  init(dependency: CoreTestCachedComponent?) {
    self.dependency = dependency
  }
}

final class CoreTestEagerInDefaultAppInstance: NSObject, CoreTestEagerInDefaultAppComponent {}

final class CoreTestCachedLibrary: NSObject, Library {
  static func componentsToRegister() -> [Component] {
    [Component(CoreTestCachedComponent.self) { _, isCacheable in
      isCacheable.pointee = true
      return CoreTestCachedInstance()
    }]
  }
}

final class CoreTestEagerLibrary: NSObject, Library {
  /// The number of instances created, across all apps.
  static let creations = CreationCounter()

  static func componentsToRegister() -> [Component] {
    [Component(CoreTestEagerComponent.self, instantiationTiming: .alwaysEager) { _, isCacheable in
      isCacheable.pointee = true
      creations.increment()
      return CoreTestEagerInstance()
    }]
  }
}

final class CoreTestUncachedLibrary: NSObject, Library {
  /// The number of instances created, across all apps.
  static let creations = CreationCounter()

  static func componentsToRegister() -> [Component] {
    [Component(CoreTestUncachedComponent.self) { _, _ in
      creations.increment()
      return CoreTestUncachedInstance()
    }]
  }
}

/// Provides `CoreTestUncachedComponent` too, so it duplicates `CoreTestUncachedLibrary`.
final class CoreTestDuplicateLibrary: NSObject, Library {
  static func componentsToRegister() -> [Component] {
    [Component(CoreTestUncachedComponent.self) { _, _ in
      CoreTestUncachedInstance()
    }]
  }
}

final class CoreTestDependentLibrary: NSObject, Library {
  static func componentsToRegister() -> [Component] {
    [Component(CoreTestDependentComponent.self) { container, isCacheable in
      isCacheable.pointee = true
      let dependency = ComponentType<CoreTestCachedComponent>.instance(
        for: CoreTestCachedComponent.self,
        in: container
      )
      return CoreTestDependentInstance(dependency: dependency)
    }]
  }
}

final class CoreTestEagerInDefaultAppLibrary: NSObject, Library {
  /// The number of instances created, across all containers.
  static let creations = CreationCounter()

  static func componentsToRegister() -> [Component] {
    [Component(CoreTestEagerInDefaultAppComponent.self,
               instantiationTiming: .eagerInDefaultApp) { _, isCacheable in
        isCacheable.pointee = true
        creations.increment()
        return CoreTestEagerInDefaultAppInstance()
      }]
  }
}

/// Registers the test libraries. Registration is global and can't be undone, so apps configured
/// afterwards, in any test, also get these components.
func registerTestLibraries() {
  FirebaseApp.registerInternalLibrary(CoreTestCachedLibrary.self,
                                      withName: "core-swift-unit-cached",
                                      withVersion: "1.0")
  FirebaseApp.registerInternalLibrary(CoreTestEagerLibrary.self,
                                      withName: "core-swift-unit-eager",
                                      withVersion: "1.0")
  FirebaseApp.registerInternalLibrary(CoreTestUncachedLibrary.self,
                                      withName: "core-swift-unit-uncached",
                                      withVersion: "1.0")
}

extension FirebaseApp {
  var cachedTestComponent: CoreTestCachedComponent? {
    ComponentType<CoreTestCachedComponent>.instance(for: CoreTestCachedComponent.self,
                                                    in: container)
  }

  var eagerTestComponent: CoreTestEagerComponent? {
    ComponentType<CoreTestEagerComponent>.instance(for: CoreTestEagerComponent.self,
                                                   in: container)
  }

  var uncachedTestComponent: CoreTestUncachedComponent? {
    ComponentType<CoreTestUncachedComponent>.instance(for: CoreTestUncachedComponent.self,
                                                      in: container)
  }

  var unregisteredTestComponent: CoreTestUnregisteredComponent? {
    ComponentType<CoreTestUnregisteredComponent>.instance(for: CoreTestUnregisteredComponent.self,
                                                          in: container)
  }
}
