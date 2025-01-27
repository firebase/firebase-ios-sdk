import Foundation
import sqlite3

class RCNConfigDBManager {
    private var _database: OpaquePointer? = nil
    private var _databaseOperationQueue: DispatchQueue

    static let sharedInstance = RCNConfigDBManager()

    private var gIsNewDatabase: Bool = false

    init() {
        _databaseOperationQueue = DispatchQueue(label: "com.google.GoogleConfigService.database", qos: .default)
        createOrOpenDatabase()
    }

    func migrateV1NamespaceToV2Namespace() {
      for table in 0...2 {
        var tableName = ""
        switch table {
          case 0:
            tableName = RCNTableNameMain
            break
          case 1:
            tableName = RCNTableNameMainActive
            break
          case 2:
            tableName = RCNTableNameMainDefault
            break
          default:
            break
        }
        let SQLString = String(format: "SELECT namespace FROM %@ WHERE namespace NOT LIKE '%%:%%'",
                               tableName)
        let SQL = SQLString.utf8String
        let statement = prepareSQL(sql: SQL!)
        if statement == nil {
          return
        }
        var namespaceArray: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
          if let configNamespace = String(utf8String: String(cString: sqlite3_column_text(statement, 0))) {
            namespaceArray.append(configNamespace)
          }
        }
        sqlite3_finalize(statement)

        // Update.
        for namespaceToUpdate in namespaceArray {
          let newNamespace = String(format: "%@:%@", namespaceToUpdate, kFIRDefaultAppName)
          let updateSQLString = String(format: "UPDATE %@ SET namespace = ? WHERE namespace = ?", tableName)
          let updateSQL = updateSQLString.utf8String
          let updateStatement = prepareSQL(sql: updateSQL!)
          if updateStatement == nil {
            return
          }
          let updateParams = [newNamespace, namespaceToUpdate]
          bindStringsToStatement(statement: updateStatement!, stringArray: updateParams)
          let result = sqlite3_step(updateStatement)
          if result != SQLITE_DONE {
              logError(sql: updateSQL, finalizeStatement: updateStatement, returnValue: false)
            return;
          }
          sqlite3_finalize(updateStatement)
        }
      }
    }
    
    func createOrOpenDatabase() {
        __weak RCNConfigDBManager *weakSelf = self;
        dispatch_async(_databaseOperationQueue, {
            let strongSelf = weakSelf;
            if strongSelf == nil {
                return;
            }
            let oldV0DBPath = RemoteConfigPathForOldDatabaseV0()
            // Backward Compatibility
            if FileManager.default.fileExists(atPath: oldV0DBPath) {
              FIRLogInfo(RCNRemoteConfigQueueLabel, "I-RCN000009",
                         "Old database V0 exists, removed it and replace with the new one.")
              strongSelf.removeDatabase(path: oldV0DBPath)
            }
            let dbPath = RCNConfigDBManager.remoteConfigPathForDatabase()
            FIRLogInfo(RCNRemoteConfigQueueLabel, "I-RCN000062", "Loading database at path \(dbPath)")
            let databasePath = dbPath.utf8String

            // Create or open database path.
            if !RemoteConfigCreateFilePathIfNotExist(filePath: dbPath) {
              return
            }
            
            var flags :Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
            #if SQLITE_OPEN_FILEPROTECTION_COMPLETEUNTILFIRSTUSERAUTHENTICATION
              flags |= SQLITE_OPEN_FILEPROTECTION_COMPLETEUNTILFIRSTUSERAUTHENTICATION
            #endif

          if sqlite3_open_v2(databasePath, &strongSelf->_database, Int32(flags), nil) == SQLITE_OK {
            // Always try to create table if not exists for backward compatibility.
            if !(strongSelf.createTableSchema()) {
              // Remove database before fail.
              strongSelf.removeDatabase(path: dbPath)
              FIRLogError(RCNRemoteConfigQueueLabel, "I-RCN000010", "Failed to create table.");
                // Create a new database if existing database file is corrupted.
                if (!RemoteConfigCreateFilePathIfNotExist(filePath: dbPath)) {
                  return
                }
            } else {
              // DB file already exists. Migrate any V1 namespace column entries to V2 fully qualified
              // 'namespace:FIRApp' entries.
              [self migrateV1NamespaceToV2Namespace];
              // Exclude the app data used from iCloud backup.
                RemoteConfigAddSkipBackupAttributeToItemAtPath(filePath: dbPath)
            }
          } else {
            strongSelf.logDatabaseError()
          }
        
        });
    }

  func logError(sql: String?, finalizeStatement: OpaquePointer?, returnValue: Bool) -> Bool {
      guard let statement = statement else {
          return false
      }
      var message: String = ""
      if let errorMessage = String(utf8String: sqlite3_errmsg(self._database)) {
        message = String(format: "%s", errorMessage)
      }
      FIRLogError(RCNRemoteConfigQueueLabel, "I-RCN000012", "Failed to execute query with error %s.",
                  [self errorMessage])
      return false
    }

  func logDatabaseError() {
      FIRLogError(RCNRemoteConfigQueueLabel, "I-RCN000015", "Error message: %@. Error code: %d.",
                  String(format: "%s", [self errorMessage]), self.errorCode())
    }

  func removeDatabase(path: String) {
    if sqlite3_close(_database) != SQLITE_OK {
      logDatabaseError()
    }

    _database = nil

    let fileManager = FileManager.default
    do {
      try fileManager.removeItem(atPath: path, error: nil)
    } catch {
      FIRLogError(RCNRemoteConfigQueueLabel, "I-RCN000011",
                  "Failed to remove database at path \(path) for error %@.", error)
    }
  }

    func logError(sql: String?, finalizeStatement: sqlite3_stmt?, returnValue: Bool) -> Bool {
        guard let statement = statement else {
            return false
        }
        let errorMessage: String = String(format:"%@", sqlite3_errmsg(self._database))
        
        FIRLogError(RCNRemoteConfigQueueLabel, "I-RCN000012", "Failed to execute query with error %s.",
                    String(format: "%@", errorMessage))
        
        
        if (statement != nil) {
          sqlite3_finalize(statement)
        }
        return returnValue
    }
    
    func logErrorWithSQL(sql: String?, finalizeStatement: OpaquePointer?, returnValue: Bool) -> Bool {
        guard let statement = statement else {
            return false
        }
        let errorMessage: String = String(format:"%@", sqlite3_errmsg(_database))
        FIRLogError(RCNRemoteConfigQueueLabel, "I-RCN000016", "Failed with SQL: %@", sql ?? "");
        FIRLogError(RCNRemoteConfigQueueLabel, "I-RCN000015", "Error message: %@. Error code: %d.", errorMessage, self.errorCode())
        
        
        if (statement != nil) {
          sqlite3_finalize(statement)
        }
        
        return returnValue
    }

    func bindStringsToStatement(statement: OpaquePointer?, stringArray: [String]) -> Bool {
      var index = 1
      for value in array {
        if !bindStringToStatement(statement: statement, index: index, string: value) {
          return false
        }
        index+=1
      }
        return true
    }

    func bindStringToStatement(statement: OpaquePointer?, index: Int, string: String) -> Bool {
        if sqlite3_bind_text(statement, Int32(index), value.utf8String!, -1, SQLITE_TRANSIENT) != SQLITE_OK {
            return false
        }
        return true
    }
    
    func executeQuery(SQL: String?) -> Bool{
        return false
    }
    
    func createTableSchema() -> Bool {
      let createTableMain =
        "create TABLE IF NOT EXISTS \(RCNTableNameMain) (_id INTEGER PRIMARY KEY, bundle_identifier TEXT, namespace TEXT, key TEXT, value BLOB)"

      let createTableMainActive =
          "create TABLE IF NOT EXISTS \(RCNTableNameMainActive) (_id INTEGER PRIMARY KEY, bundle_identifier TEXT, namespace TEXT, key TEXT, value BLOB)"

      let createTableMainDefault =
          "create TABLE IF NOT EXISTS \(RCNTableNameMainDefault) (_id INTEGER PRIMARY KEY, bundle_identifier TEXT, namespace TEXT, key TEXT, value BLOB)"

      let createTableMetadata =
          "create TABLE IF NOT EXISTS \(RCNTableNameMetadata) (_id INTEGER PRIMARY KEY, bundle_identifier TEXT, namespace TEXT, fetch_time INTEGER, digest_per_ns BLOB, device_context BLOB, app_context BLOB, success_fetch_time BLOB, failure_fetch_time BLOB, last_fetch_status INTEGER, last_fetch_error INTEGER, last_apply_time INTEGER, last_set_defaults_time INTEGER)"

      let createTableExperiment = "create TABLE IF NOT EXISTS \(RCNTableNameExperiment) (_id INTEGER PRIMARY KEY, key TEXT, value BLOB)"

      let createTablePersonalization =
          "create TABLE IF NOT EXISTS \(RCNTableNamePersonalization) (_id INTEGER PRIMARY KEY, key INTEGER, value BLOB)"

      let createTableRollout = "create TABLE IF NOT EXISTS \(RCNTableNameRollout) (_id INTEGER PRIMARY KEY, key TEXT, value BLOB)"
      
      return executeQuery(sql: createTableMain) &&
              executeQuery(sql: createTableMainActive) &&
              executeQuery(sql: createTableMainDefault) &&
              executeQuery(sql: createTableMetadata) &&
              executeQuery(sql: createTableExperiment) &&
              executeQuery(sql: createTablePersonalization) &&
              executeQuery(sql: createTableRollout)
    }
    
    func prepareSQL(sql: String?) -> OpaquePointer? {
        var statement: OpaquePointer? = nil
        if (sqlite3_prepare_v2(_database, sql?.utf8String!, -1, &statement, nil) != SQLITE_OK) {
            logError(sql: String(cString: sql!), finalizeStatement: statement, returnValue: false)
            return nil
        }
        return statement
    }
    
    func executeQuery(sql: String?) -> Bool {
        var error: UnsafeMutablePointer<Int8>? = nil
        if (sqlite3_exec(_database, sql?.utf8String!, nil, nil, &error) != SQLITE_OK) {
            FIRLogError(RCNRemoteConfigQueueLabel, "I-RCN000012", "Failed to execute query with error %@",String(cString: error!));
            return false;
        }
        return true
    }
    
    func bindStringsToStatement(statement: OpaquePointer?, stringArray: [String]) -> Bool {
      var index : Int = 1
        for param in array {
            if (!bindStringToStatement(statement: statement, index: index, string: param)) {
                return logError(sql: nil, finalizeStatement: statement, returnValue: false)
            }
            index+=1
        }
        return true;
    }
    
    func bindStringToStatement(statement: OpaquePointer?, index: Int, string: String) -> Bool {
        if sqlite3_bind_text(statement, Int32(index), value.utf8String!, -1, SQLITE_TRANSIENT) != SQLITE_OK {
            return false
        }
        return true
    }
    
    func errorMessage() -> String {
      return String(format: "%s", sqlite3_errmsg(_database))
    }
    
    func errorCode() -> Int {
      return sqlite3_errcode(_database)
    }
    
    func logError(sql: String?, finalizeStatement: OpaquePointer?, returnValue: Bool) -> Bool {
        if (statement != nil) {
          sqlite3_finalize(statement);
        }
        FIRLogError(RCNRemoteConfigQueueLabel, "I-RCN000016", "Failed with SQL: %@", sql ?? "");
      return false
    }
    
    func prepareSQL(sql: String?) -> OpaquePointer? {
      var statement: OpaquePointer? = nil
      if (sqlite3_prepare_v2(_database, sql?.utf8String, -1, &statement, nil) != SQLITE_OK) {
        logError(sql: sql, finalizeStatement: statement, returnValue: false)
        return nil
      }
      return statement
    }
    
    func removeDatabase(path: String) {
        if sqlite3_close(_database) != SQLITE_OK {
          logDatabaseError()
        }
      
        _database = nil;
        let fileManager = FileManager.default;
        var error: Error? = nil;
        
        do {
          try fileManager.removeItem(atPath: path, error: &error)
        } catch {
          FIRLogError(RCNRemoteConfigQueueLabel, "I-RCN000011",
                      "Failed to remove database at path \(path) for error %@.",
                      error?.localizedDescription ?? "");
        }
    }
    
    func bindStringToStatement(statement: OpaquePointer?, index: Int, string: String) -> Bool {
        if sqlite3_bind_text(statement, Int32(index), value.utf8String, -1, SQLITE_TRANSIENT) != SQLITE_OK {
            return false
        }
        return true
    }
    
    func errorMessage() -> String {
        return String(utf8String: sqlite3_errmsg(_database))
    }
    
    func errorCode() -> Int {
      return sqlite3_errcode(_database)
    }
    
    func logDatabaseError() {
      FIRLogError(RCNRemoteConfigQueueLabel, "I-RCN000015", "Error message: %@. Error code: %d.",
                  String(format: "%s", errorMessage()), errorCode())
    }
}
