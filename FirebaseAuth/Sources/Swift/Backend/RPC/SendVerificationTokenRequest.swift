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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public class SendVerificationCodeRequest: IdentityToolkitRequest, AuthRPCRequest {
  /** @property phoneNumber
      @brief The phone number to which the verification code should be sent.
   */
  public let phoneNumber: String

  /** @property appCredential
      @brief The credential to prove the identity of the app in order to send the verification code.
   */
  public let appCredential: AuthAppCredential?

  /** @property reCAPTCHAToken
      @brief The reCAPTCHA token to prove the identity of the app in order to send the verification
          code.
   */
  public let reCAPTCHAToken: String?

  /** @var response
      @brief The corresponding response for this request
   */
  public var response: SendVerificationCodeResponse = SendVerificationCodeResponse()

  public init(phoneNumber: String, appCredential: AuthAppCredential?,
                    reCAPTCHAToken: String?, requestConfiguration: AuthRequestConfiguration) {
    self.phoneNumber = phoneNumber
    self.appCredential = appCredential
    self.reCAPTCHAToken = reCAPTCHAToken
    super.init(
      endpoint: kSendVerificationCodeEndPoint,
      requestConfiguration: requestConfiguration
    )
  }

  public func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var postBody: [String: AnyHashable] = [:]
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
