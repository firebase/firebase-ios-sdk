@objc
(FIRAuthExchange) public class AuthExchange: AuthExchangeInterop, NSObject {

  /// Initializes an `AuthExchange` instance with the default `FirebaseApp`.
  @objc public static func authExchange() -> AuthExchange;

  /// Initializes an `AuthExchange` instance with the provided `FirebaseApp`.
  @objc(authExchangeWithApp:) public static func authExchange(app: FirebaseApp) -> AuthExchange

  /// Returns the current Auth Exchange token if valid and fetches a new one from the backend
  /// otherwise. If `forceRefresh` is true, then a new token is fetched regardless of the
  /// validity of the stored token.
  ///
  /// In order for a new token to be successfully fetched, a `TokenRefreshHandler` must be
  /// registered.
  public func getAuthExchangeToken(forceRefresh: Bool) async throws -> AuthExchangeToken

  /// See `getAuthExchangeToken(forceRefresh:)`.
  @objc(getAuthExchangeTokenForcingRefresh:completion:)
  public func getAuthExchangeToken(forceRefresh: Bool,
                                   completion: ((AuthExchangeToken?, Error?) -> Void))

  /// Clears the stored Auth Exchange token. This also has the side effect of clearing the
  /// `tokenRefreshDelegate`, if one is set.
  @objc public func clearAuthExchangeToken() throws


  // Exchange methods
 
  /// Exchanges a custom token for an Auth Exchange token by calling the corresponding backend
  /// endpoint.
  @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
  public func exchange(customToken: String) async throws -> AuthExchangeResult
 
  /// See `exchange(customToken:)`.
  @objc public func exchange(customToken: String,
                             completion: ((AuthExchangeResult?, Error?) -> Void))
 
  /// Exchanges a Firebase Installations token for an Auth Exchange token by calling the
  /// corresponding backend endpoint.
  @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
  public func exchange(installationsToken: String) async throws -> AuthExchangeResult
 
  /// See `exchange(installationsToken:)`.
  @objc public func exchange(installationsToken: String,
                             completion: ((AuthExchangeResult?, Error?) -> Void))
 
  /// Exchanges an OIDC token for an Auth Exchange token by calling the corresponding backend
  /// endpoint.
  @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
  public func exchange(OIDCToken: String) async throws -> AuthExchangeResult
 
  /// See `exchange(OIDCToken:)`.
  @objc public func exchange(OIDCToken: String,
                             completion: ((AuthExchangeResult?, Error?) -> Void))


  // Token refresh methods

  @objc public var tokenRefreshDelegate: TokenRefreshDelegate?
}

