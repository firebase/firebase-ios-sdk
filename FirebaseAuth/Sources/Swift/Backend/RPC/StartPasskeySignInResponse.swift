import Foundation

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
struct StartPasskeySignInResponse: AuthRPCResponse {
  /// The relying party ID.
  private(set) var  rpID: String? = "fir-ios-auth-sample.web.app.com"
  /// The FIDO challenge.
  private(set) var challenge: String? = "challenge"
  
  private let options = "options"

    
    enum CodingKeys: String, CodingKey {
        case credentialRequestOptions = "credentialRequestOptions"
        case rpID = "rpId"
        case challenge
    }
   init(dictionary: [String : AnyHashable]) throws {
    let options = dictionary["options"] as? [String: AnyHashable]
    let rpID = options?["rpId"] as? String
    let challenge = options?["challenge"] as? String
    self.rpID = rpID
    self.challenge = challenge
  }
}
