// Copyright 2025 Google LLC
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
import FirebaseRemoteConfigInterop
import XCTest

class ConfigContentTests: XCTestCase {
  var configContent: ConfigContent!
  let namespaceGoogleMobilePlatform = "firebase" // Initialize this constant
  var namespaceApp1: String!
  var namespaceApp2: String!

  override func setUp() {
    super.setUp()
    configContent = ConfigContent(dbManager: ConfigDBManagerFake())
    namespaceApp1 = "\(namespaceGoogleMobilePlatform):\(Constants.defaultFirebaseAppName)"
    namespaceApp2 = "\(namespaceGoogleMobilePlatform):\(Constants.secondFirebaseAppName)"
  }

  func testCrashShouldNotHappenWithoutMainBundleID() {
    // Given
    let bundleID = nil as String?
    // When
    configContent = ConfigContent(dbManager: ConfigDBManagerFake(), bundleIdentifier: bundleID)
    // Then - No crash.  Assertion is handled in ConfigContent init now.
  }

  func testUpdateConfigContentForMultipleApps() {
    // Given
    // - Update for first namespace.
    let config1ToSet: [String: Any] = [
      "state": "UPDATE",
      "entries": ["key1": "value1", "key2": "value2"],
    ]
    configContent.updateConfigContent(withResponse: config1ToSet, forNamespace: namespaceApp1)

    // - Update for second namespace.
    let config2ToSet: [String: Any] = [
      "state": "UPDATE",
      "entries": ["key11": "value11", "key21": "value21"],
    ]
    configContent.updateConfigContent(withResponse: config2ToSet, forNamespace: namespaceApp2)

    // When
    let fetchedConfig1 = configContent.fetchedConfig()
    let fetchedConfig2 = configContent.fetchedConfig()

    // Then
    // - Assertions for first namespace.
    XCTAssertEqual(fetchedConfig1[namespaceApp1]?["key1"]?.stringValue, "value1")
    XCTAssertEqual(fetchedConfig1[namespaceApp1]?["key2"]?.stringValue, "value2")

    // - Assertions for second namespace.
    XCTAssertEqual(fetchedConfig2[namespaceApp2]?["key11"]?.stringValue, "value11")
    XCTAssertEqual(fetchedConfig2[namespaceApp2]?["key21"]?.stringValue, "value21")
  }

  func testUpdateConfigContentWithResponse() {
    // Given
    let configToSet: [String: Any] = [
      "state": "UPDATE",
      "entries": ["key1": "value1", "key2": "value2"],
    ]
    configContent.updateConfigContent(
      withResponse: configToSet,
      forNamespace: namespaceGoogleMobilePlatform
    )

    // When
    let fetchedConfig = configContent.fetchedConfig()

    // Then
    XCTAssertEqual(fetchedConfig[namespaceGoogleMobilePlatform]?["key1"]?.stringValue, "value1")
    XCTAssertEqual(fetchedConfig[namespaceGoogleMobilePlatform]?["key2"]?.stringValue, "value2")
  }

  func testUpdateConfigContentWithStatusUpdateWithDifferentKeys() {
    // Given
    configContent.updateConfigContent(
      withResponse: ["state": "UPDATE", "entries": ["key1": "value1"]],
      forNamespace: namespaceGoogleMobilePlatform
    )

    configContent.updateConfigContent(
      withResponse: ["state": "UPDATE", "entries": ["key2": "value2", "key3": "value3"]],
      forNamespace: namespaceGoogleMobilePlatform
    )

    // When
    let fetchedConfig = configContent.fetchedConfig()

    // then
    XCTAssertNil(fetchedConfig[namespaceGoogleMobilePlatform]?["key1"])
    XCTAssertEqual(fetchedConfig[namespaceGoogleMobilePlatform]?["key2"]?.stringValue, "value2")
    XCTAssertEqual(fetchedConfig[namespaceGoogleMobilePlatform]?["key3"]?.stringValue, "value3")
  }

  func testUpdateConfigContentWithStatusUpdateWithDifferentNamespaces() {
    // Given
    let configToSet1: [String: Any] = ["state": "UPDATE", "entries": ["key1": "value1"]]
    let configToSet2: [String: Any] = ["state": "UPDATE", "entries": ["key2": "value2"]]

    configContent.updateConfigContent(withResponse: configToSet1, forNamespace: "namespace_1")
    configContent.updateConfigContent(withResponse: configToSet2, forNamespace: "namespace_2")
    configContent.updateConfigContent(withResponse: configToSet1, forNamespace: "namespace_3")
    configContent.updateConfigContent(withResponse: configToSet2, forNamespace: "namespace_4")

    // When
    let fetchedConfig = configContent.fetchedConfig()

    // Then
    XCTAssertEqual(fetchedConfig["namespace_1"]?["key1"]?.stringValue, "value1")
    XCTAssertEqual(fetchedConfig["namespace_2"]?["key2"]?.stringValue, "value2")
    XCTAssertEqual(fetchedConfig["namespace_3"]?["key1"]?.stringValue, "value1")
    XCTAssertEqual(fetchedConfig["namespace_4"]?["key2"]?.stringValue, "value2")
  }

  func skip_testUpdateConfigContentWithStatusNoChange() {
    // TODO: Add test case once new eTag based logic is implemented.
  }

  func skip_testUpdateConfigContentWithRemoveNamespaceStatus() {
    // TODO: Add test case once new eTag based logic is implemented.
  }

  func skip_testUpdateConfigContentWithEmptyConfig() {
    // TODO: Add test case once new eTag based logic is implemented.
  }

  // TODO: Test is broken.
  // It has to do with `configConent`'s DB Manager being non-nil.
  func testCopyFromDictionaryDoesNotUpdateFetchedConfig() {
    configContent.updateConfigContent(
      withResponse: ["state": "UPDATE", "entries": ["key1": "value1", "key2": "value2"]],
      forNamespace: "dummy_namespace"
    )

    configContent.copy(
      fromDictionary: ["dummy_namespace": ["new_key": "new_value"]],
      toSource: .fetched,
      forNamespace: "dummy_namespace"
    )

    XCTAssertEqual(configContent.fetchedConfig()["dummy_namespace"]?.count, 2)
    XCTAssertEqual(configContent.activeConfig().count, 0)
    XCTAssertEqual(configContent.defaultConfig().count, 0)
  }

//    func testCopyFromDictionaryUpdatesDefaultConfig() throws {
//        let embeddedDictionary = ["default_embedded_key": "default_embedded_Value"]
//        let dataValue = try JSONSerialization.data(withJSONObject: embeddedDictionary,
//                                                  options: .prettyPrinted)
//
//        let now = Date()
//        let jsonData = try JSONSerialization.data(withJSONObject: ["key1": "value1"])
//        let jsonString = String(data: jsonData, encoding: .utf8)
//
//
//        let namespaceToConfig: [String: [String: Any]] = [
//            "default_namespace": [
//              "new_string_key": "new_string_value",
//              "new_number_key": 1234,
//              "new_data_key": dataValue,
//              "new_date_key": now,
//              "new_json_key": jsonString as Any
//            ]
//        ]
//        configContent.copy(fromDictionary: namespaceToConfig, toSource: .default, forNamespace: "default_namespace")
//
//        let defaultConfig = configContent.defaultConfig()
//        XCTAssertEqual(configContent.fetchedConfig().count, 0)
//        XCTAssertEqual(configContent.activeConfig().count, 0)
//        XCTAssertNotNil(defaultConfig["default_namespace"])
//        XCTAssertEqual(defaultConfig["default_namespace"]?.count, 5)
//
//
//        XCTAssertEqual(defaultConfig["default_namespace"]?["new_string_key"]?.stringValue,
//        "new_string_value")
//        XCTAssertEqual(defaultConfig["default_namespace"]?["new_number_key"]?.numberValue, 1234)
//        let sampleJSON = ["key1": "value1"]
//        let configJSON = defaultConfig["default_namespace"]?["new_json_key"]?.jsonValue
//
//
//        XCTAssertEqual(NSDictionary(dictionary: sampleJSON), configJSON as? NSDictionary)
//
//        XCTAssertEqual(defaultConfig["default_namespace"]?["new_data_key"]?.dataValue, dataValue)
//
//
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        let strValueForDate = dateFormatter.string(from: now)
//
//        XCTAssertEqual(defaultConfig["default_namespace"]?["new_date_key"]?.stringValue,
//        strValueForDate)
//
//    }
//
//
//    func testCopyFromDictionaryUpdatesActiveConfig() throws {
//        let embeddedDictionary = ["active_embedded_key": "active_embedded_Value"]
//        let dataValue = try JSONSerialization.data(withJSONObject: embeddedDictionary, options:
//        .prettyPrinted)
//        let rcValue = RemoteConfigValue(data: dataValue, source: .static) //Using .static since
//        the source is -1
//
//        let namespaceToConfig = ["dummy_namespace": ["new_key": rcValue]]
//        configContent.copy(fromDictionary: namespaceToConfig, toSource: .active, forNamespace: "dummy_namespace")
//
//        XCTAssertEqual(configContent.activeConfig()["dummy_namespace"]?.count, 1)
//        XCTAssertEqual(configContent.fetchedConfig().count, 0)
//        XCTAssertEqual(configContent.defaultConfig().count, 0)
//        XCTAssertEqual(configContent.activeConfig()["dummy_namespace"]?["new_key"]?.dataValue,
//        dataValue)
//    }
//
//
  ////    func testCheckAndWaitForInitialDatabaseLoad() {
  ////        // This test relies on timing and mocking internal behavior, which is challenging to
  /// translate
  ////        // directly.  Re-implement this test to verify the timeout logic in a way that's
  /// suitable for your
  ////        // testing environment and mocking framework.
  ////    }
//
//    func testConfigUpdate_noChange_emptyResponse() {
//        let namespace = "test_namespace"
//
//        // Populate fetched config
//        let fetchResponse = createFetchResponse(config: ["key1": "value1"], p13nMetadata: nil,
//        rolloutMetadata: nil)
//        configContent.updateConfigContent(withResponse: fetchResponse, forNamespace: namespace)
//
//        // Active config same as fetched config
//        let value = RemoteConfigValue(data: "value1".data(using: .utf8), source: .remote)
//        let namespaceToConfig = [namespace: ["key1": value]]
//
//        configContent.copy(fromDictionary: namespaceToConfig, toSource: .active, forNamespace: namespace)
//
//
//        let update = configContent.getConfigUpdate(forNamespace: namespace)
//        XCTAssertEqual(update?.updatedKeys.count, 0) // No update expected.
//    }
//
//    func testConfigUpdate_paramAdded_returnsNewKey() {
//        let namespace = "test_namespace"
//        let newParam = "key2"
//
//        // Populate active config
//        let value = RemoteConfigValue(data: "value1".data(using: .utf8), source: .remote)
//        let namespaceToConfig = [namespace: ["key1": value]]
//
//        configContent.copy(fromDictionary: namespaceToConfig, toSource: .active, forNamespace: namespace)
//
//        // Fetched response has new param.
//        let fetchResponse = createFetchResponse(config: ["key1": "value1", newParam: "value2"],
//        p13nMetadata: nil, rolloutMetadata: nil)
//        configContent.updateConfigContent(withResponse: fetchResponse, forNamespace: namespace)
//
//        let update = configContent.getConfigUpdate(forNamespace: namespace)
//
//        XCTAssertEqual(update?.updatedKeys.count, 1)
//        XCTAssertTrue(update?.updatedKeys.contains(newParam) ?? false) // Use nil-coalescing and
//        optional chaining.
//
//
//    }
//
//    func testConfigUpdate_paramValueChanged_returnsUpdatedKey() {
//        let namespace = "test_namespace"
//        let existingParam = "key1"
//        let oldValue = "value1"
//        let updatedValue = "value2"
//
//        // Active config with old value
//        let value = RemoteConfigValue(data: oldValue.data(using: .utf8), source: .remote)
//
//        configContent.copy(fromDictionary: [namespace: [existingParam: value]], toSource: .active, forNamespace: namespace)
//
//        let fetchResponse = createFetchResponse(config: [existingParam: updatedValue],
//        p13nMetadata: nil, rolloutMetadata: nil)
//        configContent.updateConfigContent(withResponse: fetchResponse, forNamespace: namespace)
//
//        let update = configContent.getConfigUpdate(forNamespace: namespace)
//
//        XCTAssertEqual(update?.updatedKeys.count, 1)
//        XCTAssertTrue(update?.updatedKeys.contains(existingParam) ?? false)
//    }
//
//
//    func testConfigUpdate_paramDeleted_returnsDeletedKey() {
//        let namespace = "test_namespace"
//        let existingParam = "key1"
//        let newParam = "key2"
//        let value1 = "value1"
//
//
//        let value = RemoteConfigValue(data: value1.data(using: .utf8), source: .remote)
//
//        configContent.copy(fromDictionary: [namespace: [existingParam: value]], toSource: .active, forNamespace: namespace)
//
//
//        let fetchResponse = createFetchResponse(config: [newParam: value1], p13nMetadata: nil,
//        rolloutMetadata: nil)
//        configContent.updateConfigContent(withResponse: fetchResponse, forNamespace: namespace)
//
//        let update = configContent.getConfigUpdate(forNamespace: namespace)
//
//        XCTAssertEqual(update?.updatedKeys.count, 2) // Should contain both keys
//        XCTAssertTrue(update?.updatedKeys.contains(existingParam) ?? false)
//        XCTAssertTrue(update?.updatedKeys.contains(newParam) ?? false)
//
//    }
//
//
//
//
//    func testConfigUpdate_p13nMetadataUpdated_returnsKey() {
//        let namespace = "test_namespace"
//        let existingParam = "key1"
//        let value1 = "value1"
//        let oldMetadata = ["arm_index": "1"] //as [String: String] //Swift dictionaries are not
//        AnyObject
//        let updatedMetadata = ["arm_index": "2"] //as [String: String]  //Swift dictionaries are
//        not AnyObject
//
//        // Populate fetched config
//        let fetchResponse = createFetchResponse(config: [existingParam: value1], p13nMetadata:
//        [existingParam: oldMetadata], rolloutMetadata: nil)
//
//        configContent.updateConfigContent(withResponse: fetchResponse, forNamespace: namespace)
//        configContent.activatePersonalization()
//
//        let value = RemoteConfigValue(data: value1.data(using: .utf8), source: .remote)
//        configContent.copy(fromDictionary: [namespace: [existingParam: value]], toSource: .active, forNamespace: namespace)
//
//        var updatedFetchResponse = fetchResponse
//        updatedFetchResponse[ConfigConstants.fetchResponseKeyPersonalizationMetadata] =
//        [existingParam: updatedMetadata]
//        configContent.updateConfigContent(withResponse: updatedFetchResponse, forNamespace: namespace)
//
//
//        let update = configContent.getConfigUpdate(forNamespace: namespace)
//
//        XCTAssertEqual(update?.updatedKeys.count, 1)
//        XCTAssertTrue(update?.updatedKeys.contains(existingParam) ?? false)
//
//    }
//
//
//
//    func testConfigUpdate_rolloutMetadataUpdated_returnsKey() {
//        let namespace = "test_namespace"
//        let key1 = "key1"
//        let key2 = "key2"
//        let value = "value"
//        let rolloutId1 = "1"
//        let rolloutId2 = "2"
//        let variantId1 = "A"
//        let variantId2 = "B"
//
//        let rolloutMetadata: [[String: Any]] = [[
//            ConfigConstants.fetchResponseKeyRolloutID: rolloutId1,
//            ConfigConstants.fetchResponseKeyVariantID: variantId1,
//            ConfigConstants.fetchResponseKeyAffectedParameterKeys: [key1]
//        ]]
//
//        let updatedRolloutMetadata: [[String: Any]] = [
//          [
//            ConfigConstants.fetchResponseKeyRolloutID: rolloutId1,
//            ConfigConstants.fetchResponseKeyVariantID: variantId2,
//            ConfigConstants.fetchResponseKeyAffectedParameterKeys: [key1]
//          ],
//          [
//            ConfigConstants.fetchResponseKeyRolloutID: rolloutId2,
//            ConfigConstants.fetchResponseKeyVariantID: variantId1,
//            ConfigConstants.fetchResponseKeyAffectedParameterKeys: [key2]
//          ]
//        ]
//
//        let fetchResponse = createFetchResponse(config: [key1: value], p13nMetadata: nil,
//        rolloutMetadata: rolloutMetadata)
//        configContent.updateConfigContent(withResponse: fetchResponse, forNamespace: namespace)
//        configContent.activateRolloutMetadata( { _ in})
//        let rcValue = RemoteConfigValue(data: value.data(using: .utf8), source: .remote)
//        configContent.copy(fromDictionary: [namespace: [key1: rcValue]], toSource: .active, forNamespace: namespace)
//        var updatedFetchResponse = fetchResponse
//        updatedFetchResponse[ConfigConstants.fetchResponseKeyRolloutMetadata] =
//        updatedRolloutMetadata
//
//        configContent.updateConfigContent(withResponse: updatedFetchResponse, forNamespace: namespace)
//
//        let update = configContent.getConfigUpdate(forNamespace: namespace)
//        XCTAssertEqual(update?.updatedKeys.count, 2)
//        XCTAssertTrue(update?.updatedKeys.contains(key1) ?? false)
//        XCTAssertTrue(update?.updatedKeys.contains(key2) ?? false)
//
//    }
//
//
//    func testConfigUpdate_rolloutMetadataDeleted_returnsKey() {
//      let namespace = "test_namespace"
//      let key1 = "key1"
//      let key2 = "key2"
//      let value = "value"
//      let rolloutId1 = "1"
//      let variantId1 = "A"
//
//      let rolloutMetadata = [[
//        ConfigConstants.fetchResponseKeyRolloutID: rolloutId1,
//        ConfigConstants.fetchResponseKeyVariantID: variantId1,
//        ConfigConstants.fetchResponseKeyAffectedParameterKeys: [key1, key2]
//      ]]
//
//      let updatedRolloutMetadata = [[
//        ConfigConstants.fetchResponseKeyRolloutID: rolloutId1,
//        ConfigConstants.fetchResponseKeyVariantID: variantId1,
//        ConfigConstants.fetchResponseKeyAffectedParameterKeys: [key1]
//      ]]
//
//      let fetchResponse = createFetchResponse(config: [key1: value, key2: value], p13nMetadata:
//      nil, rolloutMetadata: rolloutMetadata)
//      configContent.updateConfigContent(withResponse: fetchResponse, forNamespace: namespace)
//
//      configContent.activateRolloutMetadata( { _ in})
//
//      let rcValue = RemoteConfigValue(data: value.data(using: .utf8), source: .remote)
//      configContent.copy(fromDictionary: [namespace: [key1: rcValue, key2: rcValue]], toSource: .active, forNamespace: namespace)
//
//      var updatedFetchResponse = fetchResponse
//      updatedFetchResponse[ConfigConstants.fetchResponseKeyRolloutMetadata] =
//      updatedRolloutMetadata
//      configContent.updateConfigContent(withResponse: updatedFetchResponse, forNamespace: namespace)
//
//      let update = configContent.getConfigUpdate(forNamespace: namespace)
//      XCTAssertEqual(update?.updatedKeys.count, 1)
//
//      XCTAssertTrue(update?.updatedKeys.contains(key2) ?? false)
//
//    }
//
//    func testConfigUpdate_rolloutMetadataDeletedAll_returnsKey() {
//        let namespace = "test_namespace"
//        let key = "key"
//        let value = "value"
//        let rolloutId1 = "1"
//        let variantId1 = "A"
//
//        let rolloutMetadata = [[
//          ConfigConstants.fetchResponseKeyRolloutID: rolloutId1,
//          ConfigConstants.fetchResponseKeyVariantID: variantId1,
//          ConfigConstants.fetchResponseKeyAffectedParameterKeys: [key]
//        ]]
//
//        let fetchResponse = createFetchResponse(config: [key: value], p13nMetadata: nil,
//        rolloutMetadata: rolloutMetadata)
//        configContent.updateConfigContent(withResponse: fetchResponse, forNamespace: namespace)
//        configContent.activateRolloutMetadata({ _ in })
//
//
//        let rcValue = RemoteConfigValue(data: value.data(using: .utf8), source: .remote)
//
//        configContent.copy(fromDictionary: [namespace: [key: rcValue]], toSource: .active, forNamespace: namespace)
//
//
//        let updatedFetchResponse = createFetchResponse(config: [key: value], p13nMetadata: nil,
//        rolloutMetadata: nil)
//        configContent.updateConfigContent(withResponse: updatedFetchResponse, forNamespace: namespace)
//        let update = configContent.getConfigUpdate(forNamespace: namespace)
//        configContent.activateRolloutMetadata({ _ in })
//
//        XCTAssertEqual(update?.updatedKeys.count, 1)
//        XCTAssertTrue(update?.updatedKeys.contains(key) ?? false)
//        XCTAssertTrue(configContent.activeRolloutMetadata().isEmpty)
//
//    }
//
//
//    func testConfigUpdate_valueSourceChanged_returnsKey() {
//        let namespace = "test_namespace"
//        let existingParam = "key1"
//        let value1 = "value1"
//
//        let value = RemoteConfigValue(data: value1.data(using: .utf8), source: .default)
//        configContent.copy(fromDictionary: [namespace: [existingParam: value]], toSource: .default, forNamespace: namespace)
//
//        let fetchResponse = createFetchResponse(config: [existingParam: value1], p13nMetadata:
//        nil, rolloutMetadata: nil)
//
//        configContent.updateConfigContent(withResponse: fetchResponse, forNamespace: namespace)
//
//        let update = configContent.getConfigUpdate(forNamespace: namespace)
//        XCTAssertEqual(update?.updatedKeys.count, 1)
//
//        XCTAssertTrue(update?.updatedKeys.contains(existingParam) ?? false)
//
//
//    }
//
//    // Helper functions (adapt to your set up)
//    private func createFetchResponse(config: [String: String]?,
//                                      p13nMetadata: [String: Any]?,
//                                      rolloutMetadata: [[String: Any]]?) -> [String: Any] {
//
//        var fetchResponse: [String: Any] = ["state": ConfigConstants.fetchResponseKeyStateUpdate]
//        if let config {
//          fetchResponse[ConfigConstants.fetchResponseKeyEntries] = config
//        }
//        if let p13nMetadata {
//          fetchResponse[ConfigConstants.fetchResponseKeyPersonalizationMetadata] = p13nMetadata
//        }
//
//        if let rolloutMetadata {
//          fetchResponse[ConfigConstants.fetchResponseKeyRolloutMetadata] = rolloutMetadata
//        }
//
//        return fetchResponse
//    }
}

private class ConfigDBManagerFake: ConfigDBManager {
//  var mockExperimentTable: [String: Any] = [:]
//
//
//  init(bundle: Bundle) {
//    super.init()
//  }
//
//  override func loadMain(withBundleIdentifier bundleIdentifier: String,
//                         completionHandler: ((Bool, [String: [String: RemoteConfigValue]]?,
//                                              [String: [String: RemoteConfigValue]]?,
//                                              [String: [String: RemoteConfigValue]]?,
//                                              [String: [[String: Any]]]) -> Void)?) {
//    completionHandler?(
//      true, [:], [:], [:], [
//        ConfigConstants.rolloutTableKeyFetchedMetadata: [],
//        ConfigConstants.rolloutTableKeyActiveMetadata: [],
//      ]
//    )
//  }
//
//  override func loadExperiment(completionHandler: ((Bool, [String: Any]?) -> Void)?) {
//    completionHandler?(true, mockExperimentTable)
//  }
//
//  override func loadPersonalization(
//    completionHandler: ((Bool, [String: Any], [String: Any], [String: Any]?, [String: Any]?)
//      -> Void)?
//  ) {
//    completionHandler?(true, [:], [:])
//  }
//  override func insertMainTable(withValues values: [Any], fromSource source: DBSource) async ->
//  Bool { true }
//  override func insertMetadataTable(withValues values: [String: Any]) async -> Bool { true }
//  override func deleteRecord(fromMainTableWithNamespace namespace: String,
//                             bundleIdentifier: String,
//                             fromSource source: DBSource) { }
//  override func insertExperimentTable(withKey key: String, value: Data) async -> Bool { true }
//
//  override func deleteExperimentTable(forKey key: String) {}
//
//
//
//  override func insertOrUpdateRolloutTable(withKey key: String, value metadataList: [[String :
//  Any]]) async -> Bool { true }
//
//    override func insertOrUpdateRolloutTable(withKey key: String,
//                                        value metadataList: [[String: Any]],
//                                        completionHandler handler: ((Bool, [String :
//                                        AnyHashable]?) -> Void)?) {
//      handler?(true, nil)
//    }
//    override func insertOrUpdatePersonalizationConfig(_ dataValue: [String : Any], fromSource
//    source: DBSource) async {
//    }
}
