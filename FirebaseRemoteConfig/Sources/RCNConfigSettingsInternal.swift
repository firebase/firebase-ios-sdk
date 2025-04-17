import Foundation
import FirebaseCore // For FIRLogger

// --- Placeholder Types ---
// These will be replaced by actual translated classes later.
typealias RCNConfigDBManager = AnyObject
// RCNUserDefaultsManager is now translated
typealias RCNDevice = AnyObject // Assuming RCNDevice provides static methods like RCNDevice.deviceCountry()

// --- Constants ---
// TODO: Move these to a central constants file
private enum Constants {
    // From RCNConfigSettings.m
    static let exponentialBackoffMinimumInterval: TimeInterval = 120 // 2 mins
    static let exponentialBackoffMaximumInterval: TimeInterval = 14400 // 4 hours (60 * 60 * 4)

    // From RCNConfigConstants.h (assuming defaults if not found elsewhere)
    static let defaultMinimumFetchInterval: TimeInterval = 43200.0 // 12 hours
    static let httpDefaultConnectionTimeout: TimeInterval = 60.0

    // Keys from RCNConfigDBManager.h (assuming)
    static let keyDeviceContext = "device_context"
    static let keyAppContext = "app_context"
    static let keySuccessFetchTime = "success_fetch_time"
    static let keyFailureFetchTime = "failure_fetch_time"
    static let keyLastFetchStatus = "last_fetch_status"
    static let keyLastFetchError = "last_fetch_error"
    static let keyLastApplyTime = "last_apply_time"
    static let keyLastSetDefaultsTime = "last_set_defaults_time"
    static let keyBundleIdentifier = "bundle_identifier"
    static let keyNamespace = "namespace"
    static let keyFetchTime = "fetch_time"
    static let keyDigestPerNamespace = "digest_per_namespace" // Backwards compat only

    // Keys from RCNUserDefaultsManager.h (assuming)
    // Define as needed when RCNUserDefaultsManager is translated

    // Keys from RCNConfigFetch.m (assuming) - for request body
    static let analyticsFirstOpenTimePropertyName = "_fot"
}

/// Enum to map RCNUpdateOption to Swift enum, primarily for DB interaction selectors
enum RCNUpdateOption: Int {
    case applyTime = 0
    case defaultTime = 1
}


/// Internal class containing settings, state, and metadata for a Remote Config instance.
/// Mirrors the Objective-C class RCNConfigSettings.
/// This class is intended for internal use within the FirebaseRemoteConfig module.
/// Note: This class is not inherently thread-safe for all properties.
/// The original Objective-C implementation relied on a serial dispatch queue (`_queue` in FIRRemoteConfig)
/// for synchronization when accessing instances of this class. Callers (like RemoteConfig.swift)
/// must ensure thread-safe access. Properties marked `atomic` in ObjC are handled here
/// using basic Swift atomicity or placeholders requiring external locking.
class RCNConfigSettingsInternal { // Not public

    // MARK: - Properties (Mirrored from RCNConfigSettings.h and .m)

    // Settable Public Settings
    var minimumFetchInterval: TimeInterval
    var fetchTimeout: TimeInterval

    // Readonly Properties (or internally set)
    let bundleIdentifier: String
    private(set) var successFetchTimes: [TimeInterval] // Equivalent to NSMutableArray
    private(set) var failureFetchTimes: [TimeInterval] // Equivalent to NSMutableArray
    private(set) var deviceContext: [String: Any] // Equivalent to NSMutableDictionary
    var customVariables: [String: Any] // Equivalent to NSMutableDictionary, settable internally

    private(set) var lastFetchStatus: RemoteConfigFetchStatus
    private(set) var lastFetchError: RemoteConfigError // Make sure RemoteConfigError enum is defined
    private(set) var lastApplyTimeInterval: TimeInterval
    private(set) var lastSetDefaultsTimeInterval: TimeInterval

    // Properties managed via RCNUserDefaultsManager
    // Use direct access via userDefaultsManager instance below
    var lastETag: String? {
        get { userDefaultsManager.lastETag }
        set { userDefaultsManager.lastETag = newValue }
    }
    var lastETagUpdateTime: TimeInterval {
        get { userDefaultsManager.lastETagUpdateTime }
        set { userDefaultsManager.lastETagUpdateTime = newValue }
    }
    var lastFetchTimeInterval: TimeInterval {
        get { userDefaultsManager.lastFetchTime }
        set { userDefaultsManager.lastFetchTime = newValue }
    }
    var lastFetchedTemplateVersion: String? { // Defaulted to "0" in RCNUserDefaultsManager getter if nil
        get { userDefaultsManager.lastFetchedTemplateVersion }
        set { userDefaultsManager.lastFetchedTemplateVersion = newValue }
    }
    var lastActiveTemplateVersion: String? { // Defaulted to "0" in RCNUserDefaultsManager getter if nil
        get { userDefaultsManager.lastActiveTemplateVersion }
        set { userDefaultsManager.lastActiveTemplateVersion = newValue }
    }
    var realtimeExponentialBackoffRetryInterval: TimeInterval {
        get { userDefaultsManager.currentRealtimeThrottlingRetryIntervalSeconds }
        set { userDefaultsManager.currentRealtimeThrottlingRetryIntervalSeconds = newValue }
    }
    var realtimeExponentialBackoffThrottleEndTime: TimeInterval {
        get { userDefaultsManager.realtimeThrottleEndTime }
        set { userDefaultsManager.realtimeThrottleEndTime = newValue }
    }
    var realtimeRetryCount: Int {
        get { userDefaultsManager.realtimeRetryCount }
        set { userDefaultsManager.realtimeRetryCount = newValue }
    }
    var customSignals: [String: String] { // Defaulted to [:] in RCNUserDefaultsManager getter if nil
        get { userDefaultsManager.customSignals }
        set { userDefaultsManager.customSignals = newValue }
    }

    // Throttling Properties
    var exponentialBackoffRetryInterval: TimeInterval // Not stored in userDefaults
    private(set) var exponentialBackoffThrottleEndTime: TimeInterval = 0 // Not stored in userDefaults

    // Installation ID and Token (marked atomic in ObjC)
    // Using basic String properties. Synchronization handled externally by RemoteConfig queue.
    var configInstallationsIdentifier: String?
    var configInstallationsToken: String?

    // Fetch In Progress Flag (marked atomic in ObjC)
    // Needs external synchronization (e.g., RemoteConfig queue)
    var isFetchInProgress: Bool = false

    // Dependencies (Placeholders - initialized in init)
    private let dbManager: RCNConfigDBManager
    private let userDefaultsManager: RCNUserDefaultsManager // Use actual translated class
    private let firebaseNamespace: String // Fully qualified (namespace:appName)
    private let googleAppID: String

    // MARK: - Initializer

    init(databaseManager: RCNConfigDBManager,
         namespace: String, // Fully qualified namespace
         firebaseAppName: String,
         googleAppID: String) {

        self.dbManager = databaseManager
        self.firebaseNamespace = namespace
        self.googleAppID = googleAppID

        // Bundle ID
        if let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty {
            self.bundleIdentifier = bundleID
        } else {
             self.bundleIdentifier = ""
             // TODO: Log warning: FIRLogNotice(kFIRLoggerRemoteConfig, @"I-RCN000038", ...)
        }

        // Initialize User Defaults Manager (Use actual translated init)
        self.userDefaultsManager = RCNUserDefaultsManager(appName: firebaseAppName, bundleID: bundleIdentifier, firebaseNamespace: namespace)

        // Check if DB is new and reset UserDefaults if needed
        // DB interaction still uses selector
        let isNewDB = self.dbManager.perform(#selector(RCNConfigDBManager.isNewDatabase))?.takeUnretainedValue() as? Bool ?? false
        if isNewDB {
             // TODO: Log notice: FIRLogNotice(kFIRLoggerRemoteConfig, @"I-RCN000072", ...)
             self.userDefaultsManager.resetUserDefaults() // Call actual method
        }

        // Initialize properties with default/loaded values
        self.minimumFetchInterval = Constants.defaultMinimumFetchInterval
        self.fetchTimeout = Constants.httpDefaultConnectionTimeout

        self.deviceContext = [:]
        self.customVariables = [:]
        self.successFetchTimes = []
        self.failureFetchTimes = []
        self.lastFetchStatus = .noFetchYet
        self.lastFetchError = .unknown // Assuming .unknown is 0 or default
        self.lastApplyTimeInterval = 0
        self.lastSetDefaultsTimeInterval = 0

        // Properties read from UserDefaults are now accessed via computed properties
        // self.lastFetchedTemplateVersion = self.userDefaultsManager.lastFetchedTemplateVersion
        // etc...

        // Initialize non-persistent state
        self.exponentialBackoffRetryInterval = Constants.exponentialBackoffMinimumInterval // Default start
        self.isFetchInProgress = false

        // Load persistent metadata from DB after initializing defaults
        // DB interaction still uses selector
        // This might overwrite some defaults like lastFetchStatus etc.
        self.loadConfigFromMetadataTable()

        // Note: lastETag, lastETagUpdateTime, lastFetchTimeInterval, customSignals are
        // also now handled by computed properties reading from userDefaultsManager.
    }

    // MARK: - UserDefaults Interaction (via RCNUserDefaultsManager)
    // Methods below are now simplified or removed as interaction happens via computed properties.

    // Setter updates UserDefaults directly via computed property setter
    func updateLastFetchTimeInterval(_ timeInterval: TimeInterval) {
        self.lastFetchTimeInterval = timeInterval
    }

    // Setter updates UserDefaults directly via computed property setter
    func updateLastFetchedTemplateVersion(_ version: String?) {
         self.lastFetchedTemplateVersion = version
    }

    // Setter updates UserDefaults directly via computed property setter
    func updateLastActiveTemplateVersionInUserDefaults(_ version: String?) {
         self.lastActiveTemplateVersion = version
    }

    // Setter updates UserDefaults directly via computed property setter
    func updateRealtimeExponentialBackoffRetryInterval(_ interval: TimeInterval) {
         self.realtimeExponentialBackoffRetryInterval = interval
    }

    // Setter updates UserDefaults directly via computed property setter
     func updateRealtimeThrottleEndTime(_ time: TimeInterval) {
         self.realtimeExponentialBackoffThrottleEndTime = time
     }

    // Setter updates UserDefaults directly via computed property setter
    func updateRealtimeRetryCount(_ count: Int) {
        self.realtimeRetryCount = count
    }

    // Setter updates UserDefaults directly via computed property setter
    func updateCustomSignals(_ signals: [String: String]) {
        self.customSignals = signals
    }

    // Internal setters for properties usually read from userDefaults
    func setLastETag(_ etag: String?) {
        let now = Date().timeIntervalSince1970
        // Set timestamp first, then etag via computed property setters
        self.lastETagUpdateTime = now
        self.lastETag = etag
    }


    // MARK: - Load/Save Metadata (DB Interaction via RCNConfigDBManager)

    @discardableResult
    func loadConfigFromMetadataTable() -> [String: Any]? {
        // DB Interaction - Keep selector
        // loadMetadataWithBundleIdentifier:namespace:
        guard let metadata = dbManager.perform(#selector(RCNConfigDBManager.loadMetadata(withBundleIdentifier:namespace:)),
                                                with: bundleIdentifier,
                                                with: firebaseNamespace)?.takeUnretainedValue() as? [String: Any]
        else {
            return nil
        }

        // Parse metadata dictionary and update self properties
        if let contextData = metadata[Constants.keyDeviceContext] as? Data,
           let contextDict = try? JSONSerialization.jsonObject(with: contextData) as? [String: Any] {
            self.deviceContext = contextDict
        }
        if let appContextData = metadata[Constants.keyAppContext] as? Data,
           let appContextDict = try? JSONSerialization.jsonObject(with: appContextData) as? [String: Any] {
            self.customVariables = appContextDict
        }
        if let successTimesData = metadata[Constants.keySuccessFetchTime] as? Data,
           let successTimesArray = try? JSONSerialization.jsonObject(with: successTimesData) as? [TimeInterval] {
             self.successFetchTimes = successTimesArray
        }
        if let failureTimesData = metadata[Constants.keyFailureFetchTime] as? Data,
           let failureTimesArray = try? JSONSerialization.jsonObject(with: failureTimesData) as? [TimeInterval] {
             self.failureFetchTimes = failureTimesArray
        }
        if let statusString = metadata[Constants.keyLastFetchStatus] as? String, let statusInt = Int(statusString), let status = RemoteConfigFetchStatus(rawValue: statusInt) {
            self.lastFetchStatus = status
        }
        if let errorString = metadata[Constants.keyLastFetchError] as? String, let errorInt = Int(errorString), let error = RemoteConfigError(rawValue: errorInt) {
            self.lastFetchError = error
        }
        if let applyTimeString = metadata[Constants.keyLastApplyTime] as? String, let applyTime = TimeInterval(applyTimeString) {
             self.lastApplyTimeInterval = applyTime
        } else if let applyTimeNum = metadata[Constants.keyLastApplyTime] as? NSNumber { // Handle potential NSNumber storage
             self.lastApplyTimeInterval = applyTimeNum.doubleValue
        }
         if let defaultTimeString = metadata[Constants.keyLastSetDefaultsTime] as? String, let defaultTime = TimeInterval(defaultTimeString) {
             self.lastSetDefaultsTimeInterval = defaultTime
         } else if let defaultTimeNum = metadata[Constants.keyLastSetDefaultsTime] as? NSNumber { // Handle potential NSNumber storage
             self.lastSetDefaultsTimeInterval = defaultTimeNum.doubleValue
         }
        // Note: Properties read from UserDefaults (e.g., lastFetchTimeInterval) are handled by computed properties now.

        return metadata
    }

    func updateMetadataTable() {
        // DB Interaction - Keep selector
        // deleteRecordWithBundleIdentifier:namespace:
         _ = dbManager.perform(#selector(RCNConfigDBManager.deleteRecord(withBundleIdentifier:namespace:)),
                               with: bundleIdentifier,
                               with: firebaseNamespace)

        // Serialize data - Requires properties to be valid for JSONSerialization
        guard let appContextData = try? JSONSerialization.data(withJSONObject: customVariables) else {
             // TODO: Log error: FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000028", ...)
             return
        }
        guard let deviceContextData = try? JSONSerialization.data(withJSONObject: deviceContext) else {
             // TODO: Log error: FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000029", ...)
             return
        }
         // Backward compat only
        guard let digestPerNamespaceData = try? JSONSerialization.data(withJSONObject: [:]) else { return }
        guard let successTimeData = try? JSONSerialization.data(withJSONObject: successFetchTimes) else {
             // TODO: Log error: FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000031", ...)
             return
        }
        guard let failureTimeData = try? JSONSerialization.data(withJSONObject: failureFetchTimes) else {
             // TODO: Log error: FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000032", ...)
             return
        }

        // Read lastFetchTimeInterval directly via computed property
        let columnNameToValue: [String: Any] = [
            Constants.keyBundleIdentifier: bundleIdentifier,
            Constants.keyNamespace: firebaseNamespace,
            Constants.keyFetchTime: self.lastFetchTimeInterval, // Read directly
            Constants.keyDigestPerNamespace: digestPerNamespaceData,
            Constants.keyDeviceContext: deviceContextData,
            Constants.keyAppContext: appContextData,
            Constants.keySuccessFetchTime: successTimeData,
            Constants.keyFailureFetchTime: failureTimeData,
            Constants.keyLastFetchStatus: String(lastFetchStatus.rawValue), // Store as String like ObjC
            Constants.keyLastFetchError: String(lastFetchError.rawValue), // Store as String like ObjC
            Constants.keyLastApplyTime: lastApplyTimeInterval, // Store as TimeInterval/Double
            Constants.keyLastSetDefaultsTime: lastSetDefaultsTimeInterval // Store as TimeInterval/Double
        ]

        // DB Interaction - Keep selector
        // insertMetadataTableWithValues:completionHandler:
        dbManager.perform(#selector(RCNConfigDBManager.insertMetadataTable(withValues:completionHandler:)),
                        with: columnNameToValue,
                        with: nil) // No completion handler in original call
    }

    // Specific update methods (used by FIRRemoteConfig setters)
    func updateLastApplyTimeIntervalInDB(_ timeInterval: TimeInterval) {
        self.lastApplyTimeInterval = timeInterval
        // DB Interaction - Keep selector
        // updateMetadataWithOption:namespace:values:completionHandler:
        dbManager.perform(#selector(RCNConfigDBManager.updateMetadata(withOption:namespace:values:completionHandler:)),
                        with: RCNUpdateOption.applyTime.rawValue, // Use enum raw value
                        with: firebaseNamespace,
                        with: [timeInterval],
                        with: nil)
    }

     func updateLastSetDefaultsTimeIntervalInDB(_ timeInterval: TimeInterval) {
         self.lastSetDefaultsTimeInterval = timeInterval
         // DB Interaction - Keep selector
         // updateMetadataWithOption:namespace:values:completionHandler:
         dbManager.perform(#selector(RCNConfigDBManager.updateMetadata(withOption:namespace:values:completionHandler:)),
                         with: RCNUpdateOption.defaultTime.rawValue, // Use enum raw value
                         with: firebaseNamespace,
                         with: [timeInterval],
                         with: nil)
     }


    // MARK: - State Update Methods

    func updateMetadataWithFetchSuccessStatus(_ fetchSuccess: Bool, templateVersion: String?) {
        // TODO: Log debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000056", ...)
        updateFetchTimeWithSuccessFetch(fetchSuccess)
        lastFetchStatus = fetchSuccess ? .success : .failure
        lastFetchError = fetchSuccess ? .unknown : .internalError // Assuming internalError for generic failure

        if fetchSuccess {
            updateLastFetchTimeInterval(Date().timeIntervalSince1970) // Updates UserDefaults via computed property
            // TODO: Get device context - Requires RCNDevice translation
            // deviceContext = FIRRemoteConfigDeviceContextWithProjectIdentifier(_googleAppID);
            deviceContext = getDeviceContextPlaceholder(projectID: googleAppID) // Placeholder call
            if let version = templateVersion {
                 updateLastFetchedTemplateVersion(version) // Updates UserDefaults via computed property
            }
        }

        updateMetadataTable() // DB Interaction - Keep selector usage within
    }

    func updateFetchTimeWithSuccessFetch(_ isSuccessfulFetch: Bool) {
        let epochTimeInterval = Date().timeIntervalSince1970
        if isSuccessfulFetch {
            successFetchTimes.append(epochTimeInterval)
        } else {
            failureFetchTimes.append(epochTimeInterval)
        }
        // Note: DB update happens in updateMetadataTable called by updateMetadataWithFetchSuccessStatus
    }

     func updateLastActiveTemplateVersion() {
         if let fetchedVersion = self.lastFetchedTemplateVersion { // Reads via computed property
             // Calls setter which updates UserDefaults and local cache
             updateLastActiveTemplateVersionInUserDefaults(fetchedVersion)
         }
     }

    // MARK: - Throttling Logic

    func updateExponentialBackoffTime() {
        if lastFetchStatus == .success {
             // TODO: Log Debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000057", @"Throttling: Entering exponential backoff mode.")
            exponentialBackoffRetryInterval = Constants.exponentialBackoffMinimumInterval
        } else {
             // TODO: Log Debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000057", @"Throttling: Updating throttling interval.")
            let doubledInterval = exponentialBackoffRetryInterval * 2
            exponentialBackoffRetryInterval = min(doubledInterval, Constants.exponentialBackoffMaximumInterval)
        }

        // Randomize +/- 50%
        let randomFactor = Double.random(in: -0.5...0.5)
        let randomizedRetryInterval = exponentialBackoffRetryInterval + (exponentialBackoffRetryInterval * randomFactor)
        exponentialBackoffThrottleEndTime = Date().timeIntervalSince1970 + randomizedRetryInterval
    }

     func updateRealtimeExponentialBackoffTime() {
         var currentRetryInterval = self.realtimeExponentialBackoffRetryInterval // Read via computed property
         if realtimeRetryCount == 0 {
              // TODO: Log Debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000058", @"Throttling: Entering exponential Realtime backoff mode.")
              currentRetryInterval = Constants.exponentialBackoffMinimumInterval
         } else {
              // TODO: Log Debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000058", @"Throttling: Updating Realtime throttling interval.")
              let doubledInterval = currentRetryInterval * 2
              currentRetryInterval = min(doubledInterval, Constants.exponentialBackoffMaximumInterval)
         }

         let randomFactor = Double.random(in: -0.5...0.5)
         let randomizedRetryInterval = currentRetryInterval + (currentRetryInterval * randomFactor)
         let newEndTime = Date().timeIntervalSince1970 + randomizedRetryInterval

         // Update UserDefaults via computed property setters
         self.realtimeThrottleEndTime = newEndTime
         self.realtimeExponentialBackoffRetryInterval = currentRetryInterval
     }

    func getRealtimeBackoffInterval() -> TimeInterval {
        let now = Date().timeIntervalSince1970
        let endTime = self.realtimeThrottleEndTime // Read directly via computed property
        let interval = endTime - now
        return max(0, interval) // Return 0 if end time is in the past
    }

    func shouldThrottle() -> Bool {
        // Check if not successful and backoff time is in the future
        let now = Date().timeIntervalSince1970
        return lastFetchStatus != .success && exponentialBackoffThrottleEndTime > now
    }

    func hasMinimumFetchIntervalElapsed(minimumInterval: TimeInterval) -> Bool {
        let lastFetch = self.lastFetchTimeInterval // Read directly via computed property
        if lastFetch <= 0 { return true } // No successful fetch yet

        let diffInSeconds = Date().timeIntervalSince1970 - lastFetch
        return diffInSeconds > minimumInterval
    }

    // MARK: - Fetch Request Body Construction

    func nextRequestWithUserProperties(_ userProperties: [String: Any]?) -> String? {
        // Ensure required IDs are present
        guard let installationsID = configInstallationsIdentifier,
              let installationsToken = configInstallationsToken,
              let appID = googleAppID else {
            // TODO: Log error?
            return nil
        }

        // Device Info - Keep selectors for RCNDevice
        // Assume RCNDevice is an NSObject subclass for perform(#selector(...))
        let countryCode = RCNDevice.perform(#selector(RCNDevice.deviceCountry))?.takeUnretainedValue() as? String ?? ""
        let languageCode = RCNDevice.perform(#selector(RCNDevice.deviceLocale))?.takeUnretainedValue() as? String ?? ""
        let platformVersion = RCNDevice.perform(#selector(RCNDevice.systemVersion))?.takeUnretainedValue() as? String ?? "" // GULAppEnvironmentUtil.systemVersion()
        let timeZone = RCNDevice.perform(#selector(RCNDevice.timezone))?.takeUnretainedValue() as? String ?? ""
        let appVersion = RCNDevice.perform(#selector(RCNDevice.appVersion))?.takeUnretainedValue() as? String ?? ""
        let appBuild = RCNDevice.perform(#selector(RCNDevice.appBuildVersion))?.takeUnretainedValue() as? String ?? ""
        let sdkVersion = RCNDevice.perform(#selector(RCNDevice.podVersion))?.takeUnretainedValue() as? String ?? "" // Renamed selector assuming podVersion exists


        var components: [String: String] = [
            "app_instance_id": "'\(installationsID)'",
            "app_instance_id_token": "'\(installationsToken)'",
            "app_id": "'\(appID)'",
            "country_code": "'\(countryCode)'",
            "language_code": "'\(languageCode)'",
            "platform_version": "'\(platformVersion)'",
            "time_zone": "'\(timeZone)'",
            "package_name": "'\(bundleIdentifier)'",
            "app_version": "'\(appVersion)'",
            "app_build": "'\(appBuild)'",
            "sdk_version": "'\(sdkVersion)'"
        ]

        var analyticsProperties = userProperties ?? [:]

        // Handle first open time
        if let firstOpenTimeNum = analyticsProperties[Constants.analyticsFirstOpenTimePropertyName] as? NSNumber {
            let firstOpenTimeSeconds = firstOpenTimeNum.doubleValue / 1000.0
            let date = Date(timeIntervalSince1970: firstOpenTimeSeconds)
            let formatter = ISO8601DateFormatter() // Swift equivalent
            components["first_open_time"] = "'\(formatter.string(from: date))'"
            analyticsProperties.removeValue(forKey: Constants.analyticsFirstOpenTimePropertyName)
        }

        // Add remaining analytics properties
        if !analyticsProperties.isEmpty {
            if let jsonData = try? JSONSerialization.data(withJSONObject: analyticsProperties),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                 components["analytics_user_properties"] = jsonString // No extra quotes needed? Check ObjC impl string format
            }
        }

         // Add custom signals
         let currentCustomSignals = self.customSignals // Read directly via computed property
         if !currentCustomSignals.isEmpty {
             if let jsonData = try? JSONSerialization.data(withJSONObject: currentCustomSignals),
                let jsonString = String(data: jsonData, encoding: .utf8) {
                 components["custom_signals"] = jsonString // No extra quotes needed? Check ObjC impl string format
                  // TODO: Log Debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000078", ...)
             }
         }

        // Construct final string - Requires careful formatting to match ObjC exactly
        let bodyString = components.map { key, value in "\(key):\(value)" }.joined(separator: ", ")
        return "{\(bodyString)}"
    }

    // MARK: - Placeholder Helpers
    private func getDeviceContextPlaceholder(projectID: String) -> [String: Any] {
        // TODO: Replace with actual call to translated RCNDevice function
        return ["project_id": projectID] // Minimal placeholder
    }

    // MARK: - Placeholder Selectors for Dependencies
    // Selectors for DB Manager (kept as placeholder)
    @objc private func isNewDatabase() -> Bool { return false }
    @objc private func loadMetadata(withBundleIdentifier id: String, namespace ns: String) -> [String: Any]? { return nil }
    @objc private func deleteRecord(withBundleIdentifier id: String, namespace ns: String) {}
    @objc private func insertMetadataTable(withValues values: [String: Any], completionHandler handler: Any?) {} // Handler is optional block
    @objc private func updateMetadata(withOption option: Int, namespace ns: String, values: [Any], completionHandler handler: Any?) {} // Handler is optional block

    // RCNDevice selectors (static methods)
    // Keep these until RCNDevice is translated
    @objc private static func deviceCountry() -> String { return "" }
    @objc private static func deviceLocale() -> String { return "" }
    @objc private static func systemVersion() -> String { return "" } // GULAppEnvironmentUtil
    @objc private static func timezone() -> String { return "" }
    @objc private static func appVersion() -> String { return "" }
    @objc private static func appBuildVersion() -> String { return "" }
    @objc private static func podVersion() -> String { return "" } // FIRRemoteConfigPodVersion
}

// Extension providing @objc methods for RemoteConfig.swift to call
// This is still needed as RemoteConfig uses selectors for DB updates via these methods
extension RCNConfigSettingsInternal {
    // Properties accessed directly by RemoteConfig.swift do not need @objc methods here
    // (e.g., lastFetchTimeInterval, lastFetchStatus, minimumFetchInterval, fetchTimeout,
    // lastETagUpdateTime, lastApplyTimeInterval, lastActiveTemplateVersion)

    // Keep methods that involve DB interaction selectors
    @objc func updateLastApplyTimeIntervalInDB(_ interval: TimeInterval) {
        updateLastApplyTimeIntervalInDB(interval) // Calls internal func with DB selector call
    }

    @objc func updateLastSetDefaultsTimeIntervalInDB(_ interval: TimeInterval) {
        updateLastSetDefaultsTimeIntervalInDB(interval) // Calls internal func with DB selector call
    }

    @objc func updateLastActiveTemplateVersion() { // Matches selector used in RemoteConfig.activate
        updateLastActiveTemplateVersion() // Calls internal func that updates property & UserDefaults
    }
}
