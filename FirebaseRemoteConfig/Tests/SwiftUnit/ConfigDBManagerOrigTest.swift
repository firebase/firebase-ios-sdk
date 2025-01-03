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

@testable import FirebaseRemoteConfig
import XCTest

class ConfigDBManagerOrigTest: XCTestCase {
  private var dbPath: String!
  private var dbManager: ConfigDBManager!
  private let expectationTimeout: TimeInterval = 10.0

  override func setUp() {
    super.setUp()
    dbPath = Self.remoteConfigPath(forTestDatabase: databaseName)
    dbManager = ConfigDBManager(dbPath: dbPath)
  }

  override func tearDown() {
    dbManager.removeDatabase(path: dbPath)
    super.tearDown()
  }

  func testV1NamespaceMigrationToV2Namespace() {
    let namespace = "testNamespace"
    let bundleIdentifier = Bundle.main.bundleIdentifier!
    let expectation = expectation(description: "test v1 namespace migration to v2 namespace")
    var count = 0

    for i in 0 ... 100 {
      let value = "value\(i)"
      let key = "key\(i)"
      let values: [Any] = [bundleIdentifier, namespace, key, value.data(using: .utf8)!]

      dbManager.insertMainTable(withValues: values, fromSource: .fetched) { success, _ in
        XCTAssertTrue(success)
        count += 1
        if count == 101 {
          self.dbManager.createOrOpenDatabase()
          self.dbManager.loadMain(withBundleIdentifier: bundleIdentifier) {
            success, fetched, _, _, _ in
            XCTAssertTrue(success)
            let fullyQualifiedNamespace = "\(namespace):__FIRAPP_DEFAULT"
            XCTAssertNotNil(fetched[fullyQualifiedNamespace])
            XCTAssertEqual(fetched[fullyQualifiedNamespace]?.count, 101)
            XCTAssertNil(fetched[namespace])
            expectation.fulfill()
          }
        }
      }
    }
    waitForExpectations(timeout: expectationTimeout)
  }

  func testWriteAndLoadMainTableResult() {
    let namespace = "namespace_1"
    let bundleIdentifier = Bundle.main.bundleIdentifier!
    let expectation = expectation(description: "Write and read metadata in database serially")
    var count = 0

    for i in 0 ... 100 {
      let value = "value\(i)"
      let key = "key\(i)"
      let values: [Any] = [bundleIdentifier, namespace, key, value.data(using: .utf8)!]
      dbManager.insertMainTable(withValues: values, fromSource: .fetched) { success, _ in
        XCTAssertTrue(success)
        count += 1
        if count == 101 {
          self.dbManager.loadMain(withBundleIdentifier: bundleIdentifier) {
            success, fetchedConfig, _, _, _ in
            XCTAssertTrue(success)
            let configValue = fetchedConfig[namespace]?["key100"]
            XCTAssertEqual(configValue?.stringValue, "value100")
            expectation.fulfill()
          }
        }
      }
    }
    waitForExpectations(timeout: expectationTimeout)
  }

  func testWriteAndLoadMetadataResult() {
    let expectation = expectation(description: "Write and load metadata successfully")
    let bundleIdentifier = Bundle.main.bundleIdentifier!
    let namespace = "test_namespace"
    let lastFetchTimestamp = Date().timeIntervalSince1970
    let now = Date().timeIntervalSince1970

    let deviceContext: [String: String] = [
      "app_version": "1.0.1",
      "app_build": "1.0.1.11",
      "os_version": "iOS9.1",
    ]
    let customVariables: [String: Sendable] = ["user_level": 15, "user_experiences": "2468"]
    let successFetchTimes: [TimeInterval] = []
    let failureFetchTimes: [TimeInterval] = [now - 200, now]

    let columnNameToValue: [String: Any] = [
      RCNKeyBundleIdentifier: bundleIdentifier,
      RCNKeyNamespace: namespace,
      RCNKeyFetchTime: lastFetchTimestamp,
      RCNKeyDigestPerNamespace: try! JSONSerialization
        .data(withJSONObject: [:], options: .prettyPrinted), // Empty dictionary
      RCNKeyDeviceContext: try! JSONSerialization
        .data(withJSONObject: deviceContext, options: .prettyPrinted),
      RCNKeyAppContext: try! JSONSerialization
        .data(withJSONObject: customVariables, options: .prettyPrinted),
      RCNKeySuccessFetchTime: try! JSONSerialization
        .data(withJSONObject: successFetchTimes, options: .prettyPrinted),
      RCNKeyFailureFetchTime: try! JSONSerialization
        .data(withJSONObject: failureFetchTimes, options: .prettyPrinted),

      RCNKeyLastFetchStatus: RemoteConfigFetchStatus.success.rawValue,
      RCNKeyLastFetchError: RemoteConfigError.unknown.rawValue,
      RCNKeyLastApplyTime: now - 100,
      RCNKeyLastSetDefaultsTime: now - 200,
    ]

    dbManager.insertMetadataTable(withValues: columnNameToValue) { success, _ in
      XCTAssertTrue(success)
      self.dbManager.loadMetadata(withBundleIdentifier: bundleIdentifier,
                                  namespace: namespace) { result in
        XCTAssertEqual(result[RCNKeyBundleIdentifier] as? String, bundleIdentifier)
        XCTAssertEqual(result[RCNKeyFetchTime] as? TimeInterval, lastFetchTimestamp)
        XCTAssertEqual(result[RCNKeyDigestPerNamespace] as? [String: String], [:])

        XCTAssertEqual(result[RCNKeyDeviceContext] as? [String: String], deviceContext)

        let loadedCustomVariables = result[RCNKeyAppContext] as? [String: Sendable]
        XCTAssertEqual(loadedCustomVariables?["user_level"] as? Int, 15)
        XCTAssertEqual(loadedCustomVariables?["user_experiences"] as? String, "2468")
        XCTAssertEqual(result[RCNKeyLastApplyTime] as? Double, now - 100)
        XCTAssertEqual(result[RCNKeyLastSetDefaultsTime] as? Double, now - 200)

        expectation.fulfill()
      }
    }

    waitForExpectations(timeout: expectationTimeout)
  }

  func testWriteAndLoadMetadataForMultipleNamespaces() {
    let expectation1 = expectation(
      description: "Metadata is stored and read based on namespace1"
    )
    let expectation2 = expectation(
      description: "Metadata is stored and read based on namespace2"
    )
    let bundleIdentifier = Bundle.main.bundleIdentifier!
    let deviceContext: [String: String] = [:] // Empty dictionary
    let customVariables: [String: Any] = [:] // Empty dictionary
    let namespace1 = "test_namespace"
    let namespace2 = "test_namespace_2"
    let lastApplyTime1 = 100.0
    let lastSetDefaultsTime1 = 200.0
    let lastApplyTime2 = 300.0
    let lastSetDefaultsTime2 = 400.0

    let serializedAppContext = try! JSONSerialization
      .data(withJSONObject: customVariables, options: .prettyPrinted)
    let serializedDeviceContext = try! JSONSerialization
      .data(withJSONObject: deviceContext, options: .prettyPrinted)
    let serializedDigestPerNamespace = try! JSONSerialization
      .data(withJSONObject: [:], options: .prettyPrinted) // Empty dictionary
    let serializedSuccessTime = try! JSONSerialization
      .data(withJSONObject: [], options: []) // Empty
    let serializedFailureTime = try! JSONSerialization
      .data(withJSONObject: [], options: []) // Empty

    let valuesForNamespace1: [String: Any] = [
      RCNKeyBundleIdentifier: bundleIdentifier,
      RCNKeyNamespace: namespace1,
      RCNKeyFetchTime: 0, // Or appropriate initial value
      RCNKeyDigestPerNamespace: serializedDigestPerNamespace,
      RCNKeyDeviceContext: serializedDeviceContext,
      RCNKeyAppContext: serializedAppContext,
      RCNKeySuccessFetchTime: serializedSuccessTime,
      RCNKeyFailureFetchTime: serializedFailureTime,
      RCNKeyLastFetchStatus: RemoteConfigFetchStatus.success.rawValue,
      RCNKeyLastFetchError: RemoteConfigError.unknown.rawValue,
      RCNKeyLastApplyTime: lastApplyTime1,
      RCNKeyLastSetDefaultsTime: lastSetDefaultsTime1,
    ]

    let valuesForNamespace2: [String: Any] = [
      RCNKeyBundleIdentifier: bundleIdentifier,
      RCNKeyNamespace: namespace2,
      RCNKeyFetchTime: 0,
      RCNKeyDigestPerNamespace: serializedDigestPerNamespace,
      RCNKeyDeviceContext: serializedDeviceContext,
      RCNKeyAppContext: serializedAppContext,
      RCNKeySuccessFetchTime: serializedSuccessTime,
      RCNKeyFailureFetchTime: serializedFailureTime,
      RCNKeyLastFetchStatus: RemoteConfigFetchStatus.success.rawValue,
      RCNKeyLastFetchError: RemoteConfigError.unknown.rawValue,
      RCNKeyLastApplyTime: lastApplyTime2,
      RCNKeyLastSetDefaultsTime: lastSetDefaultsTime2,
    ]

    dbManager.insertMetadataTable(withValues: valuesForNamespace1) { success, _ in
      XCTAssertTrue(success)
      self.dbManager.insertMetadataTable(withValues: valuesForNamespace2) { success, _ in
        XCTAssertTrue(success)

        // Load and verify namespace 1:
        self.dbManager.loadMetadata(withBundleIdentifier: bundleIdentifier,
                                    namespace: namespace1) { result in
          XCTAssertEqual(result[RCNKeyLastApplyTime] as? Double, lastApplyTime1)
          XCTAssertEqual(result[RCNKeyLastSetDefaultsTime] as? Double, lastSetDefaultsTime1)
          expectation1.fulfill()
        }

        // Load and verify namespace 2:
        self.dbManager.loadMetadata(withBundleIdentifier: bundleIdentifier,
                                    namespace: namespace2) { result in
          XCTAssertEqual(result[RCNKeyLastApplyTime] as? Double, lastApplyTime2)
          XCTAssertEqual(result[RCNKeyLastSetDefaultsTime] as? Double, lastSetDefaultsTime2)
          expectation2.fulfill()
        }
      }
    }

    waitForExpectations(timeout: expectationTimeout)
  }

  // Create a key each for two namespaces, delete it from one namespace, read both namespaces.
  func testDeleteParamAndLoadMainTable() {
    let namespaceToDelete = "namespace_delete"
    let namespaceToKeep = "namespace_keep"
    let bundleIdentifier = "testBundleID"
    let deleteExpectation =
      expectation(description: "Contents of 'namespace_delete' should be deleted.")
    let keepExpectation =
      expectation(description: "Write a key to namespace_keep and read back again.")

    let keyToDelete = "keyToDelete"
    let valueToDelete = "valueToDelete"
    let keyToRetain = "keyToRetain"
    let valueToRetain = "valueToRetain"

    let itemsToDelete: [Any] = [
      bundleIdentifier,
      namespaceToDelete,
      keyToDelete,
      valueToDelete.data(using: .utf8)!,
    ]

    let itemsToRetain: [Any] = [
      bundleIdentifier,
      namespaceToKeep,
      keyToRetain,
      valueToRetain.data(using: .utf8)!,
    ]

    // First write the data to both namespaces, then delete.
    dbManager.insertMainTable(withValues: itemsToDelete, fromSource: .active) { success, _ in
      XCTAssertTrue(success)
      self.dbManager
        .insertMainTable(withValues: itemsToRetain, fromSource: .active) { success, _ in
          XCTAssertTrue(success)
          self.dbManager.deleteRecord(fromMainTableWithNamespace: namespaceToDelete,
                                      bundleIdentifier: bundleIdentifier,
                                      fromSource: .active)

          self.dbManager.loadMain(withBundleIdentifier: bundleIdentifier) {
            success, _, active, _, _ in
            XCTAssertTrue(success)
            XCTAssertNil(active[namespaceToDelete]?[keyToDelete])
            XCTAssertEqual(active[namespaceToKeep]?[keyToRetain]?.stringValue, valueToRetain)
            deleteExpectation.fulfill()
          }
        }
    }

    dbManager.loadMain(withBundleIdentifier: bundleIdentifier) { success, _, active, _, _ in
      XCTAssertTrue(success)
      XCTAssertEqual(active[namespaceToKeep]?[keyToRetain]?.stringValue, valueToRetain)
      keepExpectation.fulfill()
    }
    waitForExpectations(timeout: expectationTimeout)
  }

  func testWriteAndLoadExperiments() {
    let expectation =
      expectation(description: "Update and load experiment in database successfully")

    let payload1 = Data() // Empty Data
    let payload2 = try! JSONSerialization.data(
      withJSONObject: ["ab", "cd"],
      options: .prettyPrinted
    )
    let payload3 = try! JSONSerialization.data(
      withJSONObject: ["experiment_ID": "35667", "experiment_activate_name": "activate_game"],
      options: .prettyPrinted
    )
    let payloads = [payload2, payload3, payload1] as [Any] // Mixed types require Any

    // Insert payloads asynchronously
    dbManager.insertExperimentTable(withKey: ConfigConstants.experimentTableKeyPayload,
                                    value: payload1) { _, _ in
      self.dbManager.insertExperimentTable(withKey: ConfigConstants.experimentTableKeyPayload,
                                           value: payload2) { _, _ in
        self.dbManager.insertExperimentTable(withKey: ConfigConstants.experimentTableKeyPayload,
                                             value: payload3) { _, _ in

          let metadata: [String: Any] = [
            "last_known_start_time": -11,
            "experiment_new_metadata": "wonderful",
          ]
          let serializedMetadata = try! JSONSerialization
            .data(withJSONObject: metadata, options: .prettyPrinted)
          self.dbManager.insertExperimentTable(
            withKey: ConfigConstants.experimentTableKeyMetadata,
            value: serializedMetadata
          ) { success, _ in
            XCTAssertTrue(success)
            self.dbManager.loadExperiment { success, experimentResults in
              XCTAssertTrue(success)
              guard let results = experimentResults else {
                XCTFail("Expected experiment results")
                return
              }
              XCTAssertNotNil(results[ConfigConstants.experimentTableKeyPayload])

              // Sort to avoid flaky tests due to array order
              let loadedPayloads = (results[ConfigConstants.experimentTableKeyPayload] as! [Data])
                .sorted { $0.hashValue < $1.hashValue }
              let sortedInput = (payloads as! [Data]).sorted { $0.hashValue < $1.hashValue }
              for (index, payload) in sortedInput.enumerated() {
                XCTAssertEqual(loadedPayloads[index], payload)
              }

              XCTAssertNotNil(results[ConfigConstants.experimentTableKeyMetadata])
              let loadedMetadata =
                results[ConfigConstants.experimentTableKeyMetadata] as! [String: Any]

              let startTime = loadedMetadata["last_known_start_time"] as! Double
              XCTAssertEqual(startTime, -11, accuracy: 1.0)
              XCTAssertEqual(loadedMetadata["experiment_new_metadata"] as? String, "wonderful")
              expectation.fulfill()
            }
          }
        }
      }
    }
    waitForExpectations(timeout: expectationTimeout)
  }

  func testWriteAndLoadActivatedExperiments() {
    let expectation = expectation(
      description: "Update and load activated experiments in database successfully"
    )

    let payload1 = Data() // Empty Data
    let payload2 = try! JSONSerialization.data(
      withJSONObject: ["ab", "cd"],
      options: .prettyPrinted
    )
    let payload3 = try! JSONSerialization.data(
      withJSONObject: ["experiment_ID": "35667", "experiment_activate_name": "activate_game"],
      options: .prettyPrinted
    )
    let payloads = [payload2, payload3, payload1]

    // Insert payloads using a loop and DispatchGroup for synchronization
    let dispatchGroup = DispatchGroup()
    for payload in payloads {
      dispatchGroup.enter()
      dbManager.insertExperimentTable(withKey: ConfigConstants.experimentTableKeyActivePayload,
                                      value: payload) { success, _ in
        XCTAssertTrue(success)
        dispatchGroup.leave()
      }
    }

    // Wait for all inserts to complete before loading
    dispatchGroup.notify(queue: .global()) {
      self.dbManager.loadExperiment { success, experimentResults in
        XCTAssertTrue(success)
        guard let results = experimentResults else {
          XCTFail("Expected experiment results")
          return
        }
        XCTAssertNotNil(results[ConfigConstants.experimentTableKeyActivePayload])

        // Sort to prevent flaky tests due to array order.
        let loadedPayloads = (results[ConfigConstants.experimentTableKeyActivePayload] as! [Data])
          .sorted { $0.hashValue < $1.hashValue }
        let sortedInput = payloads.sorted { $0.hashValue < $1.hashValue }
        XCTAssertEqual(loadedPayloads, sortedInput)
        expectation.fulfill()
      }
    }

    waitForExpectations(timeout: expectationTimeout)
  }

  func testWriteAndLoadMetadataMultipleTimes() {
    let expectation = expectation(
      description: "Update and load experiment metadata in database successfully"
    )

    let metadata1: [String: Any] = [
      "last_known_start_time": -11,
      "experiment_new_metadata": "wonderful",
    ]
    let serializedMetadata1 = try! JSONSerialization.data(withJSONObject: metadata1,
                                                          options: .prettyPrinted)

    let metadata2: [String: Any] = [
      "last_known_start_time": 12_345_678,
      "experiment_new_metadata": "wonderful",
    ]
    let serializedMetadata2 = try! JSONSerialization.data(withJSONObject: metadata2,
                                                          options: .prettyPrinted)

    // Insert the first metadata
    dbManager.insertExperimentTable(withKey: ConfigConstants.experimentTableKeyMetadata,
                                    value: serializedMetadata1) { success, _ in
      XCTAssertTrue(success)
      // Insert the updated metadata. This should replace the previous entry.
      self.dbManager.insertExperimentTable(withKey: ConfigConstants.experimentTableKeyMetadata,
                                           value: serializedMetadata2) { success, _ in
        XCTAssertTrue(success)
        self.dbManager.loadExperiment { success, experimentResults in
          XCTAssertTrue(success)
          guard let results = experimentResults else {
            XCTFail("Expected experiment results")
            return
          }
          XCTAssertNotNil(results[ConfigConstants.experimentTableKeyMetadata])
          let loadedMetadata =
            results[ConfigConstants.experimentTableKeyMetadata] as! [String: Any]
          XCTAssertEqual(loadedMetadata["last_known_start_time"] as! Double, 12_345_678.0,
                         accuracy: 1.0)
          XCTAssertEqual(loadedMetadata["experiment_new_metadata"] as? String, "wonderful")
          expectation.fulfill()
        }
      }
    }

    waitForExpectations(timeout: expectationTimeout)
  }

  func testWriteAndLoadFetchedAndActiveRollout() {
    let expectation = expectation(description: "Write and load rollout in database successfully")
    let bundleIdentifier = Bundle.main.bundleIdentifier!

    let fetchedRollout = [
      [
        "rollout_id": "1",
        "variant_id": "B",
        "affected_parameter_keys": ["key_1", "key_2"],
      ],
      [
        "rollout_id": "2",
        "variant_id": "1",
        "affected_parameter_keys": ["key_1", "key_3"],
      ],
    ]

    let activeRollout = [
      [
        "rollout_id": "1",
        "variant_id": "B",
        "affected_parameter_keys": ["key_1", "key_2"],
      ],
      [
        "rollout_id": "3",
        "variant_id": "a",
        "affected_parameter_keys": ["key_1", "key_3"],
      ],
    ]

    dbManager.insertOrUpdateRolloutTable(withKey: ConfigConstants.rolloutTableKeyFetchedMetadata,
                                         value: fetchedRollout) {
      success,
        _ in
      XCTAssertTrue(success)

      self.dbManager.insertOrUpdateRolloutTable(
        withKey: ConfigConstants.rolloutTableKeyActiveMetadata,
        value: activeRollout
      ) {
        success,
          _ in
        XCTAssertTrue(success)

        self.dbManager.loadMain(withBundleIdentifier: bundleIdentifier) {
          success,
            _,
            _,
            _,
            rolloutMetadata in

          XCTAssertTrue(success)

          let loadedFetchedRollout = rolloutMetadata[ConfigConstants.rolloutTableKeyFetchedMetadata]
          let loadedFetchedID = loadedFetchedRollout?[1]["fetched_id"] as? String
          let fetchedID = fetchedRollout[1]["fetched_id"] as? String
          XCTAssertEqual(loadedFetchedID, fetchedID)

          let loadedActiveRollout = rolloutMetadata[ConfigConstants.rolloutTableKeyActiveMetadata]
          let loadedParameters = loadedActiveRollout?[0]["affected_parameter_keys"] as? [String]
          let parameters = fetchedRollout[0]["affected_parameter_keys"] as? [String]
          XCTAssertEqual(loadedParameters, parameters)

          expectation.fulfill()
        }
      }
    }

    waitForExpectations(timeout: expectationTimeout)
  }

  func testUpdateAndLoadRollout() {
    let expectation = expectation(description: "Update and load rollout in database successfully")
    let bundleIdentifier = Bundle.main.bundleIdentifier!

    let initialFetchedRollout: [[String: Any]] = [
      [
        "rollout_id": "1",
        "variant_id": "B",
        "affected_parameter_keys": ["key_1", "key_2"],
      ],
    ]

    let updatedFetchedRollout: [[String: Any]] = [
      [
        "rollout_id": "1",
        "variant_id": "B",
        "affected_parameter_keys": ["key_1", "key_2"],
      ],
      [
        "rollout_id": "2",
        "variant_id": "1",
        "affected_parameter_keys": ["key_1", "key_3"],
      ],
    ]

    dbManager.insertOrUpdateRolloutTable(withKey: ConfigConstants.rolloutTableKeyFetchedMetadata,
                                         value: initialFetchedRollout) { success, _ in
      XCTAssertTrue(success)
      self.dbManager.insertOrUpdateRolloutTable(
        withKey: ConfigConstants.rolloutTableKeyFetchedMetadata,
        value: updatedFetchedRollout
      ) { success, _ in
        XCTAssertTrue(success)

        self.dbManager.loadMain(withBundleIdentifier: bundleIdentifier) {
          success, _, _, _, rolloutMetadata in
          XCTAssertTrue(success)

          let loadedFetchedRollout = rolloutMetadata[ConfigConstants.rolloutTableKeyFetchedMetadata]
          let loadedFetchedID = loadedFetchedRollout?[0]["variant_id"] as? String
          let fetchedID = updatedFetchedRollout[0]["variant_id"] as? String
          XCTAssertEqual(loadedFetchedID, fetchedID)

          let loadedParameters = loadedFetchedRollout?[1]["affected_parameter_keys"] as? [String]
          let parameters = updatedFetchedRollout[1]["affected_parameter_keys"] as? [String]
          XCTAssertEqual(loadedParameters, parameters)
          expectation.fulfill()
        }
      }
    }
    waitForExpectations(timeout: expectationTimeout)
  }

  func testLoadEmptyRollout() {
    let expectation = expectation(description: "Load empty rollout in database successfully")
    let bundleIdentifier = Bundle.main.bundleIdentifier!

    dbManager
      .loadMain(withBundleIdentifier: bundleIdentifier) { success, _, _, _, rolloutMetadata in
        XCTAssertTrue(success)
        let loadedFetchedRollout = rolloutMetadata[ConfigConstants.rolloutTableKeyFetchedMetadata]
        let loadedActiveRollout = rolloutMetadata[ConfigConstants.rolloutTableKeyActiveMetadata]
        XCTAssertEqual(loadedFetchedRollout?.count, 0) // Assert against empty array
        XCTAssertEqual(loadedActiveRollout?.count, 0) // Assert against empty array
        expectation.fulfill()
      }

    waitForExpectations(timeout: expectationTimeout)
  }

  func testUpdateAndloadLastFetchStatus() {
    let expectation = expectation(
      description: "Update and load last fetch status in database successfully."
    )
    let bundleIdentifier = Bundle.main.bundleIdentifier!
    let namespace = "test_namespace"

    let sampleMetadata = createSampleMetadata()

    dbManager.insertMetadataTable(withValues: sampleMetadata) { success, _ in
      XCTAssertTrue(success)
      self.dbManager.loadMetadata(withBundleIdentifier: bundleIdentifier,
                                  namespace: namespace) { result in
        XCTAssertEqual(result[RCNKeyLastFetchStatus] as? Int,
                       RemoteConfigFetchStatus.success.rawValue)
        XCTAssertEqual(result[RCNKeyLastFetchError] as? Int, RemoteConfigError.unknown.rawValue)

        let updatedValues: [Any] = [
          RemoteConfigFetchStatus.throttled.rawValue,
          RemoteConfigError.throttled.rawValue,
        ]

        self.dbManager.updateMetadata(withOption: .fetchStatus,
                                      namespace: namespace,
                                      values: updatedValues) { success, _ in
          XCTAssertTrue(success)
          self.dbManager.loadMetadata(withBundleIdentifier: bundleIdentifier,
                                      namespace: namespace) { result in
            XCTAssertEqual(result[RCNKeyLastFetchStatus] as? Int,
                           RemoteConfigFetchStatus.throttled.rawValue)
            XCTAssertEqual(result[RCNKeyLastFetchError] as? Int,
                           RemoteConfigError.throttled.rawValue)
            expectation.fulfill()
          }
        }
      }
    }
    waitForExpectations(timeout: expectationTimeout)
  }

  /// Tests that we can insert values in the database and can update them.
  func testInsertAndUpdateApplyTime() {
    let expectation = expectation(description: "Update and load apply time successfully")
    let bundleIdentifier = Bundle.main.bundleIdentifier!
    let namespace = "test_namespace"
    let lastApplyTimestamp = Date().timeIntervalSince1970

    let sampleMetadata = createSampleMetadata()

    dbManager.insertMetadataTable(withValues: sampleMetadata) { success, _ in
      XCTAssertTrue(success)
      self.dbManager.loadMetadata(withBundleIdentifier: bundleIdentifier,
                                  namespace: namespace) { result in
        XCTAssertEqual(result[RCNKeyLastApplyTime] as? Double, 100) // Original value

        self.dbManager.updateMetadata(withOption: .applyTime,
                                      namespace: namespace,
                                      values: [lastApplyTimestamp]) { success, _ in
          XCTAssertTrue(success)
          self.dbManager.loadMetadata(withBundleIdentifier: bundleIdentifier,
                                      namespace: namespace) { result in
            XCTAssertEqual(result[RCNKeyLastApplyTime] as? Double, lastApplyTimestamp)
            expectation.fulfill()
          }
        }
      }
    }
    waitForExpectations(timeout: expectationTimeout)
  }

  func testUpdateAndLoadSetDefaultsTime() {
    let expectation = expectation(
      description: "Update and load set defaults time in database successfully."
    )
    let bundleIdentifier = Bundle.main.bundleIdentifier!
    let namespace = "test_namespace"
    let lastSetDefaultsTimestamp = Date().timeIntervalSince1970

    let sampleMetadata = createSampleMetadata()

    dbManager.insertMetadataTable(withValues: sampleMetadata) { success, _ in
      XCTAssertTrue(success)
      self.dbManager.loadMetadata(withBundleIdentifier: bundleIdentifier,
                                  namespace: namespace) { result in
        XCTAssertEqual(result[RCNKeyLastSetDefaultsTime] as? Double, 200)

        self.dbManager.updateMetadata(withOption: .defaultTime,
                                      namespace: namespace,
                                      values: [lastSetDefaultsTimestamp]) { success, _ in
          XCTAssertTrue(success)
          self.dbManager.loadMetadata(withBundleIdentifier: bundleIdentifier,
                                      namespace: namespace) { result in
            XCTAssertEqual(result[RCNKeyLastSetDefaultsTime] as? Double, lastSetDefaultsTimestamp)
            expectation.fulfill()
          }
        }
      }
    }

    waitForExpectations(timeout: expectationTimeout)
  }

  private func createSampleMetadata() -> [String: Any] {
    let bundleIdentifier = Bundle.main.bundleIdentifier!
    let namespace = "test_namespace"
    let deviceContext = [String: String]() // Empty dictionary
    let customVariables = [String: String]() // Empty dictionary
    let successFetchTimes = [TimeInterval]() // Empty array
    let failureFetchTimes = [TimeInterval]() // Empty array

    return [
      RCNKeyBundleIdentifier: bundleIdentifier,
      RCNKeyNamespace: namespace,
      RCNKeyFetchTime: 0, // Or appropriate initial value
      RCNKeyDigestPerNamespace: try! JSONSerialization
        .data(withJSONObject: [:], options: []), // Empty dictionary literal
      RCNKeyDeviceContext: try! JSONSerialization.data(withJSONObject: deviceContext, options: []),
      RCNKeyAppContext: try! JSONSerialization.data(withJSONObject: customVariables, options: []),
      RCNKeySuccessFetchTime: try! JSONSerialization
        .data(withJSONObject: successFetchTimes, options: []),
      RCNKeyFailureFetchTime: try! JSONSerialization.data(
        withJSONObject: failureFetchTimes,
        options: []
      ),
      RCNKeyLastFetchStatus: RemoteConfigFetchStatus.success.rawValue,
      RCNKeyLastFetchError: RemoteConfigError.unknown.rawValue,
      RCNKeyLastApplyTime: 100.0, // Or appropriate value
      RCNKeyLastSetDefaultsTime: 200.0, // Or appropriate value
    ]
  }

  static func remoteConfigPath(forTestDatabase databaseName: String) -> String {
    #if os(tvOS)
      let dirPaths = NSSearchPathForDirectoriesInDomains(.cachesDirectory,
                                                         .userDomainMask, true)
    #else
      let dirPaths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory,
                                                         .userDomainMask, true)
    #endif
    let storageDirPath = dirPaths[0]
    let dbPath = URL(fileURLWithPath: storageDirPath)
      .appendingPathComponent("Google/RemoteConfig")
      .appendingPathComponent(databaseName).path
    return dbPath
  }

  private let databaseName = "RC_Test.sqlite3"
}
