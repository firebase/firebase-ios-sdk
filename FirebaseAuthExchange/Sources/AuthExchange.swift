// Copyright 2022 Google LLC
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

@objc(FIRAuthExchangeDelegate) public protocol AuthExchangeDelegate {
  /**
   * This method is invoked whenever a new Auth Exchange token is needed. Developers should implement this method to request a
   * new token from an identity provider and then exchange it for a new Auth Exchange token.
   */
  @objc(refreshTokenForAuthExchange:completion:)
  func refreshToken(authExchange: AuthExchange,
                    completion: @escaping (AuthExchangeToken?, Error?) -> Void)
}

@objc(FIRAuthExchange) public class AuthExchange: NSObject, AuthExchangeInterop {
  // MARK: - Public APIs

  /** The delegate object used to request a new Auth Exchange token when the current one has expired. */
  @objc public var authExchangeDelegate: AuthExchangeDelegate?

  /** Creates an `AuthExchange` instance, initialized with the default `FirebaseApp`. */
  @objc public static func authExchange() -> AuthExchange {
    return authExchange(app: FirebaseApp.app()!)
  }

  /** Creates an `AuthExchange` instance, initialized with the provided `FirebaseApp`. */
  @objc(authExchangeWithApp:) public static func authExchange(app: FirebaseApp) -> AuthExchange {
    // TODO: Integrate with ComponentProvider.
    let instance = self.init()
    instanceDictionary[app.name] = instance
    return instance
  }

  /**
   * Returns the current Auth Exchange token if valid and fetches a new one from the backend otherwise. If `forceRefresh` is true,
   * then a new token is fetched regardless of the validity of the stored token.
   *
   * In order for a new token to be successfully fetched, an `AuthExchangeDelegate` must be registered.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, watchOS 6, *)
  public func getToken(forceRefresh: Bool) async throws -> AuthExchangeToken? {
    // TODO: Implement methods.
    return authExchangeToken
  }

  /** See `getToken(forceRefresh:)`. */
  @objc(getTokenForcingRefresh:completion:)
  public func getToken(forceRefresh: Bool,
                       completion: @escaping (AuthExchangeToken?, Error?) -> Void) {
    // TODO: Implement methods.

    completion(authExchangeToken, nil)
  }

  /** Clears the stored Auth Exchange token and delegate, if one is set. */
  @objc public func clearState() {
    // TODO: Implement methods.
  }

  /** See `clearState()`. */
  @objc(clearStateWithCompletion:)
  public func clearState(completion: (Error?) -> Void) {
    // TODO: Implement methods.
  }

  /**
   * Exchanges a custom token for an `AuthExchangeToken` and updates the `AuthExchange` instance with the
   * `AuthExchangeToken`.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, watchOS 6, *)
  public func updateWith(customToken: String) async throws -> AuthExchangeResult {
    // TODO: Replace this test function with real implementation.
    let token = AuthExchangeToken(token: "token", expirationDate: Date())
    let result = AuthExchangeResult(
      authExchangeToken: token
    )
    return result
  }

  /** See `updateWith(customToken:)`. */
  @objc public func updateWith(customToken: String,
                               completion: @escaping (AuthExchangeResult?, Error?) -> Void) {
    // TODO: Replace this test function with real implementation.
    let token = AuthExchangeToken(token: "token", expirationDate: Date())
    let result = AuthExchangeResult(
      authExchangeToken: token
    )
    completion(result, nil)
  }

  /**
   * Exchanges a Firebase Installations token for an `AuthExchangeToken` and updates the `AuthExchange` instance with the
   * `AuthExchangeToken`.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, watchOS 6, *)
  public func updateWithInstallationsToken() async throws -> AuthExchangeResult {
    // TODO: Replace this test function with real implementation.
    let token = AuthExchangeToken(token: "token", expirationDate: Date())
    let result = AuthExchangeResult(
      authExchangeToken: token
    )
    return result
  }

  /** See `updateWithInstallationsToken()`. */
  @objc(updateWithInstallationsTokenWithCompletion:)
  public func updateWithInstallationsToken(completion: @escaping (AuthExchangeResult?, Error?)
    -> Void) {
    // TODO: Replace this test function with real implementation.
    let token = AuthExchangeToken(token: "token", expirationDate: Date())
    let result = AuthExchangeResult(
      authExchangeToken: token
    )
    completion(result, nil)
  }

  /**
   * Exchanges an OIDC token for an `AuthExchangeToken` and updates the `AuthExchange` instance with the
   * `AuthExchangeToken`.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, watchOS 6, *)
  public func updateWith(OIDCToken: String) async throws -> AuthExchangeResult {
    // TODO: Replace this test function with real implementation.
    let token = AuthExchangeToken(token: "token", expirationDate: Date())
    let result = AuthExchangeResult(
      authExchangeToken: token
    )
    return result
  }

  /** See `updateWith(OIDCToken:)`. */
  @objc public func updateWith(OIDCToken: String,
                               completion: @escaping (AuthExchangeResult?, Error?) -> Void) {
    // TODO: Replace this test function with real implementation.
    let token = AuthExchangeToken(token: "token", expirationDate: Date())
    let result = AuthExchangeResult(
      authExchangeToken: token
    )
    completion(result, nil)
  }

  // MARK: - Internal APIs

  // TODO: Integrate with ComponentProvider.
  private static var instanceDictionary: [String: AuthExchange] = [:]

  // TODO: Integrate with ComponentProvider.
  override public required init() {
    authExchangeDelegate = nil
  }

  /** The cached Auth Exchange token */
  var authExchangeToken: AuthExchangeToken?

  // TODO: Replace this test function with real implementation.
  /** This is a test funciton to trigger delegate call */
  public func tryDelegate() {
    let returnToAuthExchangeHandler: (AuthExchangeToken?, Error?) -> Void = {
      token, error in
      self.authExchangeToken = token
      print("[delegate] token: \(String(describing: token?.token))")
      // Auth exchange can do sth with this token
    }
    authExchangeDelegate?.refreshToken(authExchange: self, completion: returnToAuthExchangeHandler)
  }

  // MARK: - Interop APIs

  @available(iOS 13, tvOS 13, macOS 10.15, watchOS 6, *)
  public func getTokenInternal(forceRefresh: Bool) async throws -> String {
    // TODO: Implement interop methods.
    return "Unimplemented"
  }

  public func getTokenInternal(forceRefresh: Bool,
                               @escaping completion: (String?, Error?) -> Void) {
    // TODO: Implement interop methods.
  }
}
