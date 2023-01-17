//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/09/2022.
//

import Foundation

/** @class FIRAuthResetPasswordResponse
    @brief Represents the response from the resetPassword endpoint.
    @remarks Possible error codes:
       - FIRAuthErrorCodeWeakPassword
       - FIRAuthErrorCodeUserDisabled
       - FIRAuthErrorCodeOperationNotAllowed
       - FIRAuthErrorCodeExpiredActionCode
       - FIRAuthErrorCodeInvalidActionCode
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/resetPassword
 */
@objc(FIRResetPasswordResponse) public class ResetPasswordResponse: NSObject, AuthRPCResponse {

    /** @property email
     @brief The email address corresponding to the reset password request.
     */
    @objc public var email: String?

    /** @property verifiedEmail
     @brief The verified email returned from the backend.
     */
    @objc public var verifiedEmail: String?

    /** @property requestType
     @brief The tpye of request as returned by the backend.
     */
    @objc public var requestType: String?

    public func setFields(dictionary: [String: Any]) throws {
        self.email = dictionary["email"] as? String
        self.requestType = dictionary["requestType"] as? String
        self.verifiedEmail = dictionary["newEmail"] as? String
    }
}
