//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 26/09/2022.
//

import Foundation

/** @var kVerifyPasswordEndpoint
    @brief The "verifyPassword" endpoint.
 */
private let kVerifyPasswordEndpoint = "verifyPassword"

/** @var kEmailKey
    @brief The key for the "email" value in the request.
 */
private let kEmailKey = "email"

/** @var kPasswordKey
    @brief The key for the "password" value in the request.
 */
private let kPasswordKey = "password"

/** @var kPendingIDTokenKey
    @brief The key for the "pendingIdToken" value in the request.
 */
private let kPendingIDTokenKey = "pendingIdToken"

/** @var kCaptchaChallengeKey
    @brief The key for the "captchaChallenge" value in the request.
 */
private let kCaptchaChallengeKey = "captchaChallenge"

/** @var kCaptchaResponseKey
    @brief The key for the "captchaResponse" value in the request.
 */
private let kCaptchaResponseKey = "captchaResponse"

/** @var kReturnSecureTokenKey
    @brief The key for the "returnSecureToken" value in the request.
 */
private let kReturnSecureTokenKey = "returnSecureToken"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

/** @class FIRVerifyPasswordRequest
    @brief Represents the parameters for the verifyPassword endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/verifyPassword
 */
@objc(FIRVerifyPasswordRequest) public class VerifyPasswordRequest: IdentityToolkitRequest, AuthRPCRequest {

    /** @property email
        @brief The email of the user.
     */
    @objc public var email: String

    /** @property password
        @brief The password inputed by the user.
     */
    @objc public var password: String

    /** @property pendingIDToken
        @brief The GITKit token for the non-trusted IDP, which is to be confirmed by the user.
     */
    @objc public var pendingIDToken: String?

    /** @property captchaChallenge
        @brief The captcha challenge.
     */
    @objc public var captchaChallenge: String?

    /** @property captchaResponse
        @brief Response to the captcha.
     */
    @objc public var captchaResponse: String?

    /** @property returnSecureToken
        @brief Whether the response should return access token and refresh token directly.
        @remarks The default value is @c YES .
     */
    @objc public var returnSecureToken: Bool

    @objc public init(email: String, password: String, requestConfiguration: AuthRequestConfiguration) {
        self.email = email
        self.password = password
        self.returnSecureToken = true
        super.init(endpoint: kVerifyPasswordEndpoint, requestConfiguration: requestConfiguration)
    }

    public func unencodedHTTPRequestBody() throws -> Any {
        var body: [String: Any] = [
            kEmailKey: email,
            kPasswordKey: password
        ]
        if let pendingIDToken = pendingIDToken {
            body[kPendingIDTokenKey] = pendingIDToken
        }
        if let captchaChallenge = captchaChallenge {
            body[kCaptchaChallengeKey] = captchaChallenge
        }
        if let captchaResponse = captchaResponse {
            body[kCaptchaResponseKey] = captchaResponse
        }
        if returnSecureToken {
            body[kReturnSecureTokenKey] = true
        }
        if let tenantID = tenantID {
            body[kTenantIDKey] = tenantID
        }
        return body

    }
}
