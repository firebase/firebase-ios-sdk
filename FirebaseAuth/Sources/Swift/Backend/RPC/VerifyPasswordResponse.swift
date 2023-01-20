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

/** @class FIRVerifyPasswordResponse
    @brief Represents the response from the verifyPassword endpoint.
    @remarks Possible error codes:
       - FIRAuthInternalErrorCodeUserDisabled
       - FIRAuthInternalErrorCodeEmailNotFound
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/verifyPassword
 */
@objc(FIRVerifyPasswordResponse) public class VerifyPasswordResponse: NSObject, AuthRPCResponse {
    /** @property localID
        @brief The RP local ID if it's already been mapped to the IdP account identified by the
            federated ID.
     */
    @objc public var localID: String?

    /** @property email
        @brief The email returned by the IdP. NOTE: The federated login user may not own the email.
     */
    @objc public var email: String?

    /** @property displayName
        @brief The display name of the user.
     */
    @objc public var displayName: String?

    /** @property IDToken
        @brief Either an authorization code suitable for performing an STS token exchange, or the
            access token from Secure Token Service, depending on whether @c returnSecureToken is set
            on the request.
     */
    @objc public var IDToken: String?

    /** @property approximateExpirationDate
        @brief The approximate expiration date of the access token.
     */
    @objc public var approximateExpirationDate: Date?

    /** @property refreshToken
        @brief The refresh token from Secure Token Service.
     */
    @objc public var refreshToken: String?

    /** @property photoURL
        @brief The URI of the public accessible profile picture.
     */
    @objc public var photoURL: URL?

    @objc public var MFAPendingCredential: String?

    @objc public var MFAInfo: [AuthProtoMFAEnrollment]?

    public func setFields(dictionary: [String : Any]) throws {
        self.localID = dictionary["localId"] as? String
        self.email = dictionary["email"] as? String
        self.displayName = dictionary["displayName"] as? String
        self.IDToken = dictionary["idToken"] as? String
        if let expiresIn = dictionary["expiresIn"] as? String {
            self.approximateExpirationDate = Date(timeIntervalSinceNow: (expiresIn as NSString).doubleValue)
        }
        self.refreshToken = dictionary["refreshToken"] as? String
        self.photoURL = (dictionary["photoUrl"] as? String).flatMap { URL(string: $0) }

        if let mfaInfo = dictionary["mfaInfo"] as? [[String: Any]] {
            self.MFAInfo = mfaInfo.map { AuthProtoMFAEnrollment(dictionary: $0) }
        }
        self.MFAPendingCredential = dictionary["mfaPendingCredential"] as? String
    }
}
