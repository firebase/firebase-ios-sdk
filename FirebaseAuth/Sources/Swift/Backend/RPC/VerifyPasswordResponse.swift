// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// Represents the response from the verifyPassword endpoint.
///
/// Possible error codes:
/// * FIRAuthInternalErrorCodeUserDisabled
/// * FIRAuthInternalErrorCodeEmailNotFound
///
/// See https: // developers.google.com/identity/toolkit/web/reference/relyingparty/verifyPassword
struct VerifyPasswordResponse: AuthRPCResponse, AuthMFAResponse {
  /// The RP local ID if it's already been mapped to the IdP account identified by the federated ID.
  var localID: String?

  /// The email returned by the IdP. NOTE: The federated login user may not own the email.
  var email: String?

  /// The display name of the user.
  var displayName: String?

  /// Either an authorization code suitable for performing an STS token exchange, or the
  /// access token from Secure Token Service, depending on whether `returnSecureToken` is set
  /// on the request.
  private(set) var idToken: String?

  /// The approximate expiration date of the access token.
  var approximateExpirationDate: Date?

  /// The refresh token from Secure Token Service.
  var refreshToken: String?

  /// The URI of the accessible profile picture.
  var photoURL: URL?

  // MARK: - AuthMFAResponse

  private(set) var mfaPendingCredential: String?

  private(set) var mfaInfo: [AuthProtoMFAEnrollment]?

  mutating func setFields(dictionary: [String: AnyHashable]) throws {
    localID = dictionary["localId"] as? String
    email = dictionary["email"] as? String
    displayName = dictionary["displayName"] as? String
    idToken = dictionary["idToken"] as? String
    if let expiresIn = dictionary["expiresIn"] as? String {
      approximateExpirationDate = Date(timeIntervalSinceNow: (expiresIn as NSString)
        .doubleValue)
    }
    refreshToken = dictionary["refreshToken"] as? String
    photoURL = (dictionary["photoUrl"] as? String).flatMap { URL(string: $0) }

    if let mfaInfo = dictionary["mfaInfo"] as? [[String: AnyHashable]] {
      self.mfaInfo = mfaInfo.map { AuthProtoMFAEnrollment(dictionary: $0) }
    }
    mfaPendingCredential = dictionary["mfaPendingCredential"] as? String
  }
}
