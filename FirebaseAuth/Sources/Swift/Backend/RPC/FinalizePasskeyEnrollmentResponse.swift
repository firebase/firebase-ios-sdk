import Foundation

/// Represents the response from the `finalizePasskeyEnrollment` endpoint.
@available(iOS 13, *)
struct FinalizePasskeyEnrollmentResponse: AuthRPCResponse {

    /// The ID token for the authenticated user.
    public let idToken: String

    /// The refresh token for the authenticated user.
    public let refreshToken: String

    private static let kIdTokenKey = "idToken"
    private static let kRefreshTokenKey = "refreshToken"

    /// Initializes a new `FinalizePasskeyEnrollmentResponse` from a dictionary.
    ///
    /// - Parameter dictionary: The dictionary containing the response data.
    /// - Throws: An error if parsing fails.
    public init(dictionary: [String: AnyHashable]) throws {
        guard let idToken = dictionary[Self.kIdTokenKey] as? String,
              let refreshToken = dictionary[Self.kRefreshTokenKey] as? String else {
            throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
        }
        self.idToken = idToken
        self.refreshToken = refreshToken
    }
}
