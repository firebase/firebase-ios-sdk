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

/// The "verifyPassword" endpoint.
private let kVerifyPasswordEndpoint = "verifyPassword"

/// The key for the "email" value in the request.
private let kEmailKey = "email"

/// The key for the "password" value in the request.
private let kPasswordKey = "password"

/// The key for the "pendingIdToken" value in the request.
private let kPendingIDTokenKey = "pendingIdToken"

/// The key for the "captchaChallenge" value in the request.
private let kCaptchaChallengeKey = "captchaChallenge"

/// The key for the "captchaResponse" value in the request.
private let kCaptchaResponseKey = "captchaResponse"

/// The key for the "clientType" value in the request.
private let kClientType = "clientType"

/// The key for the "recaptchaVersion" value in the request.
private let kRecaptchaVersion = "recaptchaVersion"

/// The key for the "returnSecureToken" value in the request.
private let kReturnSecureTokenKey = "returnSecureToken"

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

/// Represents the parameters for the verifyPassword endpoint.
/// See https: // developers.google.com/identity/toolkit/web/reference/relyingparty/verifyPassword
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class VerifyPasswordRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = VerifyPasswordResponse

  /// The email of the user.
  private(set) var email: String

  /// The password inputted by the user.
  private(set) var password: String

  /// The GITKit token for the non-trusted IDP, which is to be confirmed by the user.
  var pendingIDToken: String?

  /// The captcha challenge.
  var captchaChallenge: String?

  /// Response to the captcha.
  var captchaResponse: String?

  /// The reCAPTCHA version.
  var recaptchaVersion: String?

  /// Whether the response should return access token and refresh token directly.
  /// The default value is `true`.
  private(set) var returnSecureToken: Bool = true

  init(email: String, password: String,
       requestConfiguration: AuthRequestConfiguration) {
    self.email = email
    self.password = password
    super.init(endpoint: kVerifyPasswordEndpoint, requestConfiguration: requestConfiguration)
  }

  var unencodedHTTPRequestBody: [String: AnyHashable]? {
    var body: [String: AnyHashable] = [
      kEmailKey: email,
      kPasswordKey: password,
    ]
    if let pendingIDToken {
      body[kPendingIDTokenKey] = pendingIDToken
    }
    if let captchaChallenge {
      body[kCaptchaChallengeKey] = captchaChallenge
    }
    if let captchaResponse {
      body[kCaptchaResponseKey] = captchaResponse
    }
    if let recaptchaVersion {
      body[kRecaptchaVersion] = recaptchaVersion
    }
    if returnSecureToken {
      body[kReturnSecureTokenKey] = true
    }
    if let tenantID {
      body[kTenantIDKey] = tenantID
    }
    body[kClientType] = clientType
    return body
  }

  func injectRecaptchaFields(recaptchaResponse: String?, recaptchaVersion: String) {
    captchaResponse = recaptchaResponse
    self.recaptchaVersion = recaptchaVersion
  }
}
