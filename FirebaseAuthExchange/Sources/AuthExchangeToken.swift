/// Convenience wrapper around the Auth Exchange token returned from the exchange service.
@objc(FIRAuthExchangeToken) public class AuthExchangeToken: NSObject {
  @objc public var token: String

  @objc public var expirationDate: Date
}
