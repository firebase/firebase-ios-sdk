import Foundation
import FirebaseCore // For FIRLogger

// --- Placeholder Types ---
typealias RCNConfigDBManager = AnyObject // Keep placeholder
// Assume RemoteConfigValue, RemoteConfigSource, DBKeys, RCNUpdateOption are defined elsewhere

// --- Helper Types (Assume these are defined elsewhere or inline if simple) ---
// Assuming RemoteConfigValue is defined
 @objc(FIRRemoteConfigValue) public class RemoteConfigValue: NSObject, NSCopying {
     let valueData: Data
     let source: RemoteConfigSource
     init(data: Data, source: RemoteConfigSource) {
         self.valueData = data; self.source = source; super.init()
     }
     override convenience init() { self.init(data: Data(), source: .staticValue) }
     @objc public func copy(with zone: NSZone? = nil) -> Any { return self }
 }
 // Assuming RemoteConfigSource is defined
 @objc(FIRRemoteConfigSource) public enum RemoteConfigSource: Int {
   case remote = 0
   case defaultValue = 1
   case staticValue = 2
 }
 // Placeholder for RemoteConfigUpdate (assuming definition from previous tasks)
 @objc(FIRRemoteConfigUpdate) public class RemoteConfigUpdate: NSObject {
   @objc public let updatedKeys: Set<String>
   init(updatedKeys: Set<String>) { self.updatedKeys = updatedKeys; super.init() }
 }


// Define RCNDBSource enum (assuming raw values)
enum RCNDBSource: Int {
    case remote = 0 // Corresponds to Fetched
    case active = 1
    case defaultValue = 2
    case staticValue = 3 // Not used for DB storage?
}

// Define DBKeys enum (assuming keys)
enum DBKeys {
    static let rolloutFetchedMetadata = "rolloutFetchedMetadata"
    static let rolloutActiveMetadata = "rolloutActiveMetadata"
}

// Placeholder for closure type until DB Manager is translated
// Needs to match the expected signature for the `loadMain` selector
typealias RCNDBLoadCompletion = @convention(block) (Bool, [String: [String: RemoteConfigValue]]?, [String: [String: RemoteConfigValue]]?, [String: [String: RemoteConfigValue]]?, [String: Any]?) -> Void
typealias RCNDBCompletion = @convention(block) (Bool, [String: Any]?) -> Void // Simplified completion for other DB operations
typealias RCNDBPersonalizationCompletion = @convention(block) (Bool, [String: Any]?, [String: Any]?, Any?, Any?) -> Void


/// Manages the fetched, active, and default config states, including personalization and rollout metadata.
/// Handles loading from and saving to the database (via RCNConfigDBManager).
/// Note: Internal state requires synchronization, handled by blocking reads until initial load completes.
/// Modifications are expected to happen serially via RemoteConfig's queue.
class RCNConfigContent { // Not public

    // MARK: - Properties

    // TODO: Replace placeholder DBManager with actual translated class and init
    @objc static let shared = RCNConfigContent(dbManager: RCNConfigDBManager()) // Use DB placeholder init

    // Config States (protected by initial load blocking)
    private var _fetchedConfig: [String: [String: RemoteConfigValue]] = [:]
    private var _activeConfig: [String: [String: RemoteConfigValue]] = [:]
    private var _defaultConfig: [String: [String: RemoteConfigValue]] = [:]

    // Metadata (protected by initial load blocking)
    private var _fetchedPersonalization: [String: Any] = [:]
    private var _activePersonalization: [String: Any] = [:]
    private var _fetchedRolloutMetadata: [[String: Any]] = [] // Array of dictionaries
    private var _activeRolloutMetadata: [[String: Any]] = []

    // Dependencies & State
    private let dbManager: RCNConfigDBManager // Placeholder
    private let bundleIdentifier: String
    private let dispatchGroup = DispatchGroup() // Used to block reads until DB load finishes
    private var isConfigLoadFromDBCompleted = false // Tracks if initial load finished
    private var isDatabaseLoadAlreadyInitiated = false // Prevents multiple load attempts

    // Constants
    private let databaseLoadTimeoutSecs: TimeInterval = 30.0 // From ObjC kDatabaseLoadTimeoutSecs

    // MARK: - Initialization

    // Private designated initializer
    init(dbManager: RCNConfigDBManager) {
        self.dbManager = dbManager
        if let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty {
            self.bundleIdentifier = bundleID
        } else {
            self.bundleIdentifier = ""
            // TODO: Log warning - FIRLogNotice(kFIRLoggerRemoteConfig, @"I-RCN000038", ...)
        }
        // Start loading data asynchronously
        loadConfigFromPersistence()
    }

    /// Kicks off the asynchronous load from the database.
    private func loadConfigFromPersistence() {
         guard !isDatabaseLoadAlreadyInitiated else { return }
         isDatabaseLoadAlreadyInitiated = true

         // Enter group for main config load
         dispatchGroup.enter()

         // Explicitly type the completion handler block to pass to perform selector
         let mainCompletion: RCNDBLoadCompletion = { [weak self] success, fetched, active, defaults, rollouts in
             guard let self = self else { return }
             self._fetchedConfig = fetched ?? [:]
             self._activeConfig = active ?? [:]
             self._defaultConfig = defaults ?? [:]
             // Extract rollout metadata
             self._fetchedRolloutMetadata = rollouts?[DBKeys.rolloutFetchedMetadata] as? [[String: Any]] ?? []
             self._activeRolloutMetadata = rollouts?[DBKeys.rolloutActiveMetadata] as? [[String: Any]] ?? []
             self.dispatchGroup.leave() // Leave group for main config load
         }

         // DB Interaction - Keep selector
         // func loadMain(bundleIdentifier: String, completionHandler: @escaping RCNDBLoadCompletion)
         dbManager.perform(#selector(RCNConfigDBManager.loadMain(bundleIdentifier:completionHandler:)),
                         with: bundleIdentifier,
                         with: mainCompletion as Any) // Pass block as Any


         // Enter group for personalization load
         dispatchGroup.enter()

         // Explicitly type the personalization completion handler
          // Adapting parameters based on ObjC impl - need verification after DB translation
         let personalizationCompletion: RCNDBPersonalizationCompletion = {
              [weak self] success, fetchedP13n, activeP13n, _, _ in // Ignore last two params
                 guard let self = self else { return }
                 self._fetchedPersonalization = fetchedP13n ?? [:]
                 self._activePersonalization = activeP13n ?? [:]
                 self.dispatchGroup.leave() // Leave group for personalization load
             }

         // DB Interaction - Placeholder Selector (Method needs translation in DB Manager)
         // func loadPersonalization(completionHandler: RCNDBLoadCompletion) - Assuming similar signature for now
         dbManager.perform(#selector(RCNConfigDBManager.loadPersonalization(completionHandler:)),
                         with: personalizationCompletion as Any) // Pass block as Any
     }


    /// Blocks until the initial database load is complete or times out.
    /// - Returns: `true` if the load completed successfully within the timeout, `false` otherwise.
    private func checkAndWaitForInitialDatabaseLoad() -> Bool {
        if !isConfigLoadFromDBCompleted {
            let result = dispatchGroup.wait(timeout: .now() + databaseLoadTimeoutSecs)
            if result == .timedOut {
                 // TODO: Log error - FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000048", ...)
                 return false
            }
            isConfigLoadFromDBCompleted = true
        }
        return true
    }

    /// Returns true if initialization succeeded (blocking call).
    @objc(initializationSuccessful) // Match selector in RemoteConfig
    func initializationSuccessful() -> Bool {
        // Note: The original implementation called this on a background thread.
        // The blocking nature is maintained here. Consider async/await if refactoring.
        return checkAndWaitForInitialDatabaseLoad()
    }

    // MARK: - Computed Properties (Getters with Load Blocking)

    @objc(fetchedConfig) // Match selector in RemoteConfig
    var fetchedConfig: [String: [String: RemoteConfigValue]] {
        _ = checkAndWaitForInitialDatabaseLoad()
        return _fetchedConfig
    }

    @objc(activeConfig) // Match selector in RemoteConfig
    var activeConfig: [String: [String: RemoteConfigValue]] {
        _ = checkAndWaitForInitialDatabaseLoad()
        return _activeConfig
    }

    @objc(defaultConfig) // Match selector in RemoteConfig
    var defaultConfig: [String: [String: RemoteConfigValue]] {
         _ = checkAndWaitForInitialDatabaseLoad()
         return _defaultConfig
     }

    var activePersonalization: [String: Any] { // Internal use, no @objc needed yet
         _ = checkAndWaitForInitialDatabaseLoad()
         return _activePersonalization
    }

     @objc(activeRolloutMetadata) // Match selector in RemoteConfig
     var activeRolloutMetadata: [[String: Any]] {
         _ = checkAndWaitForInitialDatabaseLoad()
         return _activeRolloutMetadata
     }


    // MARK: - Update Config Content

     /// Update config content from fetch response in JSON format.
     func updateConfigContentWithResponse(_ response: [String: Any], forNamespace currentNamespace: String) {
         _ = checkAndWaitForInitialDatabaseLoad() // Ensure initial load done before modifying

         guard let state = response[RCNFetchResponseKeyState] as? String else {
             // TODO: Log error - FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000049", ...)
             return
         }
          // TODO: Log Debug - FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000059", ...)

         switch state {
         case RCNFetchResponseKeyStateNoChange:
             handleNoChangeState(forConfigNamespace: currentNamespace)
         case RCNFetchResponseKeyStateEmptyConfig:
             handleEmptyConfigState(forConfigNamespace: currentNamespace)
         case RCNFetchResponseKeyStateNoTemplate:
             handleNoTemplateState(forConfigNamespace: currentNamespace)
         case RCNFetchResponseKeyStateUpdate:
             handleUpdateState(forConfigNamespace: currentNamespace,
                               withEntries: response[RCNFetchResponseKeyEntries] as? [String: String] ?? [:]) // Entries are String in response
             handleUpdatePersonalization(response[RCNFetchResponseKeyPersonalizationMetadata] as? [String: Any])
             handleUpdateRolloutFetchedMetadata(response[RCNFetchResponseKeyRolloutMetadata] as? [[String: Any]])
         default:
             // TODO: Log warning - Unknown state?
             break
         }
     }


    // MARK: - State Handling Helpers

    private func handleNoChangeState(forConfigNamespace currentNamespace: String) {
        // Ensure namespace exists in fetched config dictionary, even if empty
        if _fetchedConfig[currentNamespace] == nil {
            _fetchedConfig[currentNamespace] = [:]
        }
        // No DB changes needed
    }

    private func handleEmptyConfigState(forConfigNamespace currentNamespace: String) {
         // Clear fetched config for namespace
         _fetchedConfig[currentNamespace]?.removeAll()
         if _fetchedConfig[currentNamespace] == nil { // Ensure entry exists even if empty
             _fetchedConfig[currentNamespace] = [:]
         }
         // Clear from DB
         // DB Interaction - Keep selector
         dbManager.perform(#selector(RCNConfigDBManager.deleteRecordFromMainTable(namespace:bundleIdentifier:fromSource:)),
                         with: currentNamespace,
                         with: bundleIdentifier,
                         with: RCNDBSource.remote.rawValue) // Use raw value for selector
     }

     private func handleNoTemplateState(forConfigNamespace currentNamespace: String) {
         // Remove namespace completely
         _fetchedConfig.removeValue(forKey: currentNamespace)
         // Clear from DB
          // DB Interaction - Keep selector
          dbManager.perform(#selector(RCNConfigDBManager.deleteRecordFromMainTable(namespace:bundleIdentifier:fromSource:)),
                          with: currentNamespace,
                          with: bundleIdentifier,
                          with: RCNDBSource.remote.rawValue) // Use raw value for selector
      }

      private func handleUpdateState(forConfigNamespace currentNamespace: String, withEntries entries: [String: String]) {
           // TODO: Log Debug - FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000058", ...)
           // Clear DB first
            // DB Interaction - Keep selector
            dbManager.perform(#selector(RCNConfigDBManager.deleteRecordFromMainTable(namespace:bundleIdentifier:fromSource:)),
                            with: currentNamespace,
                            with: bundleIdentifier,
                            with: RCNDBSource.remote.rawValue) // Use raw value for selector

           // Update in-memory fetched config
           var namespaceConfig: [String: RemoteConfigValue] = [:]
           for (key, valueString) in entries {
               guard let valueData = valueString.data(using: .utf8) else { continue }
               let remoteValue = RemoteConfigValue(data: valueData, source: .remote)
               namespaceConfig[key] = remoteValue
               // Save to DB
               let values: [Any] = [bundleIdentifier, currentNamespace, key, valueData]
                // DB Interaction - Keep selector
                dbManager.perform(#selector(RCNConfigDBManager.insertMainTable(values:fromSource:completionHandler:)),
                                with: values,
                                with: RCNDBSource.remote.rawValue, // Use raw value for selector
                                with: nil) // No completion handler needed? Check ObjC
           }
           _fetchedConfig[currentNamespace] = namespaceConfig
       }

       private func handleUpdatePersonalization(_ metadata: [String: Any]?) {
           guard let metadata = metadata else { return }
           _fetchedPersonalization = metadata
           // DB Interaction - Keep selector (needs correct method name)
           // Assume: insertOrUpdatePersonalizationConfig(_:fromSource:) -> Bool
           _ = dbManager.perform(#selector(RCNConfigDBManager.insertOrUpdatePersonalizationConfig(_:fromSource:)),
                             with: metadata,
                             with: RCNDBSource.remote.rawValue) // Use raw value for selector
       }

       private func handleUpdateRolloutFetchedMetadata(_ metadata: [[String: Any]]?) {
           let metadataToSave = metadata ?? [] // Use empty array if nil
           _fetchedRolloutMetadata = metadataToSave
           // DB Interaction - Keep selector (needs correct method name)
            // Assume: insertOrUpdateRolloutTable(key:value:completionHandler:)
            dbManager.perform(#selector(RCNConfigDBManager.insertOrUpdateRolloutTable(key:value:completionHandler:)),
                            with: DBKeys.rolloutFetchedMetadata,
                            with: metadataToSave,
                            with: nil) // No completion handler needed
        }

    // MARK: - Copy & Activation

    /// Copy from a given dictionary to one of the data source (Active or Default).
    @objc(copyFromDictionary:toSource:forNamespace:) // Match selector in RemoteConfig
    func copyFromDictionary(_ fromDictionary: [String: Any]?, // Can be [String: NSObject] or [String: RemoteConfigValue]
                            toSource DBSourceRawValue: Int,
                            forNamespace FIRNamespace: String) {
         _ = checkAndWaitForInitialDatabaseLoad() // Ensure loaded before copying

         guard let DBSource = RCNDBSource(rawValue: DBSourceRawValue) else {
              print("Error: Invalid DB Source \(DBSourceRawValue)")
              return
         }

         guard let sourceDict = fromDictionary, !sourceDict.isEmpty else {
             // TODO: Log Error - FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000007", ...)
             return
         }

         let targetDict: inout [String: [String: RemoteConfigValue]] // Use inout for modification
         let targetSource: RemoteConfigSource // For RemoteConfigValue creation

         switch DBSource {
         case .defaultValue:
             targetDict = &_defaultConfig
             targetSource = .defaultValue
         case .active:
             targetDict = &_activeConfig
             targetSource = .remote // Active values originate from remote
         case .remote: // Fetched
             print("Warning: Copying to 'Fetched' source is not typical.")
             targetDict = &_fetchedConfig
             targetSource = .remote
             // TODO: Log Warning - FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000008", ...)
             // return // Original ObjC returned here, maybe prevent writing to fetched? Let's allow for now.
         case .staticValue:
              return // Cannot copy to static
          @unknown default:
              return
         }

         // Clear existing data for this namespace in the target
          // DB Interaction - Keep selector
          dbManager.perform(#selector(RCNConfigDBManager.deleteRecordFromMainTable(namespace:bundleIdentifier:fromSource:)),
                          with: FIRNamespace,
                          with: bundleIdentifier,
                          with: DBSource.rawValue) // Use raw value for selector
         targetDict[FIRNamespace]?.removeAll() // Clear in-memory dict

         var namespaceConfig: [String: RemoteConfigValue] = [:]
         // Check if the top-level dictionary has the namespace key (original assumption)
        if let configData = sourceDict[FIRNamespace] as? [String: Any] {
             processConfigData(configData, into: &namespaceConfig, targetSource: targetSource, FIRNamespace: FIRNamespace, DBSource: DBSource)
        } else if let directConfigData = sourceDict as? [String: NSObject] { // Check if sourceDict IS the namespace dict (Defaults)
             processConfigData(directConfigData, into: &namespaceConfig, targetSource: targetSource, FIRNamespace: FIRNamespace, DBSource: DBSource)
        } else if let remoteValueDict = sourceDict as? [String: RemoteConfigValue] { // Check if sourceDict IS the namespace dict (Activation)
             processConfigData(remoteValueDict, into: &namespaceConfig, targetSource: targetSource, FIRNamespace: FIRNamespace, DBSource: DBSource)
        } else {
             print("Warning: Could not interpret source dictionary structure for namespace '\(FIRNamespace)' during copy.")
             return // Could not interpret the source dictionary
         }

         targetDict[FIRNamespace] = namespaceConfig // Update in-memory dictionary
     }

    /// Helper to process the inner config data dictionary (handles both NSObject and RemoteConfigValue)
     private func processConfigData<T>(_ configData: [String: T],
                                       into namespaceConfig: inout [String: RemoteConfigValue],
                                       targetSource: RemoteConfigSource,
                                       FIRNamespace: String,
                                       DBSource: RCNDBSource) {
         for (key, value) in configData {
             let valueData: Data?
             if let rcValue = value as? RemoteConfigValue { // Activation case
                 valueData = rcValue.valueData // Use underlying data
             } else if let nsObjectValue = value as? NSObject { // Defaults case
                 // Convert NSObject to Data (mimic ObjC logic)
                  if let data = nsObjectValue as? Data { valueData = data }
                  else if let str = nsObjectValue as? String { valueData = str.data(using: .utf8) }
                  else if let num = nsObjectValue as? NSNumber { valueData = num.stringValue.data(using: .utf8) }
                  else if let date = nsObjectValue as? Date {
                       let formatter = ISO8601DateFormatter() // Use standard format
                       valueData = formatter.string(from: date).data(using: .utf8)
                   } else if let array = nsObjectValue as? NSArray { // Use NSArray/NSDictionary for JSON check
                       valueData = try? JSONSerialization.data(withJSONObject: array)
                   } else if let dict = nsObjectValue as? NSDictionary {
                       valueData = try? JSONSerialization.data(withJSONObject: dict)
                   } else {
                       // TODO: Log warning/error for unsupported default type?
                       valueData = nil
                   }
             } else {
                 valueData = nil // Unsupported type
             }

             guard let finalData = valueData else { continue }

             let newValue = RemoteConfigValue(data: finalData, source: targetSource)
             namespaceConfig[key] = newValue

             // Save to DB
              let values: [Any] = [bundleIdentifier, FIRNamespace, key, finalData]
              // DB Interaction - Keep selector
              dbManager.perform(#selector(RCNConfigDBManager.insertMainTable(values:fromSource:completionHandler:)),
                              with: values,
                              with: DBSource.rawValue, // Use raw value for selector
                              with: nil)
         }
     }

    /// Sets the fetched Personalization metadata to active and saves to DB.
    @objc(activatePersonalization) // Match selector in RemoteConfig
    func activatePersonalization() {
        _ = checkAndWaitForInitialDatabaseLoad()
        _activePersonalization = _fetchedPersonalization
         // DB Interaction - Keep selector (needs correct method name)
         _ = dbManager.perform(#selector(RCNConfigDBManager.insertOrUpdatePersonalizationConfig(_:fromSource:)),
                           with: _activePersonalization,
                           with: RCNDBSource.active.rawValue) // Use raw value for selector
    }

     /// Sets the fetched rollout metadata to active and saves to DB.
     @objc(activateRolloutMetadata:) // Match selector in RemoteConfig
     func activateRolloutMetadata(completionHandler: @escaping (Bool) -> Void) {
         _ = checkAndWaitForInitialDatabaseLoad()
         _activeRolloutMetadata = _fetchedRolloutMetadata
         // DB Interaction - Keep selector (needs correct method name)
          dbManager.perform(#selector(RCNConfigDBManager.insertOrUpdateRolloutTable(key:value:completionHandler:)),
                          with: DBKeys.rolloutActiveMetadata,
                          with: _activeRolloutMetadata,
                          with: { (success: Bool, _: [String: Any]?) in // Adapt completion signature
                              completionHandler(success)
                          } as RCNDBCompletion?) // Cast closure type explicitly
      }

    // MARK: - Getters with Metadata / Diffing

    /// Gets the active config and Personalization metadata for a namespace.
    func getConfigAndMetadata(forNamespace FIRNamespace: String) -> [String: Any] {
        _ = checkAndWaitForInitialDatabaseLoad()
        let activeNamespaceConfig = _activeConfig[FIRNamespace] ?? [:]
        // Return format matches ObjC version
        return [
            RCNFetchResponseKeyEntries: activeNamespaceConfig, // Value is [String: RemoteConfigValue]
            RCNFetchResponseKeyPersonalizationMetadata: _activePersonalization
        ]
    }

     /// Returns the updated parameters between fetched and active config for a namespace.
     func getConfigUpdate(forNamespace FIRNamespace: String) -> RemoteConfigUpdate {
         _ = checkAndWaitForInitialDatabaseLoad()

         var updatedKeys = Set<String>()

         let fetchedConfig = _fetchedConfig[FIRNamespace] ?? [:]
         let activeConfig = _activeConfig[FIRNamespace] ?? [:]
         let fetchedP13n = _fetchedPersonalization
         let activeP13n = _activePersonalization
         let fetchedRollouts = getParameterKeyToRolloutMetadata(rolloutMetadata: _fetchedRolloutMetadata)
         let activeRollouts = getParameterKeyToRolloutMetadata(rolloutMetadata: _activeRolloutMetadata)

         // Diff Config Values
         for (key, fetchedValue) in fetchedConfig {
             if let activeValue = activeConfig[key] {
                 // Compare underlying data for equality
                 if activeValue.valueData != fetchedValue.valueData {
                     updatedKeys.insert(key)
                 }
             } else {
                 updatedKeys.insert(key) // Added key
             }
         }
         for key in activeConfig.keys {
             if fetchedConfig[key] == nil {
                 updatedKeys.insert(key) // Deleted key
             }
         }

         // Diff Personalization (compare dictionaries)
         // Note: This compares based on NSObject equality, might need deeper comparison if nested objects are complex.
         let fetchedP13nNS = fetchedP13n as NSDictionary
         let activeP13nNS = activeP13n as NSDictionary

         for key in fetchedP13nNS.allKeys as? [String] ?? [] {
             if activeP13nNS[key] == nil || !activeP13nNS[key]!.isEqual(fetchedP13nNS[key]!) {
                 updatedKeys.insert(key)
             }
         }
         for key in activeP13nNS.allKeys as? [String] ?? [] {
             if fetchedP13nNS[key] == nil {
                 updatedKeys.insert(key)
             }
         }

         // Diff Rollouts (compare dictionaries derived from metadata)
         for (key, fetchedRolloutValue) in fetchedRollouts {
             if let activeRolloutValue = activeRollouts[key] {
                 if !(activeRolloutValue as NSDictionary).isEqual(to: fetchedRolloutValue as! [AnyHashable : Any]) {
                      updatedKeys.insert(key)
                 }
             } else {
                 updatedKeys.insert(key) // Added key
             }
         }
         for key in activeRollouts.keys {
              if fetchedRollouts[key] == nil {
                  updatedKeys.insert(key) // Deleted key
              }
          }


         return RemoteConfigUpdate(updatedKeys: updatedKeys) // Use actual RemoteConfigUpdate init
     }

     /// Helper to transform rollout metadata array into a dictionary keyed by parameter key.
     private func getParameterKeyToRolloutMetadata(rolloutMetadata: [[String: Any]]) -> [String: [String: String]] {
         var result: [String: [String: String]] = [:]
         for metadata in rolloutMetadata {
             guard let rolloutId = metadata[RCNFetchResponseKeyRolloutID] as? String,
                   let variantId = metadata[RCNFetchResponseKeyVariantID] as? String,
                   let affectedKeys = metadata[RCNFetchResponseKeyAffectedParameterKeys] as? [String] else {
                 continue
             }
             for key in affectedKeys {
                 if result[key] == nil {
                     result[key] = [:]
                 }
                 result[key]?[rolloutId] = variantId
             }
         }
         return result
     }

    // MARK: - Placeholder Selectors (for @objc calls if needed)
    @objc func initializationSuccessfulObjc() -> Bool { return initializationSuccessful() }

    // DB Manager selectors (keep for placeholder interactions)
    @objc func loadMain(bundleIdentifier id: String, completionHandler handler: Any?) {} // Adapt signature if needed
    @objc func loadPersonalization(completionHandler handler: Any?) {} // Adapt signature if needed
    @objc func deleteRecordFromMainTable(namespace ns: String, bundleIdentifier id: String, fromSource source: Int) {}
    @objc func insertMainTable(values: [Any], fromSource source: Int, completionHandler handler: Any?) {}
    @objc func insertOrUpdatePersonalizationConfig(_ config: [String: Any], fromSource source: Int) -> Bool { return false }
    @objc func insertOrUpdateRolloutTable(key: String, value list: [[String: Any]], completionHandler handler: Any?) {}

} // End of RCNConfigContent class


// Constants used from RCNConfigConstants.h / RCNFetchResponse.h
// TODO: Move to central constants file
let RCNFetchResponseKeyState = "state"
let RCNFetchResponseKeyStateNoChange = "NO_CHANGE"
let RCNFetchResponseKeyStateEmptyConfig = "EMPTY_CONFIG"
let RCNFetchResponseKeyStateNoTemplate = "NO_TEMPLATE"
let RCNFetchResponseKeyStateUpdate = "UPDATE_CONFIG"
let RCNFetchResponseKeyEntries = "entries"
let RCNFetchResponseKeyPersonalizationMetadata = "personalizationMetadata"
let RCNFetchResponseKeyRolloutMetadata = "rolloutMetadata"
// Rollout metadata keys
let RCNFetchResponseKeyRolloutID = "rolloutId"
let RCNFetchResponseKeyVariantID = "variantId"
let RCNFetchResponseKeyAffectedParameterKeys = "affectedParameterKeys"

// Placeholder for RemoteConfigUpdate if not defined elsewhere
//@objc(FIRRemoteConfigUpdate) public class RemoteConfigUpdate: NSObject {
//  @objc public let updatedKeys: Set<String>
//  init(updatedKeys: Set<String>) { self.updatedKeys = updatedKeys; super.init() }
//}
