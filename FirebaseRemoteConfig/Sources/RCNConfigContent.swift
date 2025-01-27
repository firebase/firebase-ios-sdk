import Foundation

class RCNConfigContent {
    /// Active config data that is currently used.
    private var _activeConfig: NSMutableDictionary
    /// Pending config (aka Fetched config) data that is latest data from server that might or might
    /// not be applied.
    private var _fetchedConfig: NSMutableDictionary
    /// Default config provided by user.
    private var _defaultConfig: NSMutableDictionary
    /// Active Personalization metadata that is currently used.
    private var _activePersonalization: NSDictionary
    /// Pending Personalization metadata that is latest data from server that might or might not be
    /// applied.
    private var _fetchedPersonalization: NSDictionary
    /// Active Rollout metadata that is currently used.
    private var _activeRolloutMetadata: [NSDictionary]
    /// Pending Rollout metadata that is latest data from server that might or might not be applied.
    private var _fetchedRolloutMetadata: [NSDictionary]
    /// DBManager
    private var _DBManager: RCNConfigDBManager?
    /// Current bundle identifier;
    private var _bundleIdentifier: String
    /// Blocks all config reads until we have read from the database. This only
    /// potentially blocks on the first read. Should be a no-wait for all subsequent reads once we
    /// have data read into memory from the database.
    private var _dispatch_group: DispatchGroup
    /// Boolean indicating if initial DB load of fetched,active and default config has succeeded.
    private var _isConfigLoadFromDBCompleted: Bool
    /// Boolean indicating that the load from database has initiated at least once.
    private var _isDatabaseLoadAlreadyInitiated: Bool

    static let sharedInstance = RCNConfigContent(DBManager: RCNConfigDBManager.sharedInstance())

    init(DBManager: RCNConfigDBManager) {
        _activeConfig = NSMutableDictionary()
        _fetchedConfig = NSMutableDictionary()
        _defaultConfig = NSMutableDictionary()
        _activePersonalization = [:]
        _fetchedPersonalization = [:]
        _activeRolloutMetadata = []
        _fetchedRolloutMetadata = []
        
        _bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        if _bundleIdentifier == "" {
          FIRLogNotice(RCNRemoteConfigQueueLabel, @"I-RCN000038",
                       "Main bundle identifier is missing. Remote Config might not work properly.")
        }
        _DBManager = DBManager
        // Waits for both config and Personalization data to load.
        _dispatch_group = DispatchGroup()
        
        loadConfigFromMainTable()
    }

    // MARK: - Database
    func loadConfigFromMainTable() {
        if _DBManager == nil {
            return
        }
      
        NSAssert(!_isDatabaseLoadAlreadyInitiated, "Database load has already been initiated")
        _isDatabaseLoadAlreadyInitiated = true

        _dispatch_group.enter()
        _DBManager?.loadMain(bundleIdentifier: _bundleIdentifier ?? "") {
            success, fetchedConfig, activeConfig, defaultConfig, rolloutMetadata in
            self.fetchedConfig = fetchedConfig?.mutableCopy() ?? NSMutableDictionary()
            self.activeConfig = activeConfig?.mutableCopy() ?? NSMutableDictionary()
            self.defaultConfig = defaultConfig?.mutableCopy() ?? NSMutableDictionary()
            self->_fetchedRolloutMetadata = rolloutMetadata[RCNRolloutTableKeyFetchedMetadata] as? [NSDictionary] ?? []
            self->_activeRolloutMetadata = rolloutMetadata[RCNRolloutTableKeyActiveMetadata] as? [NSDictionary] ?? []
            self->_isConfigLoadFromDBCompleted = true
            self->_isDatabaseLoadAlreadyInitiated = true

            self.loadPersonalization(completionHandler: {(success, fetchedPersonalization, activePersonalization,
                                                        defaultConfig, rolloutsMetadata) in
                self->_fetchedPersonalization = fetchedPersonalization ?? [:]
                self->_activePersonalization = activePersonalization ?? [:]
            })
            _dispatch_group.leave()
        }
        
        
    }
    
    func copyFromDictionary(from fromDict: [String : Any], toSource source: RCNDBSource,
                            forNamespace namespace: String) {
        // Make sure database load has completed.
        checkAndWaitForInitialDatabaseLoad()
      
        var toDict = NSMutableDictionary()
        var source : FIRRemoteConfigSource = .remote
        switch source {
            case .active:
              toDict = _activeConfig
                source = .remote
                // Completely wipe out DB first.
                _DBManager?.deleteRecordFromMainTable(namespace: namespace, bundleIdentifier: self.bundleIdentifier ?? "", fromSource: .active)
                break
            case .`default`:
              toDict = _defaultConfig
              source = .default
                break
            default:
              toDict = _activeConfig
              source = .remote
              break
        }
      
        toDict[FIRNamespace] = [:]
        let config = fromDict[FIRNamespace] as! [String : Any]
        for key in config {
            if (source == .default) {
                let value = config[key] as! NSObject
                var valueData: NSData? = nil
                if let value = value as? NSData {
                  valueData = value
                } else if let value = value as? String {
                  valueData = value.data(using: .utf8)
                } else if let value = value as? NSNumber {
                  valueData = [(NSNumber *)value stringValue].data(using: .utf8)
                } else if let value = value as? NSDate {
                  let dateFormatter = DateFormatter()
                  dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                  let strValue = dateFormatter.string(from: value as! Date)
                  valueData = strValue.data(using: .utf8)
                } else if let value = value as? NSArray {
                  do {
                    valueData = try JSONSerialization.data(withJSONObject: value, options: [])
                  } catch {
                      print("invalid array value for key \(key)")
                    }
                } else if let value = value as? NSDictionary {
                  do {
                    valueData = try JSONSerialization.data(withJSONObject: value, options: [])
                  } catch {
                      print("invalid dictionary value for key \(key)")
                  }
                } else {
                    continue
                }
                
                _fetchedConfig[FIRNamespace][key] = FIRRemoteConfigValue(data: valueData, source: source)
                let values = [_bundleIdentifier, FIRNamespace, key, valueData] as [Any]
                //[self updateMainTableWithValues:values fromSource:DBSource]
            } else {
                guard let value = config[key] as? FIRRemoteConfigValue else {
                    continue
                }
                _fetchedConfig[FIRNamespace][key] =
                FIRRemoteConfigValue(data: value.dataValue, source: source)
                let values = [_bundleIdentifier, FIRNamespace, key, value.dataValue] as [Any]
                
            }
        }

        
    }
    
    func checkAndWaitForInitialDatabaseLoad() -> Bool {
      RCN_MUST_NOT_BE_MAIN_THREAD()
      
        // Block all further calls to active/fetched/default
        // configs until load is done.
        if (!_isConfigLoadFromDBCompleted) {
            let _ = _dispatch_group.wait(timeout: .now() + kDatabaseLoadTimeoutSecs)
        }
        
        _isConfigLoadFromDBCompleted = true;
        return true
    }
    
    //MARK - DB
    
    func updateMainTableWithValues(values: [Any], fromSource: RCNDBSource) {
       _DBManager?.insertMainTableWithValues(values: values, fromSource: source, completionHandler: nil)
    }
    
    //MARK - Update
    func copyFromDictionary(from fromDict: [String : Any], toSource toSource: RCNDBSource, forNamespace: String) {
        if !fromDict.isEmpty {
            FIRLogError(RCNRemoteConfigQueueLabel, "I-RCN000007",
                        "The source dictionary to copy from does not exist.")
            return;
        }
        
        var toDict = NSMutableDictionary()
        var source : FIRRemoteConfigSource = .remote
        switch toSource {
            case .default:
                toDict = _defaultConfig;
                break;
            case .fetched:
                FIRLogWarning(RCNRemoteConfigQueueLabel, "I-RCN000008",
                              "This shouldn't happen. Destination dictionary should never be pending type.")
                return;
            case .active:
                toDict = _activeConfig;
                [toDict removeAllObjects];
                break;
            default:
                toDict = _activeConfig;
                [toDict removeAllObjects];
                break;
        }
    }

    func updateConfigContentWithResponse(response: [String : Any], forNamespace currentNamespace: String) {
        // Make sure database load has completed.
        checkAndWaitForInitialDatabaseLoad()
        guard let state = response[RCNFetchResponseKeyState] as? String else {
            return
        }

        FIRLogDebug(RCNRemoteConfigQueueLabel, "I-RCN000059",
                    "Updating config content from Response for namespace:\(currentNamespace) with state: %@",
                    response[RCNFetchResponseKeyState] ?? "")

        if state == RCNFetchResponseKeyStateNoChange {
            handleNoChangeStateForConfigNamespace(currentNamespace: currentNamespace)
        } else if state == RCNFetchResponseKeyStateEmptyConfig {
            handleEmptyConfigStateForConfigNamespace(currentNamespace: currentNamespace)
            return;
        } else if ([state isEqualToString:RCNFetchResponseKeyStateNoTemplate]) {
          handleNoTemplateStateForConfigNamespace(currentNamespace: currentNamespace)
          return;
        } else if ([state isEqualToString:RCNFetchResponseKeyStateUpdate]) {
          handleUpdateStateForConfigNamespace(currentNamespace: currentNamespace, withEntries: response[RCNFetchResponseKeyEntries] as! [String : String])
          handleUpdatePersonalization(metadata: response[RCNFetchResponseKeyPersonalizationMetadata] as? [String : Any])
          handleUpdateRolloutFetchedMetadata(metadata: response[RCNFetchResponseKeyRolloutMetadata] as? [NSDictionary])
          return;
        }
      return;
    }
  
    // MARK: - Private
    
    func handleNoChangeStateForConfigNamespace(currentNamespace: String) {
        if _fetchedConfig[currentNamespace] == nil {
            _fetchedConfig[currentNamespace] = [[NSMutableDictionary alloc] init];
        }
    }

    func handleEmptyConfigStateForConfigNamespace(currentNamespace: String) {
        if (_fetchedConfig[currentNamespace] != nil) {
            _fetchedConfig[currentNamespace].removeAllObjects()
        } else {
          // If namespace has empty status and it doesn't exist in _fetchedConfig, we will
          // still add an entry for that namespace. Even if it will not be persisted in database.
          // TODO: Add generics for all collection types.
          _fetchedConfig[currentNamespace] = [[NSMutableDictionary alloc] init];
        }
      _DBManager?.deleteRecordFromMainTable(namespace: currentNamespace,
                                             bundleIdentifier: _bundleIdentifier,
                                             fromSource: .fetched);
    }

    func handleNoTemplateStateForConfigNamespace(currentNamespace: String) {
      // Remove the namespace.
      _fetchedConfig.removeValue(forKey: currentNamespace)
      _DBManager?.deleteRecordFromMainTable(namespace: currentNamespace,
                                             bundleIdentifier: _bundleIdentifier,
                                             fromSource: .fetched);
    }

    func handleUpdateStateForConfigNamespace(currentNamespace: String, withEntries: [String: String]) {
        FIRLogDebug(RCNRemoteConfigQueueLabel, "I-RCN000058", "Update config in DB for namespace:\(currentNamespace)");
        // Clear before updating
        _DBManager?.deleteRecordFromMainTable(namespace: currentNamespace,
                                               bundleIdentifier: _bundleIdentifier,
                                               fromSource: .fetched);
        if (_fetchedConfig[currentNamespace] != nil) {
            _fetchedConfig[currentNamespace].removeAllObjects();
        } else {
            _fetchedConfig[currentNamespace] = [[NSMutableDictionary alloc] init];
        }

        // Store the fetched config values.
        for key in entries.keys {
            let valueData = entries[key]?.data(using: .utf8)
            _fetchedConfig[currentNamespace][key] = FIRRemoteConfigValue(data: valueData, source: .remote)
            let values = [_bundleIdentifier, FIRNamespace, key, valueData] as [Any];
        }
    }

    func handleUpdatePersonalization(metadata: [String : Any]?) {
      if metadata == nil {
        return;
      }
      _fetchedPersonalization = metadata ?? [:]
      [_DBManager insertOrUpdatePersonalizationConfig:metadata ?? [:] fromSource: .fetched]
    }

    func handleUpdateRolloutFetchedMetadata(metadata: [NSDictionary]?) {
      if (metadata == nil) {
        return
      }
        _fetchedRolloutMetadata = metadata ?? []
        [_DBManager insertOrUpdateRolloutTableWithKey:RCNRolloutTableKeyFetchedMetadata
                                            value:_fetchedRolloutMetadata completionHandler:nil];
    }
    
    func initializationSuccessful() -> Bool{
        return true
    }
    
    //MARK - Get Config
    
    func defaultValueForFullyQualifiedNamespace(namespace:String, key:String) -> FIRRemoteConfigValue{
        let value = self.defaultConfig[namespace]?[key];
        if value == nil {
            return FIRRemoteConfigValue(data: Data(), source: .static);
        }
        return value ?? FIRRemoteConfigValue(data: Data(), source: .static)
    }

    func checkAndWaitForInitialDatabaseLoad() -> Bool {
        /// Wait until load is done. This should be a no-op for subsequent calls.
        if (!_isConfigLoadFromDBCompleted) {
          let _ = _dispatch_group.wait(timeout: DispatchTime.now() + kDatabaseLoadTimeoutSecs)
          // Wait until load is done. This should be a no-op for subsequent calls.
          //_isConfigLoadFromDBCompleted = true
        }
        return true
    }
    
    //MARK - update main table
    func updateMainTableWithValues(values: [Any], fromSource: RCNDBSource) {
        _DBManager?.insertMainTableWithValues(values: values, fromSource: .fetched, completionHandler: nil)
    }
    
    
    func updateConfigContent(response: [String : Any], forNamespace currentNamespace: String) {
        // Make sure database load has completed.
        checkAndWaitForInitialDatabaseLoad()
        guard let state = response[RCNFetchResponseKeyState] as? String else {
            return
        }
      
        FIRLogDebug(RCNRemoteConfigQueueLabel, "I-RCN000059",
                    "Updating config content from Response for namespace:\(currentNamespace) with state: %@",
                    response[RCNFetchResponseKeyState] ?? "")

        if state == RCNFetchResponseKeyStateNoChange {
            handleNoChangeStateForConfigNamespace(currentNamespace: currentNamespace)
        } else if state == RCNFetchResponseKeyStateEmptyConfig {
          handleEmptyConfigStateForConfigNamespace(currentNamespace: currentNamespace)
          return;
        } else if ([state isEqualToString:RCNFetchResponseKeyStateNoTemplate]) {
          handleNoTemplateStateForConfigNamespace(currentNamespace: currentNamespace)
          return;
        } else if ([state isEqualToString:RCNFetchResponseKeyStateUpdate]) {
          handleUpdateStateForConfigNamespace(currentNamespace: currentNamespace,
                                              withEntries: response[RCNFetchResponseKeyEntries] as! [String : String])
          handleUpdatePersonalization(metadata: response[RCNFetchResponseKeyPersonalizationMetadata] as? [String : Any])
          handleUpdateRolloutFetchedMetadata(metadata: response[RCNFetchResponseKeyRolloutMetadata] as? [NSDictionary])
          return;
        }
    }
    
    func handleNoChangeStateForConfigNamespace(currentNamespace: String) {
        if _fetchedConfig[currentNamespace] == nil {
          _fetchedConfig[currentNamespace] = NSMutableDictionary()
        }
    }

    func handleEmptyConfigStateForConfigNamespace(currentNamespace: String) {
        if _fetchedConfig[currentNamespace] != nil {
            _fetchedConfig[currentNamespace].removeAllObjects()
        } else {
          // If namespace has empty status and it doesn't exist in _fetchedConfig, we will
          // still add an entry for that namespace. Even if it will not be persisted in database.
          // TODO: Add generics for all collection types.
          _fetchedConfig[currentNamespace] = NSMutableDictionary()
        }
        _DBManager?.deleteRecordFromMainTable(namespace: currentNamespace, bundleIdentifier: _bundleIdentifier, fromSource: .fetched)
    }

    func handleNoTemplateStateForConfigNamespace(currentNamespace: String) {
      // Remove the namespace.
      _fetchedConfig.removeValue(forKey: currentNamespace)
      _DBManager?.deleteRecordFromMainTable(namespace: currentNamespace,
                                             bundleIdentifier: _bundleIdentifier,
                                             fromSource: .fetched);
    }

    func handleUpdateStateForConfigNamespace(currentNamespace: String, withEntries: [String: String]) {
      FIRLogDebug(RCNRemoteConfigQueueLabel, "I-RCN000058", "Update config in DB for namespace:\(currentNamespace)");
      // Clear before updating
      _DBManager?.deleteRecordFromMainTable(namespace: currentNamespace,
                                             bundleIdentifier: _bundleIdentifier, fromSource: .fetched);
        if _fetchedConfig[currentNamespace] != nil) {
            _fetchedConfig[currentNamespace].removeAllObjects()
        } else {
            _fetchedConfig[currentNamespace] = NSMutableDictionary()
        }

      // Store the fetched config values.
      for key in entries.keys {
        let valueData = entries[key]?.data(using: .utf8)
        _fetchedConfig[currentNamespace][key] = FIRRemoteConfigValue(data: valueData, source: .remote)
        let values = [_bundleIdentifier, FIRNamespace, key, valueData] as [Any];
      }
    }

    func handleUpdatePersonalization(metadata: [String : Any]?) {
        _fetchedPersonalization = metadata ?? [:]
        _DBManager?.insertOrUpdatePersonalizationConfig(metadata ?? [:], fromSource: .fetched)
    }
    
    func handleUpdateRolloutFetchedMetadata(metadata: [NSDictionary]?) {
        if (metadata == nil) {
            return
        }
        _fetchedRolloutMetadata = metadata ?? []
        [_DBManager insertOrUpdateRolloutTableWithKey:RCNRolloutTableKeyFetchedMetadata
                                         value:_fetchedRolloutMetadata completionHandler:nil];
    }
    
    func initializationSuccessful() -> Bool {
      return true
    }
    
    //MARK: - Helpers
    func checkAndWaitForInitialDatabaseLoad() -> Bool{
        
        if (!_isConfigLoadFromDBCompleted) {
          let _ = _dispatch_group.wait(timeout: DispatchTime.now() + kDatabaseLoadTimeoutSecs)
            // Wait until load is done. This should be a no-op for subsequent calls.
            //_isConfigLoadFromDBCompleted = true
        }
        return true
    }
    
    //MARK: - Get config result
    
    func defaultValueForFullyQualifiedNamespace(namespace:String, key:String) -> FIRRemoteConfigValue{
        let value = self.defaultConfig[namespace]?[key];
        if value == nil {
            return FIRRemoteConfigValue(data: Data(), source: .static);
        }
        return value ?? FIRRemoteConfigValue(data: Data(), source: .static)
    }
}
