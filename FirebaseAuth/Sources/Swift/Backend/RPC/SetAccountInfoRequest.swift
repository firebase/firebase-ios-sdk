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

/// The "setAccountInfo" endpoint.
private let kSetAccountInfoEndpoint = "setAccountInfo"

/// The key for the "idToken" value in the request. This is actually the STS Access Token,
/// despite its confusing (backwards compatible) parameter name.
private let kIDTokenKey = "idToken"

/// The key for the "displayName" value in the request.
private let kDisplayNameKey = "displayName"

/// The key for the "localID" value in the request.
private let kLocalIDKey = "localId"

/// The key for the "email" value in the request.
private let kEmailKey = "email"

/// The key for the "password" value in the request.
private let kPasswordKey = "password"

/// The key for the "photoURL" value in the request.
private let kPhotoURLKey = "photoUrl"

/// The key for the "providers" value in the request.
private let kProvidersKey = "provider"

/// The key for the "OOBCode" value in the request.
private let kOOBCodeKey = "oobCode"

/// The key for the "emailVerified" value in the request.
private let kEmailVerifiedKey = "emailVerified"

/// The key for the "upgradeToFederatedLogin" value in the request.
private let kUpgradeToFederatedLoginKey = "upgradeToFederatedLogin"

/// The key for the "captchaChallenge" value in the request.
private let kCaptchaChallengeKey = "captchaChallenge"

/// The key for the "captchaResponse" value in the request.
private let kCaptchaResponseKey = "captchaResponse"

/// The key for the "deleteAttribute" value in the request.
private let kDeleteAttributesKey = "deleteAttribute"

/// The key for the "deleteProvider" value in the request.
private let kDeleteProvidersKey = "deleteProvider"

/// The key for the "returnSecureToken" value in the request.
private let kReturnSecureTokenKey = "returnSecureToken"

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

/// Represents the parameters for the setAccountInfo endpoint.
/// See https://developers.google.com/identity/toolkit/web/reference/relyingparty/setAccountInfo
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class SetAccountInfoRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = SetAccountInfoResponse

  /// The STS Access Token of the authenticated user.
  var accessToken: String?

  /// The name of the user.
  var displayName: String?

  /// The local ID of the user.
  var localID: String? = nil

  /// The email of the user.
  var email: String? = nil

  /// The photoURL of the user.
  var photoURL: URL?

  /// The new password of the user.
  var password: String? = nil

  /// The associated identity providers of the user.
  var providers: [String]? = nil

  /// The out-of-band code of the change email request.
  var oobCode: String?

  /// Whether to mark the email as verified or not.
  var emailVerified: Bool = false

  /// Whether to mark the user to upgrade to federated login.
  var upgradeToFederatedLogin: Bool = false

  /// The captcha challenge.
  var captchaChallenge: String? = nil

  /// Response to the captcha.
  var captchaResponse: String? = nil

  /// The list of user attributes to delete.
  ///
  /// Every element of the list must be one of the predefined constant starts with
  /// `SetAccountInfoUserAttribute`.
  var deleteAttributes: [String]? = nil

  /// The list of identity providers to delete.
  var deleteProviders: [String]?

  /// Whether the response should return access token and refresh token directly.
  /// The default value is `true` .
  var returnSecureToken: Bool = true

  init(accessToken: String? = nil, requestConfiguration: AuthRequestConfiguration) {
    self.accessToken = accessToken
    super.init(endpoint: kSetAccountInfoEndpoint, requestConfiguration: requestConfiguration)
  }

  var unencodedHTTPRequestBody: [String: AnyHashable]? {
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
