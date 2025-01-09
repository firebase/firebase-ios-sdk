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

import FirebaseABTesting

// import FirebaseAnalyticsInterop
import FirebaseCore
import FirebaseCoreExtension
import FirebaseInstallations
import FirebaseRemoteConfigInterop
import Foundation
@_implementationOnly import GoogleUtilities

public let FIRNamespaceGoogleMobilePlatform = "firebase"

public let FIRRemoteConfigThrottledEndTimeInSecondsKey = "error_throttled_end_time_seconds"

public let FIRRemoteConfigActivateNotification =
  Notification.Name("FIRRemoteConfigActivateNotification")

/// Listener for the get methods.
public typealias RemoteConfigListener = (String, [String: RemoteConfigValue]) -> Void

@objc(FIRRemoteConfigSettings)
public class RemoteConfigSettings: NSObject, NSCopying {
  @objc public var minimumFetchInterval: TimeInterval =
    .init(ConfigConstants.defaultMinimumFetchInterval)

  @objc public var fetchTimeout: TimeInterval =
    .init(ConfigConstants.httpDefaultConnectionTimeout)

  // Default init removed to allow for simpler initialization.

  @objc public func copy(with zone: NSZone? = nil) -> Any {
    let copy = RemoteConfigSettings()
    copy.minimumFetchInterval = minimumFetchInterval
    copy.fetchTimeout = fetchTimeout
    return copy
  }
}

/// Indicates whether updated data was successfully fetched.
@objc(FIRRemoteConfigFetchStatus)
public enum RemoteConfigFetchStatus: Int {
  /// Config has never been fetched.
  case noFetchYet
  /// Config fetch succeeded.
  case success
  /// Config fetch failed.
  case failure
  /// Config fetch was throttled.
  case throttled
}

/// Indicates whether updated data was successfully fetched and activated.
@objc(FIRRemoteConfigFetchAndActivateStatus)
public enum RemoteConfigFetchAndActivateStatus: Int {
  /// The remote fetch succeeded and fetched data was activated.
  case successFetchedFromRemote
  /// The fetch and activate succeeded from already fetched but yet unexpired config data. You can
  /// control this using minimumFetchInterval property in FIRRemoteConfigSettings.
  case successUsingPreFetchedData
  /// The fetch and activate failed.
  case error
}

@objc(FIRRemoteConfigError)
public enum RemoteConfigError: Int, LocalizedError {
  /// Unknown or no error.
  case unknown = 8001
  /// Frequency of fetch requests exceeds throttled limit.
  case throttled = 8002
  /// Internal error that covers all internal HTTP errors.
  case internalError = 8003

  public var errorDescription: String? {
    switch self {
    case .unknown:
      return "Unknown error."
    case .throttled:
      return "Frequency of fetch requests exceeds throttled limit."
    case .internalError:
      return "Internal error."
    }
  }
}

@objc(FIRRemoteConfigUpdateError)
public enum RemoteConfigUpdateError: Int, LocalizedError {
  /// Unable to make a connection to the Remote Config backend.
  case streamError = 8001
  /// Unable to fetch the latest version of the config.
  case notFetched = 8002
  /// The ConfigUpdate message was unparsable.
  case messageInvalid = 8003
  /// The Remote Config real-time config update service is unavailable.
  case unavailable = 8004

  public var errorDescription: String? {
    switch self {
    case .streamError:
      return "Unable to make a connection to the Remote Config backend."
    case .notFetched:
      return "Unable to fetch the latest version of the config."
    case .messageInvalid:
      return "The ConfigUpdate message was unparsable."
    case .unavailable:
      return "The Remote Config real-time config update service is unavailable."
    }
  }
}

/// Enumerated value that indicates the source of Remote Config data. Data can come from
/// the Remote Config service, the DefaultConfig that is available when the app is first
/// installed, or a static initialized value if data is not available from the service or
/// DefaultConfig.
@objc(FIRRemoteConfigSource)
public enum RemoteConfigSource: Int {
  case remote /// < The data source is the Remote Config service.
  case `default` /// < The data source is the DefaultConfig defined for this app.
  case `static` /// < The data doesn't exist, return a static initialized value.
}

// MARK: - RemoteConfig

private var RCInstances = [String: [String: RemoteConfig]]()

/// Firebase Remote Config class. The class method `remoteConfig()` can be used
/// to fetch, activate and read config results and set default config results on the default
/// Remote Config instance.
@objc(FIRRemoteConfig)
open class RemoteConfig: NSObject, NSFastEnumeration {
  /// All the config content.
  private let configContent: ConfigContent

  private let dbManager: ConfigDBManager

  @objc public var settings: ConfigSettings

  let configFetch: ConfigFetch

  private let configExperiment: ConfigExperiment

  private let configRealtime: ConfigRealtime

  private let queue: DispatchQueue

  // TODO: remove objc public/
  @objc public let appName: String

  private var listeners = [RemoteConfigListener]()

  public var FIRNamespace: String

  /// Shared Remote Config instances, keyed by FIRApp name and namespace.
  private static var RCInstances = [String: [String: RemoteConfig]]()

  // MARK: - Public Initializers and Accessors

  @objc public static func remoteConfig(with app: FirebaseApp) -> RemoteConfig {
    return remoteConfig(withFIRNamespace: RemoteConfigConstants.NamespaceGoogleMobilePlatform,
                        app: app)
  }

  @objc public static func remoteConfig() -> RemoteConfig {
    guard let app = FirebaseApp.app() else {
      fatalError("The default FirebaseApp instance must be configured before the " +
        "default Remote Config instance can be initialized. One way to ensure " +
        "this is to call `FirebaseApp.configure()` in the App Delegate's " +
        "`application(_:didFinishLaunchingWithOptions:)` or the `@main` struct's " +
        "initializer in SwiftUI.")
    }
    return remoteConfig(withFIRNamespace: RemoteConfigConstants.NamespaceGoogleMobilePlatform,
                        app: app)
  }

  @objc(remoteConfigWithFIRNamespace:)
  public static func remoteConfig(withFIRNamespace firebaseNamespace: String) -> RemoteConfig {
    guard let app = FirebaseApp.app() else {
      fatalError("The default FirebaseApp instance must be configured before the " +
        "default Remote Config instance can be initialized. One way to ensure " +
        "this is to call `FirebaseApp.configure()` in the App Delegate's " +
        "`application(_:didFinishLaunchingWithOptions:)` or the `@main` struct's " +
        "initializer in SwiftUI.")
    }

    return remoteConfig(withFIRNamespace: firebaseNamespace, app: app)
  }

  // Use the provider to generate and return instances of FIRRemoteConfig for this specific app and
  // namespace. This will ensure the app is configured before Remote Config can return an instance.
  @objc(remoteConfigWithFIRNamespace:app:)
  public static func remoteConfig(withFIRNamespace firebaseNamespace: String = RemoteConfigConstants
    .NamespaceGoogleMobilePlatform,
    app: FirebaseApp) -> RemoteConfig {
    let provider = ComponentType<RemoteConfigInterop>
      .instance(
        for: RemoteConfigInterop.self,
        in: app.container
      ) as! any RemoteConfigProvider as RemoteConfigProvider
    return provider.remoteConfig(forNamespace: firebaseNamespace)!
  }

  /// Last successful fetch completion time.
  @objc public var lastFetchTime: Date? {
    var fetchTime: Date?
    queue.sync {
      let lastFetchTimeInterval = self.settings.lastFetchTimeInterval
      if lastFetchTimeInterval > 0 {
        fetchTime = Date(timeIntervalSince1970: lastFetchTimeInterval)
      }
    }
    return fetchTime
  }

  /// Last fetch status. The status can be any enumerated value from `RemoteConfigFetchStatus`.
  @objc public var lastFetchStatus: RemoteConfigFetchStatus {
    var currentStatus: RemoteConfigFetchStatus = .noFetchYet
    queue.sync {
      currentStatus = self.configFetch.settings.lastFetchStatus
    }
    return currentStatus
  }

  /// Config settings are custom settings.
  @objc public var configSettings: RemoteConfigSettings {
    get {
      // These properties *must* be accessed and returned on the lock queue
      // to ensure thread safety.
      var minimumFetchInterval: TimeInterval = ConfigConstants.defaultMinimumFetchInterval
      var fetchTimeout: TimeInterval = ConfigConstants.httpDefaultConnectionTimeout
      queue.sync {
        minimumFetchInterval = self.settings.minimumFetchInterval
        fetchTimeout = self.settings.fetchTimeout
      }

      RCLog.debug("I-RCN000066",
                  "Successfully read configSettings. Minimum Fetch Interval: " +
                    "\(minimumFetchInterval), Fetch timeout: \(fetchTimeout)")
      let settings = RemoteConfigSettings()
      settings.minimumFetchInterval = minimumFetchInterval
      settings.fetchTimeout = fetchTimeout
      RCLog.debug("I-RCN987366",
                  "Successfully read configSettings. Minimum Fetch Interval: " +
                    "\(minimumFetchInterval), Fetch timeout: \(fetchTimeout)")
      return settings
    }
    set {
      queue.async {
        let configSettings = newValue
        self.settings.minimumFetchInterval = configSettings.minimumFetchInterval
        self.settings.fetchTimeout = configSettings.fetchTimeout

        /// The NSURLSession needs to be recreated whenever the fetch timeout may be updated.
        self.configFetch.recreateNetworkSession()

        RCLog.debug("I-RCN000067",
                    "Successfully set configSettings. Minimum Fetch Interval: " +
                      "\(newValue.minimumFetchInterval), " +
                      "Fetch timeout: \(newValue.fetchTimeout)")
      }
    }
  }

  @objc public subscript(key: String) -> RemoteConfigValue {
    return configValue(forKey: key)
  }

  /// Singleton instance of serial queue for queuing all incoming RC calls.
  public static let sharedRemoteConfigSerialQueue =
    DispatchQueue(label: "com.google.remoteconfig.serialQueue")

  // TODO: Designated initializer - Consolidate with next when objc tests are gone.
  @objc(initWithAppName:FIROptions:namespace:DBManager:configContent:analytics:)
  public
  convenience init(appName: String,
                   options: FirebaseOptions,
                   namespace: String,
                   dbManager: ConfigDBManager,
                   configContent: ConfigContent,
                   analytics: FIRAnalyticsInterop?) {
    self.init(
      appName: appName,
      options: options,
      namespace: namespace,
      dbManager: dbManager,
      configContent: configContent,
      userDefaults: nil,
      analytics: analytics,
      configFetch: nil,
      configRealtime: nil
    )
  }

  /// Designated initializer
  @objc(
    initWithAppName:FIROptions:namespace:DBManager:configContent:userDefaults:analytics:configFetch:configRealtime:settings:
  )
  public
  init(appName: String,
       options: FirebaseOptions,
       namespace: String,
       dbManager: ConfigDBManager,
       configContent: ConfigContent,
       userDefaults: UserDefaults?,
       analytics: FIRAnalyticsInterop?,
       configFetch: ConfigFetch? = nil,
       configRealtime: ConfigRealtime? = nil,
       settings: ConfigSettings? = nil) {
    self.appName = appName
    self.dbManager = dbManager

    // Initialize RCConfigContent if not already.
    self.configContent = configContent
    // The fully qualified Firebase namespace is namespace:firappname.
    FIRNamespace = "\(namespace):\(appName)"
    queue = RemoteConfig.sharedRemoteConfigSerialQueue

    self.settings = settings ?? ConfigSettings(
      databaseManager: dbManager,
      namespace: FIRNamespace,
      firebaseAppName: appName,
      googleAppID: options.googleAppID,
      userDefaults: userDefaults
    )

    let experimentController = ExperimentController.sharedInstance()
    configExperiment = ConfigExperiment(
      dbManager: dbManager,
      experimentController: experimentController
    )
    // Initialize with default config settings.
    self.configFetch = configFetch ?? ConfigFetch(
      content: configContent,
      DBManager: dbManager,
      settings: self.settings,
      analytics: analytics,
      experiment: configExperiment,
      queue: queue,
      namespace: FIRNamespace,
      options: options
    )
    self.configRealtime = configRealtime ?? ConfigRealtime(
      configFetch: self.configFetch,
      settings: self.settings,
      namespace: FIRNamespace,
      options: options
    )
    super.init()
    self.settings.loadConfigFromMetadataTable()
    if let analytics = analytics {
      let personalization = Personalization(analytics: analytics)
      addListener { key, config in
        personalization.logArmActive(rcParameter: key, config: config)
      }
    }
  }

  /// Ensures initialization is complete and clients can begin querying for Remote Config values.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func ensureInitialized() async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.ensureInitialized { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  /// Ensures initialization is complete and clients can begin querying for Remote Config values.
  /// - Parameter completionHandler: Initialization complete callback with error parameter.
  @objc public func ensureInitialized(completionHandler: @escaping (Error?) -> Void) {
    DispatchQueue.global(qos: .utility).async { [weak self] in
      guard let self = self else { return }
      let initializationSuccess = self.configContent.initializationSuccessful()
      let error = initializationSuccess ? nil :
        NSError(
          domain: ConfigConstants.RemoteConfigErrorDomain,
          code: RemoteConfigError.internalError.rawValue,
          userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for database load."]
        )
      completionHandler(error)
    }
  }

  /// Adds a listener that will be called whenever one of the get methods is called.
  /// - Parameter listener Function that takes in the parameter key and the config.
  @objc public func addListener(_ listener: @escaping RemoteConfigListener) {
    queue.async {
      self.listeners.append(listener)
    }
  }

  private func callListeners(key: String, config: [String: RemoteConfigValue]) {
    queue.async { [weak self] in
      guard let self = self else { return }
      for listener in self.listeners {
        listener(key, config)
      }
    }
  }

  // MARK: fetch

  /// Fetches Remote Config data with a callback. Call `activate()` to make fetched data
  /// available to your app.
  ///
  /// Note: This method uses a Firebase Installations token to identify the app instance, and once
  /// it's called, it periodically sends data to the Firebase backend. (see
  /// `Installations.authToken(completion:)`).
  /// To stop the periodic sync, call `Installations.delete(completion:)`
  /// and avoid calling this method again.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func fetch() async throws -> RemoteConfigFetchStatus {
    return try await withUnsafeThrowingContinuation { continuation in
      self.fetch { status, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: status)
        }
      }
    }
  }

  /// Fetches Remote Config data with a callback. Call `activate()` to make fetched data
  /// available to your app.
  ///
  /// Note: This method uses a Firebase Installations token to identify the app instance, and once
  /// it's called, it periodically sends data to the Firebase backend. (see
  /// `Installations.authToken(completion:)`).
  /// To stop the periodic sync, call `Installations.delete(completion:)`
  /// and avoid calling this method again.
  ///
  /// - Parameter completionHandler Fetch operation callback with status and error parameters.
  @objc public func fetch(completionHandler: ((RemoteConfigFetchStatus, Error?) -> Void)? = nil) {
    queue.async {
      self.fetch(withExpirationDuration: self.settings.minimumFetchInterval,
                 completionHandler: completionHandler)
    }
  }

  /// Fetches Remote Config data and sets a duration that specifies how long config data lasts.
  /// Call `activateWithCompletion:` to make fetched data available to your app.
  ///
  /// - Parameter expirationDuration  Override the (default or optionally set `minimumFetchInterval`
  /// property in RemoteConfigSettings) `minimumFetchInterval` for only the current request, in
  /// seconds. Setting a value of 0 seconds will force a fetch to the backend.
  ///
  /// Note: This method uses a Firebase Installations token to identify the app instance, and once
  /// it's called, it periodically sends data to the Firebase backend. (see
  /// `Installations.authToken(completion:)`).
  /// To stop the periodic sync, call `Installations.delete(completion:)`
  /// and avoid calling this method again.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func fetch(withExpirationDuration expirationDuration: TimeInterval) async throws
    -> RemoteConfigFetchStatus {
    return try await withCheckedThrowingContinuation { continuation in
      self.fetch(withExpirationDuration: expirationDuration) { status, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: status)
        }
      }
    }
  }

  /// Fetches Remote Config data and sets a duration that specifies how long config data lasts.
  /// Call `activateWithCompletion:` to make fetched data available to your app.
  ///
  /// - Parameter expirationDuration  Override the (default or optionally set `minimumFetchInterval`
  /// property in RemoteConfigSettings) `minimumFetchInterval` for only the current request, in
  /// seconds. Setting a value of 0 seconds will force a fetch to the backend.
  /// - Parameter completionHandler   Fetch operation callback with status and error parameters.
  ///
  /// Note: This method uses a Firebase Installations token to identify the app instance, and once
  /// it's called, it periodically sends data to the Firebase backend. (see
  /// `Installations.authToken(completion:)`).
  /// To stop the periodic sync, call `Installations.delete(completion:)`
  /// and avoid calling this method again.
  @objc public func fetch(withExpirationDuration expirationDuration: TimeInterval,
                          completionHandler: ((RemoteConfigFetchStatus, Error?) -> Void)? = nil) {
    configFetch.fetchConfig(withExpirationDuration: expirationDuration,
                            completionHandler: completionHandler)
  }

  // MARK: fetchAndActivate

  /// Fetches Remote Config data and if successful, activates fetched data. Optional completion
  /// handler callback is invoked after the attempted activation of data, if the fetch call
  /// succeeded.
  ///
  /// Note: This method uses a Firebase Installations token to identify the app instance, and once
  /// it's called, it periodically sends data to the Firebase backend. (see
  /// `Installations.authToken(completion:)`).
  /// To stop the periodic sync, call `Installations.delete(completion:)`
  /// and avoid calling this method again.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func fetchAndActivate() async throws -> RemoteConfigFetchAndActivateStatus {
    return try await withCheckedThrowingContinuation { continuation in
      self.fetchAndActivate { status, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: status)
        }
      }
    }
  }

  /// Fetches Remote Config data and if successful, activates fetched data. Optional completion
  /// handler callback is invoked after the attempted activation of data, if the fetch call
  /// succeeded.
  ///
  /// Note: This method uses a Firebase Installations token to identify the app instance, and once
  /// it's called, it periodically sends data to the Firebase backend. (see
  /// `Installations.authToken(completion:)`).
  /// To stop the periodic sync, call `Installations.delete(completion:)`
  /// and avoid calling this method again.
  ///
  /// - Parameter completionHandler Fetch operation callback with status and error parameters.
  @objc public func fetchAndActivate(completionHandler:
    ((RemoteConfigFetchAndActivateStatus, Error?) -> Void)? =
      nil) {
    fetch { [weak self] status, error in
      guard let self = self else { return }
      // Fetch completed. We are being called on the main queue.
      // If fetch is successful, try to activate the fetched config
      if status == .success, error == nil {
        self.activate { changed, error in
          let status: RemoteConfigFetchAndActivateStatus = error == nil ?
            .successFetchedFromRemote : .successUsingPreFetchedData
          if let completionHandler {
            DispatchQueue.main.async {
              completionHandler(status, nil)
            }
          }
        }
      } else if let completionHandler {
        DispatchQueue.main.async {
          completionHandler(.error, error)
        }
      }
    }
  }

  // MARK: activate

  /// Applies Fetched Config data to the Active Config, causing updates to the behavior and
  /// appearance of the app to take effect (depending on how config data is used in the app).
  /// - Returns A Bool indicating whether or not a change occurred.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func activate() async throws -> Bool {
    return try await withCheckedThrowingContinuation { continuation in
      self.activate { updated, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: updated)
        }
      }
    }
  }

  /// Applies Fetched Config data to the Active Config, causing updates to the behavior and
  /// appearance of the app to take effect (depending on how config data is used in the app).
  /// - Parameter completion Activate operation callback with changed and error parameters.
  @objc public func activate(completion: ((Bool, Error?) -> Void)? = nil) {
    queue.async { [weak self] in
      guard let self = self else {
        let error = NSError(
          domain: ConfigConstants.RemoteConfigErrorDomain,
          code: RemoteConfigError.internalError.rawValue,
          userInfo: ["ActivationFailureReason": "Internal Error."]
        )
        RCLog.error("I-RCN000068", "Internal error activating config.")
        if let completion {
          DispatchQueue.main.async {
            completion(false, error)
          }
        }
        return
      }
      // Check if the last fetched config has already been activated. Fetches with no data change
      // are ignored.
      if self.settings.lastETagUpdateTime == 0 ||
        self.settings.lastETagUpdateTime <= self.settings.lastApplyTimeInterval {
        RCLog.debug("I-RCN000069", "Most recently fetched config is already activated.")
        if let completion {
          DispatchQueue.main.async {
            completion(false, nil)
          }
        }
        return
      }

      self.configContent.copy(fromDictionary: self.configContent.fetchedConfig(),
                              toSource: .active, forNamespace: self.FIRNamespace)

      self.settings.lastApplyTimeInterval = Date().timeIntervalSince1970
      // New config has been activated at this point
      RCLog.debug("I-RCN000069", "Config activated.")
      self.configContent.activatePersonalization()

      // Update last active template version number in setting and userDefaults.
      self.settings.updateLastActiveTemplateVersion()

      // Update activeRolloutMetadata
      self.configContent.activateRolloutMetadata { success in
        if success {
          self.notifyRolloutsStateChange(self.configContent.activeRolloutMetadata(),
                                         versionNumber: self.settings.lastActiveTemplateVersion)
        }
      }

      // Update experiments only for 3p namespace
      let namespace = self.FIRNamespace.split(separator: ":").first.map(String.init)
      if namespace == FIRNamespaceGoogleMobilePlatform {
        DispatchQueue.main.async {
          self.notifyConfigHasActivated()
        }
        self.configExperiment.updateExperiments { error in
          DispatchQueue.main.async {
            completion?(true, error)
          }
        }
      } else {
        DispatchQueue.main.async {
          completion?(true, nil)
        }
      }
    }
  }

  private func notifyConfigHasActivated() {
    guard !appName.isEmpty else { return }
    // The Remote Config Swift SDK will be listening for this notification so it can tell SwiftUI
    // to update the UI.
    NotificationCenter.default.post(
      name: FIRRemoteConfigActivateNotification, object: self,
      userInfo: ["FIRAppNameKey": appName]
    )
  }

  // MARK: helpers

  private func fullyQualifiedNamespace(_ namespace: String) -> String {
    if namespace.contains(":") { return namespace } // Already fully qualified
    return "\(namespace):\(appName)"
  }

  private func defaultValue(forFullyQualifiedNamespace namespace: String, key: String)
    -> RemoteConfigValue {
    if let value = configContent.defaultConfig()[namespace]?[key] {
      return value
    }
    return RemoteConfigValue(data: Data(), source: .static)
  }

  // MARK: Get Config Result

  /// Gets the config value.
  /// - Parameter key Config key.
  @objc public func configValue(forKey key: String) -> RemoteConfigValue {
    guard !key.isEmpty else {
      return RemoteConfigValue(data: Data(), source: .static)
    }

    let fullyQualifiedNamespace = fullyQualifiedNamespace(FIRNamespace)
    var value: RemoteConfigValue!

    queue.sync {
      value = configContent.activeConfig()[fullyQualifiedNamespace]?[key]
      if let value = value {
        if value.source != .remote {
          RCLog.error("I-RCN000001",
                      "Key \(key) should come from source: \(RemoteConfigSource.remote.rawValue)" +
                        "instead coming from source: \(value.source.rawValue)")
        }
        if let config = configContent.getConfigAndMetadata(forNamespace: fullyQualifiedNamespace)
          as? [String: RemoteConfigValue] {
          callListeners(key: key, config: config)
        }
        return
      }

      value = defaultValue(forFullyQualifiedNamespace: fullyQualifiedNamespace, key: key)
    }
    return value
  }

  /// Gets the config value of a given source from the default namespace.
  /// - Parameter key              Config key.
  /// - Parameter source           Config value source.
  @objc public func configValue(forKey key: String, source: RemoteConfigSource) ->
    RemoteConfigValue {
    guard !key.isEmpty else {
      return RemoteConfigValue(data: Data(), source: .static)
    }
    let fullyQualifiedNamespace = self.fullyQualifiedNamespace(FIRNamespace)
    var value: RemoteConfigValue!

    queue.sync {
      switch source {
      case .remote:
        value = configContent.activeConfig()[fullyQualifiedNamespace]?[key]
      case .default:
        value = configContent.defaultConfig()[fullyQualifiedNamespace]?[key]
      case .static:
        value = RemoteConfigValue(data: Data(), source: .static)
      }
    }
    return value
  }

  @objc(allKeysFromSource:)
  public func allKeys(from source: RemoteConfigSource) -> [String] {
    var keys: [String] = []
    queue.sync {
      let fullyQualifiedNamespace = self.fullyQualifiedNamespace(FIRNamespace)
      switch source {
      case .default:
        if let values = configContent.defaultConfig()[fullyQualifiedNamespace] {
          keys = Array(values.keys)
        }
      case .remote:
        if let values = configContent.activeConfig()[fullyQualifiedNamespace] {
          keys = Array(values.keys)
        }
      case .static:
        break
      }
    }
    return keys
  }

  @objc public func keys(withPrefix prefix: String?) -> Set<String> {
    var keys = Set<String>()
    queue.sync {
      let fullyQualifiedNamespace = self.fullyQualifiedNamespace(FIRNamespace)

      if let config = configContent.activeConfig()[fullyQualifiedNamespace] {
        if let prefix = prefix, !prefix.isEmpty {
          keys = Set(config.keys.filter { $0.hasPrefix(prefix) })
        } else {
          keys = Set(config.keys)
        }
      }
    }
    return keys
  }

  public func countByEnumerating(with state: UnsafeMutablePointer<NSFastEnumerationState>,
                                 objects buffer: AutoreleasingUnsafeMutablePointer<AnyObject?>,
                                 count len: Int) -> Int {
    var count = 0
    queue.sync {
      let fullyQualifiedNamespace = self.fullyQualifiedNamespace(FIRNamespace)

      if let config = configContent.activeConfig()[fullyQualifiedNamespace] as? NSDictionary {
        count = config.countByEnumerating(with: state, objects: buffer, count: len)
      }
    }
    return count
  }

  // MARK: Defaults

  /// Sets config defaults for parameter keys and values in the default namespace config.
  /// - Parameter defaults         A dictionary mapping a NSString * key to a NSObject * value.
  @objc public func setDefaults(_ defaults: [String: Any]?) {
    let defaults = defaults ?? [String: Any]()
    let fullyQualifiedNamespace = self.fullyQualifiedNamespace(FIRNamespace)
    queue.async { [weak self] in
      guard let self = self else { return }

      self.configContent.copy(fromDictionary: [fullyQualifiedNamespace: defaults],
                              toSource: .default,
                              forNamespace: fullyQualifiedNamespace)
      self.settings.lastSetDefaultsTimeInterval = Date().timeIntervalSince1970
    }
  }

  /// Sets default configs from plist for default namespace.
  ///
  /// - Parameter fileName The plist file name, with no file name extension. For example, if the
  /// plist
  /// file is named `defaultSamples.plist`:
  ///                 `RemoteConfig.remoteConfig().setDefaults(fromPlist: "defaultSamples")`
  @objc(setDefaultsFromPlistFileName:)
  public func setDefaults(fromPlist fileName: String?) {
    guard let fileName = fileName, !fileName.isEmpty else {
      RCLog.warning("I-RCN000037",
                    "The plist file name cannot be nil or empty.")
      return
    }

    for bundle in [Bundle.main, Bundle(for: type(of: self))] {
      if let path = bundle.path(forResource: fileName, ofType: "plist"),
         let config = NSDictionary(contentsOfFile: path) as? [String: Any] {
        setDefaults(config)
        return
      }
    }
    RCLog.warning("I-RCN000037",
                  "The plist file '\(fileName)' could not be found by Remote Config.")
  }

  /// Returns the default value of a given key from the default config.
  ///
  /// - Parameter key              The parameter key of default config.
  /// - Returns                 Returns the default value of the specified key. Returns
  ///                         nil if the key doesn't exist in the default config.
  @objc public func defaultValue(forKey key: String) -> RemoteConfigValue? {
    let fullyQualifiedNamespace = self.fullyQualifiedNamespace(FIRNamespace)
    var value: RemoteConfigValue?
    queue.sync {
      if let config = configContent.defaultConfig()[fullyQualifiedNamespace] {
        value = config[key]
        if let value, value.source != .default {
          RCLog.error("I-RCN000002",
                      "Key \(key) should come from source: \(RemoteConfigSource.default.rawValue)" +
                        "instead coming from source: \(value.source.rawValue)")
        }
      }
    }
    return value
  }

  // MARK: Realtime

  /// Start listening for real-time config updates from the Remote Config backend and
  /// automatically fetch updates when they're available.
  ///
  /// If a connection to the Remote Config backend is not already open, calling this method will
  /// open it. Multiple listeners can be added by calling this method again, but subsequent calls
  /// re-use the same connection to the backend.
  ///
  /// Note: Real-time Remote Config requires the Firebase Remote Config Realtime API. See Get
  /// started with Firebase Remote Config at
  /// https://firebase.google.com/docs/remote-config/get-started
  /// for more information.
  ///
  /// - Parameter listener              The configured listener that is called for every config
  /// update.
  /// - Returns              Returns a registration representing the listener. The registration
  /// contains a remove method, which can be used to stop receiving updates for the provided
  /// listener.
  @objc public func addOnConfigUpdateListener(remoteConfigUpdateCompletion listener: @Sendable @escaping (RemoteConfigUpdate?,
                                                                                                          Error?)
      -> Void)
    -> ConfigUpdateListenerRegistration {
    return configRealtime.addConfigUpdateListener(listener)
  }

  // MARK: Rollout

  @objc public func addRemoteConfigInteropSubscriber(_ subscriber: RolloutsStateSubscriber) {
    NotificationCenter.default.addObserver(
      forName: .rolloutsStateDidChange, object: self, queue: nil
    ) { notification in
      if let rolloutsState =
        notification.userInfo?[Notification.Name.rolloutsStateDidChange.rawValue]
          as? RolloutsState {
        subscriber.rolloutsStateDidChange(rolloutsState)
      }
    }
    // Send active rollout metadata stored in persistence while app launched if there is
    // an activeConfig
    let fullyQualifiedNamespace = fullyQualifiedNamespace(FIRNamespace)
    if let activeConfig = configContent.activeConfig()[fullyQualifiedNamespace],
       activeConfig.isEmpty == false {
      notifyRolloutsStateChange(configContent.activeRolloutMetadata(),
                                versionNumber: settings.lastActiveTemplateVersion)
    }
  }

  private func notifyRolloutsStateChange(_ rolloutMetadata: [[String: Any]],
                                         versionNumber: String) {
    let rolloutsAssignments =
      rolloutsAssignments(with: rolloutMetadata, versionNumber: versionNumber)
    let rolloutsState = RolloutsState(assignmentList: rolloutsAssignments)
    RCLog.debug("I-RCN000069",
                "Send rollouts state notification with name " +
                  "\(Notification.Name.rolloutsStateDidChange.rawValue) to RemoteConfigInterop.")
    NotificationCenter.default.post(
      name: .rolloutsStateDidChange,
      object: self,
      userInfo: [Notification.Name.rolloutsStateDidChange.rawValue: rolloutsState]
    )
  }

  private func rolloutsAssignments(with rolloutMetadata: [[String: Any]], versionNumber: String)
    -> [RolloutAssignment] {
    var rolloutsAssignments = [RolloutAssignment]()
    let fullyQualifiedNamespace = fullyQualifiedNamespace(FIRNamespace)
    for metadata in rolloutMetadata {
      if let rolloutID = metadata[ConfigConstants.fetchResponseKeyRolloutID] as? String,
         let variantID = metadata[ConfigConstants.fetchResponseKeyVariantID] as? String,
         let affectedParameterKeys =
         metadata[ConfigConstants.fetchResponseKeyAffectedParameterKeys] as? [String] {
        for key in affectedParameterKeys {
          let value = configContent.activeConfig()[fullyQualifiedNamespace]?[key] ??
            defaultValue(forFullyQualifiedNamespace: fullyQualifiedNamespace, key: key)
          let assignment = RolloutAssignment(
            rolloutId: rolloutID,
            variantId: variantID,
            templateVersion: Int64(versionNumber) ?? 0,
            parameterKey: key,
            parameterValue: value.stringValue
          )
          rolloutsAssignments.append(assignment)
        }
      }
    }
    return rolloutsAssignments
  }
}

// MARK: - Rollout Notification

extension Notification.Name {
  static let rolloutsStateDidChange = Notification.Name(rawValue:
    "FIRRolloutsStateDidChangeNotification")
}
