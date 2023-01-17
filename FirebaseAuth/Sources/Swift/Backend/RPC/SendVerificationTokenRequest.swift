//
//  File.swift
//
//
//  Created by Morten Bek Ditlevsen on 16/01/2023.
//

import Foundation

/** @var kSendVerificationCodeEndPoint
    @brief The "sendVerificationCodeEnd" endpoint.
 */
private let kSendVerificationCodeEndPoint = "sendVerificationCode"

/** @var kPhoneNumberKey
    @brief The key for the Phone Number parameter in the request.
 */
private let kPhoneNumberKey = "phoneNumber"

/** @var kReceiptKey
    @brief The key for the receipt parameter in the request.
 */
private let kReceiptKey = "iosReceipt"

/** @var kSecretKey
    @brief The key for the Secret parameter in the request.
 */
private let kSecretKey = "iosSecret"

/** @var kreCAPTCHATokenKey
    @brief The key for the reCAPTCHAToken parameter in the request.
 */
private let kreCAPTCHATokenKey = "recaptchaToken"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

@objc(FIRSendVerificationCodeRequest) public class SendVerificationCodeRequest: IdentityToolkitRequest, AuthRPCRequest {

    /** @property phoneNumber
        @brief The phone number to which the verification code should be sent.
     */
    @objc public let phoneNumber: String

    /** @property appCredential
        @brief The credential to prove the identity of the app in order to send the verification code.
     */
    @objc public let appCredential: AuthAppCredential?

    /** @property reCAPTCHAToken
        @brief The reCAPTCHA token to prove the identity of the app in order to send the verification
            code.
     */
    @objc public let reCAPTCHAToken: String?

    @objc public init(phoneNumber: String, appCredential: AuthAppCredential?, reCAPTCHAToken: String?, requestConfiguration: AuthRequestConfiguration) {
        self.phoneNumber = phoneNumber
        self.appCredential = appCredential
        self.reCAPTCHAToken = reCAPTCHAToken
        super.init(endpoint: kSendVerificationCodeEndPoint, requestConfiguration: requestConfiguration)
    }

    @objc public func unencodedHTTPRequestBody() throws -> Any {
        var postBody: [String: Any] = [:]
        postBody[kPhoneNumberKey] = phoneNumber
        if let receipt = appCredential?.receipt {
            postBody[kReceiptKey] = receipt
        }
        if let secret = appCredential?.secret {
            postBody[kSecretKey] = secret
        }
        if let reCAPTCHAToken {
            postBody[kreCAPTCHATokenKey] = reCAPTCHAToken
        }

        if let tenantID {
            postBody[kTenantIDKey] = tenantID
        }
        return postBody
    }
}
