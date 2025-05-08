import Foundation

/// Represents the response from the `startPasskeyEnrollment` endpoint.
@available(iOS 13, *)
struct StartPasskeyEnrollmentResponse: AuthRPCResponse {
  
  /// The RP ID of the FIDO Relying Party.
  private(set) var rpID: String = "fir-ios-auth-sample.web.app.com"
  
  /// The user ID.
  private(set) var userID: Data
  
  /// The FIDO challenge.
  private(set) var challenge: Data
  
  ///  The name of the field in the response JSON for CredentialCreationOptions.
  private let kOptionsKey = "credentialCreationOptions"
  
  /// The name of the field in the response JSON for Relying Party.
  private let kRpKey = "rp"
  
  /// The name of the field in the response JSON for User.
  private let kUserKey = "user"
  
  /// The name of the field in the response JSON for ids.
  private let kIDKey = "id"
  
  /// The name of the field in the response JSON for challenge.
  private let kChallengeKey = "challenge"
  
  
  /// Initializes a new `StartPasskeyEnrollmentResponse` from a dictionary.
  ///
  /// - Parameters:
  ///   - dictionary: The dictionary containing the response data.
  /// - Throws: An error if parsing fails.
  init(dictionary: [String: AnyHashable]) throws {
    guard let options = dictionary[kOptionsKey] as? [String: AnyHashable] else {
      throw NSError(domain: "com.firebase.auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing credentialCreationOptions"])
    }
    
    guard let rp = options[kRpKey] as? [String: AnyHashable],
          let rpID = rp[kIDKey] as? String, !rpID.isEmpty else {
      throw NSError(domain: "com.firebase.auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid rpID"])
    }
    
    guard let user = options[kUserKey] as? [String: AnyHashable],
          let userID = user[kIDKey] as? String, !userID.isEmpty, let userIDData = userID.data(using: .utf8) else {
      throw NSError(domain: "com.firebase.auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid userID"])
    }
    
    guard let challenge = options[kChallengeKey] as? String, !challenge.isEmpty, let challengeData = challenge.data(using: .utf8) else {
      throw NSError(domain: "com.firebase.auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid challenge"])
    }
    self.rpID = rpID
    self.userID = userIDData
    self.challenge = challengeData
  }
  
  // MARK: - AuthRPCResponse default implementation
  func clientError(shortErrorMessage: String, detailedErrorMessage: String? = nil) -> Error? {
    return nil
  }
}
