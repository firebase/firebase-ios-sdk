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
import FirebaseAppCheckInterop
import FirebaseCore
import Foundation
import XCTest

import FirebaseAppCheck
#if SWIFT_PACKAGE
  import FirebaseAppCheck.Internal
  @testable import FirebaseAppCheckSwift
#else
  @testable import FirebaseAppCheck
#endif // SWIFT_PACKAGE
internal import FirebaseCoreExtension

// MARK: - Shared test helpers

/// The App Check token value App Check Core returns when an error occurs.
let kPlaceholderToken = "eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ=="

enum AppCheckTestUtils {
  static let appName = "test_app_name"
  static let appID = "test_app_id"
  static let apiKey = "test_api_key"
  static let projectID = "test_project_id"
  static let projectNumber = "123456789"

  /// Returns an app that isn't registered with Firebase, with complete options for token exchange
  /// and automatic token refresh disabled.
  static func app(name: String = appName, googleAppID: String = appID,
                  apiKey: String? = apiKey, projectID: String? = projectID) -> FirebaseApp {
    let options = FirebaseOptions(googleAppID: googleAppID, gcmSenderID: projectNumber)
    options.apiKey = apiKey
    options.projectID = projectID
    let app = FirebaseApp(instanceWithName: name, options: options)
    // The following disables automatic token refresh, which could interfere with tests.
    app.isDataCollectionDefaultEnabled = false
    return app
  }

  static func appCheckCoreError(code: AppCheckCoreErrorCode, failureReason: String?,
                                underlyingError: Error?) -> NSError {
    var userInfo: [String: Any] = [:]
    userInfo[NSUnderlyingErrorKey] = underlyingError
    userInfo[NSLocalizedFailureReasonErrorKey] = failureReason
    return NSError(domain: "com.google.app_check_core", code: code.rawValue, userInfo: userInfo)
  }
}

/// Records whether a completion handler was called.
final class CallRecorder: @unchecked Sendable {
  var called = false
}

/// A fake App Check Core provider that returns stubbed results.
class FakeAppCheckCoreProvider: NSObject, AppCheckCoreProvider {
  var tokenResult: (AppCheckCoreToken?, Error?) = (nil, nil)
  var limitedUseTokenResult: (AppCheckCoreToken?, Error?) = (nil, nil)
  private(set) var getTokenCount = 0
  private(set) var getLimitedUseTokenCount = 0

  func getToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    getTokenCount += 1
    handler(tokenResult.0, tokenResult.1)
  }

  func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    getLimitedUseTokenCount += 1
    handler(limitedUseTokenResult.0, limitedUseTokenResult.1)
  }
}

/// A fake public App Check provider.
final class FakeAppCheckProvider: NSObject, AppCheckProvider, @unchecked Sendable {
  var token = AppCheckToken(token: "token", expirationDate: .distantFuture)
  private(set) var getTokenCount = 0

  func getToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
    getTokenCount += 1
    handler(token, nil)
  }
}

final class FakeAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  let provider: AppCheckProvider?
  private(set) var requestedApps: [FirebaseApp] = []

  init(provider: AppCheckProvider?) {
    self.provider = provider
  }

  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    requestedApps.append(app)
    return provider
  }
}

private class AppCheckSubclass: AppCheck {}

// MARK: - AppCheck

final class AppCheckTests: XCTestCase {
  private final class FakeAppCheckCore: NSObject, AppCheckCoreProtocol {
    var tokenResult: AppCheckCoreTokenResult?
    var limitedUseTokenResult: AppCheckCoreTokenResult?
    /// Called when a token is requested, before the completion handler.
    var onTokenRequest: (() -> Void)?
    private(set) var forcingRefreshValues: [Bool] = []
    private(set) var limitedUseTokenCount = 0

    func token(forcingRefresh: Bool, completion: @escaping AppCheckCoreTokenHandler) {
      forcingRefreshValues.append(forcingRefresh)
      onTokenRequest?()
      completion(tokenResult!)
    }

    func limitedUseToken(completion: @escaping AppCheckCoreTokenHandler) {
      limitedUseTokenCount += 1
      completion(limitedUseTokenResult!)
    }
  }

  private final class FakeSettings: NSObject, AppCheckCoreSettingsProtocol {
    var isTokenAutoRefreshEnabled = false
  }

  private let appName = "AppCheckTests"
  private var appCheckCore: FakeAppCheckCore!
  private var settings: FakeSettings!
  private var notificationCenter: NotificationCenter!
  private var appCheck: AppCheck!

  override func setUp() {
    super.setUp()
    appCheckCore = FakeAppCheckCore()
    settings = FakeSettings()
    notificationCenter = NotificationCenter()
    appCheck = makeAppCheck(appCheckCore: appCheckCore, settings: settings)
  }

  /// Returns an `AppCheck` instance that uses fakes.
  private func makeAppCheck(appCheckCore: AppCheckCoreProtocol,
                            settings: AppCheckCoreSettingsProtocol) -> AppCheck {
    AppCheck.setAppCheckProviderFactory(FakeAppCheckProviderFactory(provider:
      FakeAppCheckProvider()))
    let appCheck = AppCheck(app: AppCheckTestUtils.app(name: appName))!
    XCTAssertEqual(appCheck.appName, appName)
    appCheck.appCheckCore = appCheckCore
    appCheck.settings = settings
    appCheck.notificationCenter = notificationCenter
    return appCheck
  }

  override func tearDown() {
    appCheck = nil
    appCheckCore = nil
    settings = nil
    notificationCenter = nil
    resetAppCheckProviderFactoryForTesting()
    super.tearDown()
  }

  // MARK: Helpers

  private func validToken() -> AppCheckToken {
    AppCheckToken(token: UUID().uuidString, expirationDate: .distantFuture)
  }

  private func internalError() -> NSError {
    NSError(domain: "com.internal.error", code: -1)
  }

  /// Stubs a successful token request that posts a token update, like App Check Core does.
  private func stubTokenRequest(token: AppCheckToken) {
    let internalToken = token.internalToken
    appCheckCore.tokenResult = AppCheckCoreTokenResult(token: internalToken)
    appCheckCore.onTokenRequest = { [unowned self] in
      appCheck.tokenDidUpdate(internalToken, serviceName: appName)
    }
  }

  private func tokenUpdateNotification(expectedToken: String) -> XCTestExpectation {
    expectation(forNotification: .AppCheckTokenDidChange,
                object: nil,
                notificationCenter: notificationCenter) { [unowned self] notification in
      XCTAssertEqual(notification.userInfo?[AppCheckAppNameNotificationKey] as? String, appName)
      XCTAssertEqual(notification.userInfo?[AppCheckTokenNotificationKey] as? String,
                     expectedToken)
      XCTAssertTrue(notification.object as AnyObject === appCheck)
      return true
    }
  }

  private func tokenUpdateNotificationNotPosted() -> XCTestExpectation {
    let expectation = XCTNSNotificationExpectation(name: .AppCheckTokenDidChange,
                                                   object: nil,
                                                   notificationCenter: notificationCenter)
    expectation.isInverted = true
    return expectation
  }

  // MARK: Initialization

  func testInitWithApp() throws {
    let options = FirebaseOptions(googleAppID: "testInitWithApp_googleAppID", gcmSenderID: "")
    options.projectID = "testInitWithApp_projectID"
    options.appGroupID = "testInitWithApp_appGroupID"
    let app = FirebaseApp(instanceWithName: "testInitWithApp_appName", options: options)
    app.isDataCollectionDefaultEnabled = false

    let provider = FakeAppCheckProvider()
    let factory = FakeAppCheckProviderFactory(provider: provider)
    AppCheck.setAppCheckProviderFactory(factory)
    let loggerLevel = FIRGetLoggerLevel()
    let appCheckCoreLogLevel = AppCheckCoreLogger.logLevel
    FIRSetLoggerLevel(.debug)
    defer {
      FIRSetLoggerLevel(loggerLevel)
      AppCheckCoreLogger.logLevel = appCheckCoreLogLevel
    }

    XCTAssertNotNil(AppCheck(app: app))

    XCTAssertEqual(factory.requestedApps.count, 1)
    XCTAssertTrue(factory.requestedApps.first === app)
    // The App Check Core logging level matches the Firebase logging level.
    XCTAssertEqual(AppCheckCoreLogger.logLevel, .debug)
  }

  func testInitWithAppWithoutProviderFactory() {
    AppCheck.setAppCheckProviderFactory(nil)
    XCTAssertNil(AppCheck(app: AppCheckTestUtils.app()))
  }

  func testInitWithAppWithoutProvider() {
    AppCheck.setAppCheckProviderFactory(FakeAppCheckProviderFactory(provider: nil))
    XCTAssertNil(AppCheck(app: AppCheckTestUtils.app()))
  }

  /// Configures a Firebase app named `name`, whose App Check instance uses a fake provider.
  ///
  /// `FirebaseApp(instanceWithName:options:)` isn't enough for tests that need the App Check
  /// component: FirebaseCore registers `FIRAppCheckComponent` in the first
  /// `FirebaseApp.configure(name:options:)` call, and an app's component container only has the
  /// components registered when it was created.
  private func configureApp(name: String) throws -> FirebaseApp {
    AppCheck.setAppCheckProviderFactory(FakeAppCheckProviderFactory(provider:
      FakeAppCheckProvider()))
    let options = FirebaseOptions(googleAppID: "1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa",
                                  gcmSenderID: "sender_id")
    options.apiKey = "api_key"
    options.projectID = "project_id"
    FirebaseApp.configure(name: name, options: options)
    let app = try XCTUnwrap(FirebaseApp.app(name: name))
    app.isDataCollectionDefaultEnabled = false
    return app
  }

  func testAppCheckInstanceForApp() async throws {
    let app = try configureApp(name: "testAppCheckInstanceForApp")

    let appCheck = try XCTUnwrap(AppCheck.appCheck(app: app))
    XCTAssertTrue(AppCheck.appCheck(app: app) === appCheck)
    // The App Check Core logging level is the default (Warning).
    XCTAssertEqual(AppCheckCoreLogger.logLevel, .warning)
    await app.delete()
  }

  /// Changed from the Objective-C implementation, which returned the registered `AppCheck`
  /// instance, typed as the subclass, from `appCheck(app:)` called on a subclass. Calling a member
  /// of the subclass on it was undefined behavior. The Swift implementation returns `nil`.
  func testAppCheckForAppIsNilWhenCalledOnASubclass() async throws {
    let app = try configureApp(name: "testAppCheckForAppIsNilWhenCalledOnASubclass")

    XCTAssertNotNil(AppCheck.appCheck(app: app))
    XCTAssertNil(AppCheckSubclass.appCheck(app: app))
    await app.delete()
  }

  func testDefaultProviderFactoryIsUsedWhenNoFactoryWasSet() {
    let storage = ProviderFactoryStorage()
    XCTAssertTrue(storage.factory is DefaultProviderFactory)
    // The same default factory instance is reused.
    XCTAssertTrue(storage.factory === storage.factory)

    storage.setFactory(nil)
    XCTAssertNil(storage.factory)

    let factory = FakeAppCheckProviderFactory(provider: nil)
    storage.setFactory(factory)
    XCTAssertTrue(storage.factory === factory)
  }

  // MARK: Public get token

  func testGetToken_Success() {
    let expectedToken = validToken()
    stubTokenRequest(token: expectedToken)
    let notification = tokenUpdateNotification(expectedToken: expectedToken.token)
    let completion = expectation(description: "getToken")

    appCheck.token(forcingRefresh: false) { token, error in
      XCTAssertEqual(token?.token, expectedToken.token)
      XCTAssertNil(error)
      completion.fulfill()
    }

    wait(for: [notification, completion], timeout: 0.5)
    XCTAssertEqual(appCheckCore.forcingRefreshValues, [false])
  }

  func testGetToken_ForcingRefresh() {
    stubTokenRequest(token: validToken())
    let completion = expectation(description: "getToken")

    appCheck.token(forcingRefresh: true) { _, _ in completion.fulfill() }

    wait(for: [completion], timeout: 0.5)
    XCTAssertEqual(appCheckCore.forcingRefreshValues, [true])
  }

  func testGetToken_Async() async throws {
    let expectedToken = validToken()
    stubTokenRequest(token: expectedToken)

    let token = try await appCheck.token(forcingRefresh: false)

    XCTAssertEqual(token.token, expectedToken.token)
  }

  func testGetToken_AppCheckProviderError() {
    let providerError = NSError(domain: "AppCheckTests", code: -1)
    appCheckCore.tokenResult = AppCheckCoreTokenResult(error: providerError)
    let notification = tokenUpdateNotificationNotPosted()
    let completion = expectation(description: "getToken")

    appCheck.token(forcingRefresh: false) { token, error in
      XCTAssertNil(token)
      let error = error as NSError?
      XCTAssertNotEqual(error, providerError)
      XCTAssertEqual(error?.domain, AppCheckErrorDomain)
      XCTAssertEqual(error?.userInfo[NSUnderlyingErrorKey] as? NSError, providerError)
      completion.fulfill()
    }

    wait(for: [notification, completion], timeout: 0.5)
  }

  func testGetToken_ServerUnreachableError() {
    let serverError = AppCheckTestUtils.appCheckCoreError(code: .serverUnreachable,
                                                          failureReason: "API request error.",
                                                          underlyingError: internalError())
    appCheckCore.tokenResult = AppCheckCoreTokenResult(error: serverError)
    let notification = tokenUpdateNotificationNotPosted()
    let completion = expectation(description: "getToken")

    appCheck.token(forcingRefresh: false) { token, error in
      XCTAssertNil(token)
      let error = error as NSError?
      XCTAssertEqual(error, AppCheckErrorUtil.publicDomainError(serverError))
      XCTAssertEqual(error?.domain, AppCheckErrorDomain)
      XCTAssertEqual(error?.code, AppCheckErrorCode.serverUnreachable.rawValue)
      XCTAssertEqual(error?.userInfo as NSDictionary?, serverError.userInfo as NSDictionary)
      completion.fulfill()
    }

    wait(for: [notification, completion], timeout: 0.5)
  }

  func testGetToken_UnsupportedError() {
    let providerError = AppCheckTestUtils.appCheckCoreError(
      code: .unsupported, failureReason: "AppAttestProvider unsupported", underlyingError: nil
    )
    appCheckCore.tokenResult = AppCheckCoreTokenResult(error: providerError)
    let completion = expectation(description: "getToken")

    appCheck.token(forcingRefresh: false) { token, error in
      XCTAssertNil(token)
      let error = error as NSError?
      XCTAssertEqual(error, AppCheckErrorUtil.publicDomainError(providerError))
      XCTAssertEqual(error?.code, AppCheckErrorCode.unsupported.rawValue)
      XCTAssertEqual(error?.userInfo as NSDictionary?, providerError.userInfo as NSDictionary)
      completion.fulfill()
    }

    wait(for: [completion], timeout: 0.5)
  }

  func testGetToken_AsyncThrows() async {
    appCheckCore.tokenResult = AppCheckCoreTokenResult(
      error: AppCheckTestUtils.appCheckCoreError(code: .keychain, failureReason: nil,
                                                 underlyingError: nil)
    )

    do {
      _ = try await appCheck.token(forcingRefresh: false)
      XCTFail("Expected an error.")
    } catch AppCheckErrorCode.keychain {
      // Expected.
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  // MARK: Interop get token

  func testInteropGetTokenForcingRefresh_Success() {
    let expectedToken = validToken()
    stubTokenRequest(token: expectedToken)
    let notification = tokenUpdateNotification(expectedToken: expectedToken.token)
    let completion = expectation(description: "getToken")

    appCheck.getToken(forcingRefresh: false) { result in
      XCTAssertEqual(result.token, expectedToken.token)
      XCTAssertNil(result.error)
      completion.fulfill()
    }

    wait(for: [notification, completion], timeout: 0.5)
  }

  func testInteropGetTokenForcingRefresh_AppCheckProviderError() {
    let providerError = NSError(domain: "AppCheckTests", code: -1)
    appCheckCore.tokenResult = AppCheckCoreTokenResult(error: providerError)
    let notification = tokenUpdateNotificationNotPosted()
    let completion = expectation(description: "getToken")

    appCheck.getToken(forcingRefresh: false) { result in
      XCTAssertEqual(result.token, kPlaceholderToken)
      // The interop API doesn't wrap errors in the public domain.
      XCTAssertEqual(result.error as NSError?, providerError)
      completion.fulfill()
    }

    wait(for: [notification, completion], timeout: 0.5)
  }

  func testInteropGetLimitedUseToken() {
    let expectedToken = validToken()
    appCheckCore.limitedUseTokenResult =
      AppCheckCoreTokenResult(token: expectedToken.internalToken)
    let completion = expectation(description: "getLimitedUseToken")

    appCheck.getLimitedUseToken { result in
      XCTAssertEqual(result.token, expectedToken.token)
      XCTAssertNil(result.error)
      completion.fulfill()
    }

    wait(for: [completion], timeout: 0.5)
  }

  // MARK: Limited-use token

  func testLimitedUseTokenWithSuccess() {
    let expectedToken = validToken()
    appCheckCore.limitedUseTokenResult =
      AppCheckCoreTokenResult(token: expectedToken.internalToken)
    let notification = tokenUpdateNotificationNotPosted()
    let completion = expectation(description: "getToken")

    appCheck.limitedUseToken { token, error in
      XCTAssertEqual(token?.token, expectedToken.token)
      XCTAssertNil(error)
      completion.fulfill()
    }

    wait(for: [notification, completion], timeout: 0.5)
    XCTAssertEqual(appCheckCore.limitedUseTokenCount, 1)
    XCTAssertEqual(appCheckCore.forcingRefreshValues, [])
  }

  func testLimitedUseToken_WhenTokenGenerationErrors() {
    let providerError = AppCheckTestUtils.appCheckCoreError(code: .keychain,
                                                            failureReason: "Keychain access error.",
                                                            underlyingError: internalError())
    appCheckCore.limitedUseTokenResult = AppCheckCoreTokenResult(error: providerError)
    let notification = tokenUpdateNotificationNotPosted()
    let completion = expectation(description: "getToken")

    appCheck.limitedUseToken { token, error in
      XCTAssertNil(token)
      let error = error as NSError?
      XCTAssertEqual(error, AppCheckErrorUtil.publicDomainError(providerError))
      XCTAssertEqual(error?.domain, AppCheckErrorDomain)
      XCTAssertEqual(error?.code, AppCheckErrorCode.keychain.rawValue)
      XCTAssertEqual(error?.userInfo as NSDictionary?, providerError.userInfo as NSDictionary)
      completion.fulfill()
    }

    wait(for: [notification, completion], timeout: 0.5)
  }

  func testLimitedUseToken_Async() async throws {
    let expectedToken = validToken()
    appCheckCore.limitedUseTokenResult =
      AppCheckCoreTokenResult(token: expectedToken.internalToken)

    let token = try await appCheck.limitedUseToken()

    XCTAssertEqual(token.token, expectedToken.token)
  }

  // MARK: Token update notifications

  func testTokenUpdateNotificationKeys() {
    XCTAssertEqual(appCheck.tokenDidChangeNotificationName(),
                   "FIRAppCheckAppCheckTokenDidChangeNotification")
    XCTAssertEqual(appCheck.notificationAppNameKey(), "FIRAppCheckAppNameNotificationKey")
    XCTAssertEqual(appCheck.notificationTokenKey(), "FIRAppCheckTokenNotificationKey")
  }

  func testTokenDelegateForwardsTokenUpdates() {
    let delegate = appCheck.tokenDelegate
    let token = validToken()
    let notification = tokenUpdateNotification(expectedToken: token.token)

    delegate.tokenDidUpdate(token.internalToken, serviceName: appName)

    wait(for: [notification], timeout: 0.5)
    XCTAssertTrue(delegate.appCheck === appCheck)
  }

  func testTokenDelegateDoesNotRetainAppCheck() {
    var delegate: AppCheckTokenDelegate?
    weak var weakAppCheck: AppCheck?
    autoreleasepool {
      let appCheck = makeAppCheck(appCheckCore: FakeAppCheckCore(), settings: FakeSettings())
      delegate = appCheck.tokenDelegate
      weakAppCheck = appCheck
    }
    XCTAssertNil(weakAppCheck)
    XCTAssertNil(delegate?.appCheck)
  }

  func testInitWithAppSetsUpAppCheckCore() throws {
    let appCheck = makeAppCheck(appCheckCore: FakeAppCheckCore(), settings: FakeSettings())
    // `makeAppCheck` replaced the dependencies; check the ones created by `init?(app:)`.
    AppCheck.setAppCheckProviderFactory(FakeAppCheckProviderFactory(provider:
      FakeAppCheckProvider()))
    let realAppCheck = try XCTUnwrap(AppCheck(app: AppCheckTestUtils.app(name: appName)))
    XCTAssertTrue(realAppCheck.appCheckCore is AppCheckCore)
    XCTAssertTrue(realAppCheck.settings is AppCheckSettings)
    XCTAssertTrue(realAppCheck.notificationCenter === NotificationCenter.default)
    XCTAssertTrue(realAppCheck.tokenDelegate.appCheck === realAppCheck)
    XCTAssertFalse(appCheck === realAppCheck)
  }

  // MARK: Auto-refresh enabled

  func testIsTokenAutoRefreshEnabled() {
    settings.isTokenAutoRefreshEnabled = false
    XCTAssertFalse(appCheck.isTokenAutoRefreshEnabled)

    settings.isTokenAutoRefreshEnabled = true
    XCTAssertTrue(appCheck.isTokenAutoRefreshEnabled)
  }

  func testSetIsTokenAutoRefreshEnabled() {
    appCheck.isTokenAutoRefreshEnabled = true
    XCTAssertTrue(settings.isTokenAutoRefreshEnabled)

    appCheck.isTokenAutoRefreshEnabled = false
    XCTAssertFalse(settings.isTokenAutoRefreshEnabled)
  }

  func testIsTokenAutoRefreshEnabledIsKeyValueObservable() {
    let observation = expectation(description: "KVO")
    let observer = appCheck.observe(\.isTokenAutoRefreshEnabled, options: [.new]) { _, change in
      XCTAssertEqual(change.newValue, true)
      observation.fulfill()
    }
    appCheck.isTokenAutoRefreshEnabled = true
    wait(for: [observation], timeout: 0.5)
    observer.invalidate()
  }

  // MARK: Component

  func testComponentRegistersEagerAppCheckInterop() throws {
    let components = AppCheckComponent.componentsToRegister()
    XCTAssertEqual(components.count, 1)
    let component = try XCTUnwrap(components.first)
    XCTAssertTrue(protocol_isEqual(component.protocol, AppCheckInterop.self))
    XCTAssertEqual(component.instantiationTiming, .alwaysEager)
  }
}

// MARK: - DefaultProviderFactory

final class DefaultProviderFactoryTests: XCTestCase {
  func testCreateProvider() throws {
    let provider = DefaultProviderFactory().createProvider(with: AppCheckTestUtils.app())
    #if targetEnvironment(simulator)
      XCTAssertTrue(provider is AppCheckDebugProvider)
    #else
      if #available(watchOS 9.0, *) {
        XCTAssertTrue(provider is DeviceCheckProvider)
      } else {
        XCTAssertNil(provider)
      }
    #endif
  }
}

// MARK: - AppCheckSettings

final class AppCheckSettingsTests: XCTestCase {
  private final class FakeUserDefaults: AppCheckUserDefaults {
    var values: [String: Any] = [:]
    private(set) var readKeys: [String] = []
    private(set) var writes: [(String, Bool)] = []

    func object(forKey defaultName: String) -> Any? {
      readKeys.append(defaultName)
      return values[defaultName]
    }

    func setBool(_ value: Bool, forKey defaultName: String) {
      writes.append((defaultName, value))
      values[defaultName] = value
    }
  }

  private final class FakeBundle: AppCheckInfoDictionary {
    var values: [String: Any] = [:]
    private(set) var readKeys: [String] = []

    func object(forInfoDictionaryKey key: String) -> Any? {
      readKeys.append(key)
      return values[key]
    }
  }

  private let appName = "FIRAppCheckSettingsTestsAppName"
  private var app: FirebaseApp!
  private var userDefaults: FakeUserDefaults!
  private var bundle: FakeBundle!
  private var settings: AppCheckSettings!
  private var userDefaultsKey: String { "FIRAppCheckTokenAutoRefreshEnabled_" + appName }
  private let infoPlistKey = "FirebaseAppCheckTokenAutoRefreshEnabled"

  override func setUp() {
    super.setUp()
    app = AppCheckTestUtils.app(name: appName)
    userDefaults = FakeUserDefaults()
    bundle = FakeBundle()
    settings = AppCheckSettings(app: app, userDefaults: userDefaults, mainBundle: bundle)
  }

  func testKeys() {
    XCTAssertEqual(AppCheckSettings.userDefaultsKeyPrefix, "FIRAppCheckTokenAutoRefreshEnabled_")
    XCTAssertEqual(AppCheckSettings.infoPlistKey, infoPlistKey)
  }

  func testIsTokenAutoRefreshEnabledWhenDidNotExplicitlySet() {
    app.isDataCollectionDefaultEnabled = true
    XCTAssertTrue(settings.isTokenAutoRefreshEnabled)
    app.isDataCollectionDefaultEnabled = false
    XCTAssertFalse(settings.isTokenAutoRefreshEnabled)

    XCTAssertEqual(userDefaults.readKeys.first, userDefaultsKey)
    XCTAssertEqual(bundle.readKeys.first, infoPlistKey)
  }

  func testIsTokenAutoRefreshEnabledWhenSetThisAppRun() {
    settings.isTokenAutoRefreshEnabled = true

    XCTAssertTrue(settings.isTokenAutoRefreshEnabled)
    XCTAssertEqual(userDefaults.readKeys, [])
    XCTAssertEqual(bundle.readKeys, [])
    XCTAssertEqual(userDefaults.writes.count, 1)
    XCTAssertEqual(userDefaults.writes.first?.0, userDefaultsKey)
    XCTAssertEqual(userDefaults.writes.first?.1, true)
  }

  func testIsTokenAutoRefreshEnabledWhenSetDuringPreviousLaunch() {
    userDefaults.values[userDefaultsKey] = true
    app.isDataCollectionDefaultEnabled = false

    XCTAssertTrue(settings.isTokenAutoRefreshEnabled)
    XCTAssertEqual(bundle.readKeys, [])
  }

  func testIsTokenAutoRefreshEnabledWhenSetInInfoPlist() {
    bundle.values[infoPlistKey] = true
    app.isDataCollectionDefaultEnabled = false

    XCTAssertTrue(settings.isTokenAutoRefreshEnabled)
    XCTAssertEqual(userDefaults.readKeys, [userDefaultsKey])
    XCTAssertEqual(bundle.readKeys, [infoPlistKey])
  }

  func testIsTokenAutoRefreshEnabledWhenSetInInfoPlistAsString() {
    bundle.values[infoPlistKey] = "NO"
    app.isDataCollectionDefaultEnabled = true

    XCTAssertFalse(settings.isTokenAutoRefreshEnabled)
  }

  func testIsTokenAutoRefreshEnabledIsCachedOnceConfigured() {
    userDefaults.values[userDefaultsKey] = false

    XCTAssertFalse(settings.isTokenAutoRefreshEnabled)
    XCTAssertFalse(settings.isTokenAutoRefreshEnabled)
    XCTAssertEqual(userDefaults.readKeys, [userDefaultsKey])
  }

  func testIsTokenAutoRefreshEnabledWhenAppDeallocated() {
    var app: FirebaseApp? = AppCheckTestUtils.app(name: appName)
    app?.isDataCollectionDefaultEnabled = true
    let settings = AppCheckSettings(app: app!, userDefaults: userDefaults, mainBundle: bundle)
    XCTAssertTrue(settings.isTokenAutoRefreshEnabled)

    weak let weakApp = app
    app = nil
    XCTAssertNil(weakApp)
    XCTAssertFalse(settings.isTokenAutoRefreshEnabled)
  }

  func testSetIsTokenAutoRefreshEnabled() {
    settings.isTokenAutoRefreshEnabled = false
    XCTAssertFalse(settings.isTokenAutoRefreshEnabled)
    settings.isTokenAutoRefreshEnabled = true
    XCTAssertTrue(settings.isTokenAutoRefreshEnabled)

    XCTAssertEqual(userDefaults.writes.map(\.1), [false, true])
    XCTAssertEqual(userDefaults.writes.map(\.0), [userDefaultsKey, userDefaultsKey])
  }
}

// MARK: - Logger

final class AppCheckLoggerTests: XCTestCase {
  func testAppCheckCoreLogLevel() {
    XCTAssertEqual(AppCheckLogger.appCheckCoreLogLevel(for: .error), .error)
    XCTAssertEqual(AppCheckLogger.appCheckCoreLogLevel(for: .warning), .warning)
    XCTAssertEqual(AppCheckLogger.appCheckCoreLogLevel(for: .notice), .warning)
    XCTAssertEqual(AppCheckLogger.appCheckCoreLogLevel(for: .info), .info)
    XCTAssertEqual(AppCheckLogger.appCheckCoreLogLevel(for: .debug), .debug)
  }

  func testAppCheckCoreLogLevelUsesCurrentFirebaseLogLevel() {
    let loggerLevel = FIRGetLoggerLevel()
    FIRSetLoggerLevel(.info)
    defer { FIRSetLoggerLevel(loggerLevel) }
    XCTAssertEqual(AppCheckLogger.appCheckCoreLogLevel(), .info)
  }

  func testServiceAndMessageCodes() {
    XCTAssertEqual(AppCheckLogger.service, "[FirebaseAppCheck]")
    let codes: [AppCheckMessageCode: String] = [
      .providerFactoryIsMissing: "I-FAA002001",
      .providerIsMissing: "I-FAA002002",
      .debugProviderIncompleteFIROptions: "I-FAA004001",
      .debugTokenExchangeFailed: "I-FAA004002",
      .debugTokenFromConfigStore: "I-FAA004003",
      .configStoreDebugTokenExchangeFailed: "I-FAA004004",
      .debugTokenConfigStoreUnreadable: "I-FAA004005",
      .debugToken: "I-FAA005001",
      .deviceCheckProviderIncompleteFIROptions: "I-FAA006001",
      .recaptchaProviderIncompleteFIROptions: "I-FAA007001",
      .recaptchaProviderMissingSiteKey: "I-FAA007002",
      .recaptchaProviderMissingRecaptchaEnterpriseSDK: "I-FAA007003",
      .deviceCheckProviderUnavailable: "I-FAA008002",
    ]
    for (code, value) in codes {
      XCTAssertEqual(code.rawValue, value)
    }
  }
}

// MARK: - Validator

final class AppCheckValidatorTests: XCTestCase {
  func testTokenExchangeMissingFieldsInOptions_noMissingFields() {
    let options = FirebaseOptions(googleAppID: "TEST_GoogleAppID", gcmSenderID: "TEST_GCMSenderID")
    options.apiKey = "TEST_APIKey"
    options.projectID = "TEST_ProjectID"
    XCTAssertEqual(AppCheckValidator.tokenExchangeMissingFields(in: options), [])
  }

  func testTokenExchangeMissingFieldsInOptions_singleMissingField() {
    let options = FirebaseOptions(googleAppID: "", gcmSenderID: "TEST_GCMSenderID")
    options.apiKey = "TEST_APIKey"
    options.projectID = "TEST_ProjectID"
    XCTAssertEqual(AppCheckValidator.tokenExchangeMissingFields(in: options), ["googleAppID"])
  }

  func testTokenExchangeMissingFieldsInOptions_multipleMissingFields() {
    let options = FirebaseOptions(googleAppID: "", gcmSenderID: "TEST_GCMSenderID")
    XCTAssertEqual(AppCheckValidator.tokenExchangeMissingFields(in: options),
                   ["APIKey", "projectID", "googleAppID"])
  }

  func testTokenExchangeMissingFieldsInOptions_emptyStrings() {
    let options = FirebaseOptions(googleAppID: "TEST_GoogleAppID", gcmSenderID: "TEST_GCMSenderID")
    options.apiKey = ""
    options.projectID = ""
    XCTAssertEqual(AppCheckValidator.tokenExchangeMissingFields(in: options),
                   ["APIKey", "projectID"])
  }
}

// MARK: - Error utilities

final class AppCheckErrorUtilTests: XCTestCase {
  private func appCheckCoreError(code: Int, failureReason: String? = "failure reason",
                                 underlyingError: Error? = NSError(domain: "underlying",
                                                                   code: 1)) -> NSError {
    var userInfo: [String: Any] = [:]
    userInfo[NSUnderlyingErrorKey] = underlyingError
    userInfo[NSLocalizedFailureReasonErrorKey] = failureReason
    return NSError(domain: "com.google.app_check_core", code: code, userInfo: userInfo)
  }

  func testPublicDomainErrorForPublicError() {
    let expectedError = NSError(domain: AppCheckErrorDomain,
                                code: AppCheckErrorCode.keychain.rawValue,
                                userInfo: ["key": "value"])
    XCTAssertTrue(AppCheckErrorUtil.publicDomainError(expectedError) === expectedError)
  }

  func testPublicDomainErrorForAppCheckCoreErrors() {
    let codes: [(AppCheckCoreErrorCode, AppCheckErrorCode.Code)] = [
      (.unknown, .unknown),
      (.serverUnreachable, .serverUnreachable),
      (.invalidConfiguration, .invalidConfiguration),
      (.keychain, .keychain),
      (.unsupported, .unsupported),
    ]
    for (coreCode, publicCode) in codes {
      let coreError = appCheckCoreError(code: coreCode.rawValue)
      let publicError = AppCheckErrorUtil.publicDomainError(coreError)
      XCTAssertEqual(publicError.domain, AppCheckErrorDomain)
      XCTAssertEqual(publicError.code, publicCode.rawValue)
      XCTAssertEqual(publicError.userInfo as NSDictionary, coreError.userInfo as NSDictionary)
    }
  }

  func testPublicDomainErrorForGACErrorUnrecognizedCode() {
    let coreError = appCheckCoreError(code: 12345)
    let publicError = AppCheckErrorUtil.publicDomainError(coreError)
    XCTAssertEqual(publicError.domain, AppCheckErrorDomain)
    XCTAssertEqual(publicError.code, AppCheckErrorCode.unknown.rawValue)
    XCTAssertEqual(publicError.userInfo[NSUnderlyingErrorKey] as? NSError, coreError)
    XCTAssertEqual(publicError.localizedFailureReason, "failure reason")
  }

  func testPublicDomainErrorForUnrecognizedDomainError() {
    let unrecognizedError = NSError(domain: "com.firebase.unknown", code: -1,
                                    userInfo: [NSLocalizedFailureReasonErrorKey: "reason"])
    let publicError = AppCheckErrorUtil.publicDomainError(unrecognizedError)
    XCTAssertEqual(publicError.domain, AppCheckErrorDomain)
    XCTAssertEqual(publicError.code, AppCheckErrorCode.unknown.rawValue)
    XCTAssertEqual(publicError.userInfo[NSUnderlyingErrorKey] as? NSError, unrecognizedError)
    XCTAssertEqual(publicError.localizedFailureReason, "reason")
    XCTAssertEqual(publicError.userInfo.count, 2)
  }

  func testPublicDomainErrorWithoutFailureReason() {
    let unrecognizedError = NSError(domain: "com.firebase.unknown", code: -1)
    let publicError = AppCheckErrorUtil.publicDomainError(unrecognizedError)
    XCTAssertNil(publicError.userInfo[NSLocalizedFailureReasonErrorKey])
    XCTAssertEqual(publicError.userInfo.count, 1)
  }
}

// MARK: - Token conversion

final class AppCheckTokenInternalTests: XCTestCase {
  func testInternalTokenRoundTripPreservesDates() {
    let expirationDate = Date(timeIntervalSince1970: 2000)
    let receivedAtDate = Date(timeIntervalSince1970: 1000)
    let internalToken = AppCheckCoreToken(token: "token", expirationDate: expirationDate,
                                          receivedAt: receivedAtDate)

    let token = AppCheckToken(internalToken: internalToken)
    XCTAssertEqual(token.token, "token")
    XCTAssertEqual(token.expirationDate, expirationDate)
    XCTAssertEqual(token.receivedAtDate, receivedAtDate)

    let roundTripped = token.internalToken
    XCTAssertEqual(roundTripped.token, "token")
    XCTAssertEqual(roundTripped.expirationDate, expirationDate)
    XCTAssertEqual(roundTripped.receivedAtDate, receivedAtDate)
  }

  func testPublicInitializerSetsReceivedAtDateToNow() {
    let before = Date()
    let token = AppCheckToken(token: "token", expirationDate: .distantFuture)
    let after = Date()
    XCTAssertGreaterThanOrEqual(token.receivedAtDate, before)
    XCTAssertLessThanOrEqual(token.receivedAtDate, after)
  }

  func testResultWithoutTokenOrError() {
    let result = AppCheckToken.result(token: nil, error: nil)
    guard case let .failure(error) = result else {
      return XCTFail("Expected a failure.")
    }
    XCTAssertEqual((error as NSError).domain, AppCheckErrorDomain)
    XCTAssertEqual((error as NSError).code, AppCheckErrorCode.unknown.rawValue)
  }

  func testResourceName() {
    XCTAssertEqual(AppCheckTestUtils.app(googleAppID: "app_id", projectID: "project_id")
      .resourceName, "projects/project_id/apps/app_id")
    // A missing project ID is formatted like the Objective-C implementation did.
    XCTAssertEqual(AppCheckTestUtils.app(googleAppID: "app_id", projectID: nil).resourceName,
                   "projects/(null)/apps/app_id")
  }

  func testRequestHookAddsHeartbeatHeader() throws {
    let hooks = AppCheckTestUtils.app().appCheckRequestHooks
    XCTAssertEqual(hooks.count, 1)
    let hook = try XCTUnwrap(hooks.first as? AppCheckCoreAPIRequestHook)
    let request = NSMutableURLRequest(url: URL(string: "https://example.com")!)
    hook(request)
    // The heartbeat logger may or may not have a payload; the hook must not crash and must only
    // set the Firebase client header.
    let headers = request.allHTTPHeaderFields ?? [:]
    XCTAssertTrue(headers.keys.allSatisfy { $0 == "X-firebase-client" })
  }
}

// MARK: - InternalAppCheckProvider

final class InternalAppCheckProviderTests: XCTestCase {
  private final class LimitedUseProvider: NSObject, AppCheckProvider {
    func getToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
      handler(AppCheckToken(token: "regular", expirationDate: .distantFuture), nil)
    }

    func getLimitedUseToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
      handler(AppCheckToken(token: "limited", expirationDate: .distantFuture), nil)
    }
  }

  func testGetToken() {
    let receivedAtDate = Date(timeIntervalSince1970: 1000)
    let provider = FakeAppCheckProvider()
    provider.token = AppCheckToken(token: "token", expirationDate: .distantFuture,
                                   receivedAtDate: receivedAtDate)
    let internalProvider = InternalAppCheckProvider(appCheckProvider: provider)

    var result: AppCheckCoreToken?
    internalProvider.getToken { token, error in
      result = token
      XCTAssertNil(error)
    }

    XCTAssertEqual(result?.token, "token")
    XCTAssertEqual(result?.receivedAtDate, receivedAtDate)
  }

  func testGetLimitedUseTokenFallsBackToGetToken() {
    let provider = FakeAppCheckProvider()
    let internalProvider = InternalAppCheckProvider(appCheckProvider: provider)

    var result: AppCheckCoreToken?
    internalProvider.getLimitedUseToken { token, _ in result = token }

    XCTAssertEqual(result?.token, "token")
    XCTAssertEqual(provider.getTokenCount, 1)
  }

  func testGetLimitedUseTokenUsesLimitedUseMethod() {
    let internalProvider = InternalAppCheckProvider(appCheckProvider: LimitedUseProvider())

    var result: AppCheckCoreToken?
    internalProvider.getLimitedUseToken { token, _ in result = token }

    XCTAssertEqual(result?.token, "limited")
  }
}
