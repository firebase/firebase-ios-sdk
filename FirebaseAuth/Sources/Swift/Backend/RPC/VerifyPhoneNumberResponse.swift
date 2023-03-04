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

@objc(FIRVerifyPhoneNumberResponse) public class VerifyPhoneNumberResponse: NSObject,
  AuthRPCResponse {
  /** @property IDToken
   @brief Either an authorization code suitable for performing an STS token exchange, or the
   access token from Secure Token Service, depending on whether @c returnSecureToken is set
   on the request.
   */
  @objc public var idToken: String?

  /** @property refreshToken
   @brief The refresh token from Secure Token Service.
   */
  @objc public var refreshToken: String?

  /** @property localID
   @brief The Firebase Auth user ID.
   */
  @objc public var localID: String?

  /** @property phoneNumber
   @brief The verified phone number.
   */
  @objc public var phoneNumber: String?

  /** @property temporaryProof
   @brief The temporary proof code returned by the backend.
   */
  @objc public var temporaryProof: String?

  /** @property isNewUser
   @brief Flag indicating that the user signing in is a new user and not a returning user.
   */

  @objc public var isNewUser: Bool = false

  /** @property approximateExpirationDate
   @brief The approximate expiration date of the access token.
   */
  @objc public var approximateExpirationDate: Date?

  // XXX TODO: What might this be?
  func expectedKind() -> String? {
    nil
  }

  public func setFields(dictionary: [String: Any]) throws {
    idToken = dictionary["idToken"] as? String
    refreshToken = dictionary["refreshToken"] as? String
    isNewUser = (dictionary["isNewUser"] as? Bool) ?? false
    localID = dictionary["localId"] as? String
    phoneNumber = dictionary["phoneNumber"] as? String
    temporaryProof = dictionary["temporaryProof"] as? String
    if let expiresIn = dictionary["expiresIn"] as? String {
      approximateExpirationDate = Date(timeIntervalSinceNow: (expiresIn as NSString)
        .doubleValue)
    }
  }
}
