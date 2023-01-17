//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 07/10/2022.
//

import Foundation

/** @var kSignupNewUserEndpoint
    @brief The "SingupNewUserEndpoint" endpoint.
 */
private let kSignupNewUserEndpoint = "signupNewUser"

/** @var kEmailKey
    @brief The key for the "email" value in the request.
 */
private let kEmailKey = "email"

/** @var kPasswordKey
    @brief The key for the "password" value in the request.
 */
private let kPasswordKey = "password"

/** @var kDisplayNameKey
    @brief The key for the "kDisplayName" value in the request.
 */
private let kDisplayNameKey = "displayName"

/** @var kReturnSecureTokenKey
    @brief The key for the "returnSecureToken" value in the request.
 */
private let kReturnSecureTokenKey = "returnSecureToken"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"


@objc(FIRSignUpNewUserRequest) public class SignUpNewUserRequest: IdentityToolkitRequest, AuthRPCRequest {

    /** @property email
        @brief The email of the user.
     */
    @objc public var email: String?

    /** @property password
        @brief The password inputed by the user.
     */
    @objc public var password: String?

    /** @property displayName
        @brief The password inputed by the user.
     */
    @objc public var displayName: String?

    /** @property returnSecureToken
        @brief Whether the response should return access token and refresh token directly.
        @remarks The default value is @c YES .
     */
    @objc public var returnSecureToken: Bool = true

    @objc public init(requestConfiguration: AuthRequestConfiguration) {
        super.init(endpoint: kSignupNewUserEndpoint, requestConfiguration: requestConfiguration)
    }

    /** @fn initWithAPIKey:email:password:displayName:requestConfiguration
        @brief Designated initializer.
        @param requestConfiguration An object containing configurations to be added to the request.
     */
    @objc public init(email: String?,
                      password: String?,
                      displayName: String?,
                      requestConfiguration: AuthRequestConfiguration) {
        self.email = email
        self.password = password
        self.displayName = displayName
        super.init(endpoint: kSignupNewUserEndpoint, requestConfiguration: requestConfiguration)
    }

    public func unencodedHTTPRequestBody() throws -> Any {
        var postBody: [String: Any] = [:]
        if let email {
            postBody[kEmailKey] = email
        }
        if let password {
            postBody[kPasswordKey] = password
        }
        if let displayName {
            postBody[kDisplayNameKey] = displayName
        }
        if returnSecureToken {
            postBody[kReturnSecureTokenKey] = true
        }
        if let tenantID {
            postBody[kTenantIDKey] = tenantID
        }
        return postBody
    }
}
