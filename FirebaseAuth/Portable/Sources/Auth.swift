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

private import FirebaseAppCheckInterop
import FirebaseAuthInterop
public import FirebaseCore
private import FirebaseCoreExtension
private import FirebaseCoreInternal
package import Foundation
#if canImport(FoundationNetworking)
  package import FoundationNetworking
#endif

/// **[Experimental]** Manages authentication for Firebase apps.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public final class Auth: Sendable {
  package static let defaultIdentityToolkitBaseURL = "https://identitytoolkit.googleapis.com/v1"
  package static let defaultSecureTokenBaseURL = "https://securetoken.googleapis.com/v1"

  /// Buffer before token expiration (5 minutes) within which cached ID tokens are refreshed.
  private static let tokenExpirationBuffer: TimeInterval = 300
  private static let loggerService = "[FirebaseAuth]"

  private struct State: Sendable {
    weak var app: FirebaseApp?
    var currentUser: User?
    var languageCode: String?
    var tenantID: String?
  }

  private enum RefreshAction: Sendable {
    case cached(String)
    case inFlight(Task<String, any Error>)
    case created(Task<String, any Error>, generation: UInt64)
  }

  private let apiKey: String?
  private let googleAppID: String
  private let identityToolkitBaseURL: String
  private let secureTokenBaseURL: String
  private let session: URLSession
  private let state: UnfairLock<State>

  /// **[Experimental]** The `FirebaseApp` object that this `Auth` instance is connected to.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var app: FirebaseApp? {
    state.withLock { $0.app }
  }

  /// **[Experimental]** Synchronously gets the cached current user, or `nil` if there is none.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var currentUser: User? {
    state.withLock { $0.currentUser }
  }

  /// **[Experimental]** The current user language code.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var languageCode: String? {
    get { state.withLock { $0.languageCode } }
    set { state.withLock { $0.languageCode = newValue } }
  }

  /// **[Experimental]** The tenant ID of the `Auth` instance, or `nil` if none is configured.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var tenantID: String? {
    get { state.withLock { $0.tenantID } }
    set { state.withLock { $0.tenantID = newValue } }
  }

  package init(app: FirebaseApp,
               session: URLSession = .shared,
               identityToolkitBaseURL: String = Auth.defaultIdentityToolkitBaseURL,
               secureTokenBaseURL: String = Auth.defaultSecureTokenBaseURL) {
    apiKey = app.options.apiKey
    googleAppID = app.options.googleAppID
    self.session = session
    self.identityToolkitBaseURL = identityToolkitBaseURL
    self.secureTokenBaseURL = secureTokenBaseURL
    state = UnfairLock(State(app: app))
  }

  // MARK: - Public Static Entry Points

  /// **[Experimental]** Gets the `Auth` object for the default Firebase app.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: The `Auth` instance for `FirebaseApp.app()`.
  public static func auth() -> Auth {
    guard let defaultApp = FirebaseApp.app() else {
      fatalError(
        """
        The default FirebaseApp instance must be configured before the default Auth instance \
        can be initialized. Call `FirebaseApp.configure()` first.
        """
      )
    }
    return auth(app: defaultApp)
  }

  /// **[Experimental]** Gets the `Auth` object for the specified `FirebaseApp`.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameter app: The `FirebaseApp` for which to retrieve the associated `Auth` instance.
  /// - Returns: The `Auth` instance associated with `app`.
  public static func auth(app: FirebaseApp) -> Auth {
    registerComponentFactory()
    if let existing = ComponentType<any AuthInterop>.instance(
      for: (any AuthInterop).self,
      in: app.container
    ) as? Auth {
      return existing
    }
    let created = Auth(app: app)
    app.container.register(instance: created, for: (any AuthInterop).self)
    return created
  }

  /// Registers the portable `Auth` factory with `FirebaseComponentContainer` so `FirebaseApp`
  /// containers can lazily instantiate `Auth` via `AuthInterop`.
  package static func registerComponentFactory() {
    FirebaseComponentContainer.register(for: (any AuthInterop).self) { app in
      Auth(app: app)
    }
  }

  // MARK: - Sign-In & Sign-Out

  /// **[Experimental]** Signs in a user with the given email address and password.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Parameters:
  ///   - email: The user's email address.
  ///   - password: The user's password.
  /// - Returns: An `AuthDataResult` containing the signed-in `User`.
  /// - Throws: An error in `AuthErrorDomain` if authentication fails.
  @discardableResult
  public func signIn(withEmail email: String, password: String) async throws -> AuthDataResult {
    let apiKey = try requireAPIKey()
    let endpointURL = try makeEndpointURL(
      baseURL: identityToolkitBaseURL,
      path: "accounts:signInWithPassword",
      apiKey: apiKey
    )

    let payload = SignInWithPasswordRequest(
      email: email,
      password: password,
      returnSecureToken: true,
      clientType: "CLIENT_TYPE_IOS",
      tenantId: tenantID
    )
    let bodyData = try JSONEncoder().encode(payload)
    let data = try await sendJSONRequest(to: endpointURL, body: bodyData)

    let decoded: IdentityToolkitAuthResponse
    do {
      decoded = try JSONDecoder().decode(IdentityToolkitAuthResponse.self, from: data)
    } catch {
      throw AuthErrorUtil.error(
        code: .internalError,
        message: "Failed to decode signInWithPassword response.",
        underlyingError: error
      )
    }

    let now = Date()
    let expiresInSeconds = Self.parseExpirationSeconds(decoded.expiresIn)
    let user = User(
      uid: decoded.localId,
      email: decoded.email ?? email,
      displayName: decoded.displayName,
      photoURL: decoded.photoUrl.flatMap(URL.init(string:)),
      isAnonymous: false,
      isEmailVerified: decoded.registered ?? false,
      idToken: decoded.idToken,
      refreshToken: decoded.refreshToken,
      expirationDate: now.addingTimeInterval(expiresInSeconds),
      auth: self
    )

    let previousUser = state.withLock { state in
      let oldUser = state.currentUser
      state.currentUser = user
      return oldUser
    }
    previousUser?.cancelInFlightRefresh()
    return AuthDataResult(user: user)
  }

  /// **[Experimental]** Asynchronously creates and signs in an anonymous user, or returns the
  /// existing anonymous user if one is already signed in.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Returns: An `AuthDataResult` containing the anonymous `User`.
  /// - Throws: An error in `AuthErrorDomain` if anonymous sign-in fails.
  @discardableResult
  public func signInAnonymously() async throws -> AuthDataResult {
    if let existingUser = currentUser, existingUser.isAnonymous {
      return AuthDataResult(user: existingUser)
    }

    let apiKey = try requireAPIKey()
    let endpointURL = try makeEndpointURL(
      baseURL: identityToolkitBaseURL,
      path: "accounts:signUp",
      apiKey: apiKey
    )

    let payload = SignUpRequest(
      returnSecureToken: true,
      clientType: "CLIENT_TYPE_IOS",
      tenantId: tenantID
    )
    let bodyData = try JSONEncoder().encode(payload)
    let data = try await sendJSONRequest(to: endpointURL, body: bodyData)

    let decoded: IdentityToolkitAuthResponse
    do {
      decoded = try JSONDecoder().decode(IdentityToolkitAuthResponse.self, from: data)
    } catch {
      throw AuthErrorUtil.error(
        code: .internalError,
        message: "Failed to decode anonymous signUp response.",
        underlyingError: error
      )
    }

    let now = Date()
    let expiresInSeconds = Self.parseExpirationSeconds(decoded.expiresIn)
    let user = User(
      uid: decoded.localId,
      email: decoded.email,
      displayName: decoded.displayName,
      photoURL: nil,
      isAnonymous: true,
      isEmailVerified: false,
      idToken: decoded.idToken,
      refreshToken: decoded.refreshToken,
      expirationDate: now.addingTimeInterval(expiresInSeconds),
      auth: self
    )

    let previousUser = state.withLock { state in
      let oldUser = state.currentUser
      state.currentUser = user
      return oldUser
    }
    previousUser?.cancelInFlightRefresh()
    return AuthDataResult(user: user)
  }

  /// **[Experimental]** Signs out the current user.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  ///
  /// - Throws: An error if signing out fails.
  public func signOut() throws {
    let previousUser = state.withLock { state in
      let oldUser = state.currentUser
      state.currentUser = nil
      return oldUser
    }
    previousUser?.cancelInFlightRefresh()
  }

  // MARK: - Internal Token Refresh

  package static func isTokenValid(expirationDate: Date) -> Bool {
    Date().addingTimeInterval(tokenExpirationBuffer) < expirationDate
  }

  package func refreshToken(for user: User, forcingRefresh: Bool) async throws -> String {
    let action: RefreshAction = user.withTokenStorageLock { storage in
      if !forcingRefresh {
        if Self.isTokenValid(expirationDate: storage.expirationDate), !storage.idToken.isEmpty {
          return .cached(storage.idToken)
        }
        if let existingTask = storage.inFlightRefreshTask {
          return .inFlight(existingTask)
        }
      }

      storage.inFlightGeneration &+= 1
      let generation = storage.inFlightGeneration
      let refreshTokenValue = storage.refreshToken
      let task = Task<String, any Error> {
        try await self.performSecureTokenRefresh(for: user, refreshToken: refreshTokenValue)
      }
      storage.inFlightRefreshTask = task
      return .created(task, generation: generation)
    }

    switch action {
    case let .cached(token):
      return token
    case let .inFlight(task):
      return try await task.value
    case let .created(task, generation):
      do {
        let token = try await task.value
        user.withTokenStorageLock { storage in
          if storage.inFlightGeneration == generation {
            storage.inFlightRefreshTask = nil
          }
        }
        return token
      } catch {
        user.withTokenStorageLock { storage in
          if storage.inFlightGeneration == generation {
            storage.inFlightRefreshTask = nil
          }
        }
        throw error
      }
    }
  }

  private func performSecureTokenRefresh(for user: User,
                                         refreshToken: String) async throws -> String {
    guard !refreshToken.isEmpty else {
      throw AuthErrorUtil.error(
        code: .invalidUserToken,
        message: "Cannot refresh ID token because the user's refresh token is empty."
      )
    }

    let apiKey = try requireAPIKey()
    let endpointURL = try makeEndpointURL(
      baseURL: secureTokenBaseURL,
      path: "token",
      apiKey: apiKey
    )

    let payload = SecureTokenRefreshRequest(
      grantType: "refresh_token",
      refreshToken: refreshToken
    )
    let bodyData = try JSONEncoder().encode(payload)
    let data = try await sendJSONRequest(to: endpointURL, body: bodyData)

    let decoded: SecureTokenRefreshResponse
    do {
      decoded = try JSONDecoder().decode(SecureTokenRefreshResponse.self, from: data)
    } catch {
      throw AuthErrorUtil.error(
        code: .internalError,
        message: "Failed to decode Secure Token refresh response.",
        underlyingError: error
      )
    }

    guard let newIDToken = decoded.resolvedIDToken, !newIDToken.isEmpty else {
      throw AuthErrorUtil.error(
        code: .internalError,
        message: "Secure Token refresh response did not contain an ID token."
      )
    }

    let now = Date()
    let expiresInSeconds = Self.parseExpirationSeconds(decoded.resolvedExpiresIn)
    user.updateTokens(
      idToken: newIDToken,
      refreshToken: decoded.resolvedRefreshToken ?? refreshToken,
      expirationDate: now.addingTimeInterval(expiresInSeconds)
    )
    return newIDToken
  }

  // MARK: - Private Networking Helpers

  private func requireAPIKey() throws -> String {
    guard let apiKey, !apiKey.isEmpty else {
      throw AuthErrorUtil.error(
        code: .invalidAPIKey,
        message: "FirebaseOptions.apiKey must be configured to use FirebaseAuth."
      )
    }
    return apiKey
  }

  private func makeEndpointURL(baseURL: String, path: String, apiKey: String) throws -> URL {
    guard var components = URLComponents(string: "\(baseURL)/\(path)") else {
      throw AuthErrorUtil.error(
        code: .internalError,
        message: "Invalid Firebase Auth endpoint URL: \(baseURL)/\(path)"
      )
    }
    var queryItems = components.queryItems ?? []
    queryItems.append(URLQueryItem(name: "key", value: apiKey))
    components.queryItems = queryItems
    guard let url = components.url else {
      throw AuthErrorUtil.error(
        code: .internalError,
        message: "Failed to construct Firebase Auth URL with API key."
      )
    }
    return url
  }

  private func sendJSONRequest(to url: URL, body: Data) async throws -> Data {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(googleAppID, forHTTPHeaderField: "X-Firebase-GMPID")
    if let languageCode {
      request.setValue(languageCode, forHTTPHeaderField: "X-Firebase-Locale")
    }

    if let app,
       let appCheck = ComponentType<any AppCheckInterop>.instance(
         for: (any AppCheckInterop).self,
         in: app.container
       ) {
      let tokenResult = await appCheck.getToken(forcingRefresh: false)
      if let error = tokenResult.error {
        FirebaseLogger.log(
          level: .warning,
          service: Self.loggerService,
          code: "I-AUT000018",
          message: "Error getting App Check token; using placeholder token instead. Error: \(error)"
        )
      }
      request.setValue(tokenResult.token, forHTTPHeaderField: "X-Firebase-AppCheck")
    }

    request.httpBody = body

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw AuthErrorUtil.error(
        code: .networkError,
        message: "Network error while communicating with Firebase Auth server.",
        underlyingError: error
      )
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw AuthErrorUtil.error(
        code: .internalError,
        message: "Invalid non-HTTP response from Firebase Auth server."
      )
    }

    guard httpResponse.statusCode == 200 else {
      throw AuthErrorUtil.serverError(from: data, statusCode: httpResponse.statusCode)
    }

    return data
  }

  private static func parseExpirationSeconds(_ expiresIn: String?) -> TimeInterval {
    guard let expiresIn else { return 3600 }
    let trimmed = expiresIn.trimmingCharacters(in: .whitespaces)
    if trimmed.hasSuffix("s") {
      if let value = TimeInterval(trimmed.dropLast()), value > 0 {
        return value
      }
      return 3600
    }
    if let value = TimeInterval(trimmed), value > 0 {
      return value
    }
    return 3600
  }
}

// MARK: - AuthInterop

extension Auth: AuthInterop {
  /// Retrieves the current user's Firebase Auth ID token, refreshing it if needed.
  package func getToken(forcingRefresh: Bool) async throws -> String? {
    guard let user = currentUser else {
      return nil
    }
    return try await refreshToken(for: user, forcingRefresh: forcingRefresh)
  }

  /// Returns the current signed-in user's UID, or `nil` if no user is signed in.
  package func getUserID() -> String? {
    currentUser?.uid
  }
}

// MARK: - REST Payload Models

extension Auth {
  private struct SignInWithPasswordRequest: Encodable {
    let email: String
    let password: String
    let returnSecureToken: Bool
    let clientType: String
    let tenantId: String?
  }

  private struct SignUpRequest: Encodable {
    let returnSecureToken: Bool
    let clientType: String
    let tenantId: String?
  }

  private struct IdentityToolkitAuthResponse: Decodable {
    let localId: String
    let email: String?
    let displayName: String?
    let photoUrl: String?
    let idToken: String
    let refreshToken: String
    let expiresIn: String?
    let registered: Bool?
  }

  private struct SecureTokenRefreshRequest: Encodable {
    let grantType: String
    let refreshToken: String
  }

  private struct SecureTokenRefreshResponse: Decodable {
    let id_token: String?
    let access_token: String?
    let idToken: String?
    let refresh_token: String?
    let refreshToken: String?
    let expires_in: String?
    let expiresIn: String?

    var resolvedIDToken: String? {
      id_token ?? access_token ?? idToken
    }

    var resolvedRefreshToken: String? {
      refresh_token ?? refreshToken
    }

    var resolvedExpiresIn: String? {
      expires_in ?? expiresIn
    }
  }
}
