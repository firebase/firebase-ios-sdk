import Foundation
import FirebaseAuthInterop

/// The request to start passkey sign in.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class StartPasskeySignInRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = StartPasskeySignInResponse
  var unencodedHTTPRequestBody: [String : AnyHashable]?

  private let kStartPasskeySignInEndpoint = "accounts/passkeySignIn:start"

    /// The sessionID
    var sessionId: String
    /// Designated initializer.
    /// - Parameter sessionId: The sessionId for the request.
    init(sessionId: String, requestConfiguration: AuthRequestConfiguration) {
        self.sessionId = sessionId
        super.init(
          endpoint: kStartPasskeySignInEndpoint,
          requestConfiguration: requestConfiguration
        )
    }
}

