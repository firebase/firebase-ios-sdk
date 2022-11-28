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
  @objc(refreshAuthExchangeTokenWithCompletion:)
  func refreshAuthExchangeToken(completion: @escaping (AuthExchangeToken?, Error?) -> Void)
}

@objc(FIRAuthExchange) public class AuthExchange: NSObject, AuthExchangeInterop {
  // MARK: - Public APIs

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
  
  /// Returns the current Auth Exchange token if valid and fetches a new one from the backend
  /// otherwise. If `forceRefresh` is true, then a new token is fetched regardless of the
  /// validity of the stored token.
  ///
  /// In order for a new token to be successfully fetched, a `TokenRefreshHandler` must be
  /// registered.
  public func getAuthExchangeToken(forceRefresh: Bool) async throws -> AuthExchangeToken? {
    // TODO: Implement methods.
    return self.authExchangeToken
  }
  
  /// See `getAuthExchangeToken(forceRefresh:)`.
  @objc(getAuthExchangeTokenForcingRefresh:completion:)
  public func getAuthExchangeToken(forceRefresh: Bool,
                                   completion: ((AuthExchangeToken?, Error?) -> Void)) {
    // TODO: Implement methods.

    completion(self.authExchangeToken, nil)
  }
  
  /** The delegate object used to request a new Auth Exchange token when the current one has expired. */
  @objc public var authExchangeDelegate: AuthExchangeDelegate?
  
  
  @objc public func clearAuthExchangeToken() {
    // TODO: Implement methods.
  }
  
  // MARK: - Exchange Token APIs

  // TODO: Replace this test function with real implementation.
  @objc(exchangeInstallationsToken:completion:)
  public func exchange(installationsToken: String,
                       handler: @escaping (AuthExchangeResult?, Error?) -> Void) {
    let token = AuthExchangeToken(token: installationsToken, expirationDate: Date())
    let result = AuthExchangeResult(
      authExchangeToken: token,
      providerIDToken: "ID123",
      providerRefreshToken: "refresh123"
    )
    handler(result, nil)
  }

  // TODO: Replace this test function with real implementation.
  @available(iOS 13, tvOS 13, macOS 10.15, watchOS 6, *)
  public func exchange(installationsToken: String) async throws -> AuthExchangeResult? {
    let token = AuthExchangeToken(token: installationsToken, expirationDate: Date())
    let result = AuthExchangeResult(
      authExchangeToken: token,
      providerIDToken: "ID123",
      providerRefreshToken: "refresh123"
    )
    return result
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
    authExchangeDelegate?.refreshAuthExchangeToken(completion: returnToAuthExchangeHandler)
  }

  // MARK: - Interop APIs

  @available(iOS 13, tvOS 13, macOS 10.15, watchOS 6, *)
  public func getToken(forceRefresh: Bool) async throws -> String {
    // TODO: Implement interop methods.
    return "Unimplemented"
  }

  public func getToken(forceRefresh: Bool, completion: (String?, Error?) -> Void) {
    // TODO: Implement interop methods.
  }
}
