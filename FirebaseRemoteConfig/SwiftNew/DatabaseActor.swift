// Copyright 2023 Google LLC
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
import SQLite3

import FirebaseCoreExtension

/// SQLite file name in versions 0, 1 and 2.
private let RCNDatabaseName = "RemoteConfig.sqlite3"

// Actor for database operations
actor DatabaseActor {
  private var database: OpaquePointer?
  private var isNewDatabase: Bool = false
  private let dbPath: String

  init(dbPath: String) {
    self.dbPath = dbPath
    Task {
      await createOrOpenDatabase()
    }
  }

  func createOrOpenDatabase() {
    let oldV0DBPath = remoteConfigPathForOldDatabaseV0()
    // Backward Compatibility
    if FileManager.default.fileExists(atPath: oldV0DBPath) {
      RCLog.info("I-RCN000009",
                 "Old database V0 exists, removed it and replace with the new one.")
      removeDatabase(atPath: oldV0DBPath)
    }
    RCLog.info("I-RCN000062", "Loading database at path \(dbPath)")
    let cDbPath = (dbPath as NSString).utf8String

    // Create or open database path.
    if !createFilePath(ifNotExist: dbPath) {
      return
    }

    let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX |
      SQLITE_OPEN_FILEPROTECTION_COMPLETEUNTILFIRSTUSERAUTHENTICATION
    if sqlite3_open_v2(cDbPath, &database, flags, nil) == SQLITE_OK {
      // Always try to create table if not exists for backward compatibility.
      if !createTableSchema() {
        // Remove database before failing.
        removeDatabase(atPath: dbPath)
        // If it failed again, there's nothing we can do here.
        RCLog.error("I-RCN000010", "Failed to create table.")
        // Create a new database if existing database file is corrupted.
        if !createFilePath(ifNotExist: dbPath) {
          return
        }
        if sqlite3_open_v2(cDbPath, &database, flags, nil) == SQLITE_OK {
          if !createTableSchema() {
            // Remove database before fail.
            removeDatabase(atPath: dbPath)
            // If it failed again, there's nothing we can do here.
            RCLog.error("I-RCN000010", "Failed to create table.")
          } else {
            // Exclude the app data used from iCloud backup.
            addSkipBackupAttribute(toItemAtPath: dbPath)
          }
        } else {
          logDatabaseError()
        }
      } else {
        // DB file already exists. Migrate any V1 namespace column entries to V2 fully qualified
        // 'namespace:FIRApp' entries.
        migrateV1NamespaceToV2Namespace()
        // Exclude the app data used from iCloud backup.
        addSkipBackupAttribute(toItemAtPath: dbPath)
      }
    } else {
      logDatabaseError()
    }
  }

  func insertMetadataTable(withValues columnNameToValue: [String: Any]) -> Bool {
    let sql = """
    INSERT into fetch_metadata_v2 (\
      bundle_identifier, \
      namespace, \
      fetch_time, \
      digest_per_ns, \
      device_context, \
      app_context, \
      success_fetch_time, \
      failure_fetch_time, \
      last_fetch_status, \
      last_fetch_error, \
      last_apply_time, \
      last_set_defaults_time\
    ) values (\
      ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?\
    )
    """
    var statement: OpaquePointer? = nil
    defer { sqlite3_finalize(statement) }

    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }

    let columns = [
      RCNKeyBundleIdentifier, RCNKeyNamespace, RCNKeyFetchTime, RCNKeyDigestPerNamespace,
      RCNKeyDeviceContext, RCNKeyAppContext, RCNKeySuccessFetchTime, RCNKeyFailureFetchTime,
      RCNKeyLastFetchStatus, RCNKeyLastFetchError, RCNKeyLastApplyTime, RCNKeyLastSetDefaultsTime,
    ]
    var index = 0
    for column in columns {
      index += 1
      switch column {
      case RCNKeyBundleIdentifier, RCNKeyNamespace:
        let value = columnNameToValue[column] as? String ?? ""
        if bindText(statement, Int32(index), value) != SQLITE_OK {
          return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
        }
      case RCNKeyFetchTime, RCNKeyLastApplyTime, RCNKeyLastSetDefaultsTime:
        let value = columnNameToValue[column] as? Double ?? 0
        if sqlite3_bind_double(statement, Int32(index), value) != SQLITE_OK {
          return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
        }
      case RCNKeyLastFetchStatus, RCNKeyLastFetchError:
        let value = columnNameToValue[column] as? Int ?? 0
        if sqlite3_bind_int(statement, Int32(index), Int32(value)) != SQLITE_OK {
          return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
        }
      default:
        let data = columnNameToValue[column] as? Data ?? Data()
        if sqlite3_bind_blob(statement, Int32(index), (data as NSData).bytes, Int32(data.count),
                             nil) != SQLITE_OK {
          return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
        }
      }
    }
    if sqlite3_step(statement) != SQLITE_DONE {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    return true
  }

  func insertMainTable(withValues values: [Any], fromSource source: DBSource) -> Bool {
    guard values.count == 4,
          let bundleIdentifier = values[0] as? String,
          let namespace = values[1] as? String,
          let key = values[2] as? String,
          let value = values[3] as? Data
    else {
      RCLog.error("I-RCN000013",
                  "Failed to insert config record. Wrong number of give parameters, current " +
                    "number is \(values.count), correct number is 4.")
      return false
    }

    let sql =
      switch source {
      case .active:
        """
        INSERT INTO main_active (bundle_identifier, namespace, key, value) \
        VALUES (?, ?, ?, ?)
        """
      case .default:
        """
        INSERT INTO main_default (bundle_identifier, namespace, key, value) \
        VALUES (?, ?, ?, ?)
        """
      case .fetched:
        """
        INSERT INTO main (bundle_identifier, namespace, key, value) \
        VALUES (?, ?, ?, ?)
        """
      }
    var statement: OpaquePointer? = nil
    defer { sqlite3_finalize(statement) }

    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }

    if bindText(statement, 1, bundleIdentifier) != SQLITE_OK ||
      bindText(statement, 2, namespace) != SQLITE_OK ||
      bindText(statement, 3, key) != SQLITE_OK ||
      sqlite3_bind_blob(statement, 4, (value as NSData).bytes, Int32(value.count), nil) !=
      SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    if sqlite3_step(statement) != SQLITE_DONE {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    return true
  }

  func insertInternalMetadataTable(withValues values: [Any]) -> Bool {
    guard values.count == 2,
          let key = values[0] as? String,
          let value = values[1] as? Data
    else {
      return false
    }
    let sql = """
    INSERT OR REPLACE INTO internal_metadata (key, value) \
    VALUES (?, ?)
    """
    var statement: OpaquePointer? = nil
    defer { sqlite3_finalize(statement) }

    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    if bindText(statement, 1, key) != SQLITE_OK ||
      sqlite3_bind_blob(statement, 2, (value as NSData).bytes, Int32(value.count), nil) != SQLITE_OK
    {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    if sqlite3_step(statement) != SQLITE_DONE {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    return true
  }

  func insertExperimentTable(withKey key: String, value dataValue: Data) -> Bool {
    let sql = "INSERT INTO experiment (key, value) values (?, ?)"
    var statement: OpaquePointer? = nil
    defer { sqlite3_finalize(statement) }

    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    if bindText(statement, 1, key) != SQLITE_OK ||
      sqlite3_bind_blob(statement, 2, (dataValue as NSData).bytes, Int32(dataValue.count), nil)
      != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }

    if sqlite3_step(statement) != SQLITE_DONE {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    return true
  }

  func insertOrUpdatePersonalizationConfig(_ payload: Data,
                                           fromSource source: DBSource) -> Bool {
    let sql = """
    INSERT OR REPLACE INTO personalization (_id, key, value) values ((
      SELECT _id from personalization WHERE key = ?
    ), ?, ?)
    """
    var statement: OpaquePointer? = nil
    defer { sqlite3_finalize(statement) }

    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    if sqlite3_bind_int(statement, 1, Int32(source.rawValue)) != SQLITE_OK ||
      sqlite3_bind_int(statement, 2, Int32(source.rawValue)) != SQLITE_OK ||
      sqlite3_bind_blob(statement, 3, (payload as NSData).bytes, Int32(payload.count), nil)
      != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    if sqlite3_step(statement) != SQLITE_DONE {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    return true
  }

  func update(experimentMetadata dataValue: Data) -> Bool {
    let sql = """
    INSERT OR REPLACE INTO experiment (_id, key, value) values ((
      SELECT _id from experiment WHERE key = ?), ?, ?)
    """
    var statement: OpaquePointer? = nil
    defer { sqlite3_finalize(statement) }

    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }

    if bindText(statement, 1, ConfigConstants.experimentTableKeyMetadata) != SQLITE_OK ||
      bindText(statement, 2, ConfigConstants.experimentTableKeyMetadata) != SQLITE_OK ||
      sqlite3_bind_blob(statement, 3, (dataValue as NSData).bytes, Int32(dataValue.count), nil)
      != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }

    if sqlite3_step(statement) != SQLITE_DONE {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    return true
  }

  func insertOrUpdateRolloutTable(withKey key: String,
                                  value arrayValue: [[String: Any]]) -> Bool {
    do {
      let dataValue = try JSONSerialization.data(withJSONObject: arrayValue,
                                                 options: .prettyPrinted)
      let sql = """
      INSERT OR REPLACE INTO rollout (_id, key, value) \
      VALUES ((SELECT _id from rollout WHERE key = ?), ?, ?)
      """
      var statement: OpaquePointer? = nil
      defer { sqlite3_finalize(statement) }

      if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
        return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
      }
      if bindText(statement, 1, key) != SQLITE_OK ||
        bindText(statement, 2, key) != SQLITE_OK ||
        sqlite3_bind_blob(statement, 3, (dataValue as NSData).bytes, Int32(dataValue.count),
                          nil) != SQLITE_OK {
        return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
      }

      if sqlite3_step(statement) != SQLITE_DONE {
        return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
      }
      return true
    } catch {
      return false
    }
  }

  func updateMetadataTable(withOption option: UpdateOption,
                           namespace: String,
                           values: [Any]) -> Bool {
    var sql: String
    switch option {
    case .applyTime:
      sql = "UPDATE fetch_metadata_v2 SET last_apply_time = ? WHERE namespace = ?"
    case .defaultTime:
      sql = "UPDATE fetch_metadata_v2 SET last_set_defaults_time = ? WHERE namespace = ?"
    case .fetchStatus:
      sql =
        "UPDATE fetch_metadata_v2 SET last_fetch_status = ?, last_fetch_error = ? WHERE namespace = ?"
    }

    var statement: OpaquePointer? = nil
    defer { sqlite3_finalize(statement) }

    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }

    var index = 0
    if option == .applyTime || option == .defaultTime, values.count == 1 {
      index += 1
      let value = values[0] as? Double ?? 0
      if sqlite3_bind_double(statement, Int32(index), value) != SQLITE_OK {
        return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
      }
    } else if option == .fetchStatus, values.count == 2 {
      for i in 0 ..< 2 {
        index += 1
        let value = values[i] as? Int ?? 0
        if sqlite3_bind_int(statement, Int32(index), Int32(value)) != SQLITE_OK {
          return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
        }
      }
    }
    index += 1
    if bindText(statement, Int32(index), namespace) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    if sqlite3_step(statement) != SQLITE_DONE {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    return true
  }

  func loadMetadataTable(withBundleIdentifier bundleIdentifier: String,
                         namespace: String) -> [String: Sendable] {
    let sql = """
    SELECT \
      bundle_identifier, \
      fetch_time, \
      digest_per_ns, \
      device_context, \
      app_context, \
      success_fetch_time, \
      failure_fetch_time, \
      last_fetch_status, \
      last_fetch_error, \
      last_apply_time, \
      last_set_defaults_time \
    FROM fetch_metadata_v2 \
    WHERE bundle_identifier = ? AND namespace = ?
    """
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: [:])
    }
    let params = [bundleIdentifier, namespace]
    if !bind(strings: params, toStatement: statement) {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: [:])
    }
    var result = [String: Any]()
    while sqlite3_step(statement) == SQLITE_ROW {
      let dbBundleIdentifier = String(cString: sqlite3_column_text(statement, 0))
      if dbBundleIdentifier != bundleIdentifier {
        RCLog.error("I-RCN000014",
                    "Load Metadata from table error: Wrong package name \(dbBundleIdentifier), " +
                      "should be \(bundleIdentifier).")
        return [:]
      }

      let fetchTime = sqlite3_column_double(statement, 1)
      let digestPerNamespace = Data(bytes: sqlite3_column_blob(statement, 2),
                                    count: Int(sqlite3_column_bytes(statement, 2)))
      let deviceContext = Data(bytes: sqlite3_column_blob(statement, 3),
                               count: Int(sqlite3_column_bytes(statement, 3)))
      let appContext = Data(bytes: sqlite3_column_blob(statement, 4),
                            count: Int(sqlite3_column_bytes(statement, 4)))
      let successTimeDigest = Data(bytes: sqlite3_column_blob(statement, 5),
                                   count: Int(sqlite3_column_bytes(statement, 5)))
      let failureTimeDigest = Data(bytes: sqlite3_column_blob(statement, 6),
                                   count: Int(sqlite3_column_bytes(statement, 6)))
      let lastFetchStatus = sqlite3_column_int(statement, 7)
      let lastFetchFailReason = sqlite3_column_int(statement, 8)
      let lastApplyTimestamp = sqlite3_column_double(statement, 9)
      let lastSetDefaultsTimestamp = sqlite3_column_double(statement, 10)

      let deviceContextDict = try? JSONSerialization.jsonObject(with: deviceContext,
                                                                options: .mutableContainers) as? [
        String: Any
      ]

      let appContextDict = try? JSONSerialization.jsonObject(with: appContext,
                                                             options: .mutableContainers) as? [
        String: Any
      ]

      let digestPerNamespaceDictionary = try? JSONSerialization.jsonObject(with: digestPerNamespace,
                                                                           options: .mutableContainers)
        as? [String: Any]

      let successTimes = try? JSONSerialization.jsonObject(with: successTimeDigest,
                                                           options: .mutableContainers)
        as? [TimeInterval]

      let failureTimes = try? JSONSerialization.jsonObject(with: failureTimeDigest,
                                                           options: .mutableContainers)
        as? [TimeInterval]

      result[RCNKeyBundleIdentifier] = dbBundleIdentifier
      result[RCNKeyFetchTime] = fetchTime
      result[RCNKeyDigestPerNamespace] = digestPerNamespaceDictionary
      result[RCNKeyDeviceContext] = deviceContextDict
      result[RCNKeyAppContext] = appContextDict
      result[RCNKeySuccessFetchTime] = successTimes
      result[RCNKeyFailureFetchTime] = failureTimes
      result[RCNKeyLastFetchStatus] = Int(lastFetchStatus)
      result[RCNKeyLastFetchError] = Int(lastFetchFailReason)
      result[RCNKeyLastApplyTime] = lastApplyTimestamp
      result[RCNKeyLastSetDefaultsTime] = lastSetDefaultsTimestamp

      break // Stop after the first row, as there should only be one.
    }
    return result
  }

  func loadMainTable(withBundleIdentifier bundleIdentifier: String,
                     fromSource source: DBSource) -> [String: [String: RemoteConfigValue]] {
    var namespaceToConfig = [String: [String: RemoteConfigValue]]()
    let sql =
      switch source {
      case .active:
        "SELECT namespace, key, value FROM main_active WHERE bundle_identifier = ?"
      case .default:
        "SELECT namespace, key, value FROM main_default WHERE bundle_identifier = ?"
      case .fetched:
        "SELECT namespace, key, value FROM main WHERE bundle_identifier = ?"
      }

    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: [:])
    }

    if bindText(statement, 1, bundleIdentifier) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: [:])
    }

    while sqlite3_step(statement) == SQLITE_ROW {
      let configNamespace = String(cString: sqlite3_column_text(statement, 0))
      let key = String(cString: sqlite3_column_text(statement, 1))
      let valueData = Data(bytes: sqlite3_column_blob(statement, 2),
                           count: Int(sqlite3_column_bytes(statement, 2)))
      let value = RemoteConfigValue(
        data: valueData,
        source: source == .default ? .default : .remote
      )

      if namespaceToConfig[configNamespace] == nil {
        namespaceToConfig[configNamespace] = [:]
      }
      namespaceToConfig[configNamespace]?[key] = value
    }
    return namespaceToConfig
  }

  func loadExperimentTable(fromKey key: String) -> [Data]? {
    let sql = "SELECT value FROM experiment WHERE key = ?"
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: nil)
    }

    if bindText(statement, 1, key) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: nil)
    }
    var results = [Data]()
    while sqlite3_step(statement) == SQLITE_ROW {
      if let bytes = sqlite3_column_blob(statement, 0) {
        let valueData = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
        results.append(valueData)
      } else {
        results.append(Data())
      }
    }
    return results
  }

  func loadRolloutTable(fromKey key: String) -> [[String: Any]] {
    let sql = "SELECT value FROM rollout WHERE key = ?"
    var statement: OpaquePointer?
    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      logError(withSQL: sql, finalizeStatement: statement, returnValue: ())
    }
    defer { sqlite3_finalize(statement) }

    if bindText(statement, 1, key) != SQLITE_OK {
      logError(withSQL: sql, finalizeStatement: statement, returnValue: ())
    }
    var results = [Data]()
    while sqlite3_step(statement) == SQLITE_ROW {
      let valueData = Data(
        bytes: sqlite3_column_blob(statement, 0),
        count: Int(sqlite3_column_bytes(statement, 0))
      )
      results.append(valueData)
    }
    if let data = results.first {
      // Convert from NSData to NSArray
      if let rollout = try? JSONSerialization
        .jsonObject(with: data, options: []) as? [[String: Any]] {
        return rollout
      } else {
        RCLog.error("I-RCN000011",
                    "Failed to convert NSData to NSAarry for Rollout Metadata")
      }
    }

    return []
  }

  func loadPersonalizationTable(fromKey key: Int) -> Data? {
    let sql = "SELECT value FROM personalization WHERE key = ?"
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }

    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: nil)
    }

    if sqlite3_bind_int(statement, 1, Int32(key)) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: nil)
    }

    var results = [Data]()
    while sqlite3_step(statement) == SQLITE_ROW {
      let valueData = Data(bytes: sqlite3_column_blob(statement, 0),
                           count: Int(sqlite3_column_bytes(statement, 0)))
      results.append(valueData)
    }
    // There should be only one entry in this table.
    if results.count == 1 {
      return results[0]
    }
    return nil
  }

  func loadInternalMetadataTableInternal() -> [String: Data] {
    var internalMetadata = [String: Data]()
    let sql = "SELECT key, value FROM internal_metadata"
    var statement: OpaquePointer?
    defer { sqlite3_finalize(statement) }
    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      logError(withSQL: sql, finalizeStatement: statement, returnValue: ())
    }
    while sqlite3_step(statement) == SQLITE_ROW {
      let key = String(cString: sqlite3_column_text(statement, 0))
      let valueData = Data(bytes: sqlite3_column_blob(statement, 1),
                           count: Int(sqlite3_column_bytes(statement, 1)))
      internalMetadata[key] = valueData
    }
    return internalMetadata
  }

  private func migrateV1NamespaceToV2Namespace() {
    for table in ["main", "main_active", "main_default"] {
      let selectSQL = "SELECT namespace FROM \(table) WHERE namespace NOT LIKE '%%:%%'"
      var statement: OpaquePointer?
      if sqlite3_prepare_v2(database, selectSQL, -1, &statement, nil) != SQLITE_OK {
        logError(withSQL: selectSQL, finalizeStatement: statement, returnValue: ())
        return
      }

      var namespacesToUpdate = [String]()
      while sqlite3_step(statement) == SQLITE_ROW {
        let namespace = String(cString: sqlite3_column_text(statement, 0))
        namespacesToUpdate.append(namespace)
      }
      sqlite3_finalize(statement)

      var updateStatement: OpaquePointer?
      for namespaceToUpdate in namespacesToUpdate {
        let newNamespace = "\(namespaceToUpdate):\(kFIRDefaultAppName)"
        let updateSQL = "UPDATE \(table) SET namespace = ? WHERE namespace = ?"
        if sqlite3_prepare_v2(database, updateSQL, -1, &updateStatement, nil) != SQLITE_OK {
          logError(withSQL: updateSQL, finalizeStatement: updateStatement, returnValue: ())
          return
        }
        if bindText(updateStatement, 1, newNamespace) != SQLITE_OK ||
          bindText(updateStatement, 2, namespaceToUpdate) != SQLITE_OK {
          logError(withSQL: updateSQL, finalizeStatement: updateStatement, returnValue: ())
          return
        }
        if sqlite3_step(updateStatement) != SQLITE_DONE {
          logError(withSQL: updateSQL, finalizeStatement: updateStatement, returnValue: ())
          return
        }
        sqlite3_finalize(updateStatement)
      }
    }
  }

  private func createFilePath(ifNotExist filePath: String) -> Bool {
    if filePath.isEmpty {
      RCLog.error("I-RCN000018",
                  "Failed to create subdirectory for an empty file path.")
      return false
    }
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: filePath) {
      isNewDatabase = true
      do {
        try fileManager.createDirectory(
          atPath: URL(fileURLWithPath: filePath).deletingLastPathComponent().path,
          withIntermediateDirectories: true,
          attributes: nil
        )
      } catch {
        RCLog.error("I-RCN000019",
                    "Failed to create subdirectory for database file: \(error)")
        return false
      }
    }
    return true
  }

  private func createTableSchema() -> Bool {
    let createMain = """
    CREATE TABLE IF NOT EXISTS main (
      _id INTEGER PRIMARY KEY,
      bundle_identifier TEXT,
      namespace TEXT,
      key TEXT,
      value BLOB
    )
    """

    let createMainActive = """
    CREATE TABLE IF NOT EXISTS main_active (
      _id INTEGER PRIMARY KEY,
      bundle_identifier TEXT,
      namespace TEXT,
      key TEXT,
      value BLOB
    )
    """

    let createMainDefault = """
    CREATE TABLE IF NOT EXISTS main_default (
      _id INTEGER PRIMARY KEY,
      bundle_identifier TEXT,
      namespace TEXT,
      key TEXT,
      value BLOB
    )
    """

    let createMetadata = """
    CREATE TABLE IF NOT EXISTS fetch_metadata_v2 (
      _id INTEGER PRIMARY KEY,
      bundle_identifier TEXT,
      namespace TEXT,
      fetch_time INTEGER,
      digest_per_ns BLOB,
      device_context BLOB,
      app_context BLOB,
      success_fetch_time BLOB,
      failure_fetch_time BLOB,
      last_fetch_status INTEGER,
      last_fetch_error INTEGER,
      last_apply_time INTEGER,
      last_set_defaults_time INTEGER
    )
    """

    let createInternalMetadata = """
    CREATE TABLE IF NOT EXISTS internal_metadata (
      _id INTEGER PRIMARY KEY,
      key TEXT,
      value BLOB
    )
    """

    let createExperiment = """
    CREATE TABLE IF NOT EXISTS experiment (
      _id INTEGER PRIMARY KEY,
      key TEXT,
      value BLOB
    )
    """
    let createPersonalization = """
    CREATE TABLE IF NOT EXISTS personalization (
      _id INTEGER PRIMARY KEY,
      key INTEGER,
      value BLOB
    )
    """

    let createRollout = """
    CREATE TABLE IF NOT EXISTS rollout (
      _id INTEGER PRIMARY KEY,
      key TEXT,
      value BLOB
    )
    """
    return executeQuery(createMain) &&
      executeQuery(createMainActive) &&
      executeQuery(createMainDefault) &&
      executeQuery(createMetadata) &&
      executeQuery(createInternalMetadata) &&
      executeQuery(createExperiment) &&
      executeQuery(createPersonalization) &&
      executeQuery(createRollout)
  }

  func removeDatabase(atPath path: String) {
    if sqlite3_close(database) != SQLITE_OK {
      logDatabaseError()
    }
    database = nil

    do {
      try FileManager.default.removeItem(atPath: path)
    } catch {
      RCLog.error("I-RCN000011",
                  "Failed to remove database at path \(path) for error \(error).")
    }
  }

  func executeQuery(_ sql: String) -> Bool {
    var error: UnsafeMutablePointer<Int8>?
    if sqlite3_exec(database, sql, nil, nil, &error) != SQLITE_OK {
      RCLog.error("I-RCN000012",
                  "Failed to execute query with error \(error!).")
      sqlite3_free(error)
      return false
    }
    return true
  }

  func executeQuery(_ sql: String, withParams params: [String]) -> Bool {
    var statement: OpaquePointer? = nil
    defer { sqlite3_finalize(statement) }

    if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }

    if !bind(strings: params, toStatement: statement) {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }

    if sqlite3_step(statement) != SQLITE_DONE {
      return logError(withSQL: sql, finalizeStatement: statement, returnValue: false)
    }
    return true
  }

  /// Params only accept TEXT format string.
  private func bind(strings: [String], toStatement statement: OpaquePointer?) -> Bool {
    var index = 1
    for param in strings {
      if bindText(statement, Int32(index), param) != SQLITE_OK {
        return logError(withSQL: nil, finalizeStatement: statement, returnValue: false)
      }
      index += 1
    }
    return true
  }

  private func addSkipBackupAttribute(toItemAtPath filePathString: String) {
    let url = URL(fileURLWithPath: filePathString)
    assert(FileManager.default.fileExists(atPath: url.path))
    do {
      try (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
    } catch {
      RCLog.error("I-RCN000017",
                  "Error excluding \(url.lastPathComponent) from backup \(error).")
    }
  }

  // MARK: Fileprivate Helpers

  fileprivate func remoteConfigPathForOldDatabaseV0() -> String {
    let dirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    let docPath = dirPaths[0]
    return URL(fileURLWithPath: docPath).appendingPathComponent(RCNDatabaseName).path
  }

  // MARK: - Error Handling

  private func logError<T>(withSQL sql: String?,
                           finalizeStatement statement: OpaquePointer?,
                           returnValue: T) -> T {
    if let sql = sql {
      RCLog.error("I-RCN000016", "Failed with SQL: \(sql).")
    }
    logDatabaseError()

    if let statement = statement {
      sqlite3_finalize(statement)
    }

    return returnValue
  }

  private func logDatabaseError() {
    guard let database = database else { return }
    let msg = String(cString: sqlite3_errmsg(database))
    let code = sqlite3_errcode(database)
    RCLog.error("I-RCN000015", "Error message: \(msg). Error code: \(code).")
  }

  // MARK: Utility Functions

  private func bindText(_ statement: OpaquePointer!, _ index: Int32, _ value: String) -> Int32 {
    return sqlite3_bind_text(statement, index, (value as NSString).utf8String, -1, nil)
  }
}
