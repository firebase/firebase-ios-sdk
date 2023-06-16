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

class SignUpNewUserRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = SignUpNewUserResponse

  /** @property email
      @brief The email of the user.
   */
  var email: String?

  /** @property password
      @brief The password inputed by the user.
   */
  var password: String?

  /** @property displayName
      @brief The password inputed by the user.
   */
  var displayName: String?

  /** @property returnSecureToken
      @brief Whether the response should return access token and refresh token directly.
      @remarks The default value is @c YES .
   */
  var returnSecureToken: Bool = true

  init(requestConfiguration: AuthRequestConfiguration) {
    super.init(endpoint: kSignupNewUserEndpoint, requestConfiguration: requestConfiguration)
  }

  /** @fn initWithAPIKey:email:password:displayName:requestConfiguration
      @brief Designated initializer.
      @param requestConfiguration An object containing configurations to be added to the request.
   */
  init(email: String?,
              password: String?,
              displayName: String?,
              requestConfiguration: AuthRequestConfiguration) {
    self.email = email
    self.password = password
    self.displayName = displayName
    super.init(endpoint: kSignupNewUserEndpoint, requestConfiguration: requestConfiguration)
  }

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
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
    if returnSecureToken {
      postBody[kReturnSecureTokenKey] = true
    }
    if let tenantID {
      postBody[kTenantIDKey] = tenantID
    }
    return postBody
  }
}
