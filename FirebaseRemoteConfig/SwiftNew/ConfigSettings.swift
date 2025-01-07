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
@_implementationOnly import GoogleUtilities

// TODO(ncooke3): Once Obj-C tests are ported, all `public` access modifers can be removed.

private let kRCNGroupPrefix = "frc.group."
private let kRCNUserDefaultsKeyNamelastETag = "lastETag"
private let kRCNUserDefaultsKeyNameLastSuccessfulFetchTime = "lastSuccessfulFetchTime"
private let kRCNAnalyticsFirstOpenTimePropertyName = "_fot"
private let kRCNExponentialBackoffMinimumInterval = 60 * 2 // 2 mins.
private let kRCNExponentialBackoffMaximumInterval = 60 * 60 * 4 // 4 hours.

let RCNHTTPDefaultConnectionTimeout: TimeInterval = 60

/// This internal class contains a set of variables that are unique among all the config instances.
/// It also handles all metadata. This class is not thread safe and does not
/// inherently allow for synchronized access. Callers are responsible for synchronization
/// (currently using serial dispatch queues).
@objc(RCNConfigSettings) public class ConfigSettings: NSObject {
  // MARK: - Private Properties

  /// A list of successful fetch timestamps in seconds.
  private var _successFetchTimes: [TimeInterval] = []

  /// A list of failed fetch timestamps in seconds.
  private var _failureFetchTimes: [TimeInterval] = []

  /// Device conditions since last successful fetch from the backend. Device conditions including
  /// app version, iOS version, device locale, language, GMP project ID and Game project ID.
  /// Used for determining whether to throttle.
  @objc public private(set) var deviceContext: [String: String] = [:]

  /// Custom variables (aka App context digest). This is the pending custom variables
  /// request before fetching.
  private var _customVariables: [String: Sendable] = [:]

  /// Last fetch status.
  @objc public var lastFetchStatus: RemoteConfigFetchStatus = .noFetchYet

  /// Last fetch Error.
  private var _lastFetchError: RemoteConfigError

  /// The time of last apply timestamp.
  private var _lastApplyTimeInterval: TimeInterval = 0

  /// The time of last setDefaults timestamp.
  private var _lastSetDefaultsTimeInterval: TimeInterval = 0

  /// The database manager.
  private var _DBManager: ConfigDBManager

  /// The namespace for this instance.
  private let _FIRNamespace: String

  /// The Google App ID of the configured FIRApp.
  private let _googleAppID: String

  /// The user defaults manager scoped to this RC instance of FIRApp and namespace.
  private var _userDefaultsManager: UserDefaultsManager

  // MARK: - Data required by config request.

  // TODO(ncooke3): This property was atomic in ObjC.
  /// InstallationsID.
  /// - Note: The property is atomic because it is accessed across multiple threads.
  @objc public var configInstallationsIdentifier = ""

  // TODO(ncooke3): This property was atomic in ObjC.
  /// Installations token.
  /// - Note: The property is atomic because it is accessed across multiple threads.
  @objc public var configInstallationsToken: String?

  /// Bundle Identifier
  public let bundleIdentifier: String

  /// Last fetched template version.
  @objc public var lastFetchedTemplateVersion: String

  /// Last active template version.
  @objc public var lastActiveTemplateVersion: String

  // MARK: - Throttling Properties

  // TODO(ncooke3): This property was atomic in ObjC.
  /// Throttling intervals are based on https://cloud.google.com/storage/docs/exponential-backoff
  /// Returns true if client has fetched config and has not got back from server. This is used to
  /// determine whether there is another config task infight when fetching.
  @objc public var isFetchInProgress: Bool

  /// Returns the current retry interval in seconds set for exponential backoff.
  @objc public var exponentialBackoffRetryInterval: Double

  /// Returns the time in seconds until the next request is allowed while in exponential backoff
  /// mode.
  @objc public var exponentialBackoffThrottleEndTime: TimeInterval

  /// Returns the current retry interval in seconds set for exponential backoff for the Realtime
  /// service.
  @objc public var realtimeExponentialBackoffRetryInterval: Double

  /// Returns the time in seconds until the next request is allowed while in
  /// exponential backoff mode for the Realtime service.
  public var realtimeExponentialBackoffThrottleEndTime: TimeInterval

  /// Realtime connection attempts.
  @objc public var realtimeRetryCount: Int

  // MARK: - Initializers

  /// Designated initializer.
  @objc public init(databaseManager: ConfigDBManager,
                    namespace: String,
                    firebaseAppName: String,
                    googleAppID: String,
                    userDefaults: UserDefaults?) {
    _FIRNamespace = namespace
    _googleAppID = googleAppID
    bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
    if bundleIdentifier.isEmpty {
      RCLog.notice(
        "I-RCN000038",
        "Main bundle identifier is missing. Remote Config might not work properly."
      )
    }
    _minimumFetchInterval = ConfigConstants.defaultMinimumFetchInterval
    deviceContext = [:]
    _customVariables = [:]
    _successFetchTimes = []
    _failureFetchTimes = []
    _DBManager = databaseManager

    _userDefaultsManager = UserDefaultsManager(
      appName: firebaseAppName,
      bundleID: bundleIdentifier,
      namespace: _FIRNamespace,
      userDefaults: userDefaults
    )

    // Check if the config database is new. If so, clear the configs saved in userDefaults.
    if _DBManager.isNewDatabase {
      RCLog.notice("I-RCN000072", "New config database created. Resetting user defaults.")
      _userDefaultsManager.resetUserDefaults()
    }

    isFetchInProgress = false
    lastFetchedTemplateVersion = _userDefaultsManager.lastFetchedTemplateVersion
    lastActiveTemplateVersion = _userDefaultsManager.lastActiveTemplateVersion
    realtimeExponentialBackoffRetryInterval = _userDefaultsManager
      .currentRealtimeThrottlingRetryIntervalSeconds
    realtimeExponentialBackoffThrottleEndTime = _userDefaultsManager
      .currentRealtimeThrottlingRetryIntervalSeconds
    realtimeRetryCount = _userDefaultsManager.realtimeRetryCount

    _lastFetchError = .unknown
    exponentialBackoffRetryInterval = 0
    _fetchTimeout = 0
    exponentialBackoffThrottleEndTime = 0

    super.init()
  }

  @objc public convenience init(databaseManager: ConfigDBManager,
                                namespace: String,
                                firebaseAppName: String,
                                googleAppID: String) {
    self.init(
      databaseManager: databaseManager,
      namespace: namespace,
      firebaseAppName: firebaseAppName,
      googleAppID: googleAppID,
      userDefaults: nil
    )
  }

  // MARK: - Read / Update User Defaults

  /// The latest eTag value stored from the last successful response.
  @objc public var lastETag: String? {
    get { _userDefaultsManager.lastETag }
    set {
      lastETagUpdateTime = Date().timeIntervalSince1970
      _userDefaultsManager.lastETag = newValue
    }
  }

  /// The time of last successful config fetch.
  @objc public var lastFetchTimeInterval: TimeInterval {
    _userDefaultsManager.lastFetchTime
  }

  /// The timestamp of the last eTag update.
  @objc public var lastETagUpdateTime: TimeInterval {
    get { _userDefaultsManager.lastETagUpdateTime }
    set { _userDefaultsManager.lastETagUpdateTime = newValue }
  }

  // TODO: Update logic for app extensions as required.
  private func updateLastFetchTimeInterval(_ lastFetchTimeInternal: TimeInterval) {
    _userDefaultsManager.lastFetchTime = lastFetchTimeInternal
  }

  // MARK: - Load from Database

  /// Returns metadata from metadata table.
  @objc public func loadConfigFromMetadataTable() {
    _DBManager
      .loadMetadata(
        withBundleIdentifier: bundleIdentifier,
        namespace: _FIRNamespace
      ) { metadata in
        // TODO: Remove (all metadata in general) once ready to
        // migrate to user defaults completely.
        if let deviceContext = metadata[RCNKeyDeviceContext] as? [String: String] {
          self.deviceContext = deviceContext
        }
        if let customVariables = metadata[RCNKeyAppContext] as? [String: Sendable] {
          self._customVariables = customVariables
        }
        if let successFetchTimes = metadata[RCNKeySuccessFetchTime] as? [TimeInterval] {
          self._successFetchTimes = successFetchTimes
        }
        if let failureFetchTimes = metadata[RCNKeyFailureFetchTime] as? [TimeInterval] {
          self._failureFetchTimes = failureFetchTimes
        }
        if let lastFetchStatus = metadata[RCNKeyLastFetchStatus] as? RemoteConfigFetchStatus {
          self.lastFetchStatus = lastFetchStatus
        }
        if let lastFetchError = metadata[RCNKeyLastFetchError] as? RemoteConfigError {
          self._lastFetchError = lastFetchError
        }
        if let lastApplyTimeInterval = metadata[RCNKeyLastApplyTime] as? TimeInterval {
          self._lastApplyTimeInterval = lastApplyTimeInterval
        }
        if let lastSetDefaultsTimeInterval = metadata[RCNKeyLastFetchStatus] as? TimeInterval {
          self._lastSetDefaultsTimeInterval = lastSetDefaultsTimeInterval
        }
      }
  }

  // MARK: - Update Database/Cache

  /// If the last fetch was not successful, update the (exponential backoff)
  /// period that we wait until fetching again. Any subsequent fetch requests
  /// will be checked and allowed only if past this throttle end time.
  @objc public func updateExponentialBackoffTime() {
    if lastFetchStatus == .success {
      RCLog.debug("I-RCN000057", "Throttling: Entering exponential backoff mode.")
      exponentialBackoffRetryInterval = Double(kRCNExponentialBackoffMinimumInterval)
    } else {
      RCLog.debug("I-RCN000057", "Throttling: Updating throttling interval.")
      // Double the retry interval until we hit the truncated exponential backoff. More info here:
      // https://cloud.google.com/storage/docs/exponential-backoff
      exponentialBackoffRetryInterval = if exponentialBackoffRetryInterval * 2 <
        Double(kRCNExponentialBackoffMaximumInterval) {
        exponentialBackoffRetryInterval * 2
      } else {
        exponentialBackoffRetryInterval
      }
    }

    // Randomize the next retry interval.
    let randomPlusMinusInterval = Bool.random() ? -0.5 : 0.5
    let randomizedRetryInterval = exponentialBackoffRetryInterval +
      (exponentialBackoffRetryInterval * randomPlusMinusInterval)
    exponentialBackoffThrottleEndTime = Date().timeIntervalSince1970 + randomizedRetryInterval
  }

  /// Increases the throttling time for Realtime. Should only be called if the Realtime error
  /// indicates a server issue.
  @objc public func updateRealtimeExponentialBackoffTime() {
    // If there was only one stream attempt before, reset the retry interval.
    if realtimeRetryCount == 0 {
      RCLog.debug("I-RCN000058", "Throttling: Entering exponential Realtime backoff mode.")
      realtimeExponentialBackoffRetryInterval = Double(kRCNExponentialBackoffMinimumInterval)
    } else {
      RCLog.debug("I-RCN000058", "Throttling: Updating Realtime throttling interval.")
      // Double the retry interval until we hit the truncated exponential backoff. More info here:
      // https://cloud.google.com/storage/docs/exponential-backoff
      realtimeExponentialBackoffRetryInterval = if (realtimeExponentialBackoffRetryInterval * 2) <
        Double(kRCNExponentialBackoffMaximumInterval) {
        realtimeExponentialBackoffRetryInterval * 2
      } else {
        realtimeExponentialBackoffRetryInterval
      }
    }

    // Randomize the next retry interval.
    let randomPlusMinusInterval = Bool.random() ? -0.5 : 0.5
    let randomizedRetryInterval = realtimeExponentialBackoffRetryInterval +
      (realtimeExponentialBackoffRetryInterval * randomPlusMinusInterval)
    realtimeExponentialBackoffThrottleEndTime = Date()
      .timeIntervalSince1970 + randomizedRetryInterval

    _userDefaultsManager.realtimeThrottleEndTime = realtimeExponentialBackoffThrottleEndTime
    _userDefaultsManager
      .currentRealtimeThrottlingRetryIntervalSeconds = realtimeExponentialBackoffRetryInterval
  }

  func setRealtimeRetryCount(_ retryCount: Int) {
    realtimeRetryCount = retryCount
    _userDefaultsManager.realtimeRetryCount = realtimeRetryCount
  }

  /// Returns the difference between the Realtime backoff end time and the current time in a
  /// NSTimeInterval format.
  @objc public func realtimeBackoffInterval() -> TimeInterval {
    let now = Date().timeIntervalSince1970
    return realtimeExponentialBackoffThrottleEndTime - now
  }

  /// Updates the metadata table with the current fetch status.
  /// @param fetchSuccess True if fetch was successful.
  @objc public func updateMetadata(withFetchSuccessStatus fetchSuccess: Bool,
                                   templateVersion: String?) {
    RCLog.debug("I-RCN000056", "Updating metadata with fetch result: \(fetchSuccess).")
    updateFetchTime(success: fetchSuccess)
    lastFetchStatus = fetchSuccess ? .success : .failure
    _lastFetchError = fetchSuccess ? .unknown : .internalError
    if fetchSuccess, let templateVersion {
      updateLastFetchTimeInterval(Date().timeIntervalSince1970)
      // Note: We expect the googleAppID to always be available.
      deviceContext = Device.remoteConfigDeviceContext(with: _googleAppID)
      lastFetchedTemplateVersion = templateVersion
      _userDefaultsManager.lastFetchedTemplateVersion = templateVersion
    }

    updateMetadataTable()
  }

  private func updateFetchTime(success: Bool) {
    let epochTimeInterval = Date().timeIntervalSince1970
    if success {
      _successFetchTimes.append(epochTimeInterval)
    } else {
      _failureFetchTimes.append(epochTimeInterval)
    }
  }

  private func updateMetadataTable() {
    _DBManager.deleteRecord(withBundleIdentifier: bundleIdentifier, namespace: _FIRNamespace)

    guard JSONSerialization.isValidJSONObject(_customVariables) else {
      RCLog.error("I-RCN000028", "Invalid custom variables to be serialized.")
      return
    }
    guard JSONSerialization.isValidJSONObject(deviceContext) else {
      RCLog.error("I-RCN000029", "Invalid device context to be serialized.")
      return
    }
    guard JSONSerialization.isValidJSONObject(_successFetchTimes) else {
      RCLog.error("I-RCN000031", "Invalid success fetch times to be serialized.")
      return
    }
    guard JSONSerialization.isValidJSONObject(_failureFetchTimes) else {
      RCLog.error("I-RCN000032", "Invalid failure fetch times to be serialized.")
      return
    }

    let serializedAppContext = try? JSONSerialization.data(withJSONObject: _customVariables,
                                                           options: [.prettyPrinted])
    let serializedDeviceContext = try? JSONSerialization.data(withJSONObject: deviceContext,
                                                              options: [.prettyPrinted])
    // The digestPerNamespace is not used and only meant for backwards DB compatibility.
    let serializedDigestPerNamespace = try? JSONSerialization.data(withJSONObject: [:],
                                                                   options: [.prettyPrinted])
    let serializedSuccessTime = try? JSONSerialization.data(withJSONObject: _successFetchTimes,
                                                            options: [.prettyPrinted])
    let serializedFailureTime = try? JSONSerialization.data(withJSONObject: _failureFetchTimes,
                                                            options: [.prettyPrinted])

    guard let serializedDigestPerNamespace = serializedDigestPerNamespace,
          let serializedDeviceContext = serializedDeviceContext,
          let serializedAppContext = serializedAppContext,
          let serializedSuccessTime = serializedSuccessTime,
          let serializedFailureTime = serializedFailureTime else {
      return
    }

    let columnNameToValue: [String: Any] = [
      RCNKeyBundleIdentifier: bundleIdentifier,
      RCNKeyNamespace: _FIRNamespace,
      RCNKeyFetchTime: lastFetchTimeInterval,
      RCNKeyDigestPerNamespace: serializedDigestPerNamespace,
      RCNKeyDeviceContext: serializedDeviceContext,
      RCNKeyAppContext: serializedAppContext,
      RCNKeySuccessFetchTime: serializedSuccessTime,
      RCNKeyFailureFetchTime: serializedFailureTime,
      RCNKeyLastFetchStatus: lastFetchStatus.rawValue,
      RCNKeyLastFetchError: _lastFetchError.rawValue,
      RCNKeyLastApplyTime: _lastApplyTimeInterval,
      RCNKeyLastSetDefaultsTime: _lastSetDefaultsTimeInterval,
    ]

    _DBManager.insertMetadataTable(withValues: columnNameToValue)
  }

  /// Update last active template version from last fetched template version.
  @objc public func updateLastActiveTemplateVersion() {
    lastActiveTemplateVersion = lastFetchedTemplateVersion
    _userDefaultsManager.lastActiveTemplateVersion = lastActiveTemplateVersion
  }

  // MARK: - Fetch Request

  /// Returns a fetch request with the latest device and config change.
  /// Whenever user issues a fetch api call, collect the latest request.
  /// - Parameter userProperties: User properties to set to config request.
  /// - Returns: Config fetch request string
  @objc public func nextRequest(withUserProperties userProperties: [String: Any]?) -> String {
    var request = "{"
    request += "app_instance_id:'\(configInstallationsIdentifier)'"
    request += ", app_instance_id_token:'\(configInstallationsToken ?? "")'"
    request += ", app_id:'\(_googleAppID)'"
    request += ", country_code:'\(Device.remoteConfigDeviceCountry())'"
    request += ", language_code:'\(Device.remoteConfigDeviceLocale())'"
    request += ", platform_version:'\(GULAppEnvironmentUtil.systemVersion())'"
    request += ", time_zone:'\(Device.remoteConfigTimezone())'"
    request += ", package_name:'\(bundleIdentifier)'"
    request += ", app_version:'\(Device.remoteConfigAppVersion())'"
    request += ", app_build:'\(Device.remoteConfigAppBuildVersion())'"
    request += ", sdk_version:'\(Device.remoteConfigPodVersion())'"

    if let userProperties, !userProperties.isEmpty {
      // Extract first open time from user properties and send as a separate field
      var remainingUserProperties = userProperties
      if let firstOpenTime = userProperties[kRCNAnalyticsFirstOpenTimePropertyName] as? NSNumber {
        let date = Date(timeIntervalSince1970: firstOpenTime.doubleValue / 1000)
        let formatter = ISO8601DateFormatter()
        let firstOpenTimeISOString = formatter.string(from: date)
        request += ", first_open_time:'\(firstOpenTimeISOString)'"

        remainingUserProperties.removeValue(forKey: kRCNAnalyticsFirstOpenTimePropertyName)
      }
      if !remainingUserProperties.isEmpty {
        do {
          let jsonData = try JSONSerialization.data(
            withJSONObject: remainingUserProperties,
            options: []
          )
          if let jsonString = String(data: jsonData, encoding: .utf8) {
            request += ", analytics_user_properties:\(jsonString)"
          }
        } catch {
          // Ignore JSON serialization error.
        }
      }
    }
    request += "}"
    return request
  }

  // MARK: - Getter/Setter

  /// The reason that last fetch failed.
  @objc public var lastFetchError: RemoteConfigError {
    get { _lastFetchError }
    set {
      _lastFetchError = newValue
      _DBManager
        .updateMetadata(
          withOption: .fetchStatus,
          namespace: _FIRNamespace,
          values: [lastFetchStatus, _lastFetchError]
        )
    }
  }

  private var _minimumFetchInterval: TimeInterval

  /// The time interval that config data stays fresh.
  @objc public var minimumFetchInterval: TimeInterval {
    get { _minimumFetchInterval }
    set { _minimumFetchInterval = max(0, newValue) }
  }

  private var _fetchTimeout: TimeInterval

  /// The timeout to set for outgoing fetch requests.
  @objc public var fetchTimeout: TimeInterval {
    get { _fetchTimeout }
    set {
      if newValue <= 0 {
        _fetchTimeout = RCNHTTPDefaultConnectionTimeout
      } else {
        _fetchTimeout = newValue
      }
    }
  }

  /// The time of last apply timestamp.
  @objc public var lastApplyTimeInterval: TimeInterval {
    get { _lastApplyTimeInterval }
    set {
      _lastApplyTimeInterval = newValue
      _DBManager
        .updateMetadata(withOption: .applyTime, namespace: _FIRNamespace, values: [newValue])
    }
  }

  /// The time of last setDefaults timestamp.
  @objc public var lastSetDefaultsTimeInterval: TimeInterval {
    get { _lastSetDefaultsTimeInterval }
    set {
      _lastSetDefaultsTimeInterval = newValue
      _DBManager.updateMetadata(
        withOption: .defaultTime,
        namespace: _FIRNamespace,
        values: [newValue]
      )
    }
  }

  // MARK: - Throttling

  /// Returns true if the last fetch is outside the minimum fetch interval supplied.
  @objc public func hasMinimumFetchIntervalElapsed(_ minimumFetchInterval: TimeInterval) -> Bool {
    if lastFetchTimeInterval == 0 {
      return true
    }

    // Check if last config fetch is within minimum fetch interval in seconds.
    let diffInSeconds = Date().timeIntervalSince1970 - lastFetchTimeInterval
    return diffInSeconds > minimumFetchInterval
  }

  /// Returns true if we are in exponential backoff mode and it is not yet the next request time.
  @objc public func shouldThrottle() -> Bool {
    let now = Date().timeIntervalSince1970
    return lastFetchTimeInterval > 0 && lastFetchStatus != .success &&
      exponentialBackoffThrottleEndTime - now > 0
  }
}
