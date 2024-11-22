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
import FirebaseCoreExtension
import Foundation
import SQLite3

@objc public enum UpdateOption: Int {
  case applyTime
  case defaultTime
  case fetchStatus
}

/// Column names in metadata table
let RCNKeyBundleIdentifier = "bundle_identifier"
let RCNKeyNamespace = "namespace"
let RCNKeyFetchTime = "fetch_time"
let RCNKeyDigestPerNamespace = "digest_per_ns"
let RCNKeyDeviceContext = "device_context"
let RCNKeyAppContext = "app_context"
let RCNKeySuccessFetchTime = "success_fetch_time"
let RCNKeyFailureFetchTime = "failure_fetch_time"
let RCNKeyLastFetchStatus = "last_fetch_status"
let RCNKeyLastFetchError = "last_fetch_error"
let RCNKeyLastApplyTime = "last_apply_time"
let RCNKeyLastSetDefaultsTime = "last_set_defaults_time"

/// SQLite file name in versions 0, 1 and 2.
private let RCNDatabaseName = "RemoteConfig.sqlite3"
/// The storage sub-directory that the Remote Config database resides in.
private let RCNRemoteConfigStorageSubDirectory = "Google/RemoteConfig"

// TODO: Delete all publics, opens, and objc's
// TODO: Convert all callback functions to `async` functions
// TODO: Consider deleting this file completely in favor of direct async calls to DatabaseActor.

/// Persist config data in sqlite database on device. Managing data read/write from/to database.
@objc(RCNConfigDBManager)
open class ConfigDBManager: NSObject {
  /// Shared Singleton Instance
  @objc public static let sharedInstance = ConfigDBManager()

  private let databaseActor: DatabaseActor

  @objc public var isNewDatabase: Bool = false

  @objc public init(dbPath: String = remoteConfigPathForDatabase()) {
    databaseActor = DatabaseActor(dbPath: dbPath)
    super.init()
  }

  /// Returns the current version of the Remote Config database.
  public static func remoteConfigPathForDatabase() -> String {
    #if os(tvOS)
      let dirPaths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
    #else
      let dirPaths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory,
                                                         .userDomainMask, true)
    #endif
    let storageDirPath = dirPaths[0]
    let dbPath = URL(fileURLWithPath: storageDirPath)
      .appendingPathComponent(RCNRemoteConfigStorageSubDirectory)
      .appendingPathComponent(RCNDatabaseName).path
    return dbPath
  }

  // MARK: - Insert

  @objc public
  func insertMetadataTable(withValues columnNameToValue: [String: Any],
                           completionHandler handler: ((Bool, [String: AnyHashable]?) -> Void)? =
                             nil) {
    Task { // Use Task to call the actor method asynchronously
      let success = await self.databaseActor.insertMetadataTable(withValues: columnNameToValue)
      if let handler {
        handler(success, nil) // Call the completion handler
      }
    }
  }

  @objc public
  func insertMainTable(withValues values: [Any],
                       fromSource source: DBSource,
                       completionHandler handler: ((Bool, [String: AnyHashable]?) -> Void)? = nil) {
    Task { // Use Task to call the actor method asynchronously
      let success = await self.databaseActor.insertMainTable(withValues: values, fromSource: source)
      if let handler {
        handler(success, nil) // Call the completion handler
      }
    }
  }

  @objc public
  func insertInternalMetadataTable(withValues values: [Any],
                                   completionHandler handler: ((Bool, [String: AnyHashable]?)
                                     -> Void)? = nil) {
    Task { // Use Task to call the actor method asynchronously
      let success = await self.databaseActor.insertInternalMetadataTable(withValues: values)
      if let handler {
        handler(success, nil) // Call the completion handler
      }
    }
  }

  @objc public
  func insertExperimentTable(withKey key: String,
                             value serializedValue: Data,
                             completionHandler handler: ((Bool, [String: AnyHashable]?) -> Void)? =
                               nil) {
    Task { // Use Task to call the actor method asynchronously
      let success = key == ConfigConstants.experimentTableKeyMetadata ?
        await self.databaseActor.update(experimentMetadata: serializedValue) :
        await self.databaseActor.insertExperimentTable(withKey: key, value: serializedValue)
      if let handler {
        handler(success, nil) // Call the completion handler
      }
    }
  }

  @objc public
  func insertOrUpdatePersonalizationConfig(_ dataValue: [String: Any],
                                           fromSource source: DBSource) {
    do {
      let payload = try JSONSerialization.data(withJSONObject: dataValue,
                                               options: .prettyPrinted)
      Task {
        await databaseActor.insertOrUpdatePersonalizationConfig(payload, fromSource: source)
      }
    } catch {
      RCLog.error("I-RCN000075",
                  "Invalid Personalization payload to be serialized.")
    }
  }

  @objc public
  func insertOrUpdateRolloutTable(withKey key: String,
                                  value metadataList: [[String: Any]],
                                  completionHandler handler: ((Bool, [String: AnyHashable]?)
                                    -> Void)? = nil) {
    Task { // Use Task to call the actor method asynchronously
      let success = await self.databaseActor.insertOrUpdateRolloutTable(
        withKey: key,
        value: metadataList
      )
      if let handler {
        handler(success, nil) // Call the completion handler
      }
    }
  }

  // MARK: - Update

  @objc public
  func updateMetadata(withOption option: UpdateOption,
                      namespace: String,
                      values: [Any],
                      completionHandler handler: ((Bool, [String: AnyHashable]?) -> Void)? = nil) {
    Task { // Use Task to call the actor method asynchronously
      let success = await self.databaseActor.updateMetadataTable(withOption: option,
                                                                 namespace: namespace,
                                                                 values: values)
      if let handler {
        handler(success, nil) // Call the completion handler
      }
    }
  }

  // MARK: - Load from DB

  @objc public
  func loadMetadata(withBundleIdentifier bundleIdentifier: String,
                    namespace: String,
                    completionHandler handler: @escaping (([String: Sendable]) -> Void)) {
    Task { // Use Task to call the actor method asynchronously
      let table = await self.databaseActor.loadMetadataTable(withBundleIdentifier: bundleIdentifier,
                                                             namespace: namespace)
      handler(table) // Call the completion handler
    }
  }

  // MARK: - Load

  @objc public
  func loadMain(withBundleIdentifier bundleIdentifier: String,
                completionHandler handler: ((Bool, [String: AnyHashable]?,
                                             [String: AnyHashable]?, [String: Any]?,
                                             [String: Any]?) -> Void)? = nil) {
    Task {
      let fetchedConfig = await self.databaseActor.loadMainTable(
        withBundleIdentifier: bundleIdentifier,
        fromSource: .fetched
      )
      let activeConfig = await self.databaseActor.loadMainTable(
        withBundleIdentifier: bundleIdentifier,
        fromSource: .active
      )
      let defaultConfig = await self.databaseActor.loadMainTable(
        withBundleIdentifier: bundleIdentifier,
        fromSource: .default
      )
      let fetchedRolloutMetadata = await self.databaseActor.loadRolloutTable(
        fromKey: ConfigConstants.rolloutTableKeyFetchedMetadata
      )
      let activeRolloutMetadata = await self.databaseActor.loadRolloutTable(
        fromKey: ConfigConstants.rolloutTableKeyActiveMetadata
      )
      if let handler {
        handler(true, fetchedConfig, activeConfig, defaultConfig, [
          ConfigConstants.rolloutTableKeyFetchedMetadata: fetchedRolloutMetadata,
          ConfigConstants.rolloutTableKeyActiveMetadata: activeRolloutMetadata,
        ])
      }
    }
  }

  @objc public
  func loadExperiment(completionHandler handler: ((Bool, [String: Sendable]?) -> Void)? = nil) {
    Task {
      let experimentPayloads = await self.databaseActor.loadExperimentTable(
        fromKey: ConfigConstants.experimentTableKeyPayload
      ) ?? []

      let metadata = await self.databaseActor.loadExperimentTable(
        fromKey: ConfigConstants.experimentTableKeyMetadata
      ) ?? []

      let experimentMetadata =
        if let experiments = metadata.first,
        // There should be only one entry for experiment metadata.
        let object =
        try? JSONSerialization.jsonObject(with: experiments,
                                          options: .mutableContainers) as? [String: Sendable] {
          object
        } else {
          [String: String]()
        }
      let activeExperimentPayloads = (await self.databaseActor.loadExperimentTable(
        fromKey: ConfigConstants.experimentTableKeyActivePayload
      ) ?? [])
      if let handler {
        handler(true, [
          ConfigConstants.experimentTableKeyPayload: experimentPayloads,
          ConfigConstants.experimentTableKeyMetadata: experimentMetadata,
          ConfigConstants.experimentTableKeyActivePayload: activeExperimentPayloads,
        ])
      }
    }
  }

  @objc public
  func loadPersonalization(completionHandler handler: ((Bool, [String: AnyHashable]?,
                                                        [String: AnyHashable]?, [String: Any]?,
                                                        [String: Any]?) -> Void)? = nil) {
    Task {
      let activePersonalizationData =
        await self.databaseActor.loadPersonalizationTable(fromKey: DBSource.active.rawValue)
      let activePersonalization =
        if let activePersonalizationData,
        let object =
        try? JSONSerialization
          .jsonObject(with: activePersonalizationData, options: []) as? [String: String] {
          object
        } else {
          [String: String]()
        }
      let fetchedPersonalizationData =
        await self.databaseActor.loadPersonalizationTable(fromKey: DBSource.fetched.rawValue)
      let fetchedPersonalization =
        if let fetchedPersonalizationData,
        let object =
        try? JSONSerialization
          .jsonObject(with: fetchedPersonalizationData, options: []) as? [String: String] {
          object
        } else {
          [String: String]()
        }
      if let handler {
        handler(true, fetchedPersonalization, activePersonalization, [:], [:])
      }
    }
  }

  @objc public
  func loadInternalMetadataTable(completionHandler handler: @escaping (([String: Data]) -> Void)) {
    Task {
      let metadata = await self.databaseActor.loadInternalMetadataTableInternal()
      handler(metadata)
    }
  }

  // MARK: - Delete

  @objc public
  func deleteRecord(fromMainTableWithNamespace namespace: String,
                    bundleIdentifier: String,
                    fromSource source: DBSource) {
    let params = [bundleIdentifier, namespace]
    let sql =
      if source == .default {
        "DELETE FROM main_default WHERE bundle_identifier = ? and namespace = ?"
      } else if source == .active {
        "DELETE FROM main_active WHERE bundle_identifier = ? and namespace = ?"
      } else {
        "DELETE FROM main WHERE bundle_identifier = ? and namespace = ?"
      }
    Task {
      await self.databaseActor.executeQuery(sql, withParams: params)
    }
  }

  @objc public
  func deleteRecord(withBundleIdentifier bundleIdentifier: String,
                    namespace: String) {
    let sql = "DELETE FROM fetch_metadata_v2 WHERE bundle_identifier = ? and namespace = ?"
    let params = [bundleIdentifier, namespace]
    Task {
      await self.databaseActor.executeQuery(sql, withParams: params)
    }
  }

  @objc public
  func deleteAllRecords(fromTableWithSource source: DBSource) {
    let sql =
      if source == .default {
        "DELETE FROM main_default"
      } else if source == .active {
        "DELETE FROM main_active"
      } else {
        "DELETE FROM main"
      }
    Task {
      await self.databaseActor.executeQuery(sql)
    }
  }

  @objc public
  func deleteExperimentTable(forKey key: String) {
    let params = [key]
    let sql = "DELETE FROM experiment WHERE key = ?"
    Task {
      await self.databaseActor.executeQuery(sql, withParams: params)
    }
  }

  // MARK: - for unit tests

  @objc public func removeDatabase(path: String) {
    Task {
      await databaseActor.removeDatabase(atPath: path)
    }
  }

  @objc func createOrOpenDatabase() {
    Task {
      await databaseActor.createOrOpenDatabase()
    }
  }
}
