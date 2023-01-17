//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 07/10/2022.
//

import Foundation

/** @var kResetPasswordEndpoint
    @brief The "resetPassword" endpoint.
 */
private let kResetPasswordEndpoint = "resetPassword"

/** @var kOOBCodeKey
    @brief The "resetPassword" key.
 */
private let kOOBCodeKey = "oobCode"

/** @var kCurrentPasswordKey
    @brief The "newPassword" key.
 */
private let kCurrentPasswordKey = "newPassword"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

@objc(FIRResetPasswordRequest) public class ResetPasswordRequest: IdentityToolkitRequest, AuthRPCRequest {
    /** @property oobCode
        @brief The oobCode sent in the request.
     */
    let oobCode: String

    /** @property updatedPassword
        @brief The new password sent in the request.
     */
    let updatedPassword: String?


    /** @fn initWithOobCode:newPassword:requestConfiguration:
        @brief Designated initializer.
        @param oobCode The OOB Code.
        @param newPassword The new password.
        @param requestConfiguration An object containing configurations to be added to the request.
     */
    @objc public init(oobCode: String, newPassword: String?, requestConfiguration: AuthRequestConfiguration) {
        self.oobCode = oobCode
        self.updatedPassword = newPassword
        super.init(endpoint: kResetPasswordEndpoint, requestConfiguration: requestConfiguration)
    }

    public func unencodedHTTPRequestBody() throws -> Any {
        var postBody: [String: Any] = [:]

        postBody[kOOBCodeKey] = oobCode
        if let updatedPassword {
          postBody[kCurrentPasswordKey] = updatedPassword;
        }
        if let tenantID {
          postBody[kTenantIDKey] = tenantID
        }
        return postBody
    }
}
