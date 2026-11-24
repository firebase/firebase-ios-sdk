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

// MARK: This file pins the exact Swift signatures of the public App Check API.

//
// It was written against the Objective-C implementation of the SDK and must keep compiling,
// without changes or new warnings, against any other implementation. The code is type-checked
// but most of it never runs. Each statement fails to compile if a declaration is removed or
// renamed, if its type, optionality, `@Sendable`-ness or `async` variant changes, if a class or
// member stops being `open`, or if a result stops being discardable.

import FirebaseAppCheck
import FirebaseCore
import Foundation
import XCTest

final class AppCheckAPICompatibilityTests: XCTestCase {
  typealias TokenHandler = @Sendable (AppCheckToken?, (any Error)?) -> Void

  func testSignatures() {
    // MARK: AppCheck

    let _: () -> AppCheck = AppCheck.appCheck
    let _: (FirebaseApp) -> AppCheck? = AppCheck.appCheck(app:)
    let _: ((any AppCheckProviderFactory)?) -> Void = AppCheck.setAppCheckProviderFactory
    let _: (AppCheck) -> (Bool, @escaping TokenHandler) -> Void =
      AppCheck.token(forcingRefresh:completion:)
    let _: (AppCheck) -> (@escaping TokenHandler) -> Void = AppCheck.limitedUseToken(completion:)
    let _: ReferenceWritableKeyPath<AppCheck, Bool> = \AppCheck.isTokenAutoRefreshEnabled

    // MARK: AppCheckToken

    let _: (String, Date) -> AppCheckToken = AppCheckToken.init(token:expirationDate:)
    let _: KeyPath<AppCheckToken, String> = \AppCheckToken.token
    let _: KeyPath<AppCheckToken, Date> = \AppCheckToken.expirationDate

    // MARK: AppCheckDebugProvider

    let _: (FirebaseApp) -> AppCheckDebugProvider? = AppCheckDebugProvider.init(app:)
    let _: (AppCheckDebugProvider) -> () -> String = AppCheckDebugProvider.localDebugToken
    let _: (AppCheckDebugProvider) -> () -> String = AppCheckDebugProvider.currentDebugToken
    let _: (AppCheckDebugProvider) -> (@escaping TokenHandler) -> Void =
      AppCheckDebugProvider.getToken(completion:)
    let _: (AppCheckDebugProvider) -> (@escaping TokenHandler) -> Void =
      AppCheckDebugProvider.getLimitedUseToken(completion:)
    let _: () -> AppCheckDebugProviderFactory = AppCheckDebugProviderFactory.init
    let _: (AppCheckDebugProviderFactory) -> (FirebaseApp) -> (any AppCheckProvider)? =
      AppCheckDebugProviderFactory.createProvider(with:)

    // MARK: DeviceCheckProvider

    if #available(watchOS 9.0, *) {
      let _: (FirebaseApp) -> DeviceCheckProvider? = DeviceCheckProvider.init(app:)
      let _: (DeviceCheckProvider) -> (@escaping TokenHandler) -> Void =
        DeviceCheckProvider.getToken(completion:)
      let _: (DeviceCheckProvider) -> (@escaping TokenHandler) -> Void =
        DeviceCheckProvider.getLimitedUseToken(completion:)
      let _: () -> DeviceCheckProviderFactory = DeviceCheckProviderFactory.init
      let _: (DeviceCheckProviderFactory) -> (FirebaseApp) -> (any AppCheckProvider)? =
        DeviceCheckProviderFactory.createProvider(with:)
    }

    // MARK: AppAttestProvider

    if #available(macOS 11.3, watchOS 9.0, *) {
      let _: (FirebaseApp) -> AppAttestProvider? = AppAttestProvider.init(app:)
      let _: (AppAttestProvider) -> (@escaping TokenHandler) -> Void =
        AppAttestProvider.getToken(completion:)
      let _: (AppAttestProvider) -> (@escaping TokenHandler) -> Void =
        AppAttestProvider.getLimitedUseToken(completion:)
      let _: () -> AppAttestProviderFactory = AppAttestProviderFactory.init
      let _: (AppAttestProviderFactory) -> (FirebaseApp) -> (any AppCheckProvider)? =
        AppAttestProviderFactory.createProvider(with:)
    }

    // MARK: RecaptchaProvider

    #if (os(iOS) && !targetEnvironment(macCatalyst)) || os(visionOS)
      let _: (FirebaseApp, String) -> RecaptchaProvider? = RecaptchaProvider.init(app:siteKey:)
      let _: (RecaptchaProvider) -> (@escaping TokenHandler) -> Void =
        RecaptchaProvider.getToken(completion:)
      let _: (RecaptchaProvider) -> (@escaping TokenHandler) -> Void =
        RecaptchaProvider.getLimitedUseToken(completion:)
      let _: (String) -> RecaptchaProviderFactory = RecaptchaProviderFactory.init(siteKey:)
      let _: (RecaptchaProviderFactory) -> (FirebaseApp) -> (any AppCheckProvider)? =
        RecaptchaProviderFactory.createProvider(with:)
    #endif

    // MARK: Protocols

    let _: (any AppCheckProvider) -> (@escaping TokenHandler) -> Void = { provider in
      provider.getToken(completion:)
    }
    let _: (any AppCheckProviderFactory) -> (FirebaseApp) -> (any AppCheckProvider)? = {
      factory in factory.createProvider(with:)
    }

    // MARK: Errors and constants

    let _: String = AppCheckErrorDomain
    let _: String = AppCheckErrorCode.errorDomain
    let _: [AppCheckErrorCode.Code] = [
      .unknown, .serverUnreachable, .invalidConfiguration, .keychain, .unsupported,
    ]
    let _ = AppCheckErrorCode(.keychain)
    let _: NSNotification.Name = .AppCheckTokenDidChange
    let _: String = AppCheckTokenNotificationKey
    let _: String = AppCheckAppNameNotificationKey
  }

  func testConstantValues() {
    XCTAssertEqual(AppCheckErrorDomain, "com.firebase.appCheck")
    XCTAssertEqual(AppCheckErrorCode.errorDomain, AppCheckErrorDomain)
    XCTAssertEqual(NSNotification.Name.AppCheckTokenDidChange.rawValue,
                   "FIRAppCheckAppCheckTokenDidChangeNotification")
    XCTAssertEqual(AppCheckTokenNotificationKey, "FIRAppCheckTokenNotificationKey")
    XCTAssertEqual(AppCheckAppNameNotificationKey, "FIRAppCheckAppNameNotificationKey")
    XCTAssertEqual(AppCheckErrorCode.Code.unknown.rawValue, 0)
    XCTAssertEqual(AppCheckErrorCode.Code.serverUnreachable.rawValue, 1)
    XCTAssertEqual(AppCheckErrorCode.Code.invalidConfiguration.rawValue, 2)
    XCTAssertEqual(AppCheckErrorCode.Code.keychain.rawValue, 3)
    XCTAssertEqual(AppCheckErrorCode.Code.unsupported.rawValue, 4)
  }

  func testErrorBridging() {
    let error: Error = NSError(domain: AppCheckErrorDomain,
                               code: AppCheckErrorCode.unsupported.rawValue)
    switch error {
    case AppCheckErrorCode.unsupported:
      break
    default:
      XCTFail("Expected an `AppCheckErrorCode.unsupported` error.")
    }
    XCTAssertEqual((error as? AppCheckErrorCode)?.code, .unsupported)
    XCTAssertEqual((error as NSError).domain, AppCheckErrorDomain)
  }

  func testTokenInitializer() {
    let date = Date(timeIntervalSince1970: 100)
    let token = AppCheckToken(token: "token", expirationDate: date)
    XCTAssertEqual(token.token, "token")
    XCTAssertEqual(token.expirationDate, date)
  }

  func testCustomProvidersOfEveryShapeCanBeUsed() async throws {
    let providers: [any AppCheckProvider] = [
      CompletionProvider(), CompletionProviderWithLimitedUse(),
      AsyncProvider(), AsyncProviderWithLimitedUse(),
    ]
    for provider in providers {
      let token = try await provider.getToken()
      XCTAssertEqual(token.token, "token")
      // Note: `try await provider.getLimitedUseToken?()` crashes the Swift 6.4 compiler, so the
      // optional requirement is called through its completion handler form.
      let limitedUseToken = await withCheckedContinuation { continuation in
        let implemented: Void? = provider.getLimitedUseToken? { token, _ in
          continuation.resume(returning: token?.token)
        }
        if implemented == nil {
          continuation.resume(returning: nil)
        }
      }
      if let limitedUseToken {
        XCTAssertEqual(limitedUseToken, "limited")
      }
    }
  }

  // MARK: Discardable results

  /// Never called. Each statement warns if its result is not discardable.
  func discardableResults(app: FirebaseApp,
                          debugProvider: AppCheckDebugProvider,
                          factory: AppCheckDebugProviderFactory) async throws {
    AppCheck.appCheck()
    AppCheck.appCheck(app: app)
    debugProvider.localDebugToken()
    debugProvider.currentDebugToken()
    factory.createProvider(with: app)
    try await AppCheck.appCheck().token(forcingRefresh: false)
    try await AppCheck.appCheck().limitedUseToken()
    try await debugProvider.getToken()
    try await debugProvider.getLimitedUseToken()
    if #available(watchOS 9.0, *) {
      if let deviceCheckProvider = DeviceCheckProvider(app: app) {
        try await deviceCheckProvider.getToken()
        try await deviceCheckProvider.getLimitedUseToken()
      }
      DeviceCheckProviderFactory().createProvider(with: app)
    }
    if #available(macOS 11.3, watchOS 9.0, *) {
      if let appAttestProvider = AppAttestProvider(app: app) {
        try await appAttestProvider.getToken()
        try await appAttestProvider.getLimitedUseToken()
      }
      AppAttestProviderFactory().createProvider(with: app)
    }
    #if (os(iOS) && !targetEnvironment(macCatalyst)) || os(visionOS)
      if let recaptchaProvider = RecaptchaProvider(app: app, siteKey: "site_key") {
        try await recaptchaProvider.getToken()
        try await recaptchaProvider.getLimitedUseToken()
      }
      RecaptchaProviderFactory(siteKey: "site_key").createProvider(with: app)
    #endif
  }

  // MARK: Async variants

  /// Never called. Pins the result types of the `async` variants.
  func asyncVariants(app: FirebaseApp, debugProvider: AppCheckDebugProvider,
                     provider: any AppCheckProvider) async throws {
    let _: AppCheckToken = try await AppCheck.appCheck().token(forcingRefresh: true)
    let _: AppCheckToken = try await AppCheck.appCheck().limitedUseToken()
    let _: AppCheckToken = try await debugProvider.getToken()
    let _: AppCheckToken = try await debugProvider.getLimitedUseToken()
    let _: AppCheckToken = try await provider.getToken()
  }

  // MARK: Completion handler closures

  /// Never called. Uses trailing closures with inferred types.
  func completionHandlers(app: FirebaseApp, debugProvider: AppCheckDebugProvider) {
    AppCheck.appCheck().token(forcingRefresh: false) { token, error in
      _ = token?.token
      _ = error?.localizedDescription
    }
    AppCheck.appCheck().limitedUseToken { token, error in
      _ = token?.expirationDate
      _ = error
    }
    debugProvider.getToken { _, _ in }
    debugProvider.getLimitedUseToken { _, _ in }
    AppCheck.appCheck().isTokenAutoRefreshEnabled = !AppCheck.appCheck().isTokenAutoRefreshEnabled
    AppCheck.setAppCheckProviderFactory(nil)
    AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
  }
}

// MARK: - Custom providers

private final class CompletionProvider: NSObject, AppCheckProvider {
  func getToken(completion handler: @escaping (AppCheckToken?, Error?) -> Void) {
    handler(AppCheckToken(token: "token", expirationDate: .distantFuture), nil)
  }
}

private final class CompletionProviderWithLimitedUse: NSObject, AppCheckProvider {
  func getToken(completion handler: @escaping @Sendable (AppCheckToken?, (any Error)?) -> Void) {
    handler(AppCheckToken(token: "token", expirationDate: .distantFuture), nil)
  }

  func getLimitedUseToken(completion handler: @escaping @Sendable (AppCheckToken?, (any Error)?)
    -> Void) {
    handler(AppCheckToken(token: "limited", expirationDate: .distantFuture), nil)
  }
}

private final class AsyncProvider: NSObject, AppCheckProvider {
  func getToken() async throws -> AppCheckToken {
    AppCheckToken(token: "token", expirationDate: .distantFuture)
  }
}

private final class AsyncProviderWithLimitedUse: NSObject, AppCheckProvider {
  func getToken() async throws -> AppCheckToken {
    AppCheckToken(token: "token", expirationDate: .distantFuture)
  }

  func getLimitedUseToken() async throws -> AppCheckToken {
    AppCheckToken(token: "limited", expirationDate: .distantFuture)
  }
}

private final class CustomFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    CompletionProvider()
  }
}

// MARK: - Subclasses

// Classes and members are `open`, so apps can subclass and override them.

private class AppCheckSubclass: AppCheck {
  override class func appCheck() -> Self {
    super.appCheck()
  }

  override class func appCheck(app: FirebaseApp) -> Self? {
    super.appCheck(app: app)
  }

  override class func setAppCheckProviderFactory(_ factory: (any AppCheckProviderFactory)?) {
    super.setAppCheckProviderFactory(factory)
  }

  override var isTokenAutoRefreshEnabled: Bool {
    get { super.isTokenAutoRefreshEnabled }
    set { super.isTokenAutoRefreshEnabled = newValue }
  }

  override func token(forcingRefresh: Bool,
                      completion handler: @escaping @Sendable (AppCheckToken?, (any Error)?)
                        -> Void) {
    super.token(forcingRefresh: forcingRefresh, completion: handler)
  }

  override func limitedUseToken(completion handler: @escaping @Sendable (AppCheckToken?,
                                                                         (any Error)?)
      -> Void) {
    super.limitedUseToken(completion: handler)
  }
}

private class AppCheckTokenSubclass: AppCheckToken {
  override var token: String { "subclass-" + super.token }
  override var expirationDate: Date { super.expirationDate }

  override init(token: String, expirationDate: Date) {
    super.init(token: token, expirationDate: expirationDate)
  }
}

private class DebugProviderSubclass: AppCheckDebugProvider {
  override init?(app: FirebaseApp) {
    super.init(app: app)
  }

  override func localDebugToken() -> String {
    super.localDebugToken()
  }

  override func currentDebugToken() -> String {
    super.currentDebugToken()
  }

  override func getToken(completion handler: @escaping @Sendable (AppCheckToken?, (any Error)?)
    -> Void) {
    super.getToken(completion: handler)
  }

  override func getLimitedUseToken(completion handler: @escaping @Sendable (AppCheckToken?,
                                                                            (any Error)?)
      -> Void) {
    super.getLimitedUseToken(completion: handler)
  }
}

private class DebugProviderAsyncSubclass: AppCheckDebugProvider {
  override func getToken() async throws -> AppCheckToken {
    try await super.getToken()
  }

  override func getLimitedUseToken() async throws -> AppCheckToken {
    try await super.getLimitedUseToken()
  }
}

private class DebugProviderFactorySubclass: AppCheckDebugProviderFactory {
  override func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
    super.createProvider(with: app)
  }
}

@available(watchOS 9.0, *)
private class DeviceCheckProviderSubclass: DeviceCheckProvider {
  override init?(app: FirebaseApp) {
    super.init(app: app)
  }

  override func getToken(completion handler: @escaping @Sendable (AppCheckToken?, (any Error)?)
    -> Void) {
    super.getToken(completion: handler)
  }

  override func getLimitedUseToken(completion handler: @escaping @Sendable (AppCheckToken?,
                                                                            (any Error)?)
      -> Void) {
    super.getLimitedUseToken(completion: handler)
  }
}

@available(watchOS 9.0, *)
private class DeviceCheckProviderFactorySubclass: DeviceCheckProviderFactory {
  override func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
    super.createProvider(with: app)
  }
}

@available(macOS 11.3, watchOS 9.0, *)
private class AppAttestProviderSubclass: AppAttestProvider {
  override init?(app: FirebaseApp) {
    super.init(app: app)
  }

  override func getToken(completion handler: @escaping @Sendable (AppCheckToken?, (any Error)?)
    -> Void) {
    super.getToken(completion: handler)
  }

  override func getLimitedUseToken(completion handler: @escaping @Sendable (AppCheckToken?,
                                                                            (any Error)?)
      -> Void) {
    super.getLimitedUseToken(completion: handler)
  }
}

@available(macOS 11.3, watchOS 9.0, *)
private class AppAttestProviderFactorySubclass: AppAttestProviderFactory {
  override func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
    super.createProvider(with: app)
  }
}

#if (os(iOS) && !targetEnvironment(macCatalyst)) || os(visionOS)
  private class RecaptchaProviderSubclass: RecaptchaProvider {
    override init?(app: FirebaseApp, siteKey: String) {
      super.init(app: app, siteKey: siteKey)
    }

    override func getToken(completion handler: @escaping @Sendable (AppCheckToken?,
                                                                    (any Error)?)
        -> Void) {
      super.getToken(completion: handler)
    }

    override func getLimitedUseToken(completion handler: @escaping @Sendable (AppCheckToken?,
                                                                              (any Error)?)
        -> Void) {
      super.getLimitedUseToken(completion: handler)
    }
  }

  private class RecaptchaProviderFactorySubclass: RecaptchaProviderFactory {
    override init(siteKey: String) {
      super.init(siteKey: siteKey)
    }

    override func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
      super.createProvider(with: app)
    }
  }
#endif
