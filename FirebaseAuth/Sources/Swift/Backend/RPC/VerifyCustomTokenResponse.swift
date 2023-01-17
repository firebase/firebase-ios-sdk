//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 16/01/2023.
//

import Foundation

/** @class FIRVerifyCustomTokenResponse
    @brief Represents the response from the verifyCustomToken endpoint.
 */
@objc(FIRVerifyCustomTokenResponse) public class VerifyCustomTokenResponse: NSObject, AuthRPCResponse {

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

    /** @property isNewUser
     @brief Flag indicating that the user signing in is a new user and not a returning user.
     */
    @objc public var isNewUser: Bool = false

    public func setFields(dictionary: [String: Any]) throws {
        self.IDToken = dictionary["idToken"] as? String
        if let dateString = dictionary["expiresIn"] as? NSString {
            self.approximateExpirationDate = Date(timeIntervalSinceNow: dateString.doubleValue)
        }
        self.refreshToken = dictionary["refreshToken"] as? String
        self.isNewUser = dictionary["isNewUser"] as? Bool ?? false
    }
}
