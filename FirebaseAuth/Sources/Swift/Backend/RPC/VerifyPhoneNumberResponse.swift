//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 20/01/2023.
//

import Foundation

@objc(FIRVerifyPhoneNumberResponse) public class VerifyPhoneNumberResponse: NSObject, AuthRPCResponse {
    /** @property IDToken
     @brief Either an authorization code suitable for performing an STS token exchange, or the
     access token from Secure Token Service, depending on whether @c returnSecureToken is set
     on the request.
     */
    @objc public var IDToken: String?

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
        self.IDToken = dictionary["idToken"] as? String
        self.refreshToken = dictionary["refreshToken"] as? String
        self.isNewUser = (dictionary["isNewUser"] as? Bool) ?? false
        self.localID = dictionary["localId"] as? String
        self.phoneNumber = dictionary["phoneNumber"] as? String
        self.temporaryProof = dictionary["temporaryProof"] as? String
        if let expiresIn = dictionary["expiresIn"] as? String {
            self.approximateExpirationDate = Date(timeIntervalSinceNow: (expiresIn as NSString).doubleValue)
        }
    }
}
