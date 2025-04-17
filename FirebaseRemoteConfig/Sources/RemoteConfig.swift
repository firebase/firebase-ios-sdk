import Foundation
import FirebaseCore // For FIROptions, FIRApp, FIRAnalyticsInterop, etc.
// TODO: Import necessary modules like FirebaseInstallations if needed after translation

// Placeholder types for internal Objective-C classes until they are translated
// Keep DBManager placeholder if translation was skipped
typealias RCNConfigContent = AnyObject
typealias RCNConfigDBManager = AnyObject
// RCNConfigSettingsInternal is now translated
typealias RCNConfigFetch = AnyObject
typealias RCNConfigExperiment = AnyObject
typealias RCNConfigRealtime = AnyObject
typealias FIRAnalyticsInterop = AnyObject // Assuming FIRAnalyticsInterop is ObjC protocol
typealias FIRExperimentController = AnyObject // Placeholder
// Define RemoteConfigSource enum based on previous translation
@objc(FIRRemoteConfigSource) public enum RemoteConfigSource: Int {
  case remote = 0
  case defaultValue = 1
  case staticValue = 2
}
// Define RemoteConfigValue based on previous translation (simplified for context)
@objc(FIRRemoteConfigValue) public class RemoteConfigValue: NSObject, NSCopying {
    let valueData: Data
    let source: RemoteConfigSource
    init(data: Data, source: RemoteConfigSource) {
        self.valueData = data; self.source = source; super.init()
    }
    override convenience init() { self.init(data: Data(), source: .staticValue) }
    @objc public func copy(with zone: NSZone? = nil) -> Any { return self }
    // Add properties like stringValue, boolValue etc. if needed by selectors below
    @objc public var stringValue: String { String(data: valueData, encoding: .utf8) ?? "" } // Placeholder implementation
    @objc public var numberValue: NSNumber { NSNumber(value: Double(stringValue) ?? 0.0) } // Placeholder
    @objc public var dataValue: Data { valueData } // Placeholder
    @objc public var boolValue: Bool { false } // Placeholder
    @objc public var jsonValue: Any? { nil } // Placeholder
}


// Constants mirroring Objective-C defines (move to a constants file later?)
let defaultMinimumFetchInterval: TimeInterval = 43200.0 // 12 hours
let defaultFetchTimeout: TimeInterval = 60.0
struct RemoteConfigConstants {
    static let errorDomain = "com.google.remoteconfig.ErrorDomain"
    static let remoteConfigActivateNotification = Notification.Name("FIRRemoteConfigActivateNotification")
    static let appNameKey = "FIRAppNameKey" // Assuming kFIRAppNameKey maps to this
    static let googleMobilePlatformNamespace = "firebase" // Placeholder for FIRNamespaceGoogleMobilePlatform
}

// TODO: Define RemoteConfigFetchStatus, RemoteConfigFetchAndActivateStatus, RemoteConfigError enums
@objc(FIRRemoteConfigFetchStatus) public enum RemoteConfigFetchStatus: Int {
    case noFetchYet = 0
    case success = 1
    case failure = 2
    case throttled = 3
}
@objc(FIRRemoteConfigFetchAndActivateStatus) public enum RemoteConfigFetchAndActivateStatus: Int {
    case successFetchedFromRemote = 0
    case successUsingPreFetchedData = 1
    case error = 2
}
@objc(FIRRemoteConfigError) public enum RemoteConfigError: Int {
    case unknown = 8001
    case throttled = 8002
    case internalError = 8003
}

/// Firebase Remote Config class.
@objc(FIRRemoteConfig)
public class RemoteConfig: NSObject {

    // --- Properties ---
    private let configContent: RCNConfigContent
    private let dbManager: RCNConfigDBManager
    private let settingsInternal: RCNConfigSettingsInternal // Use actual translated class
    private let configFetch: RCNConfigFetch
    private let configExperiment: RCNConfigExperiment
    private let configRealtime: RCNConfigRealtime
    private static let sharedQueue = DispatchQueue(label: "com.google.firebase.remoteconfig.serial")
    private let queue: DispatchQueue = RemoteConfig.sharedQueue

    private let appName: String
    private let firebaseNamespace: String // Fully qualified namespace (namespace:appName)

    @objc public var lastFetchTime: Date? {
        var fetchTimeInterval: TimeInterval = 0
        // Access directly via userDefaultsManager used by settingsInternal
        queue.sync {
           fetchTimeInterval = self.settingsInternal.lastFetchTimeInterval
        }
        return fetchTimeInterval > 0 ? Date(timeIntervalSince1970: fetchTimeInterval) : nil
    }

    @objc public var lastFetchStatus: RemoteConfigFetchStatus {
         var status: RemoteConfigFetchStatus = .noFetchYet
         // Access internal settings property safely on the queue
         queue.sync {
           status = self.settingsInternal.lastFetchStatus
         }
         return status
    }

    @objc public var configSettings: RemoteConfigSettings {
        get {
            let currentSettings = RemoteConfigSettings()
            // Access internal settings properties safely on the queue
            queue.sync {
                currentSettings.minimumFetchInterval = self.settingsInternal.minimumFetchInterval
                currentSettings.fetchTimeout = self.settingsInternal.fetchTimeout
            }
            // TODO: Log debug message? FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000066", ...)
            return currentSettings
        }
        set {
            // Update internal settings properties safely on the queue
            queue.async { // Use async for setter as ObjC does
                self.settingsInternal.minimumFetchInterval = newValue.minimumFetchInterval
                self.settingsInternal.fetchTimeout = newValue.fetchTimeout

                // TODO: Recreate network session if needed
                // This likely involves calling a method on the (translated) configFetch object
                 _ = self.configFetch.perform(#selector(RCNConfigFetch.recreateNetworkSession))

                // TODO: Log debug message? FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000067", ...)
            }
        }
    }

     @objc(remoteConfig)
     public static func remoteConfig() -> RemoteConfig { return FIRRemoteConfig.remoteConfig() } // Bridge
     @objc(remoteConfigWithApp:)
     public static func remoteConfig(app: FirebaseApp) -> RemoteConfig { return FIRRemoteConfig.remoteConfig(with: app) } // Bridge


    init(appName: String, options: FIROptions, namespace: String, dbManager: RCNConfigDBManager, configContent: RCNConfigContent, analytics: FIRAnalyticsInterop?) {
        self.appName = appName
        self.firebaseNamespace = "\(namespace):\(appName)" // Corrected namespace format
        self.dbManager = dbManager
        self.configContent = configContent

        // Initialize RCNConfigSettingsInternal (Use actual translated init)
        // Pass dbManager placeholder, namespace, appName, options.googleAppID
        // Note: options.googleAppID might be optional, handle nil case
        self.settingsInternal = RCNConfigSettingsInternal(databaseManager: dbManager, namespace: self.firebaseNamespace, firebaseAppName: appName, googleAppID: options.googleAppID ?? "")

        // Initialize RCNConfigExperiment (Placeholder - requires translation)
         // let experimentController = FIRExperimentController.sharedInstance() // Requires FIRExperimentController translation
         self.configExperiment = RCNConfigExperiment() // Placeholder

        // Initialize RCNConfigFetch (Placeholder - requires translation)
        self.configFetch = RCNConfigFetch() // Placeholder

        // Initialize RCNConfigRealtime (Placeholder - requires translation)
        self.configRealtime = RCNConfigRealtime() // Placeholder

        super.init()
    }
     @available(*, unavailable, message: "Use RemoteConfig.remoteConfig() static method instead.")
     public override init() { fatalError("Use RemoteConfig.remoteConfig() static method instead.") }

    @objc(ensureInitializedWithCompletionHandler:)
    public func ensureInitialized(completionHandler: @escaping @Sendable (Error?) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            var initializationSuccessful = false
            // Keep using selector for untranslated RCNConfigContent
            let successValue = self.configContent.perform(#selector(getter: RCNConfigContent.initializationSuccessful))?.takeUnretainedValue() as? Bool
            initializationSuccessful = successValue ?? false
            var error: Error? = nil
            if !initializationSuccessful {
                error = NSError(domain: RemoteConfigConstants.errorDomain, code: RemoteConfigError.internalError.rawValue, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for database load."])
            }
            completionHandler(error)
        }
    }


    // --- Fetch & Activate Methods ---
    @objc(fetchWithCompletionHandler:)
    public func fetch(completionHandler: ((RemoteConfigFetchStatus, Error?) -> Void)? = nil) {
        queue.async {
            // Use direct access to settingsInternal property
            let expirationDuration = self.settingsInternal.minimumFetchInterval
            self.fetch(withExpirationDuration: expirationDuration, completionHandler: completionHandler)
        }
     }
    @objc(fetchWithExpirationDuration:completionHandler:)
    public func fetch(withExpirationDuration expirationDuration: TimeInterval, completionHandler: ((RemoteConfigFetchStatus, Error?) -> Void)? = nil) {
        // Keep using selector for untranslated RCNConfigFetch
        _ = configFetch.perform(#selector(RCNConfigFetch.fetchConfig(withExpirationDuration:completionHandler:)),
                                with: expirationDuration, with: completionHandler as Any?)
    }
    @objc(activateWithCompletion:)
    public func activate(completion: ((Bool, Error?) -> Void)? = nil) {
         queue.async { [weak self] in
             guard let self = self else {
                  completion?(false, NSError(domain: RemoteConfigConstants.errorDomain, code: RemoteConfigError.internalError.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error activating config: Instance deallocated."]))
                  return
             }
             // Use direct access for settingsInternal properties
             // Check if the last fetched config has already been activated.
             if self.settingsInternal.lastETagUpdateTime <= 0 || self.settingsInternal.lastETagUpdateTime <= self.settingsInternal.lastApplyTimeInterval {
                  // TODO: Log debug message? FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000069", ...)
                  DispatchQueue.global().async { completion?(false, nil) } // Match ObjC global queue dispatch
                  return
             }

             // Keep selectors for untranslated RCNConfigContent
             let fetchedConfigDict = self.configContent.perform(#selector(getter: RCNConfigContent.fetchedConfig))?.takeUnretainedValue() as? NSDictionary
             _ = self.configContent.perform(#selector(RCNConfigContent.copyFromDictionary(_:toSource:forNamespace:)), with: fetchedConfigDict, with: 1 /* Active */, with: self.firebaseNamespace)

             // Update last apply time via settingsInternal method (interacts with DB placeholder)
             let now = Date().timeIntervalSince1970
             self.settingsInternal.updateLastApplyTimeIntervalInDB(now)

             // TODO: Log debug message? FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000069", @"Config activated.")

             // Keep selector for untranslated RCNConfigContent
             _ = self.configContent.perform(#selector(RCNConfigContent.activatePersonalization))

             // Update last active template version via settingsInternal method
             self.settingsInternal.updateLastActiveTemplateVersion()

             // Keep selector for untranslated RCNConfigContent for rollout activation
             let rolloutCompletion: @convention(block) (Bool) -> Void = { success in
                 if success {
                    // Use actual property for version, keep selector for metadata
                    let activeMetadata = self.configContent.perform(#selector(getter: RCNConfigContent.activeRolloutMetadata))?.takeUnretainedValue() as? NSArray // Placeholder type
                    let versionNumber = self.settingsInternal.lastActiveTemplateVersion // Use actual property
                    // TODO: Call notifyRolloutsStateChange - Requires translation
                 }
             }
             _ = self.configContent.perform(#selector(RCNConfigContent.activateRolloutMetadata(_:)), with: rolloutCompletion as Any?)

             let namespacePrefix = self.firebaseNamespace.components(separatedBy: ":").first ?? ""
             if namespacePrefix == RemoteConfigConstants.googleMobilePlatformNamespace {
                  DispatchQueue.main.async { self.notifyConfigHasActivated() } // Match ObjC main queue dispatch
                  // Keep selector for untranslated RCNConfigExperiment
                  let experimentCompletion: @convention(block) (Error?) -> Void = { error in DispatchQueue.global().async { completion?(true, error) } } // Match ObjC global queue dispatch
                   _ = self.configExperiment.perform(#selector(RCNConfigExperiment.updateExperiments(handler:)), with: experimentCompletion as Any?)
             } else {
                  DispatchQueue.global().async { completion?(true, nil) } // Match ObjC global queue dispatch
             }
         }
     }
    @objc(fetchAndActivateWithCompletionHandler:)
    public func fetchAndActivate(completionHandler: ((RemoteConfigFetchAndActivateStatus, Error?) -> Void)? = nil) {
        self.fetch { [weak self] status, error in
            guard let self = self else { return }
            if status == .success, error == nil {
                self.activate { changed, activateError in
                    if let activateError = activateError {
                         completionHandler?(.error, activateError)
                    } else {
                         completionHandler?(.successUsingPreFetchedData, nil) // Match ObjC
                    }
                }
            } else {
                 let fetchError = error ?? NSError(domain: RemoteConfigConstants.errorDomain, code: RemoteConfigError.internalError.rawValue, userInfo: [NSLocalizedDescriptionKey: "Fetch failed with status: \(status.rawValue)"])
                 completionHandler?(.error, fetchError)
            }
        }
    }
    private func notifyConfigHasActivated() {
        guard !self.appName.isEmpty else { return }
        let appInfoDict = [RemoteConfigConstants.appNameKey: self.appName]
        NotificationCenter.default.post(name: RemoteConfigConstants.remoteConfigActivateNotification, object: self, userInfo: appInfoDict)
    }


    // --- Get Config Methods ---
    @objc public subscript(key: String) -> RemoteConfigValue {
        return configValue(forKey: key)
    }

    @objc(configValueForKey:)
    public func configValue(forKey key: String?) -> RemoteConfigValue {
        guard let key = key, !key.isEmpty else {
            return RemoteConfigValue(data: Data(), source: .staticValue)
        }

        return queue.sync { [weak self] () -> RemoteConfigValue in
            guard let self = self else {
                 return RemoteConfigValue(data: Data(), source: .staticValue)
            }

            // Keep selectors for untranslated RCNConfigContent
            let activeConfig = self.configContent.perform(#selector(getter: RCNConfigContent.activeConfig))?.takeUnretainedValue() as? [String: [String: RemoteConfigValue]]

            if let value = activeConfig?[self.firebaseNamespace]?[key] {
                // TODO: Check value.source == .remote? Log error?
                // TODO: Call listeners?
                return value
            }

            // Call local defaultValue(forKey:) method
            let defaultValue = self.defaultValue(forKey: key)
            return defaultValue ?? RemoteConfigValue(data: Data(), source: .staticValue)
        }
    }

    @objc(configValueForKey:source:)
    public func configValue(forKey key: String?, source: RemoteConfigSource) -> RemoteConfigValue {
         guard let key = key, !key.isEmpty else {
             return RemoteConfigValue(data: Data(), source: .staticValue)
         }

         return queue.sync { [weak self] () -> RemoteConfigValue in
            guard let self = self else { return RemoteConfigValue(data: Data(), source: .staticValue) }

            // Keep selectors for untranslated RCNConfigContent
            var value: RemoteConfigValue? = nil
            switch source {
            case .remote:
                let activeConfig = self.configContent.perform(#selector(getter: RCNConfigContent.activeConfig))?.takeUnretainedValue() as? [String: [String: RemoteConfigValue]]
                value = activeConfig?[self.firebaseNamespace]?[key]
            case .defaultValue:
                 let defaultConfig = self.configContent.perform(#selector(getter: RCNConfigContent.defaultConfig))?.takeUnretainedValue() as? [String: [String: RemoteConfigValue]]
                 value = defaultConfig?[self.firebaseNamespace]?[key]
            case .staticValue:
                break
            @unknown default:
                 break
            }
            return value ?? RemoteConfigValue(data: Data(), source: .staticValue)
         }
    }

    @objc(allKeysFromSource:)
    public func allKeys(from source: RemoteConfigSource) -> [String] {
        return queue.sync { [weak self] () -> [String] in
            guard let self = self else { return [] }

            // Keep selectors for untranslated RCNConfigContent
            var keys: [String]? = nil
            switch source {
            case .remote:
                 let activeConfig = self.configContent.perform(#selector(getter: RCNConfigContent.activeConfig))?.takeUnretainedValue() as? [String: [String: RemoteConfigValue]]
                 keys = activeConfig?[self.firebaseNamespace]?.keys.map { $0 }
            case .defaultValue:
                 let defaultConfig = self.configContent.perform(#selector(getter: RCNConfigContent.defaultConfig))?.takeUnretainedValue() as? [String: [String: RemoteConfigValue]]
                 keys = defaultConfig?[self.firebaseNamespace]?.keys.map { $0 }
            case .staticValue:
                 break
            @unknown default:
                 break
            }
            return keys ?? []
        }
    }

    @objc(keysWithPrefix:)
    public func keys(withPrefix prefix: String?) -> Set<String> {
        return queue.sync { [weak self] () -> Set<String> in
            guard let self = self else { return [] }

            // Keep selector for untranslated RCNConfigContent
            let activeConfig = self.configContent.perform(#selector(getter: RCNConfigContent.activeConfig))?.takeUnretainedValue() as? [String: [String: RemoteConfigValue]]
            guard let namespaceConfig = activeConfig?[self.firebaseNamespace] else {
                return []
            }

            let allKeys = namespaceConfig.keys
            guard let prefix = prefix, !prefix.isEmpty else {
                return Set(allKeys)
            }

            return Set(allKeys.filter { $0.hasPrefix(prefix) })
        }
    }

    // MARK: - Defaults

    @objc(setDefaults:)
    public func setDefaults(_ defaults: [String: NSObject]?) {
        let defaultsCopy = defaults ?? [:]

        queue.async { [weak self] in
            guard let self = self else { return }

            // Keep selectors for untranslated RCNConfigContent
            let namespaceToDefaults = [self.firebaseNamespace: defaultsCopy]
             _ = self.configContent.perform(#selector(RCNConfigContent.copyFromDictionary(_:toSource:forNamespace:)),
                                            with: namespaceToDefaults,
                                            with: 2, // RCNDBSourceDefault
                                            with: self.firebaseNamespace)

             // Update last set defaults time via settingsInternal method (interacts with DB placeholder)
             let now = Date().timeIntervalSince1970
             self.settingsInternal.updateLastSetDefaultsTimeIntervalInDB(now)
        }
    }

    @objc(setDefaultsFromPlistFileName:)
    public func setDefaults(fromPlist fileName: String?) {
        guard let fileName = fileName, !fileName.isEmpty else { return }
        let bundlesToSearch = [Bundle.main, Bundle(for: RemoteConfig.self)]
        var plistPath: String?
        for bundle in bundlesToSearch {
             if let path = bundle.path(forResource: fileName, ofType: "plist") {
                 plistPath = path; break
             }
        }
        guard let finalPath = plistPath else { return }
        if let defaultsDict = NSDictionary(contentsOfFile: finalPath) as? [String: NSObject] {
            setDefaults(defaultsDict)
        }
    }

    @objc(defaultValueForKey:)
    public func defaultValue(forKey key: String?) -> RemoteConfigValue? {
        guard let key = key, !key.isEmpty else { return nil }

        return queue.sync { [weak self] () -> RemoteConfigValue? in
             guard let self = self else { return nil }

             // Keep selectors for untranslated RCNConfigContent
             let defaultConfig = self.configContent.perform(#selector(getter: RCNConfigContent.defaultConfig))?.takeUnretainedValue() as? [String: [String: RemoteConfigValue]]
             let value = defaultConfig?[self.firebaseNamespace]?[key]
             // TODO: Check source == .defaultValue?
             return value
        }
    }

    // MARK: - Placeholder selectors for untranslated classes

    // RCNConfigContent related
    @objc private func activeConfig() -> Any? { return nil }
    @objc private func defaultConfig() -> Any? { return nil }
    @objc private func fetchedConfig() -> NSDictionary? { return nil }
    @objc private func copyFromDictionary(_ dict: Any?, toSource source: Int, forNamespace ns: String) {}
    @objc private func activatePersonalization() {}
    @objc private func activeRolloutMetadata() -> NSArray? { return nil }
    @objc private func activateRolloutMetadata(_ completion: Any?) {}
    @objc private func initializationSuccessful() -> Bool { return false }

    // RCNConfigFetch related
    @objc private func recreateNetworkSession() {}
    @objc private func fetchConfig(withExpirationDuration duration: TimeInterval, completionHandler handler: Any?) {}

    // RCNConfigExperiment related
    @objc private func updateExperiments(handler: Any?) {}

    // Selectors for DB interactions via RCNConfigSettingsInternal
    @objc private func updateLastApplyTimeIntervalInDB(_ interval: TimeInterval) {}
    @objc private func updateLastSetDefaultsTimeIntervalInDB(_ interval: TimeInterval) {}

} // End of RemoteConfig class
