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

private import FirebaseCoreInternal
import Foundation

/// A container that holds interop component instances for a `FirebaseApp`.
package final class FirebaseComponentContainer: Sendable {
  // MARK: - Types

  /// A closure that creates a component instance for a `FirebaseApp`.
  package typealias ComponentFactory = @Sendable (FirebaseApp) -> (any Sendable)?

  private struct Storage: Sendable {
    weak var app: FirebaseApp?
    var cachedInstances: [ObjectIdentifier: any Sendable] = [:]
  }

  // MARK: - Properties

  private static let factories = UnfairLock<[ObjectIdentifier: ComponentFactory]>([:])

  private let storage: UnfairLock<Storage>

  /// The `FirebaseApp` that this container belongs to.
  package var app: FirebaseApp? {
    storage.withLock { $0.app }
  }

  // MARK: - Initializers

  package init() {
    storage = UnfairLock(Storage())
  }

  package func bind(to app: FirebaseApp) {
    storage.withLock { $0.app = app }
  }

  // MARK: - Registration & Lookup

  /// Registers a component factory for an interop protocol type across all `FirebaseApp`
  /// instances.
  ///
  /// - Parameters:
  ///   - type: The interop protocol or component type to register.
  ///   - factory: A closure that produces an instance for a given `FirebaseApp`. Factories must be
  ///     idempotent and hold only weak references to the `FirebaseApp`.
  package static func register<T>(for type: T.Type,
                                  factory: @escaping ComponentFactory) {
    factories.withLock { $0[ObjectIdentifier(type)] = factory }
  }

  /// Removes all registered component factories.
  package static func removeAllRegistrations() {
    factories.withLock { $0.removeAll() }
  }

  /// Registers a specific component instance for an interop protocol type on this container.
  ///
  /// - Parameters:
  ///   - instance: The component instance to cache in this container.
  ///   - type: The interop protocol or component type to associate with `instance`.
  package func register<T>(instance: any Sendable, for type: T.Type) {
    storage.withLock { $0.cachedInstances[ObjectIdentifier(type)] = instance }
  }

  /// Retrieves an instance that conforms to the specified interop protocol or component type.
  ///
  /// - Parameter type: The interop protocol or component type to retrieve.
  /// - Returns: The component instance, or `nil` if none is registered.
  package func instance<T>(for type: T.Type) -> T? {
    let key = ObjectIdentifier(type)
    let (hasCached, cached, app): (Bool, (any Sendable)?, FirebaseApp?) = storage
      .withLock { state in
        let entry = state.cachedInstances[key]
        return (entry != nil, entry, state.app)
      }
    if hasCached {
      return cached as? T
    }

    guard let app,
          let factory = Self.factories.withLock({ $0[key] }),
          let created = factory(app) else {
      return nil
    }

    let resolved: (any Sendable)? = storage.withLock { state in
      guard state.app != nil else {
        return nil
      }
      if let existing = state.cachedInstances[key] {
        return existing
      }
      state.cachedInstances[key] = created
      return created
    }
    return resolved as? T
  }

  /// Removes all cached component instances from this container.
  package func removeAllCachedInstances() {
    storage.withLock { $0.cachedInstances.removeAll() }
  }

  /// Unbinds the app and removes all cached component instances so no new components can be
  /// instantiated after deletion.
  package func invalidate() {
    storage.withLock { state in
      state.app = nil
      state.cachedInstances.removeAll()
    }
  }
}
