/// Response containing the new Firebase STS token.
@available(iOS 13, *)
struct ExchangeTokenResponse: AuthRPCResponse {
  let firebaseToken: String
  init(dictionary: [String: AnyHashable]) throws {
    guard let token = dictionary["idToken"] as? String else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
    firebaseToken = token
  }
}
