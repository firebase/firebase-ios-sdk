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

import Foundation

/// The entry point of Firebase SDKs.
public final class FirebaseApp: @unchecked Sendable {
    private static let defaultAppName = "__FIRAPP_DEFAULT"
    nonisolated(unsafe) private static var _allApps: [String: FirebaseApp] = [:]
    private static let lock = NSLock()

    // Components registered by other SDKs
    private static var registeredComponents: [AnyComponent] = []

    /// Gets the name of this app.
    public let name: String

    /// Gets a copy of the options for this app.
    public let options: FirebaseOptions

    /// Gets or sets whether automatic data collection is enabled for all products.
    public var isDataCollectionDefaultEnabled: Bool = true

    // Internal container
    internal var _container: FirebaseComponentContainer!

    /// The component container for this app.
    public var container: ComponentContainer {
        return _container
    }

    /// Returns true if this is the default app.
    public var isDefaultApp: Bool {
        return name == FirebaseApp.defaultAppName
    }

    private init(name: String, options: FirebaseOptions) {
        self.name = name
        self.options = options
        self._container = FirebaseComponentContainer(app: self, registeredComponents: FirebaseApp.registeredComponents)
    }

    private func initializeComponents() {
        _container.instantiateEagerComponents()
    }

    /// Configures a default Firebase app.
    public static func configure() {
        guard let options = FirebaseOptions.defaultOptions() else {
            print("[FirebaseCore] Error: Could not find default options.")
            return
        }
        configure(options: options)
    }

    /// Configures a Firebase app with the given name and options.
    /// If name is omitted, the default app name is used.
    public static func configure(name: String = defaultAppName, options: FirebaseOptions) {
        lock.lock()
        defer { lock.unlock() }

        if _allApps[name] != nil {
             print("[FirebaseCore] App \(name) is already configured.")
             return
        }

        let app = FirebaseApp(name: name, options: options)
        _allApps[name] = app
        app.initializeComponents()
    }

    /// Returns the default app, or `nil` if the default app does not exist.
    public static func app() -> FirebaseApp? {
        return app(name: defaultAppName)
    }

    /// Returns a previously created `FirebaseApp` instance with the given name, or `nil` if no such app exists.
    public static func app(name: String) -> FirebaseApp? {
        lock.lock()
        defer { lock.unlock() }
        return _allApps[name]
    }

    /// Returns the set of all extant `FirebaseApp` instances.
    public static var allApps: [String: FirebaseApp] {
        lock.lock()
        defer { lock.unlock() }
        return _allApps
    }

    /// Cleans up the current `FirebaseApp`.
    public func delete(completion: ((Bool) -> Void)?) {
        FirebaseApp.lock.lock()
        FirebaseApp._allApps.removeValue(forKey: name)
        FirebaseApp.lock.unlock()

        _container.cleanup()
        completion?(true)
    }

    /// Registers a component for use by Firebase apps.
    public static func register<T>(_ component: Component<T>) {
        lock.lock()
        defer { lock.unlock() }
        registeredComponents.append(component)
    }
}
