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

import FirebaseCore
import Foundation

#if SWIFT_PACKAGE
  // The public API is declared in the Objective-C headers of the `FirebaseAppCheck` target, and
  // implemented in this target.
  import FirebaseAppCheck
#endif // SWIFT_PACKAGE

#if FIREBASE_APP_CHECK_EXPLICIT_INTERNAL_MODULE
  // Internal declarations implemented in this file (`FIRAppCheckInternal.h`).
  internal import FirebaseAppCheck.Internal
#endif // FIREBASE_APP_CHECK_EXPLICIT_INTERNAL_MODULE

internal import AppCheckCore
internal import FirebaseAppCheckInterop
internal import FirebaseCoreExtension
#if COCOAPODS
  internal import GoogleUtilities
#else
  internal import GoogleUtilities_UserDefaults
#endif // COCOAPODS

/// The provider factory set with `AppCheck.setAppCheckProviderFactory(_:)`.
private let providerFactoryStorage = ProviderFactoryStorage()

/// Implements `FIRAppCheck`, declared in `FIRAppCheck.h` and `FIRAppCheckInternal.h`.
@objc @implementation extension AppCheck {
  // MARK: - Internal

  final let appName: String
  final let appCheckCore: AppCheckCoreProtocol
  final let notificationCenter: NotificationCenter
  final let settings: AppCheckCoreSettingsProtocol
  /// Receives token updates from `appCheckCore`, which only keeps a weak reference to it.
  final let tokenDelegate: AppCheckTokenDelegate

  private init(appName: NSString,
               appCheckCore: AppCheckCoreProtocol,
               notificationCenter: NotificationCenter,
               settings: AppCheckCoreSettingsProtocol,
               tokenDelegate: AppCheckTokenDelegate) {
    self.appName = appName as String
    self.appCheckCore = appCheckCore
    self.notificationCenter = notificationCenter
    self.settings = settings
    self.tokenDelegate = tokenDelegate
    super.init()
    tokenDelegate.attach(self)
  }

  /// Creates an `AppCheck` instance wired to test fakes without running production setup.
  final class func makeForTesting(appName: String,
                                  appCheckCore: AppCheckCoreProtocol,
                                  settings: AppCheckCoreSettingsProtocol,
                                  notificationCenter: NotificationCenter) -> AppCheck {
    AppCheck(
      appName: appName as NSString,
      appCheckCore: appCheckCore,
      notificationCenter: notificationCenter,
      settings: settings,
      tokenDelegate: AppCheckTokenDelegate()
    )
  }

  /// Creates the App Check instance of a Firebase app.
  final class func make(app: FirebaseApp) -> AppCheck? {
    // Set the App Check Core logging level to the current equivalent Firebase logging level.
    AppCheckCoreLogger.logLevel = AppCheckLogger.appCheckCoreLogLevel()

    guard let providerFactory = providerFactoryStorage.factory else {
      AppCheckLogger.log(
        .error,
        .providerFactoryIsMissing,
        "Cannot instantiate `FIRAppCheck` for app: \(app.name) without a provider factory. "
          + "Please register a provider factory using "
          + "`AppCheck.setAppCheckProviderFactory(_ ,forAppName:)` method."
      )
      return nil
    }

    guard let appCheckProvider = providerFactory.createProvider(with: app) else {
      AppCheckLogger.log(
        .error,
        .providerIsMissing,
        "Cannot instantiate `FIRAppCheck` for app: \(app.name) without an app check provider. "
          + "Please make sure the provider factory returns a valid app check provider."
      )
      return nil
    }

    let settings = AppCheckSettings(app: app,
                                    userDefaults: GULUserDefaults.standard(),
                                    mainBundle: Bundle.main)
    let tokenDelegate = AppCheckTokenDelegate()
    let appCheckCore = AppCheckCore(
      serviceName: "FirebaseApp:\(app.name)",
      resourceName: app.resourceName,
      appCheckProvider: InternalAppCheckProvider(appCheckProvider: appCheckProvider),
      settings: settings,
      tokenDelegate: tokenDelegate,
      keychainAccessGroup: app.options.appGroupID
    )
    return AppCheck(
      appName: app.name as NSString,
      appCheckCore: appCheckCore,
      notificationCenter: NotificationCenter.default,
      settings: settings,
      tokenDelegate: tokenDelegate
    )
  }

  // MARK: - Public

  @objc(appCheck)
  class func appCheck() -> Self {
    guard let defaultApp = FirebaseApp.app() else {
      raiseException(
        NSExceptionName(rawValue: AppCheckErrorDomain),
        reason: "The default FirebaseApp instance must be configured before the default"
          + "AppCheck instance can be initialized. One way to ensure this is to "
          + "call `FirebaseApp.configure()` in the App Delegate's "
          + "`application(_:didFinishLaunchingWithOptions:)`."
      )
    }
    // The public header declares this method nonnull, but the Objective-C implementation returned
    // `nil` when App Check isn't available for the app, for example when the provider factory is
    // nil. Keep that behavior, which `testDefaultAppCheckIsNilWithoutProviderFactory` pins.
    // Callers get `nil`, and Objective-C messages sent to it do nothing. Making the header
    // nullable, or returning a placeholder instance, would change the public API or its behavior.
    // `Self?.none` is a null object reference, so the cast only changes the static type.
    return appCheck(app: defaultApp) ?? unsafeBitCast(Self?.none, to: Self.self)
  }

  @objc(appCheckWithApp:)
  class func appCheck(app firebaseApp: FirebaseApp) -> Self? {
    let appCheck = ComponentType<AppCheckInterop>.instance(for: AppCheckInterop.self,
                                                           in: firebaseApp.container)
    return appCheck as? Self
  }

  @objc(setAppCheckProviderFactory:)
  class func setAppCheckProviderFactory(_ factory: AppCheckProviderFactory?) {
    providerFactoryStorage.setFactory(factory)
  }

  var isTokenAutoRefreshEnabled: Bool {
    get { settings.isTokenAutoRefreshEnabled }
    set { settings.isTokenAutoRefreshEnabled = newValue }
  }

  @objc(tokenForcingRefresh:completion:)
  func token(forcingRefresh: Bool,
             completion handler: @escaping @Sendable (AppCheckToken?, Error?) -> Void) {
    appCheckCore.token(forcingRefresh: forcingRefresh) { result in
      if let error = result.error {
        handler(nil, AppCheckErrorUtil.publicDomainError(error))
        return
      }
      handler(AppCheckToken(internalToken: result.token), nil)
    }
  }

  @objc(limitedUseTokenWithCompletion:)
  func limitedUseToken(completion handler: @escaping @Sendable (AppCheckToken?, Error?) -> Void) {
    appCheckCore.limitedUseToken { result in
      if let error = result.error {
        handler(nil, AppCheckErrorUtil.publicDomainError(error))
        return
      }
      handler(AppCheckToken(internalToken: result.token), nil)
    }
  }

  // MARK: - AppCheckInterop

  /// For use by other Firebase SDKs. See `AppCheckInterop`.
  @objc(getTokenForcingRefresh:completion:)
  func getToken(forcingRefresh: Bool,
                completion handler: @escaping AppCheckTokenHandlerInterop) {
    appCheckCore.token(forcingRefresh: forcingRefresh) { result in
      handler(AppCheckTokenResult(token: result.token.token, error: result.error))
    }
  }

  /// For use by other Firebase SDKs. See `AppCheckInterop`.
  @objc(getLimitedUseTokenWithCompletion:)
  func getLimitedUseToken(completion handler: @escaping AppCheckTokenHandlerInterop) {
    appCheckCore.limitedUseToken { result in
      handler(AppCheckTokenResult(token: result.token.token, error: result.error))
    }
  }

  /// For use by other Firebase SDKs. See `AppCheckInterop`.
  func tokenDidChangeNotificationName() -> String {
    NSNotification.Name.AppCheckTokenDidChange.rawValue
  }

  /// For use by other Firebase SDKs. See `AppCheckInterop`.
  func notificationTokenKey() -> String {
    AppCheckTokenNotificationKey
  }

  /// For use by other Firebase SDKs. See `AppCheckInterop`.
  func notificationAppNameKey() -> String {
    AppCheckAppNameNotificationKey
  }

  // MARK: - Token updates

  /// Called by App Check Core when a new token was received.
  final func tokenDidUpdate(_ token: AppCheckCoreToken, serviceName: String) {
    notificationCenter.post(
      name: .AppCheckTokenDidChange,
      object: self,
      userInfo: [
        AppCheckTokenNotificationKey: token.token,
        AppCheckAppNameNotificationKey: appName,
      ]
    )
  }
}

// MARK: - Helpers

/// Forwards token updates from App Check Core to an `AppCheck` instance.
///
/// `AppCheck` doesn't conform to `AppCheckCoreTokenDelegate` itself to keep the App Check Core
/// types out of its public API. `AppCheckCore.init` can trigger an immediate refresh before
/// `AppCheck.init` finishes, so updates arriving before `attach(_:)` are buffered under a lock and
/// delivered when `attach(_:)` runs.
final class AppCheckTokenDelegate: NSObject, AppCheckCoreTokenDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private weak var _appCheck: AppCheck?
  private var isAttached = false
  private var pendingUpdates: [(token: AppCheckCoreToken, serviceName: String)] = []

  var appCheck: AppCheck? {
    lock.lock()
    defer { lock.unlock() }
    return _appCheck
  }

  func attach(_ appCheck: AppCheck) {
    let buffered: [(token: AppCheckCoreToken, serviceName: String)]
    lock.lock()
    _appCheck = appCheck
    isAttached = true
    buffered = pendingUpdates
    pendingUpdates.removeAll()
    lock.unlock()

    for update in buffered {
      appCheck.tokenDidUpdate(update.token, serviceName: update.serviceName)
    }
  }

  func tokenDidUpdate(_ token: AppCheckCoreToken, serviceName: String) {
    let target: AppCheck?
    lock.lock()
    if let appCheck = _appCheck {
      target = appCheck
    } else if !isAttached {
      pendingUpdates.append((token, serviceName))
      target = nil
    } else {
      target = nil
    }
    lock.unlock()

    target?.tokenDidUpdate(token, serviceName: serviceName)
  }
}

/// Thread-safe storage for the provider factory set with
/// `AppCheck.setAppCheckProviderFactory(_:)`.
final class ProviderFactoryStorage: @unchecked Sendable {
  private enum State {
    /// No factory was set. The default factory is used.
    case unset
    /// A factory, or `nil`, was set explicitly.
    case set(AppCheckProviderFactory?)
  }

  private let lock = NSLock()
  private var state = State.unset
  private lazy var defaultFactory: AppCheckProviderFactory = DefaultProviderFactory()

  var factory: AppCheckProviderFactory? {
    lock.lock()
    defer { lock.unlock() }
    switch state {
    case .unset:
      return defaultFactory
    case let .set(factory):
      return factory
    }
  }

  func setFactory(_ factory: AppCheckProviderFactory?) {
    let previousState: State
    lock.lock()
    previousState = state
    state = .set(factory)
    lock.unlock()
    // Release the previous factory outside the lock so a custom factory's `deinit` can't deadlock.
    withExtendedLifetime(previousState) {}
  }

  /// Forgets the factory that was set, so the default factory is used again.
  func reset() {
    let previousState: State
    lock.lock()
    previousState = state
    state = .unset
    lock.unlock()
    withExtendedLifetime(previousState) {}
  }
}

/// Test hook: forgets the provider factory set with `AppCheck.setAppCheckProviderFactory(_:)`, so
/// new `AppCheck` instances use the default provider factory again, as in a new process. Swift-only
/// and internal; not part of the public API.
func resetAppCheckProviderFactoryForTesting() {
  providerFactoryStorage.reset()
}
