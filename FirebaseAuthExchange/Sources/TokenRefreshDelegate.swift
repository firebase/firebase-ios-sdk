@objc(FIRTokenRefreshDelegate) public protocol TokenRefreshDelegate {
 
  /// This method is invoked whenever a new Auth Exchange token is needed. Developers should
  /// implement this method to request a new token from an identity provider and then exchange
  /// it for a new Auth Exchange token using one of the exchange methods.
  @objc(refreshAuthExchangeTokenWithCompletion:)
  func refreshAuthExchangeToken(completion:@escaping (AuthExchangeToken?, Error?) -> Void)
}

