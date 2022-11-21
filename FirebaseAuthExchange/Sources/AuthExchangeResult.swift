/// Wrapper around the Auth Exchange response from the exchange service. This will always
/// contain the `AuthExchangeToken`. For some provider flows (i.e. OIDC) a provider ID token and
/// a refresh token may also be returned.
@objc(FIRAuthExchangeResult) public class AuthExchangeResult: NSObject {
  @objc public private(set) var authExchangeToken: AuthExchangeToken

  @objc public private(set) var providerIDToken: String?

  @objc public private(set) var providerRefreshToken: String?
}
