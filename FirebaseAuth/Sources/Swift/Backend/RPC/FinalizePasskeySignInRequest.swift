import Foundation
import AuthenticationServices

/// Represents the request for the `finalizePasskeySignIn` endpoint.
@available(iOS 13, *)
class FinalizePasskeySignInRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = FinalizePasskeySignInResponse
  var unencodedHTTPRequestBody: [String : AnyHashable]?
  
  
  /// GCIP endpoint for finalizePasskeySignIn RPC.
  private let finalizePasskeySignInEndpoint = "accounts/passkeySignIn:finalize"
  
  /// The signature from the authenticator.
  let signature: String
  /// Identifier for the registered credential.
  var credentialID: String = "id"
  /// The CollectedClientData object from the authenticator.
  var clientDataJSON: String = "clientDataJSON"
  /// The AuthenticatorData from the authenticator.
  var authenticatorData: String = "response"
  /// The user ID.
  let userID: String
  
  /// Initializes a new `FinalizePasskeySignInRequest` with platform credential and request configuration.
  ///
  /// - Parameters:
  ///   - credentialID: The credential ID.
  ///   - clientDataJson: The CollectedClientData object from the authenticator.
  ///   - authenticatorData: The AuthenticatorData from the authenticator.
  ///   - signature: The signature from the authenticator.
  ///   - userID: The user ID.
  ///   - requestConfiguration: An object containing configurations to be added to the request.
  init(credentialID: String, clientDataJson: String, authenticatorData: String, signature: String, userID: String, requestConfiguration: AuthRequestConfiguration) {
    
    self.credentialID = credentialID
    self.clientDataJSON = clientDataJson
    self.authenticatorData = authenticatorData
    self.signature = signature
    self.userID = userID
    super.init(endpoint: finalizePasskeySignInEndpoint, requestConfiguration: requestConfiguration, useIdentityPlatform: true)
  }
}
