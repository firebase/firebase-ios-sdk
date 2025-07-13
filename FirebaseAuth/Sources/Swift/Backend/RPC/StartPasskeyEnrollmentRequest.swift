import Foundation

/// Represents the parameters for the `startPasskeyEnrollment` endpoint.
@available(iOS 13, *)
class StartPasskeyEnrollmentRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = StartPasskeyEnrollmentResponse
  var unencodedHTTPRequestBody: [String: AnyHashable]?

  /// The raw user access token.
  let idToken: String

  /// The tenant ID for the request.
  let tenantId: String?

  /// The endpoint for the request.
  private let kStartPasskeyEnrollmentEndpoint = "accounts/passkeyEnrollment:start"

  /// The request configuration.
  let requestConfiguration: AuthRequestConfiguration?

  /// Initializes a new `StartPasskeyEnrollmentRequest`.
  ///
  /// - Parameters:
  ///   - idToken: The raw user access token.
  ///   - requestConfiguration: The request configuration.
  ///   - tenantId: The tenant ID for the request.
  init(idToken: String, requestConfiguration: AuthRequestConfiguration?, tenantId: String? = nil) {
    self.idToken = idToken
    self.requestConfiguration = requestConfiguration
    self.tenantId = tenantId
    super.init(
      endpoint: kStartPasskeyEnrollmentEndpoint,
      requestConfiguration: requestConfiguration!,
      useIdentityPlatform: true
    )
  }
}
