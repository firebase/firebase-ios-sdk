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

private let FIRSetAccountInfoUserAttributeEmail = "EMAIL"

private let FIRSetAccountInfoUserAttributeDisplayName = "DISPLAY_NAME"

private let FIRSetAccountInfoUserAttributeProvider = "PROVIDER"

private let FIRSetAccountInfoUserAttributePhotoURL = "PHOTO_URL"

private let FIRSetAccountInfoUserAttributePassword = "PASSWORD"

/** @var kCreateAuthURIEndpoint
    @brief The "setAccountInfo" endpoint.
 */
private let kSetAccountInfoEndpoint = "setAccountInfo"

/** @var kIDTokenKey
    @brief The key for the "idToken" value in the request. This is actually the STS Access Token,
        despite it's confusing (backwards compatiable) parameter name.
 */
private let kIDTokenKey = "idToken"

/** @var kDisplayNameKey
    @brief The key for the "displayName" value in the request.
 */
private let kDisplayNameKey = "displayName"

/** @var kLocalIDKey
    @brief The key for the "localID" value in the request.
 */
private let kLocalIDKey = "localId"

/** @var kEmailKey
    @brief The key for the "email" value in the request.
 */
private let kEmailKey = "email"

/** @var kPasswordKey
    @brief The key for the "password" value in the request.
 */
private let kPasswordKey = "password"

/** @var kPhotoURLKey
    @brief The key for the "photoURL" value in the request.
 */
private let kPhotoURLKey = "photoUrl"

/** @var kProvidersKey
    @brief The key for the "providers" value in the request.
 */
private let kProvidersKey = "provider"

/** @var kOOBCodeKey
    @brief The key for the "OOBCode" value in the request.
 */
private let kOOBCodeKey = "oobCode"

/** @var kEmailVerifiedKey
    @brief The key for the "emailVerified" value in the request.
 */
private let kEmailVerifiedKey = "emailVerified"

/** @var kUpgradeToFederatedLoginKey
    @brief The key for the "upgradeToFederatedLogin" value in the request.
 */
private let kUpgradeToFederatedLoginKey = "upgradeToFederatedLogin"

/** @var kCaptchaChallengeKey
    @brief The key for the "captchaChallenge" value in the request.
 */
private let kCaptchaChallengeKey = "captchaChallenge"

/** @var kCaptchaResponseKey
    @brief The key for the "captchaResponse" value in the request.
 */
private let kCaptchaResponseKey = "captchaResponse"

/** @var kDeleteAttributesKey
    @brief The key for the "deleteAttribute" value in the request.
 */
private let kDeleteAttributesKey = "deleteAttribute"

/** @var kDeleteProvidersKey
    @brief The key for the "deleteProvider" value in the request.
 */
private let kDeleteProvidersKey = "deleteProvider"

/** @var kReturnSecureTokenKey
    @brief The key for the "returnSecureToken" value in the request.
 */
private let kReturnSecureTokenKey = "returnSecureToken"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

/** @class FIRSetAccountInfoRequest
    @brief Represents the parameters for the setAccountInfo endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/setAccountInfo
 */
public class SetAccountInfoRequest: IdentityToolkitRequest, AuthRPCRequest {
  /** @property accessToken
      @brief The STS Access Token of the authenticated user.
   */
  public var accessToken: String?

  /** @property displayName
      @brief The name of the user.
   */
  public var displayName: String?

  /** @property localID
      @brief The local ID of the user.
   */
  public var localID: String?

  /** @property email
      @brief The email of the user.
   */
  public var email: String?

  /** @property photoURL
      @brief The photoURL of the user.
   */
  public var photoURL: URL?

  /** @property password
      @brief The new password of the user.
   */
  public var password: String?

  /** @property providers
      @brief The associated identity providers of the user.
   */
  public var providers: [String]?

  /** @property OOBCode
      @brief The out-of-band code of the change email request.
   */
  public var oobCode: String?

  /** @property emailVerified
      @brief Whether to mark the email as verified or not.
   */
  public var emailVerified: Bool = false

  /** @property upgradeToFederatedLogin
      @brief Whether to mark the user to upgrade to federated login.
   */
  public var upgradeToFederatedLogin: Bool = false

  /** @property captchaChallenge
      @brief The captcha challenge.
   */
  public var captchaChallenge: String?

  /** @property captchaResponse
      @brief Response to the captcha.
   */
  public var captchaResponse: String?

  /** @property deleteAttributes
      @brief The list of user attributes to delete.
      @remarks Every element of the list must be one of the predefined constant starts with
          "FIRSetAccountInfoUserAttribute".
   */
  public var deleteAttributes: [String]?

  /** @property deleteProviders
      @brief The list of identity providers to delete.
   */
  public var deleteProviders: [String]?

  /** @property returnSecureToken
      @brief Whether the response should return access token and refresh token directly.
      @remarks The default value is @c YES .
   */
  public var returnSecureToken: Bool = false

  /** @var response
      @brief The corresponding response for this request
   */
  public var response: SetAccountInfoResponse = .init()

  public init(requestConfiguration: AuthRequestConfiguration) {
    returnSecureToken = true
    super.init(endpoint: kSetAccountInfoEndpoint, requestConfiguration: requestConfiguration)
  }

  public func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var postBody: [String: AnyHashable] = [:]
    if let accessToken {
      postBody[kIDTokenKey] = accessToken
    }
    if let displayName {
      postBody[kDisplayNameKey] = displayName
    }
    if let localID {
      postBody[kLocalIDKey] = localID
    }
    if let email {
      postBody[kEmailKey] = email
    }
    if let password {
      postBody[kPasswordKey] = password
    }
    if let photoURL {
      postBody[kPhotoURLKey] = photoURL.absoluteString
    }
    if let providers {
      postBody[kProvidersKey] = providers
    }
    if let oobCode {
      postBody[kOOBCodeKey] = oobCode
    }
    if emailVerified {
      postBody[kEmailVerifiedKey] = true
    }
    if upgradeToFederatedLogin {
      postBody[kUpgradeToFederatedLoginKey] = true
    }
    if let captchaChallenge {
      postBody[kCaptchaChallengeKey] = captchaChallenge
    }
    if let captchaResponse {
      postBody[kCaptchaResponseKey] = captchaResponse
    }
    if let deleteAttributes {
      postBody[kDeleteAttributesKey] = deleteAttributes
    }
    if let deleteProviders {
      postBody[kDeleteProvidersKey] = deleteProviders
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
