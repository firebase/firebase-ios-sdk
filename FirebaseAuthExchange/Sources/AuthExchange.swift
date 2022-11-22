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

@objc(FIRTokenRefreshDelegate) public protocol TokenRefreshDelegate {
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

  // TODO: Integrate with ComponentProvider.
  private static var instanceDictionary: [String: AuthExchange] = [:]

  // TODO: Integrate with ComponentProvider.
  override public required init() {
    tokenRefreshDelegate = nil
  }

  /** Creates an `AuthExchange` instance, initialized with the provided `FirebaseApp`. */
  @objc(authExchangeWithApp:) public static func authExchange(app: FirebaseApp) -> AuthExchange {
    // TODO: Integrate with ComponentProvider.
    let instance = self.init()
    instanceDictionary[app.name] = instance
    return instance
  }

  /** The delegate object used to request a new Auth Exchange token when the current one has expired. */
  @objc public var tokenRefreshDelegate: TokenRefreshDelegate?

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
