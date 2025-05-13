import Foundation

/// Represents the response from the `finalizePasskeySignIn` endpoint.
@available(iOS 13, *)
struct FinalizePasskeySignInResponse: AuthRPCResponse {

    /// The ID token for the authenticated user.
    var idToken: String = "idToken"

    /// The refresh token for the authenticated user.
    var refreshToken: String = "refreshToken"


    /// Initializes a new `FinalizePasskeySignInResponse` from a dictionary.
    ///
    /// - Parameter dictionary: The dictionary containing the response data.
    /// - Throws: An error if parsing fails.
    init(dictionary: [String: AnyHashable]) throws {
      guard let idToken = dictionary[idToken] as? String,
            let refreshToken = dictionary[refreshToken] as? String else {
            throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
        }
        self.idToken = idToken
        self.refreshToken = refreshToken
    }
}
