import Foundation
import FirebaseCore // For FIRLogger

// TODO: Move keys to a central constants file
private enum UserDefaultsKeys {
    static let lastETag = "lastETag"
    static let lastETagUpdateTime = "lastETagUpdateTime"
    static let lastSuccessfulFetchTime = "lastSuccessfulFetchTime"
    static let lastFetchStatus = "lastFetchStatus" // Note: This seems unused in RCNConfigSettingsInternal read path
    static let isClientThrottled = "isClientThrottledWithExponentialBackoff"
    static let throttleEndTime = "throttleEndTime"
    static let currentThrottlingRetryInterval = "currentThrottlingRetryInterval"
    static let realtimeThrottleEndTime = "throttleRealtimeEndTime"
    static let currentRealtimeThrottlingRetryInterval = "currentRealtimeThrottlingRetryInterval"
    static let realtimeRetryCount = "realtimeRetryCount"
    static let lastFetchedTemplateVersion = "fetchTemplateVersion" // From RCNConfigConstants? Check key name
    static let lastActiveTemplateVersion = "activeTemplateVersion" // From RCNConfigConstants? Check key name
    static let customSignals = "customSignals"

    // Grouping constants from ObjC implementation
    static let groupPrefix = "group"
    static let groupSuffix = "firebase"

}


/// Wraps UserDefaults to provide scoped, thread-safe access for Remote Config settings.
class RCNUserDefaultsManager {

    private let userDefaults: UserDefaults
    private let firebaseAppName: String
    private let firebaseNamespace: String // Just the namespace part (e.g., "firebase")
    private let bundleIdentifier: String
    private let lock = NSLock() // Lock for synchronizing writes

    // MARK: - Initialization

    /// Designated initializer.
    init(appName: String, bundleID: String, firebaseNamespace qualifiedNamespace: String) {
        self.firebaseAppName = appName
        self.bundleIdentifier = bundleID

        // Extract namespace part from "namespace:appName"
        if let range = qualifiedNamespace.range(of: ":") {
             self.firebaseNamespace = String(qualifiedNamespace[..<range.lowerBound])
        } else {
             // TODO: Log error - Namespace not fully qualified
             print("Error: Namespace '\(qualifiedNamespace)' is not fully qualified.")
             self.firebaseNamespace = qualifiedNamespace // Use as is, might cause issues
        }

        // Get shared UserDefaults instance for the app group derived from bundle ID
        self.userDefaults = RCNUserDefaultsManager.sharedUserDefaults(forBundleIdentifier: bundleID)
    }

    // MARK: - Static Methods for Shared UserDefaults

    private static func userDefaultsSuiteName(forBundleIdentifier bundleIdentifier: String) -> String {
        // Ensure bundleIdentifier is not empty? ObjC didn't check here.
        return "\(UserDefaultsKeys.groupPrefix).\(bundleIdentifier).\(UserDefaultsKeys.groupSuffix)"
    }

    private static func sharedUserDefaults(forBundleIdentifier bundleIdentifier: String) -> UserDefaults {
        // This mimics dispatch_once behavior implicitly through static initialization in Swift >= 1.2
        struct Static {
            static let instance = UserDefaults(suiteName: userDefaultsSuiteName(forBundleIdentifier: bundleIdentifier)) ?? UserDefaults.standard // Fallback unlikely needed
        }
        return Static.instance
    }

    // MARK: - Scoped Key Path

    /// Generates the key path for accessing the setting within UserDefaults: AppName.Namespace.Key
    private func scopedKeyPath(forKey key: String) -> String {
        return "\(firebaseAppName).\(firebaseNamespace).\(key)"
    }

    // MARK: - Read/Write Helpers (with locking)

    private func readValue<T>(forKey key: String) -> T? {
        // Reading UserDefaults is thread-safe, no lock needed technically,
        // but ObjC implementation read inside @synchronized block indirectly via instanceUserDefaults.
        // Let's keep reads simple for now.
        return userDefaults.value(forKeyPath: scopedKeyPath(forKey: key)) as? T
    }

    private func writeValue(_ value: Any?, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }

        // We need to read the current app dictionary, then the namespace dictionary,
        // modify it, and write the whole app dictionary back. This mimics the ObjC logic.

        let appKey = firebaseAppName
        let namespaceKey = firebaseNamespace
        let settingKey = key

        var appDict = userDefaults.dictionary(forKey: appKey) ?? [:]
        var namespaceDict = appDict[namespaceKey] as? [String: Any] ?? [:]

        if let newValue = value {
            namespaceDict[settingKey] = newValue
        } else {
            namespaceDict.removeValue(forKey: settingKey) // Remove if value is nil
        }

        appDict[namespaceKey] = namespaceDict // Put potentially modified namespace dict back
        userDefaults.set(appDict, forKey: appKey) // Write the whole app dict back

        // Mimic explicit synchronize call, though often discouraged in Swift.
        // Required for potential app extension communication relying on it.
        userDefaults.synchronize()
    }


    // MARK: - Public Properties (Computed)

    var lastETag: String? {
        get { readValue(forKey: UserDefaultsKeys.lastETag) }
        set { writeValue(newValue, forKey: UserDefaultsKeys.lastETag) }
    }

    var lastETagUpdateTime: TimeInterval {
        get { readValue(forKey: UserDefaultsKeys.lastETagUpdateTime) ?? 0.0 }
        set { writeValue(newValue, forKey: UserDefaultsKeys.lastETagUpdateTime) }
    }

    var lastFetchTime: TimeInterval {
         get { readValue(forKey: UserDefaultsKeys.lastSuccessfulFetchTime) ?? 0.0 }
         set { writeValue(newValue, forKey: UserDefaultsKeys.lastSuccessfulFetchTime) }
     }

     // lastFetchStatus seems unused internally for read, only written? Keep setter for now.
     // var lastFetchStatus: String? {
     //     get { readValue(forKey: UserDefaultsKeys.lastFetchStatus) }
     //     set { writeValue(newValue, forKey: UserDefaultsKeys.lastFetchStatus) }
     // }

     var isClientThrottledWithExponentialBackoff: Bool {
         get { readValue(forKey: UserDefaultsKeys.isClientThrottled) ?? false }
         set { writeValue(newValue, forKey: UserDefaultsKeys.isClientThrottled) }
     }

     var throttleEndTime: TimeInterval {
         get { readValue(forKey: UserDefaultsKeys.throttleEndTime) ?? 0.0 }
         set { writeValue(newValue, forKey: UserDefaultsKeys.throttleEndTime) }
     }

     var currentThrottlingRetryIntervalSeconds: TimeInterval {
         get { readValue(forKey: UserDefaultsKeys.currentThrottlingRetryInterval) ?? 0.0 }
         set { writeValue(newValue, forKey: UserDefaultsKeys.currentThrottlingRetryInterval) }
     }

     var realtimeThrottleEndTime: TimeInterval {
         get { readValue(forKey: UserDefaultsKeys.realtimeThrottleEndTime) ?? 0.0 }
         set { writeValue(newValue, forKey: UserDefaultsKeys.realtimeThrottleEndTime) }
     }

     var currentRealtimeThrottlingRetryIntervalSeconds: TimeInterval {
          get { readValue(forKey: UserDefaultsKeys.currentRealtimeThrottlingRetryInterval) ?? 0.0 }
          set { writeValue(newValue, forKey: UserDefaultsKeys.currentRealtimeThrottlingRetryInterval) }
      }

      var realtimeRetryCount: Int {
           get { readValue(forKey: UserDefaultsKeys.realtimeRetryCount) ?? 0 }
           set { writeValue(newValue, forKey: UserDefaultsKeys.realtimeRetryCount) }
       }

     var lastFetchedTemplateVersion: String? { // Defaulted to "0" in ObjC getter if nil
         get { readValue(forKey: UserDefaultsKeys.lastFetchedTemplateVersion) ?? "0" }
         set { writeValue(newValue, forKey: UserDefaultsKeys.lastFetchedTemplateVersion) }
     }

     var lastActiveTemplateVersion: String? { // Defaulted to "0" in ObjC getter if nil
         get { readValue(forKey: UserDefaultsKeys.lastActiveTemplateVersion) ?? "0" }
         set { writeValue(newValue, forKey: UserDefaultsKeys.lastActiveTemplateVersion) }
     }

     var customSignals: [String: String] {
         get { readValue(forKey: UserDefaultsKeys.customSignals) ?? [:] } // Default to empty dict
         set { writeValue(newValue, forKey: UserDefaultsKeys.customSignals) }
     }


    // MARK: - Public Methods

    /// Delete all saved user defaults for this instance (App Name + Namespace scope).
    func resetUserDefaults() {
        lock.lock()
        defer { lock.unlock() }

        let appKey = firebaseAppName
        let namespaceKey = firebaseNamespace

        var appDict = userDefaults.dictionary(forKey: appKey) ?? [:]
        appDict.removeValue(forKey: namespaceKey) // Remove the namespace dict

        if appDict.isEmpty {
             userDefaults.removeObject(forKey: appKey) // Remove app dict if empty
        } else {
             userDefaults.set(appDict, forKey: appKey) // Write back modified app dict
        }

        userDefaults.synchronize()
    }

    // MARK: - Placeholder Selectors (for @objc calls from RCNConfigSettingsInternal)
    // These allow RCNConfigSettingsInternal to call this Swift class via selectors
    // until RCNConfigSettingsInternal is updated to call Swift methods directly.

    @objc func lastETagObjc() -> String? { return lastETag }
    @objc func setLastETagObjc(_ etag: String?) { lastETag = etag }

    @objc func lastETagUpdateTimeObjc() -> TimeInterval { return lastETagUpdateTime }
    @objc func setLastETagUpdateTimeObjc(_ time: TimeInterval) { lastETagUpdateTime = time }

    @objc func lastFetchTimeObjc() -> TimeInterval { return lastFetchTime }
    @objc func setLastFetchTimeObjc(_ time: TimeInterval) { lastFetchTime = time }

    // No getter for lastFetchStatus needed?
    // @objc func setLastFetchStatusObjc(_ status: String?) { lastFetchStatus = status }

    @objc func isClientThrottledWithExponentialBackoffObjc() -> Bool { return isClientThrottledWithExponentialBackoff }
    @objc func setIsClientThrottledWithExponentialBackoffObjc(_ throttled: Bool) { isClientThrottledWithExponentialBackoff = throttled }

    @objc func throttleEndTimeObjc() -> TimeInterval { return throttleEndTime }
    @objc func setThrottleEndTimeObjc(_ time: TimeInterval) { throttleEndTime = time }

    @objc func currentThrottlingRetryIntervalSecondsObjc() -> TimeInterval { return currentThrottlingRetryIntervalSeconds }
    @objc func setCurrentThrottlingRetryIntervalSecondsObjc(_ interval: TimeInterval) { currentThrottlingRetryIntervalSeconds = interval }

    @objc func realtimeThrottleEndTimeObjc() -> TimeInterval { return realtimeThrottleEndTime }
    @objc func setRealtimeThrottleEndTimeObjc(_ time: TimeInterval) { realtimeThrottleEndTime = time }

    @objc func currentRealtimeThrottlingRetryIntervalSecondsObjc() -> TimeInterval { return currentRealtimeThrottlingRetryIntervalSeconds }
    @objc func setCurrentRealtimeThrottlingRetryIntervalSecondsObjc(_ interval: TimeInterval) { currentRealtimeThrottlingRetryIntervalSeconds = interval }

    @objc func realtimeRetryCountObjc() -> Int { return realtimeRetryCount }
    @objc func setRealtimeRetryCountObjc(_ count: Int) { realtimeRetryCount = count }

    @objc func lastFetchedTemplateVersionObjc() -> String? { return lastFetchedTemplateVersion }
    @objc func setLastFetchedTemplateVersionObjc(_ version: String?) { lastFetchedTemplateVersion = version }

    @objc func lastActiveTemplateVersionObjc() -> String? { return lastActiveTemplateVersion }
    @objc func setLastActiveTemplateVersionObjc(_ version: String?) { lastActiveTemplateVersion = version }

    @objc func customSignalsObjc() -> [String: String]? { return customSignals }
    @objc func setCustomSignalsObjc(_ signals: [String: String]?) { customSignals = signals ?? [:] }

    @objc func resetUserDefaultsObjc() { resetUserDefaults() }

}

// Temporary placeholder for RemoteConfigSource enum if not defined elsewhere yet
//@objc(FIRRemoteConfigSource) public enum RemoteConfigSource: Int { case remote, defaultValue, staticValue }
