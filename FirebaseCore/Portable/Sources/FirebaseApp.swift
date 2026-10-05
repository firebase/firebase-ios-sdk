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

/// **[Experimental]** The entry point of Firebase SDKs.
///
/// > Warning: This portable implementation is for development and testing use only. The Firebase
/// > Apple SDK is only officially supported on Apple platforms.
public final class FirebaseApp: Sendable, Equatable, Hashable {
  // MARK: - Constants & Registry

  package static let defaultAppName = "__FIRAPP_DEFAULT"

  private static let apps = UnfairLock<[String: FirebaseApp]>([:])

  // MARK: - Properties

  /// **[Experimental]** Gets the name of this app.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public let name: String

  /// **[Experimental]** Gets a copy of the options for this app. These are non-modifiable.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public let options: FirebaseOptions

  /// A flag indicating if this is the default app.
  package var isDefaultApp: Bool {
    name == Self.defaultAppName
  }

  private let dataCollectionEnabled = UnfairLock<Bool>(true)

  /// **[Experimental]** Gets or sets whether automatic data collection is enabled for all
  /// products.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public var isDataCollectionDefaultEnabled: Bool {
    get { dataCollectionEnabled.value() }
    set { dataCollectionEnabled.withLock { $0 = newValue } }
  }

  /// The container of interop SDKs for this app.
  package let container: FirebaseComponentContainer

  // MARK: - Initializers

  /// Initializes a `FirebaseApp` instance with the given name and options without registering it
  /// in the global app dictionary (used by SDK unit tests).
  ///
  /// - Parameters:
  ///   - name: The application's name.
  ///   - options: The Firebase application options.
  package init(instanceWithName name: String, options: FirebaseOptions) {
    self.name = name
    self.options = options.copy(lockEditing: true)
    let container = FirebaseComponentContainer()
    self.container = container
    container.bind(to: self)
  }

  // MARK: - Configuration

  /// **[Experimental]** Configures a default Firebase app using `FirebaseOptions.defaultOptions()`.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public static func configure() {
    guard let options = FirebaseOptions.defaultOptions() else {
      fatalError(
        "`FirebaseApp.configure()` could not find a valid `GoogleService-Info.plist`. " +
          "Set `GOOGLE_SERVICE_INFO_PATH` or call `FirebaseApp.configure(options:)`."
      )
    }
    configure(name: defaultAppName, options: options)
  }

  /// **[Experimental]** Configures the default Firebase app with the provided options.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Parameter options: The Firebase application options used to configure the service.
  public static func configure(options: FirebaseOptions) {
    configure(name: defaultAppName, options: options)
  }

  /// **[Experimental]** Configures a Firebase app with the given name and options.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Parameters:
  ///   - name: The application's name given by the developer.
  ///   - options: The Firebase application options used to configure the services.
  public static func configure(name: String, options: FirebaseOptions) {
    precondition(!name.isEmpty, "FirebaseApp name cannot be empty.")
    if name != defaultAppName {
      precondition(
        isValidAppName(name),
        "App name can only contain alphanumeric, hyphen (-), and underscore (_) characters."
      )
    }
    let app = FirebaseApp(instanceWithName: name, options: options)
    apps.withLock { registry in
      precondition(
        registry[name] == nil,
        "FirebaseApp named '\(name)' has already been configured."
      )
      registry[name] = app
    }
  }

  private static func isValidAppName(_ name: String) -> Bool {
    name.utf8.allSatisfy { byte in
      (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z"))
        || (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z"))
        || (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
        || byte == UInt8(ascii: "-")
        || byte == UInt8(ascii: "_")
    }
  }

  // MARK: - Retrieval

  /// **[Experimental]** Returns the default app, or `nil` if the default app does not exist.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Returns: The default `FirebaseApp`, or `nil` if not configured.
  public static func app() -> FirebaseApp? {
    app(name: defaultAppName)
  }

  /// **[Experimental]** Returns a previously created `FirebaseApp` instance with the given name,
  /// or `nil` if no such app exists.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Parameter name: The name of the app to retrieve.
  /// - Returns: The `FirebaseApp` with `name`, or `nil` if not found.
  public static func app(name: String) -> FirebaseApp? {
    apps.withLock { $0[name] }
  }

  /// **[Experimental]** Returns the set of all extant `FirebaseApp` instances, or `nil` if there
  /// are no `FirebaseApp` instances.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public static var allApps: [String: FirebaseApp]? {
    apps.withLock { $0.isEmpty ? nil : $0 }
  }

  /// Checks if the default app is configured without trying to configure it.
  ///
  /// - Returns: `true` if the default app is currently configured.
  package static func isDefaultAppConfigured() -> Bool {
    apps.withLock { $0[defaultAppName] != nil }
  }

  // MARK: - Deletion & Reset

  /// **[Experimental]** Cleans up the current `FirebaseApp`, freeing associated data and returning
  /// its name to the pool for future use.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Parameter completion: A callback invoked with `true` if the app was removed.
  public func delete(_ completion: @escaping @Sendable (Bool) -> Void) {
    completion(removeFromRegistry())
  }

  /// **[Experimental]** Asynchronously cleans up the current `FirebaseApp`, freeing associated
  /// data and returning its name to the pool for future use.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Returns: `true` if the app was removed, or `false` if it was not registered.
  @discardableResult
  public func delete() async -> Bool {
    removeFromRegistry()
  }

  private func removeFromRegistry() -> Bool {
    guard let removedApp = Self.apps.withLock({ $0.removeValue(forKey: name) }) else {
      return false
    }
    removedApp.container.invalidate()
    container.invalidate()
    return true
  }

  /// Resets all configured `FirebaseApp` instances for testing.
  package static func resetApps() {
    let removedApps = apps.withLock { registry -> [FirebaseApp] in
      let current = Array(registry.values)
      registry.removeAll()
      return current
    }
    for app in removedApps {
      app.container.invalidate()
    }
  }

  // MARK: - Equatable & Hashable

  /// **[Experimental]** Compares two `FirebaseApp` instances by object identity.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Parameters:
  ///   - lhs: The first `FirebaseApp` instance.
  ///   - rhs: The second `FirebaseApp` instance.
  /// - Returns: `true` if `lhs` and `rhs` refer to the same `FirebaseApp` instance.
  public static func == (lhs: FirebaseApp, rhs: FirebaseApp) -> Bool {
    lhs === rhs
  }

  /// **[Experimental]** Hashes the identity of this `FirebaseApp` into the given hasher.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Parameter hasher: The hasher to use when combining the identity of this instance.
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
