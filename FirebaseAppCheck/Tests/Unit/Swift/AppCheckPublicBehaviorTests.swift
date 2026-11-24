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

// MARK: Black-box tests of the public App Check API.

//
// These tests only use the public API (and the interop component that other Firebase SDKs use).
// They were written against the Objective-C implementation of the SDK and must keep passing
// against any other implementation. The only addition since is the
// `resetAppCheckProviderFactory()` test hook (`AppCheckTestHooks.swift`) in `tearDown()`.
//
// They avoid code paths that store tokens in the keychain, which isn't available to SwiftPM unit
// tests that run without a host app.

import FirebaseAppCheck
import FirebaseAppCheckInterop
import FirebaseCore
internal import FirebaseCoreExtension
import Foundation
#if SWIFT_PACKAGE
  import SharedTestUtilities
#endif
import XCTest

final class AppCheckPublicBehaviorTests: XCTestCase {
  private var app: FirebaseApp?
  private var userDefaultsKey: String?

  override func tearDown() {
    if let userDefaultsKey {
      UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    if let app {
      let deleted = expectation(description: "app deleted")
      app.delete { _ in deleted.fulfill() }
      wait(for: [deleted], timeout: 5)
    }
    app = nil
    resetAppCheckProviderFactory()
    super.tearDown()
  }

  // MARK: - Helpers

  private static let placeholderToken = "eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ=="

  /// Configures a new `FirebaseApp`. App Check is instantiated eagerly during configuration, using
  /// the provider factory that is set at that time.
  private func configureApp(factory: AppCheckProviderFactory?,
                            options: FirebaseOptions? = nil,
                            function: String = #function) -> FirebaseApp {
    AppCheck.setAppCheckProviderFactory(factory)
    let name = "AppCheckPublicBehaviorTests_" + function
      .replacingOccurrences(of: "()", with: "")
    FirebaseApp.configure(name: name, options: options ?? Self.completeOptions())
    let app = FirebaseApp.app(name: name)!
    // Disables automatic token refresh, which could interfere with the tests.
    app.isDataCollectionDefaultEnabled = false
    self.app = app
    return app
  }

  private static func completeOptions() -> FirebaseOptions {
    let options = FirebaseOptions(googleAppID: "1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa",
                                  gcmSenderID: "sender_id")
    options.apiKey = "api_key"
    options.projectID = "project_id"
    return options
  }

  private static func incompleteOptions() -> FirebaseOptions {
    let options = FirebaseOptions(googleAppID: "1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa",
                                  gcmSenderID: "sender_id")
    options.projectID = "project_id"
    return options
  }

  private func interop(for app: FirebaseApp) -> AppCheckInterop? {
    ComponentType<AppCheckInterop>.instance(for: AppCheckInterop.self, in: app.container)
  }

  // MARK: - Instances

  func testAppCheckForAppIsTheInteropComponent() throws {
    let app = configureApp(factory: FakeProviderFactory(provider: FakeProvider()))

    let appCheck = try XCTUnwrap(AppCheck.appCheck(app: app))
    XCTAssertTrue(AppCheck.appCheck(app: app) === appCheck)
    let interop = try XCTUnwrap(interop(for: app))
    XCTAssertTrue(interop === appCheck)
    XCTAssertTrue((appCheck as AnyObject) is AppCheckInterop)
  }

  func testFactoryIsCalledWithTheApp() throws {
    let factory = FakeProviderFactory(provider: FakeProvider())
    let app = configureApp(factory: factory)

    XCTAssertTrue(factory.requestedApps.contains { $0 === app })
    XCTAssertNotNil(AppCheck.appCheck(app: app))
  }

  func testNilProviderFactoryDisablesAppCheck() {
    let app = configureApp(factory: nil)

    XCTAssertNil(AppCheck.appCheck(app: app))
    XCTAssertNil(interop(for: app))
  }

  func testNilProviderDisablesAppCheck() {
    let app = configureApp(factory: FakeProviderFactory(provider: nil))

    XCTAssertNil(AppCheck.appCheck(app: app))
  }

  func testAppCheckWithoutDefaultAppRaisesException() throws {
    try XCTSkipIf(FirebaseApp.app() != nil, "A default app is configured.")

    XCTAssertThrowsError(try ExceptionCatcher.catchException {
      _ = AppCheck.appCheck()
    }) { error in
      XCTAssertEqual((error as NSError).domain, "com.firebase.appCheck")
      let reason = (error as NSError).userInfo["ExceptionReason"] as? String
      XCTAssertTrue(reason?.contains("FirebaseApp.configure()") ?? false)
    }
  }

  // MARK: - Limited-use tokens

  func testLimitedUseTokenUsesProviderLimitedUseMethod() throws {
    let provider = FakeProvider()
    provider.limitedUseResult = .success("limited")
    let app = configureApp(factory: FakeProviderFactory(provider: provider))
    let appCheck = try XCTUnwrap(AppCheck.appCheck(app: app))

    let completion = expectation(description: "completion")
    appCheck.limitedUseToken { token, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(token?.token, "limited")
      XCTAssertNil(error)
      completion.fulfill()
    }
    wait(for: [completion], timeout: 5)
    XCTAssertEqual(provider.getTokenCount, 0)
    XCTAssertEqual(provider.getLimitedUseTokenCount, 1)
  }

  func testLimitedUseTokenAsync() async throws {
    let provider = FakeProvider()
    provider.limitedUseResult = .success("limited")
    let app = configureApp(factory: FakeProviderFactory(provider: provider))
    let appCheck = try XCTUnwrap(AppCheck.appCheck(app: app))

    let token = try await appCheck.limitedUseToken()

    XCTAssertEqual(token.token, "limited")
  }

  func testLimitedUseTokenFallsBackToGetToken() throws {
    let provider = FakeProviderWithoutLimitedUse()
    let app = configureApp(factory: FakeProviderFactory(provider: provider))
    let appCheck = try XCTUnwrap(AppCheck.appCheck(app: app))

    let completion = expectation(description: "completion")
    appCheck.limitedUseToken { token, error in
      XCTAssertEqual(token?.token, "regular")
      XCTAssertNil(error)
      completion.fulfill()
    }
    wait(for: [completion], timeout: 5)
  }

  func testLimitedUseTokenErrorIsInPublicDomain() throws {
    let providerError = NSError(domain: "AppCheckPublicBehaviorTests", code: 42,
                                userInfo: [NSLocalizedFailureReasonErrorKey: "reason"])
    let provider = FakeProvider()
    provider.limitedUseResult = .failure(providerError)
    let app = configureApp(factory: FakeProviderFactory(provider: provider))
    let appCheck = try XCTUnwrap(AppCheck.appCheck(app: app))

    let completion = expectation(description: "completion")
    appCheck.limitedUseToken { token, error in
      XCTAssertNil(token)
      let error = error as NSError?
      XCTAssertEqual(error?.domain, AppCheckErrorDomain)
      XCTAssertEqual(error?.code, AppCheckErrorCode.unknown.rawValue)
      XCTAssertEqual(error?.userInfo[NSUnderlyingErrorKey] as? NSError, providerError)
      XCTAssertEqual(error?.localizedFailureReason, "reason")
      completion.fulfill()
    }
    wait(for: [completion], timeout: 5)
  }

  func testLimitedUseTokenAsyncThrowsPublicError() async throws {
    let provider = FakeProvider()
    provider.limitedUseResult = .failure(NSError(domain: "AppCheckPublicBehaviorTests", code: 1))
    let app = configureApp(factory: FakeProviderFactory(provider: provider))
    let appCheck = try XCTUnwrap(AppCheck.appCheck(app: app))

    do {
      _ = try await appCheck.limitedUseToken()
      XCTFail("Expected an error.")
    } catch AppCheckErrorCode.unknown {
      // Expected.
    }
  }

  // MARK: - Tokens

  func testTokenProviderErrorIsInPublicDomainAndDoesNotNotify() throws {
    let providerError = NSError(domain: "AppCheckPublicBehaviorTests", code: 7)
    let provider = FakeProvider()
    provider.result = .failure(providerError)
    let app = configureApp(factory: FakeProviderFactory(provider: provider))
    let appCheck = try XCTUnwrap(AppCheck.appCheck(app: app))
    let notification = expectation(forNotification: .AppCheckTokenDidChange, object: appCheck)
    notification.isInverted = true

    let completion = expectation(description: "completion")
    appCheck.token(forcingRefresh: true) { token, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(token)
      let error = error as NSError?
      XCTAssertEqual(error?.domain, AppCheckErrorDomain)
      XCTAssertEqual(error?.code, AppCheckErrorCode.unknown.rawValue)
      XCTAssertEqual(error?.userInfo[NSUnderlyingErrorKey] as? NSError, providerError)
      completion.fulfill()
    }
    wait(for: [completion, notification], timeout: 1)
  }

  func testTokenAsyncThrowsPublicError() async throws {
    let provider = FakeProvider()
    provider.result = .failure(NSError(domain: "AppCheckPublicBehaviorTests", code: 1))
    let app = configureApp(factory: FakeProviderFactory(provider: provider))
    let appCheck = try XCTUnwrap(AppCheck.appCheck(app: app))

    do {
      _ = try await appCheck.token(forcingRefresh: true)
      XCTFail("Expected an error.")
    } catch {
      XCTAssertEqual((error as NSError).domain, AppCheckErrorDomain)
    }
  }

  // MARK: - Interop

  func testInteropReturnsRawErrorAndPlaceholderToken() throws {
    let providerError = NSError(domain: "AppCheckPublicBehaviorTests", code: 3)
    let provider = FakeProvider()
    provider.result = .failure(providerError)
    let app = configureApp(factory: FakeProviderFactory(provider: provider))
    let interop = try XCTUnwrap(interop(for: app))

    let completion = expectation(description: "completion")
    interop.getToken(forcingRefresh: true) { result in
      XCTAssertEqual(result.token, Self.placeholderToken)
      XCTAssertEqual(result.error as NSError?, providerError)
      completion.fulfill()
    }
    wait(for: [completion], timeout: 5)
  }

  func testInteropLimitedUseToken() throws {
    let provider = FakeProvider()
    provider.limitedUseResult = .success("limited")
    let app = configureApp(factory: FakeProviderFactory(provider: provider))
    let interop = try XCTUnwrap(interop(for: app))

    let completion = expectation(description: "completion")
    interop.getLimitedUseToken?() { result in
      XCTAssertEqual(result.token, "limited")
      XCTAssertNil(result.error)
      completion.fulfill()
    }
    wait(for: [completion], timeout: 5)
  }

  func testInteropNotificationNames() throws {
    let app = configureApp(factory: FakeProviderFactory(provider: FakeProvider()))
    let interop = try XCTUnwrap(interop(for: app))

    XCTAssertEqual(interop.tokenDidChangeNotificationName(),
                   NSNotification.Name.AppCheckTokenDidChange.rawValue)
    XCTAssertEqual(interop.notificationTokenKey(), AppCheckTokenNotificationKey)
    XCTAssertEqual(interop.notificationAppNameKey(), AppCheckAppNameNotificationKey)
  }

  // MARK: - Auto-refresh setting

  func testIsTokenAutoRefreshEnabledFollowsDataCollectionFlag() throws {
    let app = configureApp(factory: FakeProviderFactory(provider: FakeProvider()))
    let appCheck = try XCTUnwrap(AppCheck.appCheck(app: app))
    userDefaultsKey = "FIRAppCheckTokenAutoRefreshEnabled_" + app.name
    UserDefaults.standard.removeObject(forKey: userDefaultsKey!)

    app.isDataCollectionDefaultEnabled = false
    XCTAssertFalse(appCheck.isTokenAutoRefreshEnabled)
    app.isDataCollectionDefaultEnabled = true
    XCTAssertTrue(appCheck.isTokenAutoRefreshEnabled)
    app.isDataCollectionDefaultEnabled = false
  }

  func testIsTokenAutoRefreshEnabledIsPersisted() throws {
    let app = configureApp(factory: FakeProviderFactory(provider: FakeProvider()))
    let appCheck = try XCTUnwrap(AppCheck.appCheck(app: app))
    userDefaultsKey = "FIRAppCheckTokenAutoRefreshEnabled_" + app.name

    appCheck.isTokenAutoRefreshEnabled = true
    XCTAssertTrue(appCheck.isTokenAutoRefreshEnabled)
    XCTAssertEqual(UserDefaults.standard.object(forKey: userDefaultsKey!) as? Bool, true)

    appCheck.isTokenAutoRefreshEnabled = false
    XCTAssertFalse(appCheck.isTokenAutoRefreshEnabled)
    XCTAssertEqual(UserDefaults.standard.object(forKey: userDefaultsKey!) as? Bool, false)
  }

  // MARK: - Built-in provider factories

  func testDebugProviderFactory() throws {
    let app = configureApp(factory: FakeProviderFactory(provider: FakeProvider()))
    let provider = AppCheckDebugProviderFactory().createProvider(with: app)
    let debugProvider = try XCTUnwrap(provider as? AppCheckDebugProvider)
    XCTAssertFalse(debugProvider.currentDebugToken().isEmpty)
    XCTAssertFalse(debugProvider.localDebugToken().isEmpty)
  }

  func testDebugProviderRequiresCompleteOptions() {
    let app = configureApp(factory: FakeProviderFactory(provider: FakeProvider()),
                           options: Self.incompleteOptions())
    XCTAssertNil(AppCheckDebugProvider(app: app))
    XCTAssertNil(AppCheckDebugProviderFactory().createProvider(with: app))
  }

  func testDeviceCheckProviderFactory() throws {
    guard #available(watchOS 9.0, *) else { throw XCTSkip("Requires watchOS 9.0") }
    let app = configureApp(factory: FakeProviderFactory(provider: FakeProvider()))
    XCTAssertTrue(DeviceCheckProviderFactory().createProvider(with: app) is DeviceCheckProvider)
  }

  func testDeviceCheckProviderRequiresCompleteOptions() throws {
    guard #available(watchOS 9.0, *) else { throw XCTSkip("Requires watchOS 9.0") }
    let app = configureApp(factory: FakeProviderFactory(provider: FakeProvider()),
                           options: Self.incompleteOptions())
    XCTAssertNil(DeviceCheckProvider(app: app))
    XCTAssertNil(DeviceCheckProviderFactory().createProvider(with: app))
  }

  func testAppAttestProviderFactory() throws {
    guard #available(macOS 11.3, watchOS 9.0, *) else {
      throw XCTSkip("Requires macOS 11.3 or watchOS 9.0")
    }
    let app = configureApp(factory: FakeProviderFactory(provider: FakeProvider()))
    XCTAssertTrue(AppAttestProviderFactory().createProvider(with: app) is AppAttestProvider)
  }
}

// MARK: - Fakes

private final class FakeProviderFactory: NSObject, AppCheckProviderFactory {
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

private final class FakeProvider: NSObject, AppCheckProvider, @unchecked Sendable {
  var result: Result<String, Error> = .success("regular")
  var limitedUseResult: Result<String, Error> = .success("limited")
  private(set) var getTokenCount = 0
  private(set) var getLimitedUseTokenCount = 0

  private static func complete(_ result: Result<String, Error>,
                               handler: (AppCheckToken?, Error?) -> Void) {
    switch result {
    case let .success(token):
      handler(AppCheckToken(token: token, expirationDate: Date(timeIntervalSinceNow: 3600)), nil)
    case let .failure(error):
      handler(nil, error)
    }
  }

  func getToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
    getTokenCount += 1
    Self.complete(result, handler: handler)
  }

  func getLimitedUseToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
    getLimitedUseTokenCount += 1
    Self.complete(limitedUseResult, handler: handler)
  }
}

private final class FakeProviderWithoutLimitedUse: NSObject, AppCheckProvider {
  func getToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
    handler(AppCheckToken(token: "regular", expirationDate: Date(timeIntervalSinceNow: 3600)), nil)
  }
}
