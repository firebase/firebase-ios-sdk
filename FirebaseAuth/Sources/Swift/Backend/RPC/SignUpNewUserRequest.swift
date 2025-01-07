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

/// The "SignupNewUserEndpoint" endpoint.
private let kSignupNewUserEndpoint = "signupNewUser"

/// The key for the "email" value in the request.
private let kEmailKey = "email"

/// The key for the "password" value in the request.
private let kPasswordKey = "password"

/// The key for the "kDisplayName" value in the request.
private let kDisplayNameKey = "displayName"

/// The key for the "kIDToken" value in the request.
private let kIDToken = "idToken"

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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class SignUpNewUserRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = SignUpNewUserResponse

  /// The email of the user.
  private(set) var email: String?

  /// The password inputted by the user.
  private(set) var password: String?

  /// The password inputted by the user.
  private(set) var displayName: String?

  /// The idToken of the user.
  private(set) var idToken: String?

  /// Response to the captcha.
  var captchaResponse: String?

  /// The reCAPTCHA version.
  var recaptchaVersion: String?

  /// Whether the response should return access token and refresh token directly.
  /// The default value is `true`.
  var returnSecureToken: Bool = true

  init(requestConfiguration: AuthRequestConfiguration) {
    super.init(endpoint: kSignupNewUserEndpoint, requestConfiguration: requestConfiguration)
  }

  /// Designated initializer.
  /// - Parameter requestConfiguration: An object containing configurations to be added to the
  /// request.
  init(email: String?,
       password: String?,
       displayName: String?,
       idToken: String?,
       requestConfiguration: AuthRequestConfiguration) {
    self.email = email
    self.password = password
    self.displayName = displayName
    self.idToken = idToken
    super.init(endpoint: kSignupNewUserEndpoint, requestConfiguration: requestConfiguration)
  }

  var unencodedHTTPRequestBody: [String: AnyHashable]? {
    var postBody: [String: AnyHashable] = [:]
    if let email {
      postBody[kEmailKey] = email
    }
    if let password {
      postBody[kPasswordKey] = password
    }
    if let displayName {
      postBody[kDisplayNameKey] = displayName
    }
    if let idToken {
      postBody[kIDToken] = idToken
    }
    if let captchaResponse {
      postBody[kCaptchaResponseKey] = captchaResponse
    }
    postBody[kClientType] = clientType
    if let recaptchaVersion {
      postBody[kRecaptchaVersion] = recaptchaVersion
    }
    if returnSecureToken {
      postBody[kReturnSecureTokenKey] = true
    }
    if let tenantID {
      postBody[kTenantIDKey] = tenantID
    }
    return postBody
  }

  func injectRecaptchaFields(recaptchaResponse: String?, recaptchaVersion: String) {
    captchaResponse = recaptchaResponse
    self.recaptchaVersion = recaptchaVersion
  }
}
