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
  import FirebaseAppCheck
#endif // SWIFT_PACKAGE

internal import AppCheckCore
internal import FirebaseAppCheckInterop
internal import FirebaseCoreExtension
#if COCOAPODS
  internal import GoogleUtilities
#else
  internal import GoogleUtilities_UserDefaults
#endif // COCOAPODS

// MARK: - Validation

enum AppCheckValidator {
  /// Returns the names of the `FirebaseOptions` fields that are required to exchange an
  /// attestation for an App Check token, but are missing.
  static func tokenExchangeMissingFields(in options: FirebaseOptions) -> [String] {
    var missingFields: [String] = []
    if (options.apiKey ?? "").isEmpty {
      missingFields.append("APIKey")
    }
    if (options.projectID ?? "").isEmpty {
      missingFields.append("projectID")
    }
    if options.googleAppID.isEmpty {
      missingFields.append("googleAppID")
    }
    return missingFields
  }
}

// MARK: - FirebaseApp

extension FirebaseApp {
  /// The App Check resource name of the app: `projects/{project_id}/apps/{app_id}`.
  ///
  /// A missing project ID is formatted as `(null)`, like the Objective-C implementation of the SDK
  /// did. The resource name is part of the keychain key of stored tokens.
  var resourceName: String {
    "projects/\(options.projectID ?? "(null)")/apps/\(options.googleAppID)"
  }

  /// Request hooks for App Check Core API requests: adds the heartbeat logging payload header.
  var appCheckRequestHooks: [Any] {
    [heartbeatRequestHook(heartbeatLogger: heartbeatLogger)]
  }
}

/// Returns an App Check Core API request hook that sets the `X-firebase-client` header to the
/// heartbeat logging payload of `heartbeatLogger`, if there is one.
func heartbeatRequestHook(heartbeatLogger: FIRHeartbeatLoggerProtocol)
  -> AppCheckCoreAPIRequestHook {
  { request in
    if let headerValue = heartbeatLogger.headerValue() {
      request.setValue(headerValue, forHTTPHeaderField: "X-firebase-client")
    }
  }
}

// MARK: - Tokens

/// Implements `FIRAppCheckToken`, declared in `FIRAppCheckToken.h`.
@objc @implementation extension AppCheckToken {
  // Dates are stored as `NSDate`: `@implementation` classes can't store values of resilient types
  // such as `Date`.
  private final let storedExpirationDate: NSDate
  private final var storedReceivedAtDate: NSDate

  let token: String

  var expirationDate: Date {
    storedExpirationDate as Date
  }

  /// The date the token was received at, in the device's local time.
  private(set) final var receivedAtDate: Date {
    get { storedReceivedAtDate as Date }
    set { storedReceivedAtDate = newValue as NSDate }
  }

  @objc(initWithToken:expirationDate:)
  init(token: String, expirationDate: Date) {
    self.token = token
    storedExpirationDate = expirationDate as NSDate
    storedReceivedAtDate = NSDate()
    super.init()
  }
}

extension AppCheckToken {
  /// Creates a token with the date it was received at.
  convenience init(token: String, expirationDate: Date, receivedAtDate: Date) {
    self.init(token: token, expirationDate: expirationDate)
    self.receivedAtDate = receivedAtDate
  }

  /// Creates a token from an App Check Core token.
  convenience init(internalToken: AppCheckCoreToken) {
    self.init(token: internalToken.token,
              expirationDate: internalToken.expirationDate,
              receivedAtDate: internalToken.receivedAtDate)
  }

  /// The App Check Core token that is equivalent to this token.
  var internalToken: AppCheckCoreToken {
    AppCheckCoreToken(token: token, expirationDate: expirationDate, receivedAt: receivedAtDate)
  }

  /// The error for a provider that returned neither a token nor an error.
  static func missingTokenError() -> NSError {
    NSError(
      domain: AppCheckErrorDomain,
      code: AppCheckErrorCode.unknown.rawValue,
      userInfo: [NSLocalizedFailureReasonErrorKey: "No token and no error returned."]
    )
  }
}

/// The result of a token request made through `AppCheckInterop`.
final class AppCheckTokenResult: NSObject, FIRAppCheckTokenResultInterop, @unchecked Sendable {
  let token: String
  let error: Error?

  init(token: String, error: Error?) {
    self.token = token
    self.error = error
  }
}

// MARK: - Providers

/// Adapts a public `AppCheckProvider` to the App Check Core provider protocol.
final class InternalAppCheckProvider: NSObject, AppCheckCoreProvider {
  let appCheckProvider: AppCheckProvider

  init(appCheckProvider: AppCheckProvider) {
    self.appCheckProvider = appCheckProvider
  }

  func getToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    nonisolated(unsafe) let handler = handler
    appCheckProvider.getToken { token, error in
      handler(token?.internalToken, error)
    }
  }

  func getLimitedUseToken(completion handler: @escaping (AppCheckCoreToken?, Error?) -> Void) {
    nonisolated(unsafe) let handler = handler
    let implemented: Void? = appCheckProvider.getLimitedUseToken? { token, error in
      handler(token?.internalToken, error)
    }
    if implemented == nil {
      // The provider doesn't implement the optional limited-use token method.
      getToken(completion: handler)
    }
  }
}

/// Converts the result of an App Check Core provider to the arguments of a public token
/// completion handler.
func appCheckTokenCompletion(_ handler: @escaping @Sendable (AppCheckToken?, Error?) -> Void)
  -> (AppCheckCoreToken?, Error?) -> Void {
  return { internalToken, error in
    if let error {
      handler(nil, error)
      return
    }
    guard let internalToken else {
      handler(nil, AppCheckToken.missingTokenError())
      return
    }
    handler(AppCheckToken(internalToken: internalToken), nil)
  }
}

// MARK: - Exceptions

/// Raises an Objective-C exception, like the Objective-C implementation of the SDK did.
func raiseException(_ name: NSExceptionName, reason: String) -> Never {
  NSException(name: name, reason: reason, userInfo: nil).raise()
  fatalError(reason)
}

// MARK: - Settings

/// The subset of `GULUserDefaults` used by `AppCheckSettings`.
protocol AppCheckUserDefaults: AnyObject {
  func object(forKey defaultName: String) -> Any?
  func setBool(_ value: Bool, forKey defaultName: String)
}

extension GULUserDefaults: AppCheckUserDefaults {}

/// The subset of `Bundle` used by `AppCheckSettings`.
protocol AppCheckInfoDictionary: AnyObject {
  func object(forInfoDictionaryKey key: String) -> Any?
}

extension Bundle: AppCheckInfoDictionary {}

/// App Check settings that are persisted across app launches.
final class AppCheckSettings: NSObject, AppCheckCoreSettingsProtocol, @unchecked Sendable {
  static let userDefaultsKeyPrefix = "FIRAppCheckTokenAutoRefreshEnabled_"
  static let infoPlistKey = "FirebaseAppCheckTokenAutoRefreshEnabled"

  private weak var firebaseApp: FirebaseApp?
  private let userDefaults: AppCheckUserDefaults
  private let mainBundle: AppCheckInfoDictionary
  private let userDefaultsKey: String

  // Recursive, matching Objective-C `@synchronized(self)`: `userDefaults.setBool(_:forKey:)`
  // synchronously posts `UserDefaults.didChangeNotification` and KVO callbacks on the calling
  // thread, and an observer may read or write `isTokenAutoRefreshEnabled`.
  private let lock = NSRecursiveLock()
  private var cachedIsTokenAutoRefreshEnabled = false
  private var isTokenAutoRefreshConfigured = false

  init(app: FirebaseApp, userDefaults: AppCheckUserDefaults, mainBundle: AppCheckInfoDictionary) {
    firebaseApp = app
    self.userDefaults = userDefaults
    self.mainBundle = mainBundle
    userDefaultsKey = Self.userDefaultsKeyPrefix + app.name
  }

  var isTokenAutoRefreshEnabled: Bool {
    get {
      lock.lock()
      defer { lock.unlock() }

      if isTokenAutoRefreshConfigured {
        // Return the value from the in-memory cache to avoid accessing the user default or bundle
        // when not required.
        return cachedIsTokenAutoRefreshEnabled
      }

      // Check user defaults for a value set during the previous launch, then Info.plist.
      if let isEnabled = Self.boolValue(userDefaults.object(forKey: userDefaultsKey)) ??
        Self.boolValue(mainBundle.object(forInfoDictionaryKey: Self.infoPlistKey)) {
        // Update in-memory cache.
        isTokenAutoRefreshConfigured = true
        cachedIsTokenAutoRefreshEnabled = isEnabled
        return isEnabled
      }

      // Fallback to the global data collection flag. If the app has been deleted, there is no
      // auto-refresh.
      return firebaseApp?.isDataCollectionDefaultEnabled ?? false
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      isTokenAutoRefreshConfigured = true
      cachedIsTokenAutoRefreshEnabled = newValue
      userDefaults.setBool(newValue, forKey: userDefaultsKey)
    }
  }

  /// Returns the Boolean value of a user defaults or Info.plist value, like `-[NSNumber boolValue]`
  /// and `-[NSString boolValue]`.
  private static func boolValue(_ value: Any?) -> Bool? {
    if let number = value as? NSNumber {
      return number.boolValue
    }
    if let string = value as? NSString {
      return string.boolValue
    }
    return nil
  }
}
