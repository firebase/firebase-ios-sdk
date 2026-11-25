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

import AppCheckCore
import FirebaseCore
import Foundation
import XCTest

import FirebaseAppCheck
#if SWIFT_PACKAGE
  @testable import FirebaseAppCheckSwift
#else
  @testable import FirebaseAppCheck
#endif // SWIFT_PACKAGE
internal import FirebaseCoreExtension

// MARK: - AppCheckDebugProvider

final class AppCheckDebugProviderTests: XCTestCase {
  private final class FakeDebugProvider: FakeAppCheckCoreProvider, AppCheckCoreDebugProviding {
    var debugTokenSource: AppCheckCoreDebugTokenSource = .local
    var localToken = "local_token"
    var currentToken = "current_token"
    private(set) var localDebugTokenCount = 0

    func localDebugToken() -> String {
      localDebugTokenCount += 1
      return localToken
    }

    func currentDebugToken() -> String {
      currentToken
    }
  }

  private var debugProvider: FakeDebugProvider!
  private var provider: AppCheckDebugProvider!

  override func setUp() {
    super.setUp()
    debugProvider = FakeDebugProvider()
    provider = makeProvider(projectID: nil)
  }

  /// Returns a provider that uses the fake App Check Core debug provider.
  private func makeProvider(projectID: String?) -> AppCheckDebugProvider {
    AppCheckDebugProvider.makeForTesting(debugProvider: debugProvider,
                                         projectID: projectID,
                                         googleAppID: AppCheckTestUtils.appID)
  }

  /// Returns a provider whose core debug provider resolved its debug token from `source`.
  private func provider(debugTokenSource source: AppCheckCoreDebugTokenSource,
                        projectID: String?) -> AppCheckDebugProvider {
    debugProvider.debugTokenSource = source
    return makeProvider(projectID: projectID)
  }

  // MARK: Initialization

  func testInitWithValidApp() throws {
    let provider = try XCTUnwrap(AppCheckDebugProvider(app: AppCheckTestUtils.app()))
    XCTAssertTrue(provider.debugProvider is AppCheckCoreDebugProvider)
    XCTAssertEqual(provider.projectID, AppCheckTestUtils.projectID)
    XCTAssertEqual(provider.googleAppID, AppCheckTestUtils.appID)
    XCTAssertFalse(provider.currentDebugToken().isEmpty)
  }

  func testInitWithDebugProvider() {
    XCTAssertEqual(provider.debugTokenSource, .local)
    XCTAssertTrue(provider.debugProvider === debugProvider)
  }

  func testInitWithIncompleteApp() {
    XCTAssertNil(AppCheckDebugProvider(app: AppCheckTestUtils.app(apiKey: nil)))
    XCTAssertNil(AppCheckDebugProvider(app: AppCheckTestUtils.app(projectID: nil)))
    XCTAssertNil(AppCheckDebugProvider(app: AppCheckTestUtils.app(googleAppID: "")))
  }

  // MARK: Debug token source

  func testInitWithConfigStoreDebugTokenLogsAttribution() {
    let provider = provider(debugTokenSource: .provided, projectID: AppCheckTestUtils.projectID)
    XCTAssertEqual(provider.debugTokenSource, .provided)
    XCTAssertEqual(debugProvider.localDebugTokenCount, 0)
  }

  func testInitWithEnvironmentVariableDebugTokenDoesNotLogLocalToken() {
    let provider = provider(debugTokenSource: .environmentVariable,
                            projectID: AppCheckTestUtils.projectID)
    XCTAssertEqual(provider.debugTokenSource, .environmentVariable)
    XCTAssertEqual(debugProvider.localDebugTokenCount, 0)
  }

  func testInitWithLocalDebugTokenLogsLocalToken() {
    let provider = provider(debugTokenSource: .local, projectID: AppCheckTestUtils.projectID)
    XCTAssertEqual(provider.debugTokenSource, .local)
    XCTAssertEqual(debugProvider.localDebugTokenCount, 1)
  }

  func testInitWithLocalDebugTokenWithoutProjectIDDoesNotLogLocalToken() {
    // `setUp` creates a provider without a project ID.
    XCTAssertEqual(debugProvider.localDebugTokenCount, 0)
  }

  func testInitWithEmptyLocalDebugTokenSkipsRegistrationLog() {
    debugProvider.localToken = ""
    let provider = provider(debugTokenSource: .local, projectID: AppCheckTestUtils.projectID)
    XCTAssertEqual(provider.debugTokenSource, .local)
    XCTAssertEqual(debugProvider.localDebugTokenCount, 1)
  }

  func testUnrecognizedDebugTokenSourceIsNotTreatedAsLocal() {
    let unrecognized = unsafeBitCast(999 as Int, to: AppCheckCoreDebugTokenSource.self)
    let provider = provider(debugTokenSource: unrecognized, projectID: AppCheckTestUtils.projectID)
    XCTAssertEqual(provider.debugTokenSource.rawValue, 999)
    XCTAssertEqual(debugProvider.localDebugTokenCount, 0)

    let expectedError = NSError(domain: "testUnrecognizedDebugTokenSource", code: -1)
    debugProvider.tokenResult = (nil, expectedError)
    let handlerCalled = CallRecorder()
    provider.getToken { token, error in
      handlerCalled.called = true
      XCTAssertNil(token)
      XCTAssertEqual(error as NSError?, expectedError)
    }

    XCTAssertTrue(handlerCalled.called)
    XCTAssertEqual(debugProvider.localDebugTokenCount, 0)
    XCTAssertNil(provider.debugTokenExchangeFailureMessage(for: expectedError))
  }

  func testGetTokenAPIErrorWithLocalDebugTokenLogsLocalToken() {
    let provider = provider(debugTokenSource: .local, projectID: AppCheckTestUtils.projectID)
    let expectedError = NSError(domain: "testGetTokenAPIError", code: -1)
    debugProvider.tokenResult = (nil, expectedError)

    let handlerCalled = CallRecorder()
    provider.getToken { token, error in
      handlerCalled.called = true
      XCTAssertNil(token)
      XCTAssertEqual(error as NSError?, expectedError)
    }

    XCTAssertTrue(handlerCalled.called)
    // Once when the provider was created, and once for the failed token exchange.
    XCTAssertEqual(debugProvider.localDebugTokenCount, 2)
  }

  func testGetTokenAPIErrorWithConfigStoreDebugTokenDoesNotLogLocalToken() {
    let provider = provider(debugTokenSource: .provided, projectID: AppCheckTestUtils.projectID)
    let expectedError = NSError(domain: "testGetTokenAPIError", code: -1)
    debugProvider.tokenResult = (nil, expectedError)

    let handlerCalled = CallRecorder()
    provider.getToken { token, error in
      handlerCalled.called = true
      XCTAssertNil(token)
      XCTAssertEqual(error as NSError?, expectedError)
    }

    XCTAssertTrue(handlerCalled.called)
    XCTAssertEqual(debugProvider.localDebugTokenCount, 0)
  }

  func testGetLimitedUseTokenAPIErrorWithConfigStoreDebugTokenDoesNotLogLocalToken() {
    let provider = provider(debugTokenSource: .provided, projectID: AppCheckTestUtils.projectID)
    let expectedError = NSError(domain: "testGetLimitedUseTokenAPIError", code: -1)
    debugProvider.limitedUseTokenResult = (nil, expectedError)

    let handlerCalled = CallRecorder()
    provider.getLimitedUseToken { token, error in
      handlerCalled.called = true
      XCTAssertNil(token)
      XCTAssertEqual(error as NSError?, expectedError)
    }

    XCTAssertTrue(handlerCalled.called)
    XCTAssertEqual(debugProvider.localDebugTokenCount, 0)
  }

  func testGetTokenAPIErrorWithEnvironmentVariableDebugTokenDoesNotLogLocalToken() {
    let provider = provider(debugTokenSource: .environmentVariable,
                            projectID: AppCheckTestUtils.projectID)
    let expectedError = NSError(domain: "testGetTokenAPIError", code: -1)
    debugProvider.tokenResult = (nil, expectedError)

    let handlerCalled = CallRecorder()
    provider.getToken { token, error in
      handlerCalled.called = true
      XCTAssertNil(token)
      XCTAssertEqual(error as NSError?, expectedError)
    }

    XCTAssertTrue(handlerCalled.called)
    XCTAssertEqual(debugProvider.localDebugTokenCount, 0)
  }

  // MARK: Exchange failure messages

  func testConfigStoreExchangeFailureMessageSuggestsForceCreateAndRelaunch() throws {
    let provider = provider(debugTokenSource: .provided, projectID: AppCheckTestUtils.projectID)
    let error = NSError(domain: "testDomain", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Permission denied"])

    let message = try XCTUnwrap(provider.debugTokenExchangeFailureMessage(for: error))

    XCTAssertTrue(message.contains("~/.config/configstore/firebase-appcheck.json"))
    XCTAssertTrue(message.contains("Permission denied"))
    XCTAssertTrue(message.contains(
      "`firebase appcheck:debugtokens:create --force --project \(AppCheckTestUtils.projectID) "
        + "--app \(AppCheckTestUtils.appID)`"
    ), message)
    XCTAssertTrue(message.contains("relaunch the app"), message)
  }

  func testConfigStoreExchangeFailureMessageOmitsMissingProjectID() throws {
    let provider = provider(debugTokenSource: .provided, projectID: nil)
    let error = NSError(domain: "testDomain", code: -1)

    let message = try XCTUnwrap(provider.debugTokenExchangeFailureMessage(for: error))

    XCTAssertFalse(message.contains("--project"), message)
    XCTAssertFalse(message.contains("(null)"), message)
    XCTAssertTrue(message.contains(
      "`firebase appcheck:debugtokens:create --force --app \(AppCheckTestUtils.appID)`"
    ), message)
  }

  func testConfigStoreExchangeFailureMessagePrefersFailureReason() throws {
    let provider = provider(debugTokenSource: .provided, projectID: AppCheckTestUtils.projectID)
    let error = NSError(domain: "testDomain", code: -1,
                        userInfo: [
                          NSLocalizedFailureReasonErrorKey: "The server responded with an error",
                        ])

    let message = try XCTUnwrap(provider.debugTokenExchangeFailureMessage(for: error))

    XCTAssertTrue(message.contains(": The server responded with an error"), message)
    XCTAssertFalse(message.contains("couldn’t be completed"), message)
  }

  func testEnvironmentVariableExchangeFailureMessageNamesVariablesWithoutForce() throws {
    let provider = provider(debugTokenSource: .environmentVariable,
                            projectID: AppCheckTestUtils.projectID)
    let error = NSError(domain: "testDomain", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Permission denied"])

    let message = try XCTUnwrap(provider.debugTokenExchangeFailureMessage(for: error))

    XCTAssertTrue(message.contains("`AppCheckDebugToken`"), message)
    XCTAssertTrue(message.contains("`FIRAAppCheckDebugToken`"), message)
    XCTAssertTrue(message.contains("Permission denied"), message)
    XCTAssertTrue(message.contains(
      "`firebase appcheck:debugtokens:create <token> --project \(AppCheckTestUtils.projectID) "
        + "--app \(AppCheckTestUtils.appID)`"
    ), message)
    XCTAssertFalse(message.contains("--force"), message)
    XCTAssertFalse(message.contains("firebase-appcheck.json"), message)
  }

  func testLocalExchangeFailureMessageIsNil() {
    let error = NSError(domain: "testDomain", code: -1)
    XCTAssertNil(provider.debugTokenExchangeFailureMessage(for: error))
  }

  func testExchangeFailureMessageIsNilWhenServerUnreachable() {
    let error = NSError(domain: AppCheckCoreErrorDomain,
                        code: AppCheckCoreErrorCode.serverUnreachable.rawValue)
    let configStoreProvider = provider(debugTokenSource: .provided,
                                       projectID: AppCheckTestUtils.projectID)
    let environmentVariableProvider = provider(debugTokenSource: .environmentVariable,
                                               projectID: AppCheckTestUtils.projectID)

    XCTAssertNil(configStoreProvider.debugTokenExchangeFailureMessage(for: error))
    XCTAssertNil(environmentVariableProvider.debugTokenExchangeFailureMessage(for: error))
  }

  #if targetEnvironment(simulator)
    func testInitWithAppUsesConfigStoreDebugTokenForEachApp() throws {
      let otherAppID = "other_test_app_id"
      let hostHomeURL = temporaryHostHome(tokens: [
        AppCheckTestUtils.appID: "config_store_token",
        otherAppID: "other_config_store_token",
      ])
      setEnvironmentVariable("SIMULATOR_HOST_HOME", value: hostHomeURL.path)
      setEnvironmentVariable("AppCheckDebugToken", value: nil)
      setEnvironmentVariable("FIRAAppCheckDebugToken", value: nil)

      let provider = try XCTUnwrap(AppCheckDebugProvider(app: AppCheckTestUtils.app()))
      let otherProvider = try XCTUnwrap(AppCheckDebugProvider(app: AppCheckTestUtils.app(
        name: "other_test_app_name", googleAppID: otherAppID
      )))

      XCTAssertEqual(provider.currentDebugToken(), "config_store_token")
      XCTAssertEqual(provider.debugTokenSource, .provided)
      XCTAssertEqual(otherProvider.currentDebugToken(), "other_config_store_token")
      XCTAssertEqual(otherProvider.debugTokenSource, .provided)
    }

    func testInitWithAppAttributesMatchingEnvironmentVariableToEnvironment() throws {
      let hostHomeURL = temporaryHostHome(tokens: [AppCheckTestUtils.appID: "same_token"])
      setEnvironmentVariable("SIMULATOR_HOST_HOME", value: hostHomeURL.path)
      setEnvironmentVariable("AppCheckDebugToken", value: "same_token")
      setEnvironmentVariable("FIRAAppCheckDebugToken", value: nil)

      let provider = try XCTUnwrap(AppCheckDebugProvider(app: AppCheckTestUtils.app()))

      XCTAssertEqual(provider.currentDebugToken(), "same_token")
      XCTAssertEqual(provider.debugTokenSource, .environmentVariable)
    }

    private func temporaryHostHome(tokens: [String: String], file: StaticString = #filePath,
                                   line: UInt = #line) -> URL {
      let hostHomeURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
      let fileURL = hostHomeURL.appendingPathComponent(DebugTokenConfigStore.relativePath,
                                                       isDirectory: false)
      XCTAssertNoThrow(try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
      ), file: file, line: line)
      XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: ["tokens": tokens])
        .write(to: fileURL, options: .atomic), file: file, line: line)
      addTeardownBlock {
        try? FileManager.default.removeItem(at: hostHomeURL)
      }
      return hostHomeURL
    }

    /// Sets (or unsets, when `value` is `nil`) a process environment variable for the duration
    /// of the test, restoring its previous value afterwards.
    private func setEnvironmentVariable(_ name: String, value: String?) {
      let previous = getenv(name).map { String(cString: $0) }
      if let value {
        setenv(name, value, 1)
      } else {
        unsetenv(name)
      }
      addTeardownBlock {
        if let previous {
          setenv(name, previous, 1)
        } else {
          unsetenv(name)
        }
      }
    }
  #endif // targetEnvironment(simulator)

  // MARK: Debug tokens

  func testCurrentTokenShim() {
    debugProvider.currentToken = "debug_token"
    XCTAssertEqual(provider.currentDebugToken(), "debug_token")
  }

  func testLocalDebugToken() {
    debugProvider.localToken = "TEST_LocalDebugToken"
    XCTAssertEqual(provider.localDebugToken(), "TEST_LocalDebugToken")
  }

  // MARK: Debug token to FAC token exchange

  func testGetTokenSuccess() {
    let validInternalToken = AppCheckCoreToken(token: "valid_token", expirationDate: Date(),
                                               receivedAt: Date())
    debugProvider.tokenResult = (validInternalToken, nil)

    let handlerCalled = CallRecorder()
    provider.getToken { token, error in
      handlerCalled.called = true
      XCTAssertEqual(token?.token, validInternalToken.token)
      XCTAssertEqual(token?.expirationDate, validInternalToken.expirationDate)
      XCTAssertEqual(token?.receivedAtDate, validInternalToken.receivedAtDate)
      XCTAssertNil(error)
    }

    XCTAssertTrue(handlerCalled.called)
    XCTAssertEqual(debugProvider.getTokenCount, 1)
  }

  func testGetTokenAsync() async throws {
    debugProvider.tokenResult = (AppCheckCoreToken(token: "valid_token",
                                                   expirationDate: .distantFuture), nil)
    let token = try await provider.getToken()
    XCTAssertEqual(token.token, "valid_token")
  }

  func testGetTokenAPIError() {
    let expectedError = NSError(domain: "testGetTokenAPIError", code: -1)
    debugProvider.tokenResult = (nil, expectedError)

    let handlerCalled = CallRecorder()
    provider.getToken { token, error in
      handlerCalled.called = true
      XCTAssertNil(token)
      XCTAssertEqual(error as NSError?, expectedError)
    }

    XCTAssertTrue(handlerCalled.called)
  }

  func testGetTokenWithoutTokenOrError() {
    debugProvider.tokenResult = (nil, nil)

    let handlerCalled = CallRecorder()
    provider.getToken { token, error in
      handlerCalled.called = true
      XCTAssertNil(token)
      XCTAssertEqual((error as NSError?)?.domain, AppCheckErrorDomain)
    }

    XCTAssertTrue(handlerCalled.called)
  }

  // MARK: Limited-use token

  func testGetLimitedUseTokenSuccess() {
    let validInternalToken = AppCheckCoreToken(token: "TEST_ValidToken", expirationDate: Date(),
                                               receivedAt: Date())
    debugProvider.limitedUseTokenResult = (validInternalToken, nil)

    let handlerCalled = CallRecorder()
    provider.getLimitedUseToken { token, error in
      handlerCalled.called = true
      XCTAssertEqual(token?.token, validInternalToken.token)
      XCTAssertEqual(token?.expirationDate, validInternalToken.expirationDate)
      XCTAssertEqual(token?.receivedAtDate, validInternalToken.receivedAtDate)
      XCTAssertNil(error)
    }

    XCTAssertTrue(handlerCalled.called)
    XCTAssertEqual(debugProvider.getLimitedUseTokenCount, 1)
    XCTAssertEqual(debugProvider.getTokenCount, 0)
  }

  func testGetLimitedUseTokenAsync() async throws {
    debugProvider.limitedUseTokenResult = (AppCheckCoreToken(token: "limited",
                                                             expirationDate: .distantFuture), nil)
    let token = try await provider.getLimitedUseToken()
    XCTAssertEqual(token.token, "limited")
  }

  func testGetLimitedUseTokenProviderError() {
    let expectedError = NSError(domain: "TEST_LimitedUseToken_Error", code: -1)
    debugProvider.limitedUseTokenResult = (nil, expectedError)

    let handlerCalled = CallRecorder()
    provider.getLimitedUseToken { token, error in
      handlerCalled.called = true
      XCTAssertNil(token)
      XCTAssertTrue(error as NSError? === expectedError)
    }

    XCTAssertTrue(handlerCalled.called)
  }

  // `AppCheckDebugProviderFactory` is tested in `AppCheckPublicBehaviorTests`.
}

// MARK: - DebugTokenConfigStore

final class DebugTokenConfigStoreTests: XCTestCase {
  private let appID = "1:248211933065:ios:91feeddd848ff1a48f0358"
  private let otherAppID = "1:248211933065:android:0123456789abcdef012345"
  private let token = "29d93e77-7bea-4f2a-b6ed-c1d1db892666"

  /// A temporary directory standing in for the host user's home directory.
  private var hostHomeURL: URL!
  private var environment: [String: String]!

  override func setUpWithError() throws {
    try super.setUpWithError()
    hostHomeURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("DebugTokenConfigStoreTests-\(UUID().uuidString)",
                              isDirectory: true)
    try FileManager.default.createDirectory(at: hostHomeURL, withIntermediateDirectories: true)
    environment = ["SIMULATOR_HOST_HOME": hostHomeURL.path]
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: hostHomeURL)
    super.tearDown()
  }

  // MARK: Helpers

  private var configStoreURL: URL {
    hostHomeURL.appendingPathComponent(DebugTokenConfigStore.relativePath, isDirectory: false)
  }

  private func writeConfigStoreContents(_ contents: String) throws {
    try FileManager.default.createDirectory(at: configStoreURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try contents.write(to: configStoreURL, atomically: true, encoding: .utf8)
  }

  private func writeConfigStoreTokens(_ tokens: [String: Any]) throws {
    let json: [String: Any] = [
      "_comment": "This file contains secrets and should not be committed to source repositories",
      "tokens": tokens,
    ]
    let data = try JSONSerialization.data(withJSONObject: json)
    try writeConfigStoreContents(String(decoding: data, as: UTF8.self))
  }

  /// Writes an empty regular file at `relativePath` under the temporary host home.
  private func writeEmptyFile(atRelativePath relativePath: String) throws {
    let fileURL = hostHomeURL.appendingPathComponent(relativePath, isDirectory: false)
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try "".write(to: fileURL, atomically: true, encoding: .utf8)
  }

  /// Reads the config store file under the temporary host home the same way the config store
  /// does, and returns the resulting error.
  private func configStoreReadError(file: StaticString = #filePath,
                                    line: UInt = #line) -> Error? {
    do {
      _ = try Data(contentsOf: configStoreURL)
      XCTFail("Expected reading the config store to fail.", file: file, line: line)
      return nil
    } catch {
      return error
    }
  }

  private func debugToken(forGoogleAppID googleAppID: String? = nil,
                          environment: [String: String]? = nil) -> String? {
    DebugTokenConfigStore.debugToken(forGoogleAppID: googleAppID ?? appID,
                                     environment: environment ?? self.environment)
  }

  // MARK: Tests

  func testRelativePath() {
    XCTAssertEqual(DebugTokenConfigStore.relativePath,
                   ".config/configstore/firebase-appcheck.json")
  }

  #if targetEnvironment(simulator)
    func testDebugTokenForAppInConfigStore() throws {
      try writeConfigStoreTokens([appID: token, otherAppID: "other-token"])
      XCTAssertEqual(debugToken(), token)
    }

    func testDebugTokenForAppMissingFromConfigStore() throws {
      try writeConfigStoreTokens([otherAppID: "other-token"])
      XCTAssertNil(debugToken())
    }

    func testDebugTokenWhenConfigStoreFileMissing() {
      XCTAssertNil(debugToken())
    }

    func testDebugTokenWhenSimulatorHostHomeUnset() throws {
      try writeConfigStoreTokens([appID: token])
      XCTAssertNil(debugToken(environment: [:]))
    }

    func testDebugTokenWhenSimulatorHostHomeEmpty() throws {
      try writeConfigStoreTokens([appID: token])
      XCTAssertNil(debugToken(environment: ["SIMULATOR_HOST_HOME": ""]))
    }

    func testDebugTokenWhenConfigStoreMalformed() throws {
      try writeConfigStoreContents("{ not json")
      XCTAssertNil(debugToken())
    }

    func testDebugTokenWhenTokensNotADictionary() throws {
      try writeConfigStoreContents("{\"tokens\": [\"not\", \"a\", \"dictionary\"]}")
      XCTAssertNil(debugToken())
    }

    func testDebugTokenWhenTokensKeyMissing() throws {
      try writeConfigStoreContents("{\"tokenNames\": {}}")
      XCTAssertNil(debugToken())
    }

    func testDebugTokenWhenTokensIsNull() throws {
      try writeConfigStoreContents("{\"tokens\": null}")
      XCTAssertNil(debugToken())
    }

    func testDebugTokenWhenConfigStoreIsEmptyObject() throws {
      try writeConfigStoreContents("{}")
      XCTAssertNil(debugToken())
    }

    func testDebugTokenWhenTokenNotAString() throws {
      try writeConfigStoreTokens([appID: 42])
      XCTAssertNil(debugToken())
    }

    func testDebugTokenWhenTokenEmpty() throws {
      try writeConfigStoreTokens([appID: ""])
      XCTAssertNil(debugToken())
    }

    func testDebugTokenWhenGoogleAppIDEmpty() throws {
      try writeConfigStoreTokens([appID: token])
      XCTAssertNil(debugToken(forGoogleAppID: ""))
    }

    func testDebugTokenWhenTopLevelJSONIsAnArray() throws {
      try writeConfigStoreContents("[{\"tokens\": {}}]")
      XCTAssertNil(debugToken())
    }

    func testDebugTokenWhenTokenIsNull() throws {
      try writeConfigStoreTokens([appID: NSNull()])
      XCTAssertNil(debugToken())
    }

    func testDebugTokenWhenSimulatorHostHomeHasTrailingSlash() throws {
      try writeConfigStoreTokens([appID: token])
      XCTAssertEqual(debugToken(environment: ["SIMULATOR_HOST_HOME": hostHomeURL.path + "/"]),
                     token)
    }

    func testDebugTokenWhenConfigStorePathIsADirectory() throws {
      try FileManager.default.createDirectory(at: configStoreURL,
                                              withIntermediateDirectories: true)
      XCTAssertNil(debugToken())
    }

    func testDebugTokenWhenConfigStoreParentIsAFile() throws {
      // `~/.config` is a regular file, so the config store cannot exist; treated like a missing
      // file.
      try writeEmptyFile(atRelativePath: ".config")
      XCTAssertNil(debugToken())
    }
  #else
    func testDebugTokenIsNilOutsideSimulator() throws {
      // Seed a valid config store so a `nil` result proves the lookup is compiled out rather
      // than failing to find the file.
      try writeConfigStoreTokens([appID: token])
      XCTAssertNil(debugToken())
    }
  #endif // targetEnvironment(simulator)

  // MARK: Missing config store errors

  func testMissingFileIsMissingConfigStoreError() {
    let error = configStoreReadError()
    XCTAssertTrue(
      DebugTokenConfigStore.isMissingConfigStoreError(error),
      "\(String(describing: error))"
    )
  }

  func testConfigParentFileIsMissingConfigStoreError() throws {
    try writeEmptyFile(atRelativePath: ".config")
    let error = configStoreReadError()
    XCTAssertTrue(
      DebugTokenConfigStore.isMissingConfigStoreError(error),
      "\(String(describing: error))"
    )
  }

  func testConfigstoreParentFileIsMissingConfigStoreError() throws {
    try writeEmptyFile(atRelativePath: ".config/configstore")
    let error = configStoreReadError()
    XCTAssertTrue(
      DebugTokenConfigStore.isMissingConfigStoreError(error),
      "\(String(describing: error))"
    )
  }

  func testDirectoryAtConfigStorePathIsNotMissingConfigStoreError() throws {
    try FileManager.default.createDirectory(at: configStoreURL, withIntermediateDirectories: true)
    let error = configStoreReadError()
    XCTAssertFalse(
      DebugTokenConfigStore.isMissingConfigStoreError(error),
      "\(String(describing: error))"
    )
  }

  func testUnreadableConfigStoreIsNotMissingConfigStoreError() throws {
    try writeConfigStoreTokens([appID: token])
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: configStoreURL.path)
    let error = configStoreReadError()
    XCTAssertFalse(
      DebugTokenConfigStore.isMissingConfigStoreError(error),
      "\(String(describing: error))"
    )
  }

  func testNilIsNotMissingConfigStoreError() {
    XCTAssertFalse(DebugTokenConfigStore.isMissingConfigStoreError(nil))
  }

  func testNonErrorUnderlyingValueIsNotMissingConfigStoreError() {
    let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
                        userInfo: [NSUnderlyingErrorKey: "not an error"])
    XCTAssertFalse(DebugTokenConfigStore.isMissingConfigStoreError(error))
  }
}
