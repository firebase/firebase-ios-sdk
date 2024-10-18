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

/// A class that manages user defaults for Firebase Remote Config.
@objc(RCNUserDefaultsManager)
public class UserDefaultsManager: NSObject {
  /// The user defaults instance for this bundleID. NSUserDefaults is guaranteed to be thread-safe.
  private let userDefaults: UserDefaults

  /// The suite name for this user defaults instance. It is a combination of a prefix and the
  /// bundleID. This is because you cannot use just the bundleID of the current app as the suite
  /// name when initializing user defaults.
  private let userDefaultsSuiteName: String = ""

  /// The FIRApp that this instance is scoped within.
  private let firebaseAppName: String

  /// The Firebase Namespace that this instance is scoped within.
  private let firebaseNamespace: String

  /// The bundleID of the app. In case of an extension, this will be the bundleID of the parent app.
  private let bundleIdentifier: String

  static let kRCNGroupPrefix = "group"
  static let kRCNGroupSuffix = "firebase"
  let kRCNUserDefaultsKeyNamelastETag = "lastETag"
  let kRCNUserDefaultsKeyNamelastETagUpdateTime = "lastETagUpdateTime"
  let kRCNUserDefaultsKeyNameLastSuccessfulFetchTime = "lastSuccessfulFetchTime"
  let kRCNUserDefaultsKeyNamelastFetchStatus = "lastFetchStatus"
  let kRCNUserDefaultsKeyNameIsClientThrottled = "isClientThrottledWithExponentialBackoff"
  let kRCNUserDefaultsKeyNameThrottleEndTime = "throttleEndTime"
  let kRCNUserDefaultsKeyNameCurrentThrottlingRetryInterval = "currentThrottlingRetryInterval"
  let kRCNUserDefaultsKeyNameRealtimeThrottleEndTime = "throttleRealtimeEndTime"
  let kRCNUserDefaultsKeyNameCurrentRealtimeThrottlingRetryInterval =
    "currentRealtimeThrottlingRetryInterval"
  let kRCNUserDefaultsKeyNameRealtimeRetryCount = "realtimeRetryCount"

  @objc public init(appName: String, bundleID: String, namespace: String) {
    firebaseAppName = appName
    bundleIdentifier = bundleID
    firebaseNamespace = UserDefaultsManager.validateNamespace(namespace: namespace)

    // Initialize the user defaults with a prefix and the bundleID. For app extensions, this will be
    // the bundleID of the app extension.
    userDefaults =
      UserDefaultsManager.sharedUserDefaultsForBundleIdentifier(bundleIdentifier)
  }

  private static func validateNamespace(namespace: String) -> String {
    if namespace.contains(":") {
      let components = namespace.components(separatedBy: ":")
      return components[0]
    } else {
      // TODO: FIRLogError(kFIRLoggerRemoteConfig, "I-RCN00064",
      //                    "Error: Namespace %@ is not fully qualified app:namespace.", namespace)
      print("Error: Namespace \(namespace) is not fully qualified app:namespace.")
      return namespace
    }
  }

  private static var sharedInstanceMap: [String: UserDefaults] = [:]

  /// Returns the shared user defaults instance for the given bundle identifier.
  ///
  /// - Parameter bundleIdentifier: The bundle identifier of the app.
  /// - Returns: The shared user defaults instance.
  @objc(sharedUserDefaultsForBundleIdentifier:)
  static func sharedUserDefaultsForBundleIdentifier(_ bundleIdentifier: String) -> UserDefaults {
    objc_sync_enter(sharedInstanceMap)
    defer { objc_sync_exit(sharedInstanceMap) }
    if let instance = sharedInstanceMap[bundleIdentifier] {
      return instance
    }
    let userDefaults = UserDefaults(suiteName: userDefaultsSuiteName(for: bundleIdentifier))!
    sharedInstanceMap[bundleIdentifier] = userDefaults
    return userDefaults
  }

  /// Returns the user defaults suite name for the given bundle identifier.
  ///
  /// - Parameter bundleIdentifier: The bundle identifier of the app.
  /// - Returns: The user defaults suite name.
  @objc(userDefaultsSuiteNameForBundleIdentifier:)
  public static func userDefaultsSuiteName(for bundleIdentifier: String) -> String {
    return "\(kRCNGroupPrefix).\(bundleIdentifier).\(kRCNGroupSuffix)"
  }

  /// The last ETag received from the server.
  @objc public var lastETag: String? {
    return instanceUserDefaults[kRCNUserDefaultsKeyNamelastETag] as? String
  }

  /// Sets the last ETag received from the server.
  ///
  /// - Parameter lastETag: The last ETag received from the server.
  @objc public func setLastETag(_ lastETag: String?) {
    if let lastETag = lastETag {
      setInstanceUserDefaultsValue(lastETag, forKey: kRCNUserDefaultsKeyNamelastETag)
    }
  }

  /// The last fetched template version.
  @objc public var lastFetchedTemplateVersion: String {
    return instanceUserDefaults[ConfigConstants.fetchResponseKeyTemplateVersion] as? String ?? "0"
  }

  /// Sets the last fetched template version.
  ///
  /// - Parameter templateVersion: The last fetched template version.
  @objc public func setLastFetchedTemplateVersion(_ templateVersion: String) {
    setInstanceUserDefaultsValue(
      templateVersion,
      forKey: ConfigConstants.fetchResponseKeyTemplateVersion
    )
  }

  /// The last active template version.
  @objc public var lastActiveTemplateVersion: String {
    return instanceUserDefaults[ConfigConstants.activeKeyTemplateVersion] as? String ?? "0"
  }

  /// Sets the last active template version.
  ///
  /// - Parameter templateVersion: The last active template version.
  @objc public func setLastActiveTemplateVersion(_ templateVersion: String) {
    setInstanceUserDefaultsValue(templateVersion, forKey: ConfigConstants.activeKeyTemplateVersion)
  }

  /// The last ETag update time.
  @objc public var lastETagUpdateTime: TimeInterval {
    return instanceUserDefaults[kRCNUserDefaultsKeyNamelastETagUpdateTime] as? TimeInterval ?? 0
  }

  /// Sets the last ETag update time.
  ///
  /// - Parameter lastETagUpdateTime: The last ETag update time.
  @objc public func setLastETagUpdateTime(_ lastETagUpdateTime: TimeInterval) {
    setInstanceUserDefaultsValue(
      lastETagUpdateTime,
      forKey: kRCNUserDefaultsKeyNamelastETagUpdateTime
    )
  }

  /// The last fetch time.
  @objc public var lastFetchTime: TimeInterval {
    return instanceUserDefaults[kRCNUserDefaultsKeyNameLastSuccessfulFetchTime] as? TimeInterval ??
      0
  }

  /// Sets the last fetch time.
  ///
  /// - Parameter lastFetchTime: The last fetch time.
  @objc public func setLastFetchTime(_ lastFetchTime: TimeInterval) {
    setInstanceUserDefaultsValue(
      lastFetchTime,
      forKey: kRCNUserDefaultsKeyNameLastSuccessfulFetchTime
    )
  }

  /// The last fetch status.
  @objc public var lastFetchStatus: String? {
    return instanceUserDefaults[kRCNUserDefaultsKeyNamelastFetchStatus] as? String
  }

  /// Sets the last fetch status.
  ///
  /// - Parameter lastFetchStatus: The last fetch status.
  @objc public func setLastFetchStatus(_ lastFetchStatus: String?) {
    if let lastFetchStatus = lastFetchStatus {
      setInstanceUserDefaultsValue(lastFetchStatus, forKey: kRCNUserDefaultsKeyNamelastFetchStatus)
    }
  }

  /// Whether the client is throttled with exponential backoff.
  @objc public var isClientThrottledWithExponentialBackoff: Bool {
    return instanceUserDefaults[kRCNUserDefaultsKeyNameIsClientThrottled] as? Bool ?? false
  }

  /// Sets whether the client is throttled with exponential backoff.
  ///
  /// - Parameter isThrottledWithExponentialBackoff: Whether the client is throttled with
  /// exponential backoff.
  @objc public func setIsClientThrottledWithExponentialBackoff(_ isThrottledWithExponentialBackoff: Bool) {
    setInstanceUserDefaultsValue(
      isThrottledWithExponentialBackoff,
      forKey: kRCNUserDefaultsKeyNameIsClientThrottled
    )
  }

  /// The throttle end time.
  @objc public var throttleEndTime: TimeInterval {
    return instanceUserDefaults[kRCNUserDefaultsKeyNameThrottleEndTime] as? TimeInterval ?? 0
  }

  /// Sets the throttle end time.
  ///
  /// - Parameter throttleEndTime: The throttle end time.
  @objc public func setThrottleEndTime(_ throttleEndTime: TimeInterval) {
    setInstanceUserDefaultsValue(throttleEndTime, forKey: kRCNUserDefaultsKeyNameThrottleEndTime)
  }

  /// The current throttling retry interval in seconds.
  @objc public var currentThrottlingRetryIntervalSeconds: TimeInterval {
    return instanceUserDefaults[
      kRCNUserDefaultsKeyNameCurrentThrottlingRetryInterval
    ] as? TimeInterval ??
      0
  }

  /// Sets the current throttling retry interval in seconds.
  ///
  /// - Parameter throttlingRetryIntervalSeconds: The current throttling retry interval in seconds.
  @objc public func setCurrentThrottlingRetryIntervalSeconds(_ throttlingRetryIntervalSeconds: TimeInterval) {
    setInstanceUserDefaultsValue(
      throttlingRetryIntervalSeconds,
      forKey: kRCNUserDefaultsKeyNameCurrentThrottlingRetryInterval
    )
  }

  /// The realtime retry count.
  @objc public var realtimeRetryCount: Int {
    return instanceUserDefaults[kRCNUserDefaultsKeyNameRealtimeRetryCount] as? Int ?? 0
  }

  /// Sets the realtime retry count.
  ///
  /// - Parameter realtimeRetryCount: The realtime retry count.
  @objc public func setRealtimeRetryCount(_ realtimeRetryCount: Int) {
    setInstanceUserDefaultsValue(
      realtimeRetryCount,
      forKey: kRCNUserDefaultsKeyNameRealtimeRetryCount
    )
  }

  /// The realtime throttle end time.
  @objc public var realtimeThrottleEndTime: TimeInterval {
    return instanceUserDefaults[kRCNUserDefaultsKeyNameRealtimeThrottleEndTime] as? TimeInterval ??
      0
  }

  /// Sets the realtime throttle end time.
  ///
  /// - Parameter throttleEndTime: The realtime throttle end time.
  @objc public func setRealtimeThrottleEndTime(_ throttleEndTime: TimeInterval) {
    setInstanceUserDefaultsValue(
      throttleEndTime,
      forKey: kRCNUserDefaultsKeyNameRealtimeThrottleEndTime
    )
  }

  /// The current realtime throttling retry interval in seconds.
  @objc public var currentRealtimeThrottlingRetryIntervalSeconds: TimeInterval {
    return instanceUserDefaults[
      kRCNUserDefaultsKeyNameCurrentRealtimeThrottlingRetryInterval
    ] as? TimeInterval ??
      0
  }

  /// Sets the current realtime throttling retry interval in seconds.
  ///
  /// - Parameter throttlingRetryIntervalSeconds: The current realtime throttling retry interval in
  /// seconds.
  @objc public func setCurrentRealtimeThrottlingRetryIntervalSeconds(_ throttlingRetryIntervalSeconds: TimeInterval) {
    setInstanceUserDefaultsValue(throttlingRetryIntervalSeconds,
                                 forKey: kRCNUserDefaultsKeyNameCurrentRealtimeThrottlingRetryInterval)
  }

  /// Resets the user defaults.
  @objc public func resetUserDefaults() {
    resetInstanceUserDefaults()
  }

  // There is a nested hierarchy for the userdefaults as follows:
  // [FIRAppName][FIRNamespaceName][Key]
  private var appUserDefaults: [String: Any] {
    let appPath = firebaseAppName
    return userDefaults.dictionary(forKey: appPath) ?? [:]
  }

  // Search for the user defaults for this (app, namespace) instance using the valueForKeyPath
  // method.
  private var instanceUserDefaults: [String: AnyHashable] {
    let namespacedDictionary = userDefaults.dictionary(forKey: firebaseAppName)
    return namespacedDictionary?[firebaseNamespace] as? [String: AnyHashable] ?? [:]
  }

  // Update users defaults for just this (app, namespace) instance.
  private func setInstanceUserDefaultsValue(_ value: AnyHashable, forKey key: String) {
    objc_sync_enter(userDefaults)
    defer { objc_sync_exit(userDefaults) }
    var appUserDefaults = appUserDefaults
    var appNamespaceUserDefaults = instanceUserDefaults
    appNamespaceUserDefaults[key] = value
    appUserDefaults[firebaseNamespace] = appNamespaceUserDefaults
    userDefaults.set(appUserDefaults, forKey: firebaseAppName)
    // We need to synchronize to have this value updated for the extension.
    userDefaults.synchronize()
  }

  // Delete any existing userdefaults for this instance.
  private func resetInstanceUserDefaults() {
    objc_sync_enter(userDefaults)
    defer { objc_sync_exit(userDefaults) }
    var appUserDefaults = appUserDefaults
    var appNamespaceUserDefaults = instanceUserDefaults
    appNamespaceUserDefaults.removeAll()
    appUserDefaults[firebaseNamespace] = appNamespaceUserDefaults
    userDefaults.set(appUserDefaults, forKey: firebaseAppName)
    // We need to synchronize to have this value updated for the extension.
    userDefaults.synchronize()
  }
}
