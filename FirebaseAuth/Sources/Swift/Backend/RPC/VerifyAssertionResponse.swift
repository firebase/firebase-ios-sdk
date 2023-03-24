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

/** @class FIRVerifyAssertionResponse
 @brief Represents the response from the verifyAssertion endpoint.
 @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/verifyAssertion
 */
@objc(FIRVerifyAssertionResponse) public class VerifyAssertionResponse: NSObject, AuthRPCResponse {
  /** @property federatedID
   @brief The unique ID identifies the IdP account.
   */
  @objc public var federatedID: String?

  /** @property providerID
   @brief The IdP ID. For white listed IdPs it's a short domain name e.g. google.com, aol.com,
   live.net and yahoo.com. If the "providerId" param is set to OpenID OP identifer other than
   the whilte listed IdPs the OP identifier is returned. If the "identifier" param is federated
   ID in the createAuthUri request. The domain part of the federated ID is returned.
   */
  @objc public var providerID: String?

  /** @property localID
   @brief The RP local ID if it's already been mapped to the IdP account identified by the
   federated ID.
   */
  @objc public var localID: String?

  /** @property email
   @brief The email returned by the IdP. NOTE: The federated login user may not own the email.
   */
  @objc public var email: String?

  /** @property inputEmail
   @brief It's the identifier param in the createAuthUri request if the identifier is an email. It
   can be used to check whether the user input email is different from the asserted email.
   */
  @objc public var inputEmail: String?

  /** @property originalEmail
   @brief The original email stored in the mapping storage. It's returned when the federated ID is
   associated to a different email.
   */
  @objc public var originalEmail: String?

  /** @property oauthRequestToken
   @brief The user approved request token for the OpenID OAuth extension.
   */
  @objc public var oauthRequestToken: String?

  /** @property oauthScope
   @brief The scope for the OpenID OAuth extension.
   */
  @objc public var oauthScope: String?

  /** @property firstName
   @brief The first name of the user.
   */
  @objc public var firstName: String?

  /** @property lastName
   @brief The last name of the user.
   */
  @objc public var lastName: String?

  /** @property fullName
   @brief The full name of the user.
   */
  @objc public var fullName: String?

  /** @property nickName
   @brief The nick name of the user.
   */
  @objc public var nickName: String?

  /** @property displayName
   @brief The display name of the user.
   */
  @objc public var displayName: String?

  /** @property idToken
   @brief Either an authorization code suitable for performing an STS token exchange, or the
   access token from Secure Token Service, depending on whether @c returnSecureToken is set
   on the request.
   */
  @objc(IDToken) public var idToken: String?

  /** @property approximateExpirationDate
   @brief The approximate expiration date of the access token.
   */
  @objc public var approximateExpirationDate: Date?

  /** @property refreshToken
   @brief The refresh token from Secure Token Service.
   */
  @objc public var refreshToken: String?

  /** @property action
   @brief The action code.
   */
  @objc public var action: String?

  /** @property language
   @brief The language preference of the user.
   */
  @objc public var language: String?

  /** @property timeZone
   @brief The timezone of the user.
   */
  @objc public var timeZone: String?

  /** @property photoURL
   @brief The URI of the public accessible profile picture.
   */
  @objc public var photoURL: URL?

  /** @property dateOfBirth
   @brief The birth date of the IdP account.
   */
  @objc public var dateOfBirth: String?

  /** @property context
   @brief The opaque value used by the client to maintain context info between the authentication
   request and the IDP callback.
   */
  @objc public var context: String?

  /** @property verifiedProvider
   @brief When action is 'map', contains the idps which can be used for confirmation.
   */
  @objc public var verifiedProvider: [String]?

  /** @property needConfirmation
   @brief Whether the assertion is from a non-trusted IDP and need account linking confirmation.
   */
  @objc public var needConfirmation: Bool = false

  /** @property emailRecycled
   @brief It's true if the email is recycled.
   */
  @objc public var emailRecycled: Bool = false

  /** @property emailVerified
   @brief The value is true if the IDP is also the email provider. It means the user owns the
   email.
   */
  @objc public var emailVerified: Bool = false

  /** @property isNewUser
   @brief Flag indicating that the user signing in is a new user and not a returning user.
   */
  @objc public var isNewUser: Bool = false

  /** @property profile
   @brief Dictionary containing the additional IdP specific information.
   */
  @objc public var profile: [String: Any]?

  /** @property username
   @brief The name of the user.
   */
  @objc public var username: String?

  /** @property oauthIDToken
   @brief The ID token for the OpenID OAuth extension.
   */
  @objc public var oauthIDToken: String?

  /** @property oauthExpirationDate
   @brief The approximate expiration date of the oauth access token.
   */
  @objc public var oauthExpirationDate: Date?

  /** @property oauthAccessToken
   @brief The access token for the OpenID OAuth extension.
   */
  @objc public var oauthAccessToken: String?

  /** @property oauthSecretToken
   @brief The secret for the OpenID OAuth extention.
   */
  @objc public var oauthSecretToken: String?

  /** @property pendingToken
   @brief The pending ID Token string.
   */
  @objc public var pendingToken: String?

  @objc public var MFAPendingCredential: String?

  @objc public var MFAInfo: [AuthProtoMFAEnrollment]?

  public func setFields(dictionary: [String: AnyHashable]) throws {
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
      MFAInfo = mfaInfoDicts.map {
        AuthProtoMFAEnrollment(dictionary: $0)
      }
    }
    MFAPendingCredential = dictionary["mfaPendingCredential"] as? String
  }
}
