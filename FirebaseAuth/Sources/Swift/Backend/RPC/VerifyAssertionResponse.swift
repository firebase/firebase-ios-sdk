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

/// Represents the response from the verifyAssertion endpoint.
/// See https: // developers.google.com/identity/toolkit/web/reference/relyingparty/verifyAssertion
class VerifyAssertionResponse: AuthRPCResponse, AuthMFAResponse {
  required init() {}

  /// The unique ID identifies the IdP account.
  var federatedID: String?

  /// The IdP ID. For white listed IdPs it's a short domain name e.g. google.com, aol.com,
  /// live.net and yahoo.com.If the "providerId" param is set to OpenID OP identifier other than
  /// the white listed IdPs the OP identifier is returned.If the "identifier" param is federated
  /// ID in the createAuthUri request.The domain part of the federated ID is returned.
  var providerID: String?

  /// The RP local ID if it's already been mapped to the IdP account identified by the federated ID.
  var localID: String?

  /// The email returned by the IdP. NOTE: The federated login user may not own the email.
  var email: String?

  /// It's the identifier param in the createAuthUri request if the identifier is an email. It
  /// can be used to check whether the user input email is different from the asserted email.
  var inputEmail: String?

  /// The original email stored in the mapping storage. It's returned when the federated ID is
  /// associated to a different email.
  var originalEmail: String?

  /// The user approved request token for the OpenID OAuth extension.
  var oauthRequestToken: String?

  /// The scope for the OpenID OAuth extension.
  var oauthScope: String?

  /// The first name of the user.
  var firstName: String?

  /// The last name of the user.
  var lastName: String?

  /// The full name of the user.
  var fullName: String?

  /// The nickname of the user.
  var nickName: String?

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

  /// The action code.
  var action: String?

  /// The language preference of the user.
  var language: String?

  /// The timezone of the user.
  var timeZone: String?

  /// The URI of the accessible profile picture.
  var photoURL: URL?

  /// The birth date of the IdP account.
  var dateOfBirth: String?

  /// The opaque value used by the client to maintain context info between the authentication
  /// request and the IDP callback.
  var context: String?

  /// When action is 'map', contains the idps which can be used for confirmation.
  var verifiedProvider: [String]?

  /// Whether the assertion is from a non-trusted IDP and need account linking confirmation.
  var needConfirmation: Bool = false

  /// It's true if the email is recycled.
  var emailRecycled: Bool = false

  /// The value is true if the IDP is also the email provider. It means the user owns the email.
  var emailVerified: Bool = false

  /// Flag indicating that the user signing in is a new user and not a returning user.
  var isNewUser: Bool = false

  /// Dictionary containing the additional IdP specific information.
  var profile: [String: Any]?

  /// The name of the user.
  var username: String?

  /// The ID token for the OpenID OAuth extension.
  var oauthIDToken: String?

  /// The approximate expiration date of the oauth access token.
  var oauthExpirationDate: Date?

  /// The access token for the OpenID OAuth extension.
  var oauthAccessToken: String?

  /// The secret for the OpenID OAuth extension.
  var oauthSecretToken: String?

  /// The pending ID Token string.
  var pendingToken: String?

  // MARK: - AuthMFAResponse

  private(set) var mfaPendingCredential: String?

  private(set) var mfaInfo: [AuthProtoMFAEnrollment]?

  func setFields(dictionary: [String: AnyHashable]) throws {
    federatedID = dictionary["federatedId"] as? String
    providerID = dictionary["providerId"] as? String
    localID = dictionary["localId"] as? String
    emailRecycled = dictionary["emailRecycled"] as? Bool ?? false
    emailVerified = dictionary["emailVerified"] as? Bool ?? false
    email = dictionary["email"] as? String
    inputEmail = dictionary["inputEmail"] as? String
    originalEmail = dictionary["originalEmail"] as? String
    oauthRequestToken = dictionary["oauthRequestToken"] as? String
    oauthScope = dictionary["oauthScope"] as? String
    firstName = dictionary["firstName"] as? String
    lastName = dictionary["lastName"] as? String
    fullName = dictionary["fullName"] as? String
    nickName = dictionary["nickName"] as? String
    displayName = dictionary["displayName"] as? String
    idToken = dictionary["idToken"] as? String
    if let expiresIn = dictionary["expiresIn"] as? String {
      approximateExpirationDate = Date(timeIntervalSinceNow: (expiresIn as NSString)
        .doubleValue)
    }
    refreshToken = dictionary["refreshToken"] as? String
    isNewUser = dictionary["isNewUser"] as? Bool ?? false
    if let rawUserInfo = dictionary["rawUserInfo"] as? String,
       let data = rawUserInfo.data(using: .utf8) {
      if let info = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves),
         let profile = info as? [String: Any] {
        self.profile = profile
      }
    } else if let profile = dictionary["rawUserInfo"] as? [String: Any] {
      self.profile = profile
    }
    username = dictionary["username"] as? String
    action = dictionary["action"] as? String
    language = dictionary["language"] as? String
    timeZone = dictionary["timeZone"] as? String
    photoURL = URL(string: dictionary["photoUrl"] as? String ?? "")
    dateOfBirth = dictionary["dateOfBirth"] as? String
    context = dictionary["context"] as? String
    needConfirmation = dictionary["needConfirmation"] as? Bool ?? false

    if let verifiedProvider = dictionary["verifiedProvider"] as? String,
       let data = verifiedProvider.data(using: .utf8) {
      if let decoded = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves),
         let provider = decoded as? [String] {
        self.verifiedProvider = provider
      }
    } else if let verifiedProvider = dictionary["verifiedProvider"] as? [String] {
      self.verifiedProvider = verifiedProvider
    }

    oauthIDToken = dictionary["oauthIdToken"] as? String
    if let oauthExpirationDate = dictionary["oauthExpireIn"] as? String {
      self
        .oauthExpirationDate = Date(timeIntervalSinceNow: (oauthExpirationDate as NSString)
          .doubleValue)
    }
    oauthAccessToken = dictionary["oauthAccessToken"] as? String
    oauthSecretToken = dictionary["oauthTokenSecret"] as? String
    pendingToken = dictionary["pendingToken"] as? String

    if let mfaInfoDicts = dictionary["mfaInfo"] as? [[String: AnyHashable]] {
      mfaInfo = mfaInfoDicts.map {
        AuthProtoMFAEnrollment(dictionary: $0)
      }
    }
    mfaPendingCredential = dictionary["mfaPendingCredential"] as? String
  }
}
