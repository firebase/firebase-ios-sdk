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
    @brief Represents the response from the emailLinkSignin endpoint.
 */
public class EmailLinkSignInResponse: NSObject, AuthRPCResponse {
  /** @property IDToken
   @brief The ID token in the email link sign-in response.
   */
  @objc(IDToken) public var idToken: String?

  /** @property email
   @brief The email returned by the IdP.
   */
  public var email: String?

  /** @property refreshToken
   @brief The refreshToken returned by the server.
   */
  public var refreshToken: String?

  /** @property approximateExpirationDate
   @brief The approximate expiration date of the access token.
   */
  public var approximateExpirationDate: Date?

  /** @property isNewUser
   @brief Flag indicating that the user signing in is a new user and not a returning user.
   */
  public var isNewUser: Bool = false

  /** @property MFAPendingCredential
       @brief An opaque string that functions as proof that the user has successfully passed the first
      factor check.
   */
  public var MFAPendingCredential: String?

  /** @property MFAInfo
       @brief Info on which multi-factor authentication providers are enabled.
   */
  public var MFAInfo: [AuthProtoMFAEnrollment]?

  public func setFields(dictionary: [String: AnyHashable]) throws {
    email = dictionary["email"] as? String
    idToken = dictionary["idToken"] as? String
    isNewUser = dictionary["isNewUser"] as? Bool ?? false
    refreshToken = dictionary["refreshToken"] as? String

    approximateExpirationDate = (dictionary["expiresIn"] as? String)
      .flatMap { Date(timeIntervalSinceNow: ($0 as NSString).doubleValue)
      }

    if let mfaInfoArray = dictionary["mfaInfo"] as? [[String: AnyHashable]] {
      var mfaInfo: [AuthProtoMFAEnrollment] = []
      for entry in mfaInfoArray {
        let enrollment = AuthProtoMFAEnrollment(dictionary: entry)
        mfaInfo.append(enrollment)
      }
      MFAInfo = mfaInfo
    }
    MFAPendingCredential = dictionary["mfaPendingCredential"] as? String
  }
}
