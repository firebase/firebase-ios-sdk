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

/// The "resetPassword" endpoint.
private let kResetPasswordEndpoint = "resetPassword"

/// The "resetPassword" key.
private let kOOBCodeKey = "oobCode"

/// The "newPassword" key.
private let kCurrentPasswordKey = "newPassword"

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class ResetPasswordRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = ResetPasswordResponse

  /// The oobCode sent in the request.
  let oobCode: String

  /// The new password sent in the request.
  let updatedPassword: String?

  /// Designated initializer.
  /// - Parameter oobCode: The OOB Code.
  /// - Parameter newPassword: The new password.
  /// - Parameter requestConfiguration: An object containing configurations to be added to the
  /// request.
  init(oobCode: String, newPassword: String?,
       requestConfiguration: AuthRequestConfiguration) {
    self.oobCode = oobCode
    updatedPassword = newPassword
    super.init(endpoint: kResetPasswordEndpoint, requestConfiguration: requestConfiguration)
  }

  var unencodedHTTPRequestBody: [String: AnyHashable]? {
    var postBody: [String: AnyHashable] = [:]

    postBody[kOOBCodeKey] = oobCode
    if let updatedPassword {
      postBody[kCurrentPasswordKey] = updatedPassword
    }
    if let tenantID {
      postBody[kTenantIDKey] = tenantID
    }
    return postBody
  }
}
