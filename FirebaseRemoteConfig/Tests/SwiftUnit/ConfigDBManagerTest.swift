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

import Dispatch
@testable import FirebaseRemoteConfig
import XCTest

class ConfigDBManagerTest: XCTestCase {
  let dbManager = ConfigDBManager()
  let bundleID = Bundle.main.bundleIdentifier!
  let namespace = "namespace"
  var filePath: String { ConfigDBManager.remoteConfigPathForDatabase() }

  override func setUp() {
    super.setUp()
    removeDatabase()
    createOrOpenDatabaseBlock()
  }

  override func tearDown() {
    removeDatabase()
    super.tearDown()
  }

  func testCreateOrOpenDBSuccess() {
    XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))
  }

  #if INVESTIGATE_RACE_CONDITION
    func testIsNewDatabase() async throws {
      // For a newly created DB, isNewDatabase should be true
      let isNew = dbManager.isNewDatabase
      XCTAssertTrue(isNew)
    }
  #endif

  func testLoadMainTableWithBundleIdentifier() throws {
    let config = [
      "key1": "value1",
      "key2": "value2",
    ]
    let data = try JSONSerialization.data(withJSONObject: config, options: [])
    let rcValue = RemoteConfigValue(data: data, source: .remote)
    let namespace = "namespace"

    let exp = expectation(description: #function)
    dbManager.insertMainTable(withValues: [bundleID, namespace, "key", rcValue.dataValue],
                              fromSource: .fetched) { success, _ in
      XCTAssertTrue(success)

      self.dbManager.loadMain(withBundleIdentifier: self.bundleID) { success, fetched, _, _, _ in
        XCTAssert(success)
        XCTAssertTrue(
          fetched[namespace]?["key"]?.stringValue == "{\"key1\":\"value1\",\"key2\":\"value2\"}" ||
            fetched[namespace]?["key"]?.stringValue == "{\"key2\":\"value2\",\"key1\":\"value1\"}"
        )
        exp.fulfill()
      }
    }
    waitForExpectations()
  }

  func testLoadMainTableWithBundleIdentifier_noData() {
    let exp = expectation(description: #function)
    dbManager.loadMain(withBundleIdentifier: bundleID) { success, fetched, _, _, _ in
      XCTAssert(success) // success should still be true.
      XCTAssertEqual(fetched, [:])
      exp.fulfill()
    }
    waitForExpectations()
  }

  func testLoadMetadataTableWithBundleIdentifier() throws {
    let exp = expectation(description: #function)
    let deviceContext = ["device": "info"]
    let appContext = ["app": "info"]
    let digestPerNamespace = ["digest": "info"]
    let deviceContextData = try JSONSerialization.data(withJSONObject: deviceContext, options: [])
    let appContextData = try JSONSerialization.data(withJSONObject: appContext, options: [])
    let digestPerNamespaceData = try JSONSerialization.data(withJSONObject: digestPerNamespace,
                                                            options: [])
    let columnNameToValue = try [
      RCNKeyBundleIdentifier: bundleID,
      RCNKeyNamespace: namespace,
      RCNKeyFetchTime: Date().timeIntervalSince1970,
      RCNKeyDigestPerNamespace: digestPerNamespaceData,
      RCNKeyDeviceContext: deviceContextData,
      RCNKeyAppContext: appContextData,
      RCNKeySuccessFetchTime: JSONSerialization.data(withJSONObject: [], options: []),
      RCNKeyFailureFetchTime: JSONSerialization.data(withJSONObject: [], options: []),
      RCNKeyLastFetchStatus: 0,
      RCNKeyLastFetchError: 0,
      RCNKeyLastApplyTime: Date().timeIntervalSince1970,
      RCNKeyLastSetDefaultsTime: Date().timeIntervalSince1970,
    ] as [String: Any]
    dbManager.insertMetadataTable(withValues: columnNameToValue) { success, _ in
      XCTAssertTrue(success)
      self.dbManager.loadMetadata(withBundleIdentifier: self.bundleID,
                                  namespace: self.namespace) { result in
        XCTAssertEqual(result[RCNKeyBundleIdentifier] as? String, self.bundleID)
        exp.fulfill()
      }
    }
    waitForExpectations()
  }

  func testLoadMetadataTableWithBundleIdentifierAndNamespace_noData() {
    let exp = expectation(description: #function)
    dbManager.loadMetadata(withBundleIdentifier: bundleID, namespace: namespace) { result in
      XCTAssertTrue(result.isEmpty)
      exp.fulfill()
    }
    waitForExpectations()
  }

  func testUpdateMetadataTable() async throws {
    try await insertMetadata()
    let values: [Any] = [1, 1] // Fetch Failure status.

    let success = await dbManager.databaseActor.updateMetadataTable(withOption: .fetchStatus,
                                                                    namespace: namespace,
                                                                    values: values)
    XCTAssertTrue(success)
    let result = await dbManager.databaseActor.loadMetadataTable(
      withBundleIdentifier: bundleID,
      namespace: namespace
    )
    XCTAssertEqual(result[RCNKeyLastFetchStatus] as? Int, 1)
    XCTAssertEqual(result[RCNKeyLastFetchError] as? Int, 1)
  }

  func testInsertInternalMetadataTable() {
    let exp = expectation(description: #function)
    let values: [Any] = [
      "\(bundleID):\(namespace):fetch_timeout",
      "100.2".data(using: .utf8)!,
    ]
    dbManager.insertInternalMetadataTable(withValues: values) { success, _ in
      XCTAssert(success)
      self.dbManager.loadInternalMetadataTable { result in
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(String(data: result[values[0] as! String]!, encoding: .utf8), "100.2")
        exp.fulfill()
      }
    }
    waitForExpectations()
  }

  func testLoadInternalMetadataTable_noData() {
    let exp = expectation(description: #function)
    dbManager.loadInternalMetadataTable { result in
      XCTAssertTrue(result.isEmpty)
      exp.fulfill()
    }
    waitForExpectations()
  }

  func testDeleteRecordsFromMainTableForNamespace() async throws {
    try await insertMainTableValue()

    await dbManager.databaseActor.deleteRecord(fromMainTableWithNamespace: namespace,
                                               bundleIdentifier: bundleID,
                                               fromSource: .fetched)
    let fetched = await dbManager.databaseActor.loadMainTable(
      withBundleIdentifier: bundleID,
      fromSource: .fetched
    )
    XCTAssertNil(fetched[namespace]?["key"])
  }

  func testDeleteAllRecordsFromMetadataTable() async throws {
    try await insertMetadata()
    await dbManager.databaseActor.deleteRecord(withBundleIdentifier: bundleID, namespace: namespace)
    let result = await dbManager.databaseActor.loadMetadataTable(withBundleIdentifier: bundleID,
                                                                 namespace: namespace)
    XCTAssertTrue(result.isEmpty)
  }

  func testDeleteAllRecordsFromMainTable() async throws {
    try await insertMainTableValue()

    await dbManager.databaseActor.deleteAllRecords(fromTableWithSource: .fetched)
    let fetched = await dbManager.databaseActor.loadMainTable(
      withBundleIdentifier: bundleID,
      fromSource: .fetched
    )
    XCTAssertTrue(fetched.isEmpty)
  }

  func testInsertExperimentTable() throws {
    let exp = expectation(description: #function)
    let experiment: [String: Any?] = [
      "experimentId": "experiment",
      "variantId": "variant",
      "triggerEvent": "fetch",
      "triggerTimeoutMillis": 15000,
      "timeToLiveMillis": 900_000,
      "setRolloutId": "id",
      "activateEvent": "activate",
      "assignmentTimeoutMillis": 45000,
      "clearEvent": nil,
    ]
    let experimentData = try JSONSerialization.data(withJSONObject: experiment, options: [])

    dbManager.insertExperimentTable(withKey: ConfigConstants.experimentTableKeyPayload,
                                    value: experimentData) { success, _ in
      XCTAssertTrue(success)

      self.dbManager.loadExperiment { success, result in
        let payloads = result?[ConfigConstants.experimentTableKeyPayload] as? [Data]
        XCTAssertEqual(payloads?.count, 1)

        let loadedExperiment = try! JSONSerialization.jsonObject(with: payloads![0], options: [])
          as! [String: Any]
        XCTAssertEqual(loadedExperiment["experimentId"] as? String, "experiment")
        XCTAssertEqual(loadedExperiment["timeToLiveMillis"] as? Int, 900_000)
        XCTAssertEqual(loadedExperiment["clearEvent"] as? NSNull, NSNull())
        exp.fulfill()
      }
    }
    waitForExpectations()
  }

  func testUpdateExperimentMetadata() throws {
    let exp = expectation(description: #function)
    let metadata = ["lastStartTime": 123]
    let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [])

    dbManager.insertExperimentTable(withKey: ConfigConstants.experimentTableKeyMetadata,
                                    value: metadataData) { success, _ in
      XCTAssertTrue(success)
      let newMetadata = ["lastStartTime": 456]
      let newMetadataData = try! JSONSerialization.data(withJSONObject: newMetadata, options: [])

      self.dbManager.insertExperimentTable(withKey: ConfigConstants.experimentTableKeyMetadata,
                                           value: newMetadataData) { success, _ in
        XCTAssertTrue(success)

        self.dbManager.loadExperiment { success, result in
          let experimentMetadata =
            result?[ConfigConstants.experimentTableKeyMetadata] as? [String: Int]
          XCTAssertEqual(experimentMetadata?["lastStartTime"], 456)
          exp.fulfill()
        }
      }
    }
    waitForExpectations()
  }

  func testLoadExperiment_noData() {
    let exp = expectation(description: #function)
    dbManager.loadExperiment { success, result in
      XCTAssertTrue(success) // success is still true
      let payloads = result?[ConfigConstants.experimentTableKeyPayload] as? [Data]
      XCTAssertEqual(payloads, [])
      let metadata = result?[ConfigConstants.experimentTableKeyMetadata] as? [String: Any]
      XCTAssertNotNil(metadata) // metadata is initialized even if DB is empty.
      exp.fulfill()
    }
    waitForExpectations()
  }

  func testDeleteExperimentTableForKey() async throws {
    try await insertExperiment()
    await dbManager.databaseActor
      .deleteExperimentTable(forKey: ConfigConstants.experimentTableKeyPayload)

    let result = await dbManager.databaseActor
      .loadExperimentTable(fromKey: ConfigConstants.experimentTableKeyPayload)
    XCTAssertEqual(result, [])
  }

  func testInsertPersonalizationTable() {
    let exp = expectation(description: #function)
    let personalization: [String: Any] = [
      "armKey": "value",
    ]
    dbManager.insertOrUpdatePersonalizationConfig(personalization, fromSource: .fetched)
    dbManager.loadPersonalization { success, fetchedPersonalization, _ in
      XCTAssertTrue(success)
      XCTAssertEqual(
        fetchedPersonalization as? [String: String],
        personalization as? [String: String]
      )
      exp.fulfill()
    }
    waitForExpectations()
  }

  func testLoadPersonalization_noData() {
    let exp = expectation(description: #function)
    dbManager.loadPersonalization { success, fetchedPersonalization, _ in
      XCTAssertTrue(success) // success is still true
      XCTAssertNotNil(fetchedPersonalization) // initialized even if DB is empty
      exp.fulfill()
    }
    waitForExpectations()
  }

  func testInsertRolloutTable() async {
    let rolloutMetadata: [[String: any Sendable]] = [[
      "rolloutId": "id",
      "variantId": "variant",
      "affectedParameterKeys": ["key1", "key2"],
    ]]
    let success = await dbManager.databaseActor.insertOrUpdateRolloutTable(
      withKey: ConfigConstants.rolloutTableKeyFetchedMetadata,
      value: rolloutMetadata
    )
    XCTAssertTrue(success)
    let activeMetadata =
      await dbManager.databaseActor.loadRolloutTable(
        fromKey: ConfigConstants.rolloutTableKeyFetchedMetadata
      )
    let metadata = activeMetadata[0]
    let rolloutId = metadata["rolloutId"] as? String
    XCTAssertEqual(rolloutId, "id")
    let param2 = (metadata["affectedParameterKeys"] as? [String])?[1]
    XCTAssertEqual(param2, "key2")
  }

  func testLoadRolloutMetadata_noData() async {
    let activeMetadata =
      await dbManager.databaseActor
        .loadRolloutTable(fromKey: ConfigConstants.rolloutTableKeyActiveMetadata)
    XCTAssertNotNil(activeMetadata) // initialized even if DB is empty

    let fetchedMetadata =
      await dbManager.databaseActor.loadRolloutTable(
        fromKey: ConfigConstants.rolloutTableKeyFetchedMetadata
      )
    XCTAssertNotNil(fetchedMetadata) // initialized even if DB is empty
  }

  // MARK: - Helpers

  func removeDatabase() {
    try? FileManager.default.removeItem(atPath: filePath)
  }

  func insertMetadata() async throws {
    let deviceContextData = try JSONSerialization.data(withJSONObject: [:], options: [])
    let appContextData = try JSONSerialization.data(withJSONObject: [:], options: [])
    let digestPerNamespaceData = try JSONSerialization.data(withJSONObject: [:], options: [])
    let columnNameToValue = try [
      RCNKeyBundleIdentifier: bundleID,
      RCNKeyNamespace: namespace,
      RCNKeyFetchTime: Date().timeIntervalSince1970,
      RCNKeyDigestPerNamespace: digestPerNamespaceData,
      RCNKeyDeviceContext: deviceContextData,
      RCNKeyAppContext: appContextData,
      RCNKeySuccessFetchTime: JSONSerialization.data(withJSONObject: [], options: []),
      RCNKeyFailureFetchTime: JSONSerialization.data(withJSONObject: [], options: []),
      RCNKeyLastFetchStatus: 0,
      RCNKeyLastFetchError: 0,
      RCNKeyLastApplyTime: Date().timeIntervalSince1970,
      RCNKeyLastSetDefaultsTime: Date().timeIntervalSince1970,
    ] as [String: Any]
    let success = await dbManager.databaseActor.insertMetadataTable(withValues: columnNameToValue)
    XCTAssertTrue(success)
  }

  private func insertMainTableValue() async throws {
    let config = [
      "key1": "value1",
      "key2": "value2",
    ]
    let data = try JSONSerialization.data(withJSONObject: config, options: [])
    let rcValue = RemoteConfigValue(data: data, source: .remote)

    let success = await dbManager.databaseActor.insertMainTable(
      withValues: [bundleID, namespace, "key", rcValue.dataValue],
      fromSource: .fetched
    )
    XCTAssertTrue(success)
  }

  private func insertExperiment() async throws {
    let experiment: [String: Any] = [
      "experimentId": "experiment",
    ]
    let experimentData = try JSONSerialization.data(withJSONObject: experiment, options: [])
    let success = await dbManager.databaseActor.insertExperimentTable(
      withKey: ConfigConstants.experimentTableKeyPayload,
      value: experimentData
    )
    XCTAssertTrue(success)
  }

  private func createOrOpenDatabaseBlock() {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      await dbManager.databaseActor.createOrOpenDatabase()
      semaphore.signal()
    }
    semaphore.wait()
  }

  private func waitForExpectations() {
    waitForExpectations(timeout: 5.0)
  }
}
