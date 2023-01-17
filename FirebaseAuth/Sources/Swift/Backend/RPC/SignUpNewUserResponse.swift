//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 07/10/2022.
//

import Foundation

@objc(FIRSignUpNewUserResponse) public class SignUpNewUserResponse: NSObject, AuthRPCResponse {

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

    public func setFields(dictionary: [String : Any]) throws {
        self.IDToken = dictionary["idToken"] as? String
          if let approximateExpirationDate = dictionary["expiresIn"] as? String {
              self.approximateExpirationDate = Date(timeIntervalSinceNow: (approximateExpirationDate as NSString).doubleValue)
          }
        self.refreshToken = dictionary["refreshToken"] as? String
    }
}
