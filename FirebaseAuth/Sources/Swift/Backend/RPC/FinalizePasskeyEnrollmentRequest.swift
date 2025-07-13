import Foundation

/// Represents the request for the `finalizePasskeyEnrollment` endpoint.
@available(iOS 13, *)
class FinalizePasskeyEnrollmentRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = FinalizePasskeyEnrollmentResponse
  var unencodedHTTPRequestBody: [String: AnyHashable]?

  /// GCIP endpoint for finalizePasskeyEnrollment RPC.
  let kFinalizePasskeyEnrollmentEndpoint = "accounts/passkeyEnrollment:finalize"

  /// The raw user access token.
  let idToken: String
  //  name of user or passkey ?.?
  let name: String
  /// The credential ID.
  var credentialID: String = "id"
  /// The CollectedClientData object from the authenticator.
  var clientDataJson: String = "clientDataJSON"
  /// The attestation object from the authenticator.
  var attestationObject: String = "response"

  /// The request configuration.
  let requestConfiguration: AuthRequestConfiguration?

  /// Initializes a new `FinalizePasskeyEnrollmentRequest`.
  ///
  /// - Parameters:
  ///   - IDToken: The raw user access token.
  ///   - name: The passkey name.
  ///   - credentialID: The credential ID.
  ///   - clientDataJson: The CollectedClientData object from the authenticator.
  ///   - attestationObject: The attestation object from the authenticator.
  ///   - requestConfiguration: The request configuration.
  init(idToken: String, name: String, credentialID: String, clientDataJson: String,
       attestationObject: String, requestConfiguration: AuthRequestConfiguration) {
    self.idToken = idToken
    self.name = name
    self.credentialID = credentialID
    self.clientDataJson = clientDataJson
    self.attestationObject = attestationObject
    self.requestConfiguration = requestConfiguration
    super.init(
      endpoint: kFinalizePasskeyEnrollmentEndpoint,
      requestConfiguration: requestConfiguration,
      useIdentityPlatform: true
    )
  }
}
