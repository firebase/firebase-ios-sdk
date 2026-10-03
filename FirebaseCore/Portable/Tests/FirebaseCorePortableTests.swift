// Copyright 2026 Google LLC
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

import FirebaseCoreInternal
import Foundation
import Testing

@testable import FirebaseCore
@testable import FirebaseCoreExtension

private protocol MockServiceInterop: AnyObject, Sendable {
  var identifier: String { get }
}

private final class MockService: MockServiceInterop {
  let identifier: String

  init(identifier: String) {
    self.identifier = identifier
  }
}

@Suite(.serialized)
struct FirebaseCorePortableTests {
  init() {
    FirebaseApp.resetApps()
    FirebaseComponentContainer.removeAllRegistrations()
    FirebaseConfiguration.shared.setLoggerLevel(.notice)
    FirebaseLogger.setSink(nil)
  }

  // MARK: - FirebaseOptions Tests

  @Test
  func optionsDesignatedInitializerAndMutation() {
    let options = FirebaseOptions(
      googleAppID: "1:123:ios:abc",
      gcmSenderID: "123456789"
    )
    let matchingOptions = FirebaseOptions(
      googleAppID: "1:123:ios:abc",
      gcmSenderID: "123456789"
    )
    let differentOptions = FirebaseOptions(
      googleAppID: "1:999:ios:xyz",
      gcmSenderID: "123456789"
    )

    options.apiKey = "AIzaSyTestKey"
    options.projectID = "test-project"
    options.storageBucket = "test-project.appspot.com"
    options.bundleID = "com.example.app"
    options.clientID = "123.apps.googleusercontent.com"
    options.databaseURL = "https://test-project.firebaseio.com"
    options.appGroupID = "group.com.example.app"
    matchingOptions.apiKey = "AIzaSyTestKey"
    matchingOptions.projectID = "test-project"
    matchingOptions.storageBucket = "test-project.appspot.com"
    matchingOptions.bundleID = "com.example.app"
    matchingOptions.clientID = "123.apps.googleusercontent.com"
    matchingOptions.databaseURL = "https://test-project.firebaseio.com"
    matchingOptions.appGroupID = "group.com.example.app"

    #expect(options.googleAppID == "1:123:ios:abc")
    #expect(options.gcmSenderID == "123456789")
    #expect(options.apiKey == "AIzaSyTestKey")
    #expect(options.projectID == "test-project")
    #expect(options.storageBucket == "test-project.appspot.com")
    #expect(options.bundleID == "com.example.app")
    #expect(options.clientID == "123.apps.googleusercontent.com")
    #expect(options.databaseURL == "https://test-project.firebaseio.com")
    #expect(options.appGroupID == "group.com.example.app")
    #expect(options == matchingOptions)
    #expect(options != differentOptions)
    #expect(options.hashValue == matchingOptions.hashValue)
  }

  @Test
  func optionsConvenienceInitializer() {
    let googleAppID = "1:999:ios:def"
    let gcmSenderID = "999888777"

    let options = FirebaseOptions(
      googleAppID: googleAppID,
      gcmSenderID: gcmSenderID,
      apiKey: "AIzaSyConvKey",
      projectID: "conv-project",
      storageBucket: "conv-bucket",
      bundleID: "com.example.conv",
      clientID: "conv-client",
      databaseURL: "https://conv.firebaseio.com",
      appGroupID: "group.conv"
    )

    #expect(options.googleAppID == googleAppID)
    #expect(options.gcmSenderID == gcmSenderID)
    #expect(options.apiKey == "AIzaSyConvKey")
    #expect(options.projectID == "conv-project")
    #expect(options.storageBucket == "conv-bucket")
    #expect(options.bundleID == "com.example.conv")
    #expect(options.clientID == "conv-client")
    #expect(options.databaseURL == "https://conv.firebaseio.com")
    #expect(options.appGroupID == "group.conv")
  }

  @Test
  func optionsCopySnapshotBehavior() {
    let original = FirebaseOptions(googleAppID: "1:111:ios:222", gcmSenderID: "333")
    original.apiKey = "original-key"

    let snapshot = original.copy()
    original.apiKey = "mutated-key"

    #expect(snapshot.apiKey == "original-key")
    #expect(original.apiKey == "mutated-key")
    #expect(snapshot != original)
  }

  @Test
  func optionsPlistInitializerLoadsValidPlist() throws {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("GoogleService-Info-\(UUID().uuidString).plist")
    defer { try? FileManager.default.removeItem(at: tempURL) }
    let plistDict: [String: String] = [
      "GOOGLE_APP_ID": "1:123:ios:123abc",
      "GCM_SENDER_ID": "correct_gcm_sender_id",
      "API_KEY": "correct_api_key",
      "PROJECT_ID": "abc-xyz-123",
      "STORAGE_BUCKET": "project-id-123.storage.firebase.com",
      "BUNDLE_ID": "com.google.FirebaseSDKTests",
      "CLIENT_ID": "correct_client_id",
      "DATABASE_URL": "https://abc-xyz-123.firebaseio.com",
    ]
    let plistData = try PropertyListSerialization.data(
      fromPropertyList: plistDict,
      format: .xml,
      options: 0
    )
    try plistData.write(to: tempURL)

    let loaded = try #require(FirebaseOptions(contentsOfFile: tempURL.path))

    #expect(loaded.googleAppID == "1:123:ios:123abc")
    #expect(loaded.gcmSenderID == "correct_gcm_sender_id")
    #expect(loaded.apiKey == "correct_api_key")
    #expect(loaded.projectID == "abc-xyz-123")
    #expect(loaded.storageBucket == "project-id-123.storage.firebase.com")
    #expect(loaded.bundleID == "com.google.FirebaseSDKTests")
    #expect(loaded.clientID == "correct_client_id")
    #expect(loaded.databaseURL == "https://abc-xyz-123.firebaseio.com")
  }

  @Test
  func optionsPlistAllowsMissingGCMSenderIDAndBinaryFormat() throws {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("GoogleService-Info-binary-\(UUID().uuidString).plist")
    defer { try? FileManager.default.removeItem(at: tempURL) }
    let plistDict: [String: String] = [
      "GOOGLE_APP_ID": "1:123:ios:binary",
      "API_KEY": "binary_api_key",
      "PROJECT_ID": "binary-project",
    ]
    let binaryData = try PropertyListSerialization.data(
      fromPropertyList: plistDict,
      format: .binary,
      options: 0
    )
    try binaryData.write(to: tempURL)

    let loaded = try #require(FirebaseOptions(contentsOfFile: tempURL.path))

    #expect(loaded.googleAppID == "1:123:ios:binary")
    #expect(loaded.gcmSenderID.isEmpty)
    #expect(loaded.apiKey == "binary_api_key")
    #expect(loaded.projectID == "binary-project")
  }

  @Test
  func optionsPlistInitializerReturnsNilForInvalidOrMissingFile() throws {
    let missingPath = FileManager.default.temporaryDirectory
      .appendingPathComponent("nonexistent-\(UUID().uuidString).plist").path
    let invalidURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("invalid-\(UUID().uuidString).plist")
    defer { try? FileManager.default.removeItem(at: invalidURL) }
    let incompletePlist = ["API_KEY": "only_api_key"]
    let data = try PropertyListSerialization.data(
      fromPropertyList: incompletePlist,
      format: .xml,
      options: 0
    )
    try data.write(to: invalidURL)

    let missingOptions = FirebaseOptions(contentsOfFile: missingPath)
    let invalidOptions = FirebaseOptions(contentsOfFile: invalidURL.path)

    #expect(missingOptions == nil)
    #expect(invalidOptions == nil)
  }

  @Test
  func defaultOptionsLoadsFromEnvironmentVariable() throws {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("GoogleService-Info-env-\(UUID().uuidString).plist")
    defer {
      unsetenv("GOOGLE_SERVICE_INFO_PATH")
      try? FileManager.default.removeItem(at: tempURL)
    }
    let plistDict: [String: String] = [
      "GOOGLE_APP_ID": "1:777:ios:env",
      "GCM_SENDER_ID": "777",
      "API_KEY": "env_api_key",
    ]
    let plistData = try PropertyListSerialization.data(
      fromPropertyList: plistDict,
      format: .xml,
      options: 0
    )
    try plistData.write(to: tempURL)
    setenv("GOOGLE_SERVICE_INFO_PATH", tempURL.path, 1)

    let options = try #require(FirebaseOptions.defaultOptions())

    #expect(options.googleAppID == "1:777:ios:env")
    #expect(options.apiKey == "env_api_key")
  }

  // MARK: - FirebaseApp Lifecycle Tests

  @Test
  func defaultAppConfigurationAndSnapshotOptions() throws {
    let options = FirebaseOptions(googleAppID: "1:111:ios:222", gcmSenderID: "333")
    options.apiKey = "initial-key"
    options.projectID = "initial-project"
    defer { FirebaseApp.resetApps() }

    FirebaseApp.configure(options: options)
    let defaultApp = try #require(FirebaseApp.app())
    let equalBeforeMutation = (defaultApp.options == options)
    let hashEqualBeforeMutation = (defaultApp.options.hashValue == options.hashValue)
    options.apiKey = "mutated-after-configure"

    #expect(FirebaseApp.isDefaultAppConfigured())
    #expect(defaultApp.isDefaultApp)
    #expect(defaultApp.name == "__FIRAPP_DEFAULT")
    #expect(equalBeforeMutation)
    #expect(hashEqualBeforeMutation)
    #expect(defaultApp.options.apiKey == "initial-key")
    #expect(defaultApp.options.projectID == "initial-project")
  }

  @Test
  func namedAppConfigurationDeletionAndAllApps() async throws {
    let options = FirebaseOptions(googleAppID: "1:111:ios:222", gcmSenderID: "333")
    defer { FirebaseApp.resetApps() }

    FirebaseApp.configure(name: "custom_app-1", options: options)
    let customApp = try #require(FirebaseApp.app(name: "custom_app-1"))
    customApp.isDataCollectionDefaultEnabled = false
    let allAppsBeforeDelete = try #require(FirebaseApp.allApps)
    let deleted = await customApp.delete()
    let deletedSecondTime = await customApp.delete()

    #expect(!customApp.isDefaultApp)
    #expect(!customApp.isDataCollectionDefaultEnabled)
    #expect(allAppsBeforeDelete["custom_app-1"] == customApp)
    #expect(deleted)
    #expect(!deletedSecondTime)
    #expect(FirebaseApp.app(name: "custom_app-1") == nil)
    #expect(FirebaseApp.allApps == nil)
  }

  @Test
  func deleteCompletionHandlerAndNoComponentResurrection() throws {
    let options = FirebaseOptions(googleAppID: "1:111:ios:222", gcmSenderID: "333")
    let factoryCallCount = UnfairLock<Int>(0)
    defer {
      FirebaseApp.resetApps()
      FirebaseComponentContainer.removeAllRegistrations()
    }
    FirebaseComponentContainer.register(for: (any MockServiceInterop).self) { app in
      factoryCallCount.withLock { $0 += 1 }
      return MockService(identifier: app.name)
    }
    FirebaseApp.configure(name: "delete-test", options: options)
    let configuredApp = try #require(FirebaseApp.app(name: "delete-test"))
    _ = ComponentType<any MockServiceInterop>.instance(
      for: (any MockServiceInterop).self,
      in: configuredApp.container
    )
    let standaloneSameName = FirebaseApp(instanceWithName: "delete-test", options: options)
    let standaloneUnregistered = FirebaseApp(instanceWithName: "unregistered", options: options)
    let deletedByNameBox = UnfairLock<Bool>(false)
    let deletedUnregisteredBox = UnfairLock<Bool>(true)

    standaloneSameName.delete { success in
      deletedByNameBox.withLock { $0 = success }
    }
    standaloneUnregistered.delete { success in
      deletedUnregisteredBox.withLock { $0 = success }
    }
    let postDeleteLookup = ComponentType<any MockServiceInterop>.instance(
      for: (any MockServiceInterop).self,
      in: configuredApp.container
    )

    #expect(deletedByNameBox.value())
    #expect(!deletedUnregisteredBox.value())
    #expect(postDeleteLookup == nil)
    #expect(factoryCallCount.value() == 1)
  }

  @Test
  func standaloneInstanceDoesNotPolluteGlobalRegistryAndDeallocates() {
    weak var weakApp: FirebaseApp?
    weak var weakContainer: FirebaseComponentContainer?

    do {
      let options = FirebaseOptions(googleAppID: "1:111:ios:222", gcmSenderID: "333")
      let transientApp = FirebaseApp(instanceWithName: "transient", options: options)
      let secondTransientApp = FirebaseApp(instanceWithName: "transient", options: options)
      weakApp = transientApp
      weakContainer = transientApp.container
      #expect(FirebaseApp.app(name: "transient") == nil)
      #expect(transientApp.container.app == transientApp)
      #expect(transientApp != secondTransientApp)
    }

    #expect(weakApp == nil)
    #expect(weakContainer == nil)
  }

  // MARK: - Precondition Exit Tests

  @Test
  func mutatingConfiguredAppOptionsExits() async {
    await #expect(processExitsWith: .failure) {
      let options = FirebaseOptions(googleAppID: "1:111:ios:222", gcmSenderID: "333")
      let app = FirebaseApp(instanceWithName: "locked-app", options: options)
      app.options.apiKey = "illegal-mutation"
    }
  }

  @Test
  func configuringInvalidAppNameExits() async {
    await #expect(processExitsWith: .failure) {
      let options = FirebaseOptions(googleAppID: "1:111:ios:222", gcmSenderID: "333")
      FirebaseApp.configure(name: "invalid name with spaces!", options: options)
    }
  }

  @Test
  func duplicateConfigureExits() async {
    await #expect(processExitsWith: .failure) {
      let options = FirebaseOptions(googleAppID: "1:111:ios:222", gcmSenderID: "333")
      FirebaseApp.configure(name: "dup-app", options: options)
      FirebaseApp.configure(name: "dup-app", options: options)
    }
  }

  // MARK: - FirebaseComponentContainer & ComponentType Tests

  @Test
  func componentContainerLazyFactoryLookup() throws {
    let options = FirebaseOptions(googleAppID: "1:111:ios:222", gcmSenderID: "333")
    defer {
      FirebaseApp.resetApps()
      FirebaseComponentContainer.removeAllRegistrations()
    }
    FirebaseComponentContainer.register(for: (any MockServiceInterop).self) { app in
      MockService(identifier: "service-for-\(app.name)")
    }
    FirebaseApp.configure(name: "service-app", options: options)
    let app = try #require(FirebaseApp.app(name: "service-app"))

    let resolvedFirst = try #require(
      ComponentType<any MockServiceInterop>.instance(
        for: (any MockServiceInterop).self,
        in: app.container
      )
    )
    let resolvedSecond = try #require(
      ComponentType<any MockServiceInterop>.instance(
        for: (any MockServiceInterop).self,
        in: app.container
      )
    )

    #expect(resolvedFirst.identifier == "service-for-service-app")
    #expect(resolvedFirst === resolvedSecond)
  }

  @Test
  func componentContainerDirectRegistrationAndResetCleanup() throws {
    let options = FirebaseOptions(googleAppID: "1:111:ios:222", gcmSenderID: "333")
    defer {
      FirebaseApp.resetApps()
      FirebaseComponentContainer.removeAllRegistrations()
    }
    FirebaseApp.configure(name: "direct-app", options: options)
    let app = try #require(FirebaseApp.app(name: "direct-app"))
    let directInstance = MockService(identifier: "direct-instance")

    app.container.register(instance: directInstance, for: (any MockServiceInterop).self)
    let resolvedBeforeReset = try #require(
      ComponentType<any MockServiceInterop>.instance(
        for: (any MockServiceInterop).self,
        in: app.container
      )
    )
    FirebaseApp.resetApps()
    let resolvedAfterReset = ComponentType<any MockServiceInterop>.instance(
      for: (any MockServiceInterop).self,
      in: app.container
    )

    #expect(resolvedBeforeReset === directInstance)
    #expect(resolvedAfterReset == nil)
  }

  @Test
  func componentContainerConcurrentInstanceLookupReturnsSameInstance() async throws {
    let options = FirebaseOptions(googleAppID: "1:111:ios:222", gcmSenderID: "333")
    defer {
      FirebaseApp.resetApps()
      FirebaseComponentContainer.removeAllRegistrations()
    }
    FirebaseComponentContainer.register(for: (any MockServiceInterop).self) { app in
      MockService(identifier: "concurrent-\(app.name)")
    }
    FirebaseApp.configure(name: "concurrent-app", options: options)
    let app = try #require(FirebaseApp.app(name: "concurrent-app"))
    let results = UnfairLock<[ObjectIdentifier]>([])

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 50 {
        group.addTask {
          if let service = ComponentType<any MockServiceInterop>.instance(
            for: (any MockServiceInterop).self,
            in: app.container
          ) {
            let id = ObjectIdentifier(service)
            results.withLock { $0.append(id) }
          }
        }
      }
    }

    let identifiers = results.value()
    let uniqueIdentifiers = Set(identifiers)
    #expect(identifiers.count == 50)
    #expect(uniqueIdentifiers.count == 1)
  }

  // MARK: - FirebaseConfiguration & FirebaseLogger Tests

  @Test
  func configurationLoggerLevelAndLoggerFiltering() {
    let recordedMessages = UnfairLock<[String]>([])
    defer {
      FirebaseConfiguration.shared.setLoggerLevel(.notice)
      FirebaseLogger.setSink(nil)
    }
    FirebaseConfiguration.shared.setLoggerLevel(.warning)
    FirebaseLogger.setSink { _, _, code, message in
      recordedMessages.withLock { $0.append("\(code):\(message)") }
    }

    FirebaseLogger.log(
      level: .error,
      service: "[Test]",
      code: "I-TST000001",
      message: "error-msg"
    )
    FirebaseLogger.log(
      level: .warning,
      service: "[Test]",
      code: "I-TST000002",
      message: "warn-msg"
    )
    FirebaseLogger.log(
      level: .notice,
      service: "[Test]",
      code: "I-TST000003",
      message: "notice-msg"
    )
    FirebaseLogger.log(
      level: .debug,
      service: "[Test]",
      code: "I-TST000004",
      message: "debug-msg"
    )

    #expect(FirebaseConfiguration.shared.loggerLevel() == .warning)
    #expect(FirebaseLoggerLevel.min == .error)
    #expect(FirebaseLoggerLevel.max == .debug)
    #expect(recordedMessages.value() == ["I-TST000001:error-msg", "I-TST000002:warn-msg"])
  }

  @Test
  func firebaseVersionFormat() {
    let version = FirebaseVersion()

    let hasPortableSuffix = version.hasSuffix("-portable")

    #expect(!version.isEmpty)
    #expect(hasPortableSuffix)
  }

  // MARK: - Concurrency Tests

  @Test
  func concurrentDataCollectionDefaultEnabledAccess() async {
    let options = FirebaseOptions(googleAppID: "1:111:ios:222", gcmSenderID: "333")
    let app = FirebaseApp(instanceWithName: "concurrency-app", options: options)
    let readValues = UnfairLock<[Bool]>([])

    await withTaskGroup(of: Void.self) { group in
      for index in 0 ..< 100 {
        group.addTask {
          if index.isMultiple(of: 2) {
            app.isDataCollectionDefaultEnabled = (index % 4 == 0)
          } else {
            let current = app.isDataCollectionDefaultEnabled
            readValues.withLock { $0.append(current) }
          }
        }
      }
    }

    #expect(readValues.value().count == 50)
  }

  @Test
  func unfairLockConcurrentMutations() async {
    let counter = UnfairLock<Int>(0)
    let iterations = 100

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< iterations {
        group.addTask {
          counter.withLock { $0 += 1 }
        }
      }
    }

    #expect(counter.value() == iterations)
  }
}
