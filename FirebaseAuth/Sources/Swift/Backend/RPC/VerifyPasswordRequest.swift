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
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public class VerifyPasswordRequest: IdentityToolkitRequest, AuthRPCRequest {
  /** @property email
      @brief The email of the user.
   */
  public var email: String

  /** @property password
      @brief The password inputed by the user.
   */
  public var password: String

  /** @property pendingIDToken
      @brief The GITKit token for the non-trusted IDP, which is to be confirmed by the user.
   */
  public var pendingIDToken: String?

  /** @property captchaChallenge
      @brief The captcha challenge.
   */
  public var captchaChallenge: String?

  /** @property captchaResponse
      @brief Response to the captcha.
   */
  public var captchaResponse: String?

  /** @property returnSecureToken
      @brief Whether the response should return access token and refresh token directly.
      @remarks The default value is @c YES .
   */
  public var returnSecureToken: Bool

  /** @var response
      @brief The corresponding response for this request
   */
  public var response: VerifyPasswordResponse = .init()

  public init(email: String, password: String,
              requestConfiguration: AuthRequestConfiguration) {
    self.email = email
    self.password = password
    returnSecureToken = true
    super.init(endpoint: kVerifyPasswordEndpoint, requestConfiguration: requestConfiguration)
  }

  public func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var body: [String: AnyHashable] = [
      kEmailKey: email,
      kPasswordKey: password,
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
