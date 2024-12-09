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

import FirebaseCore
import Foundation

@objc(RCNDBSource) public enum DBSource: Int {
  case active
  case `default`
  case fetched
}

/// The AtomicConfig class for the config variables enables atomic accesses to support multiple
/// namespace usage of RemoteConfig.
private class AtomicConfig {
  private var value: [String: [String: RemoteConfigValue]]
  private let lock = NSLock()

  init(_ value: [String: [String: RemoteConfigValue]]) {
    self.value = value
  }

  var wrappedValue: [String: [String: RemoteConfigValue]] {
    get { return load() }
    set { store(newValue: newValue) }
  }

  func load() -> [String: [String: RemoteConfigValue]] {
    lock.lock()
    defer { lock.unlock() }
    return value
  }

  func store(newValue: [String: [String: RemoteConfigValue]]) {
    lock.lock()
    defer { lock.unlock() }
    value = newValue
  }

  func update(namespace: String, newValue: [String: RemoteConfigValue]) {
    lock.lock()
    defer { lock.unlock() }
    value[namespace] = newValue
  }

  func update(namespace: String, key: String, rcValue: RemoteConfigValue) {
    lock.lock()
    defer { lock.unlock() }
    value[namespace]?[key] = rcValue
  }
}

/// This class handles all the config content that is fetched from the server, cached in local
/// config or persisted in database.
@objc(RCNConfigContent) public
class ConfigContent: NSObject {
  /// Active config data that is currently used.
  private var _activeConfig = AtomicConfig([:])

  /// Pending config (aka Fetched config) data that is latest data from server that might or might
  /// not be applied.
  private var _fetchedConfig = AtomicConfig([:])

  /// Default config provided by user.
  private var _defaultConfig = AtomicConfig([:])

  /// Active Personalization metadata that is currently used.
  private var _activePersonalization: [String: Any] = [:]

  /// Pending Personalization metadata that is latest data from server that might or might not be
  /// applied.
  private var _fetchedPersonalization: [String: Any] = [:]

  /// Active Rollout metadata that is currently used.
  private var _activeRolloutMetadata: [[String: Any]] = []

  /// Pending Rollout metadata that is latest data from server that might or might not be applied.
  private var _fetchedRolloutMetadata: [[String: Any]] = []

  /// DBManager
  private var dbManager: ConfigDBManager?

  /// Current bundle identifier;
  private var bundleIdentifier: String

  /// Blocks all config reads until we have read from the database. This only
  /// potentially blocks on the first read. Should be a no-wait for all subsequent reads once we
  /// have data read into memory from the database.
  private let dispatchGroup: DispatchGroup

  /// Boolean indicating if initial DB load of fetched,active and default config has succeeded.
  private var isConfigLoadFromDBCompleted: Bool

  /// Boolean indicating that the load from database has initiated at least once.
  private var isDatabaseLoadAlreadyInitiated: Bool

  /// Default timeout when waiting to read data from database.
  private let databaseLoadTimeoutSecs = 30.0

  /// Shared Singleton Instance
  @objc public
  static let sharedInstance = ConfigContent(dbManager: ConfigDBManager.sharedInstance)

  /// Designated initializer
  @objc(initWithDBManager:) public
  init(dbManager: ConfigDBManager) {
    self.dbManager = dbManager
    bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
    if bundleIdentifier.isEmpty {
      RCLog.notice("I-RCN000038",
                   "Main bundle identifier is missing. Remote Config might not work properly.")
    }
    dispatchGroup = DispatchGroup()
    isConfigLoadFromDBCompleted = false
    isDatabaseLoadAlreadyInitiated = false
    super.init()
    loadConfigFromMainTable()
  }

  // Blocking call that returns true/false once database load completes / times out.
  // @return Initialization status.
  @objc public
  func initializationSuccessful() -> Bool {
    assert(!Thread.isMainThread, "Must not be executing on the main thread.")
    return checkAndWaitForInitialDatabaseLoad()
  }

  /// We load the database async at init time. Block all further calls to active/fetched/default
  /// configs until load is done.
  @discardableResult
  private func checkAndWaitForInitialDatabaseLoad() -> Bool {
    /// Wait until load is done. This should be a no-op for subsequent calls.
    if !isConfigLoadFromDBCompleted {
      let waitResult = dispatchGroup.wait(timeout: .now() + databaseLoadTimeoutSecs)
      if waitResult == .timedOut {
        RCLog.error("I-RCN000048", "Timed out waiting for fetched config to be loaded from DB")
        return false
      }
      isConfigLoadFromDBCompleted = true
    }
    return true
  }

  // MARK: - Database

  /// This method is only meant to be called at init time. The underlying logic will need to be
  /// reevaluated if the assumption changes at a later time.
  private func loadConfigFromMainTable() {
    guard let dbManager = dbManager else { return }

    assert(!isDatabaseLoadAlreadyInitiated, "Database load has already been initiated")
    isDatabaseLoadAlreadyInitiated = true

    dispatchGroup.enter()
    dbManager.loadMain(withBundleIdentifier: bundleIdentifier) { [weak self] success,
      fetched, active, defaults, rolloutMetadata in
      guard let self = self else { return }
      self._fetchedConfig.store(newValue: fetched)
      self._activeConfig.store(newValue: active)
      self._defaultConfig.store(newValue: defaults)
      self
        ._fetchedRolloutMetadata =
        rolloutMetadata[ConfigConstants.rolloutTableKeyFetchedMetadata] as? [[String: Any]] ?? []
      self
        ._activeRolloutMetadata =
        rolloutMetadata[ConfigConstants.rolloutTableKeyActiveMetadata] as? [[String: Any]] ?? []
      self.dispatchGroup.leave()
    }

    // TODO(karenzeng): Refactor personalization to be returned in loadMainWithBundleIdentifier above
    dispatchGroup.enter()
    dbManager.loadPersonalization { [weak self] success, fetchedPersonalization,
      activePersonalization in
      guard let self = self else { return }
      self._fetchedPersonalization = fetchedPersonalization
      self._activePersonalization = activePersonalization
      self.dispatchGroup.leave()
    }
  }

  /// Update the current config result to main table.
  /// @param values Values in a row to write to the table.
  /// @param source The source the config data is coming from. It determines which table to write
  /// to.
  private func updateMainTable(withValues values: [Any], fromSource source: DBSource) {
    dbManager?.insertMainTable(withValues: values, fromSource: source, completionHandler: nil)
  }

  // MARK: - Update

  /// This function is for copying dictionary when user set up a default config or when user clicks
  /// activate. For now the DBSource can only be Active or Default.
  @objc public
  func copy(fromDictionary dictionary: [String: [String: Any]],
            toSource dbSource: DBSource,
            forNamespace firebaseNamespace: String) {
    // Make sure database load has completed.
    checkAndWaitForInitialDatabaseLoad()

    var source: RemoteConfigSource = .remote
    var toDictionary: [String: [String: RemoteConfigValue]]

    switch dbSource {
    case .default:
      toDictionary = defaultConfig()
      source = .default
    case .fetched:
      RCLog.warning("I-RCN000008",
                    "This shouldn't happen. Destination dictionary should never be pending type.")
      return
    case .active:
      toDictionary = activeConfig()
      source = .remote
      toDictionary.removeValue(forKey: firebaseNamespace)
    }

    // Completely wipe out DB first.
    dbManager?.deleteRecord(fromMainTableWithNamespace: firebaseNamespace,
                            bundleIdentifier: bundleIdentifier,
                            fromSource: dbSource)

    toDictionary[firebaseNamespace] = [:]
    guard let config = dictionary[firebaseNamespace] else { return }
    for (key, value) in config {
      if dbSource == .default {
        guard let value = value as? NSObject else { continue }
        var valueData: Data?
        if let value = value as? Data {
          valueData = value
        } else if let value = value as? String {
          valueData = value.data(using: .utf8)
        } else if let value = value as? NSNumber {
          let stringValue = value.stringValue
          valueData = stringValue.data(using: .utf8)
        } else if let value = value as? Date {
          let dateFormatter = DateFormatter()
          dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
          let stringValue = dateFormatter.string(from: value)
          valueData = stringValue.data(using: .utf8)
        } else if let value = value as? [Any] {
          do {
            valueData = try JSONSerialization.data(withJSONObject: value, options: [])
          } catch {
            RCLog.error("I-RCN000076", "Invalid array value for key '\(key)'")
          }
        } else if let value = value as? [String: Any] {
          do {
            valueData = try JSONSerialization.data(withJSONObject: value, options: [])
          } catch {
            RCLog.error("I-RCN000077",
                        "Invalid dictionary value for key '\(key)'")
          }
        } else {
          continue
        }
        guard let data = valueData else { continue }

        toDictionary[firebaseNamespace]?[key] = RemoteConfigValue(data: data, source: source)
        let values: [Any] = [bundleIdentifier, firebaseNamespace, key, data]
        updateMainTable(withValues: values, fromSource: dbSource)
      } else {
        guard let value = value as? RemoteConfigValue else { continue }
        toDictionary[firebaseNamespace]?[key] = RemoteConfigValue(
          data: value.dataValue,
          source: source
        )
        let values: [Any] = [bundleIdentifier, firebaseNamespace, key, value.dataValue]
        updateMainTable(withValues: values, fromSource: dbSource)
      }
    }

    if dbSource == .default {
      _defaultConfig.store(newValue: toDictionary)
    } else {
      _activeConfig.store(newValue: toDictionary)
    }
  }

  @objc public
  func updateConfigContent(withResponse response: [String: Any],
                           forNamespace firebaseNamespace: String) {
    // Make sure database load has completed.
    checkAndWaitForInitialDatabaseLoad()
    guard let state = response[ConfigConstants.fetchResponseKeyState] as? String else {
      RCLog.error("I-RCN000049", "State field in fetch response is nil.")
      return
    }
    RCLog.debug("I-RCN000059",
                "Updating config content from Response for namespace: \(firebaseNamespace) with state: \(state)")

    if state == ConfigConstants.fetchResponseKeyStateNoChange {
      handleNoChangeState(forConfigNamespace: firebaseNamespace)
      return
    }

    /// Handle empty config state
    if state == ConfigConstants.fetchResponseKeyStateEmptyConfig {
      handleEmptyConfigState(forConfigNamespace: firebaseNamespace)
      return
    }

    /// Handle no template state.
    if state == ConfigConstants.fetchResponseKeyStateNoTemplate {
      handleNoTemplateState(forConfigNamespace: firebaseNamespace)
      return
    }

    /// Handle update state
    if state == ConfigConstants.fetchResponseKeyStateUpdate {
      let entries = response[ConfigConstants.fetchResponseKeyEntries] as? [String: String] ?? [:]
      handleUpdateState(forConfigNamespace: firebaseNamespace, withEntries: entries)
      handleUpdatePersonalization(response[ConfigConstants
          .fetchResponseKeyPersonalizationMetadata] as? [String: Any])
      handleUpdateRolloutFetchedMetadata(response[ConfigConstants
          .fetchResponseKeyRolloutMetadata] as? [[String: Any]])
      return
    }
  }

  @objc public
  func activatePersonalization() {
    _activePersonalization = _fetchedPersonalization
    dbManager?.insertOrUpdatePersonalizationConfig(_activePersonalization, fromSource: .active)
  }

  @objc public
  func activateRolloutMetadata(_ completionHandler: @escaping (Bool) -> Void) {
    _activeRolloutMetadata = _fetchedRolloutMetadata
    dbManager?.insertOrUpdateRolloutTable(withKey: ConfigConstants.rolloutTableKeyActiveMetadata,
                                          value: _activeRolloutMetadata,
                                          completionHandler: { success, _ in
                                            completionHandler(success)
                                          })
  }

  // MARK: - State Handling

  func handleNoChangeState(forConfigNamespace firebaseNamespace: String) {
    if fetchedConfig()[firebaseNamespace] == nil {
      _fetchedConfig.update(namespace: firebaseNamespace, newValue: [:])
    }
  }

  func handleEmptyConfigState(forConfigNamespace firebaseNamespace: String) {
    // If namespace has empty status and it doesn't exist in _fetchedConfig, we will
    // still add an entry for that namespace. Even if it will not be persisted in database.
    _fetchedConfig.update(namespace: firebaseNamespace, newValue: [:])
    dbManager?.deleteRecord(fromMainTableWithNamespace: firebaseNamespace,
                            bundleIdentifier: bundleIdentifier,
                            fromSource: .fetched)
  }

  func handleNoTemplateState(forConfigNamespace firebaseNamespace: String) {
    // Remove the namespace.
    _fetchedConfig.update(namespace: firebaseNamespace, newValue: [:])
    dbManager?.deleteRecord(fromMainTableWithNamespace: firebaseNamespace,
                            bundleIdentifier: bundleIdentifier,
                            fromSource: .fetched)
  }

  func handleUpdateState(forConfigNamespace firebaseNamespace: String,
                         withEntries entries: [String: String]) {
    RCLog.debug("I-RCN000058",
                "Update config in DB for namespace: \(firebaseNamespace)")
    // Clear before updating
    dbManager?.deleteRecord(fromMainTableWithNamespace: firebaseNamespace,
                            bundleIdentifier: bundleIdentifier,
                            fromSource: .fetched)
    _fetchedConfig.update(namespace: firebaseNamespace, newValue: [:])

    // Store the fetched config values.
    for (key, value) in entries {
      guard let valueData = value.data(using: .utf8) else { continue }
      _fetchedConfig
        .update(namespace: firebaseNamespace, key: key,
                rcValue: RemoteConfigValue(data: valueData, source: .remote))
      let values: [Any] = [bundleIdentifier, firebaseNamespace, key, valueData]
      updateMainTable(withValues: values, fromSource: .fetched)
    }
  }

  func handleUpdatePersonalization(_ metadata: [String: Any]?) {
    guard let metadata = metadata else { return }
    _fetchedPersonalization = metadata
    dbManager?.insertOrUpdatePersonalizationConfig(metadata, fromSource: .fetched)
  }

  func handleUpdateRolloutFetchedMetadata(_ metadata: [[String: Any]]?) {
    _fetchedRolloutMetadata = metadata ?? []
    dbManager?.insertOrUpdateRolloutTable(withKey: ConfigConstants.rolloutTableKeyFetchedMetadata,
                                          value: _fetchedRolloutMetadata,
                                          completionHandler: nil)
  }

  // MARK: - Getters/Setters

  @objc public
  func fetchedConfig() -> [String: [String: RemoteConfigValue]] {
    /// If this is the first time reading the fetchedConfig, we might still be reading it from the
    /// database.
    checkAndWaitForInitialDatabaseLoad()
    return _fetchedConfig.wrappedValue
  }

  @objc public
  func activeConfig() -> [String: [String: RemoteConfigValue]] {
    /// If this is the first time reading the activeConfig, we might still be reading it from the
    /// database.
    checkAndWaitForInitialDatabaseLoad()
    return _activeConfig.wrappedValue
  }

  @objc public
  func defaultConfig() -> [String: [String: RemoteConfigValue]] {
    /// If this is the first time reading the defaultConfig, we might still be reading it from the
    /// database.
    checkAndWaitForInitialDatabaseLoad()
    return _defaultConfig.wrappedValue
  }

  @objc public
  func activePersonalization() -> [String: Any] {
    /// If this is the first time reading the activePersonalization, we might still be reading it
    /// from the
    /// database.
    checkAndWaitForInitialDatabaseLoad()
    return _activePersonalization
  }

  @objc public
  func activeRolloutMetadata() -> [[String: Any]] {
    /// If this is the first time reading the activeRolloutMetadata, we might still be reading it
    /// from the
    /// database.
    checkAndWaitForInitialDatabaseLoad()
    return _activeRolloutMetadata
  }

  @objc public
  func getConfigAndMetadata(forNamespace firebaseNamespace: String) -> [String: Any] {
    // If this is the first time reading the active metadata, we might still be reading it from the
    // database.
    checkAndWaitForInitialDatabaseLoad()
    return [
      ConfigConstants.fetchResponseKeyEntries: activeConfig()[firebaseNamespace] as Any,
      ConfigConstants.fetchResponseKeyPersonalizationMetadata: activePersonalization,
    ]
  }

  // Compare fetched config with active config and output what has changed
  @objc public
  func getConfigUpdate(forNamespace firebaseNamespace: String) -> RemoteConfigUpdate? {
    // TODO: handle diff in experiment metadata.
    var updatedKeys = Set<String>()

    let fetchedConfig = fetchedConfig()[firebaseNamespace] ?? [:]
    let activeConfig = activeConfig()[firebaseNamespace] ?? [:]
    let fetchedP13n = _fetchedPersonalization
    let activeP13n = _activePersonalization
    let fetchedRolloutMetadata = _fetchedRolloutMetadata
    let activeRolloutMetadata = _activeRolloutMetadata

    // Add new/updated params
    for key in fetchedConfig.keys {
      if activeConfig[key] == nil ||
        activeConfig[key]?.stringValue != fetchedConfig[key]?.stringValue {
        updatedKeys.insert(key)
      }
    }
    // Add deleted params
    for key in activeConfig.keys {
      if fetchedConfig[key] == nil {
        updatedKeys.insert(key)
      }
    }

    // Add params with new/updated p13n metadata
    for key in fetchedP13n.keys {
      if activeP13n[key] == nil ||
        !isEqual(activeP13n[key], fetchedP13n[key]) {
        updatedKeys.insert(key)
      }
    }

    // Add params with deleted p13n metadata
    for key in activeP13n.keys {
      if fetchedP13n[key] == nil {
        updatedKeys.insert(key)
      }
    }

    let fetchedRollouts = parameterKeyToRolloutMetadata(rolloutMetadata: fetchedRolloutMetadata)
    let activeRollouts = parameterKeyToRolloutMetadata(rolloutMetadata: activeRolloutMetadata)

    // Add params with new/updated rollout metadata
    for key in fetchedRollouts.keys {
      if activeRollouts[key] == nil ||
        !isEqual(activeRollouts[key], fetchedRollouts[key]) {
        updatedKeys.insert(key)
      }
    }

    // Add params with deleted rollout metadata
    for key in activeRollouts.keys {
      if fetchedRollouts[key] == nil {
        updatedKeys.insert(key)
      }
    }

    return RemoteConfigUpdate(updatedKeys: updatedKeys)
  }

  private func isEqual(_ object1: Any?, _ object2: Any?) -> Bool {
    guard let object1 = object1, let object2 = object2 else {
      return object1 == nil && object2 == nil // consider nil equal to nil.
    }

    // Attempt to compare as dictionaries.
    if let dict1 = object1 as? [String: Any], let dict2 = object2 as? [String: Any] {
      return NSDictionary(dictionary: dict1).isEqual(to: dict2)
    }
    return String(describing: object1) == String(describing: object2)
  }

  private func parameterKeyToRolloutMetadata(rolloutMetadata: [[String: Any]]) -> [String: Any] {
    var result = [String: [String: String]]()
    for metadata in rolloutMetadata {
      guard let rolloutID = metadata[ConfigConstants.fetchResponseKeyRolloutID] as? String,
            let variantID = metadata[ConfigConstants.fetchResponseKeyVariantID] as? String,
            let affectedKeys =
            metadata[ConfigConstants.fetchResponseKeyAffectedParameterKeys] as? [String]
      else { continue }

      for key in affectedKeys {
        if var rolloutIdToVariantId = result[key] {
          rolloutIdToVariantId[rolloutID] = variantID
          result[key] = rolloutIdToVariantId
        } else {
          result[key] = [rolloutID: variantID]
        }
      }
    }
    return result
  }
}
