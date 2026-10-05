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

package import FirebaseAppCheckInterop
public import FirebaseCore
private import FirebaseCoreExtension
private import FirebaseCoreInternal
public import Foundation

public extension Notification.Name {
  /// **[Experimental]** A notification posted to `NotificationCenter.default` each time a Firebase
  /// App Check token is refreshed.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  static let AppCheckTokenDidChange = Notification.Name(
    "FIRAppCheckAppCheckTokenDidChangeNotification"
  )
}

/// **[Experimental]** `userInfo` key for the App Check token string in an `AppCheckTokenDidChange`
/// notification.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public let AppCheckTokenNotificationKey: String = "FIRAppCheckTokenNotificationKey"

/// **[Experimental]** `userInfo` key for the `FirebaseApp.name` in an `AppCheckTokenDidChange`
/// notification.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public let AppCheckAppNameNotificationKey: String = "FIRAppCheckAppNameNotificationKey"

/// Internal representation of a token lookup result conforming to `FIRAppCheckTokenResultInterop`.
package struct AppCheckTokenResult: FIRAppCheckTokenResultInterop, Sendable {
  package let token: String
  package let error: (any Error)?

  package init(token: String, error: (any Error)? = nil) {
    self.token = token
    self.error = error
  }
}

/// **[Experimental]** A class used to manage App Check tokens for a given Firebase app.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public final class AppCheck: Sendable {
  /// Base64-encoded `{"error":"UNKNOWN_ERROR"}` returned to interop callers when token refresh
  /// fails, matching Darwin `FIRAppCheckTokenResult`.
  package static let placeholderToken = "eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ=="

  /// Buffer before token expiration (5 minutes) within which cached tokens are refreshed.
  private static let tokenExpirationBuffer: TimeInterval = 300
  private static let loggerService = "[FirebaseAppCheck]"

  private static let providerFactory = UnfairLock<(any AppCheckProviderFactory)?>(nil)

  private struct TokenState: Sendable {
    var cachedToken: AppCheckToken?
    var inFlightTask: Task<AppCheckToken, any Error>?
    var inFlightGeneration: UInt64 = 0
  }

  private enum TokenLookupAction: Sendable {
    case cached(AppCheckToken)
    case inFlight(Task<AppCheckToken, any Error>)
    case created(Task<AppCheckToken, any Error>, generation: UInt64)
  }

  private let appName: String
  private let provider: any AppCheckProvider
  private let autoRefreshEnabled: UnfairLock<Bool>
  private let tokenState: UnfairLock<TokenState>

  /// **[Experimental]** Controls whether Firebase App Check periodically auto-refreshes the App
  /// Check token.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// Defaults to `FirebaseApp.isDataCollectionDefaultEnabled`.
  public var isTokenAutoRefreshEnabled: Bool {
    get { autoRefreshEnabled.withLock { $0 } }
    set { autoRefreshEnabled.withLock { $0 = newValue } }
  }

  /// Creates an `AppCheck` instance for the specified `FirebaseApp` using the registered provider
  /// factory.
  package convenience init?(app: FirebaseApp) {
    guard let factory = Self.providerFactory.withLock({ $0 }) else {
      FirebaseLogger.log(
        level: .error,
        service: Self.loggerService,
        code: "I-FAA001001",
        message: "Cannot instantiate `AppCheck` for app: \(app.name) without a provider factory. " +
          "Please register a provider factory using `AppCheck.setAppCheckProviderFactory(_:)`."
      )
      return nil
    }

    guard let provider = factory.createProvider(with: app) else {
      FirebaseLogger.log(
        level: .error,
        service: Self.loggerService,
        code: "I-FAA001002",
        message: "Cannot instantiate `AppCheck` for app: \(app.name) without an App Check " +
          "provider. Please make sure the provider factory returns a valid App Check provider."
      )
      return nil
    }

    self.init(
      appName: app.name,
      provider: provider,
      isTokenAutoRefreshEnabled: app.isDataCollectionDefaultEnabled
    )
  }

  /// Creates an `AppCheck` instance with an explicit provider.
  package init(appName: String,
               provider: any AppCheckProvider,
               isTokenAutoRefreshEnabled: Bool = true) {
    self.appName = appName
    self.provider = provider
    autoRefreshEnabled = UnfairLock(isTokenAutoRefreshEnabled)
    tokenState = UnfairLock(TokenState())
  }

  // MARK: - Public API

  /// **[Experimental]** Returns the default `AppCheck` instance.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: The `AppCheck` instance for `FirebaseApp.app()`.
  public static func appCheck() -> AppCheck {
    guard let defaultApp = FirebaseApp.app() else {
      fatalError(
        """
        The default FirebaseApp instance must be configured before the default AppCheck instance \
        can be initialized. Call `FirebaseApp.configure()` first.
        """
      )
    }
    guard let instance = appCheck(app: defaultApp) else {
      fatalError(
        """
        Cannot instantiate `AppCheck` for the default FirebaseApp without a valid provider \
        factory. Call `AppCheck.setAppCheckProviderFactory(_:)` before `FirebaseApp.configure()`.
        """
      )
    }
    return instance
  }

  /// **[Experimental]** Returns the `AppCheck` instance for the specified `FirebaseApp`.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter firebaseApp: A configured `FirebaseApp` instance.
  /// - Returns: The `AppCheck` instance corresponding to `firebaseApp`, or `nil` if no provider
  ///   could be created.
  public static func appCheck(app firebaseApp: FirebaseApp) -> AppCheck? {
    registerComponentFactory()
    return ComponentType<any AppCheckInterop>.instance(
      for: (any AppCheckInterop).self,
      in: firebaseApp.container
    ) as? AppCheck
  }

  /// **[Experimental]** Sets the `AppCheckProviderFactory` used to generate `AppCheckProvider`
  /// instances.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// Make sure to call this method before `FirebaseApp.configure()`.
  ///
  /// - Parameter factory: The provider factory to use, or `nil` to clear the registered factory.
  public static func setAppCheckProviderFactory(_ factory: (any AppCheckProviderFactory)?) {
    providerFactory.withLock { $0 = factory }
    registerComponentFactory()
  }

  /// **[Experimental]** Requests a Firebase App Check token.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter forcingRefresh: If `true`, a new Firebase App Check token is requested and the
  ///   token cache is ignored. If `false`, the cached token is used if it exists and has not
  ///   expired yet.
  /// - Returns: A valid `AppCheckToken`.
  /// - Throws: An error if the token request fails.
  public func token(forcingRefresh: Bool) async throws -> AppCheckToken {
    let provider = self.provider
    let action: TokenLookupAction = tokenState.withLock { state in
      if !forcingRefresh {
        if let cached = state.cachedToken, Self.isTokenValid(cached) {
          return .cached(cached)
        }
        if let existingTask = state.inFlightTask {
          return .inFlight(existingTask)
        }
      }

      state.inFlightGeneration &+= 1
      let generation = state.inFlightGeneration
      let task = Task<AppCheckToken, any Error> {
        try await provider.getToken()
      }
      state.inFlightTask = task
      return .created(task, generation: generation)
    }

    switch action {
    case let .cached(token):
      return token
    case let .inFlight(task):
      return try await task.value
    case let .created(task, generation):
      do {
        let newToken = try await task.value
        let shouldNotify = tokenState.withLock { state -> Bool in
          if state.inFlightGeneration == generation {
            state.cachedToken = newToken
            state.inFlightTask = nil
            return true
          }
          return false
        }
        if shouldNotify {
          postTokenUpdateNotification(token: newToken)
        }
        return newToken
      } catch {
        tokenState.withLock { state in
          if state.inFlightGeneration == generation {
            state.inFlightTask = nil
          }
        }
        throw error
      }
    }
  }

  /// **[Experimental]** Requests a limited-use Firebase App Check token.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// This method does not affect the token caching behavior of `token(forcingRefresh:)`.
  ///
  /// - Returns: A newly minted limited-use `AppCheckToken`.
  /// - Throws: An error if the token request fails.
  public func limitedUseToken() async throws -> AppCheckToken {
    try await provider.getLimitedUseToken()
  }

  // MARK: - Private Helpers

  private static func registerComponentFactory() {
    FirebaseComponentContainer.register(for: (any AppCheckInterop).self) { app in
      AppCheck(app: app)
    }
  }

  private static func isTokenValid(_ token: AppCheckToken) -> Bool {
    guard !token.token.isEmpty else { return false }
    return Date().addingTimeInterval(tokenExpirationBuffer) < token.expirationDate
  }

  private func postTokenUpdateNotification(token: AppCheckToken) {
    NotificationCenter.default.post(
      name: .AppCheckTokenDidChange,
      object: self,
      userInfo: [
        AppCheckTokenNotificationKey: token.token,
        AppCheckAppNameNotificationKey: appName,
      ]
    )
  }
}

// MARK: - AppCheckInterop

extension AppCheck: AppCheckInterop {
  /// Retrieves a cached or newly generated Firebase App Check token for internal Firebase SDKs.
  package func getToken(forcingRefresh: Bool) async -> any FIRAppCheckTokenResultInterop {
    do {
      let appCheckToken = try await token(forcingRefresh: forcingRefresh)
      return AppCheckTokenResult(token: appCheckToken.token, error: nil)
    } catch {
      return AppCheckTokenResult(token: Self.placeholderToken, error: error)
    }
  }

  /// Retrieves a newly generated limited-use Firebase App Check token for internal Firebase SDKs.
  package func getLimitedUseToken() async -> any FIRAppCheckTokenResultInterop {
    do {
      let appCheckToken = try await limitedUseToken()
      return AppCheckTokenResult(token: appCheckToken.token, error: nil)
    } catch {
      return AppCheckTokenResult(token: Self.placeholderToken, error: error)
    }
  }

  /// Returns the notification name posted when the App Check token changes.
  package func tokenDidChangeNotificationName() -> String {
    Notification.Name.AppCheckTokenDidChange.rawValue
  }

  /// Returns the `userInfo` key for the updated token string.
  package func notificationTokenKey() -> String {
    AppCheckTokenNotificationKey
  }

  /// Returns the `userInfo` key for the `FirebaseApp.name`.
  package func notificationAppNameKey() -> String {
    AppCheckAppNameNotificationKey
  }
}
