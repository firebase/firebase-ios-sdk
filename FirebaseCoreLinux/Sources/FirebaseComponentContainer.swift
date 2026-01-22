// Copyright 2025 Google LLC
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

internal class FirebaseComponentContainer: ComponentContainer {
    unowned let app: FirebaseApp
    private var instances: [ObjectIdentifier: Any] = [:]
    private var components: [ObjectIdentifier: AnyComponent] = [:]
    private let lock = NSLock()

    init(app: FirebaseApp, registeredComponents: [AnyComponent]) {
        self.app = app
        for component in registeredComponents {
            components[component.serviceTypeID] = component
        }
    }

    func instance<T>(for serviceType: T.Type) -> T? {
        let key = ObjectIdentifier(serviceType)

        lock.lock()
        // Check cache
        if let instance = instances[key] as? T {
            lock.unlock()
            return instance
        }
        lock.unlock()

        // Check registration
        // We assume components map is immutable after init, so technically thread safe to read?
        // But better lock it or copy reference.
        guard let component = components[key] else {
            return nil
        }

        // Instantiate
        // Use lock for instantiation to avoid race conditions creating multiple instances
        lock.lock()
        // Double check
        if let instance = instances[key] as? T {
            lock.unlock()
            return instance
        }

        if let instance = component.instantiate(container: self) as? T {
            instances[key] = instance
            lock.unlock()
            return instance
        }

        lock.unlock()
        return nil
    }

    func instantiateEagerComponents() {
        for component in components.values {
            var shouldInstantiate = false
            switch component.instantiationTiming {
            case .alwaysEager:
                shouldInstantiate = true
            case .eagerInDefaultApp:
                if app.isDefaultApp {
                    shouldInstantiate = true
                }
            case .lazy:
                shouldInstantiate = false
            }

            if shouldInstantiate {
                _ = component.instantiate(container: self)
            }
        }
    }

    func cleanup() {
        lock.lock()
        defer { lock.unlock() }

        for instance in instances.values {
            if let maintainer = instance as? ComponentLifecycleMaintainer {
                maintainer.appWillBeDeleted(app)
            }
        }
        instances.removeAll()
    }
}
