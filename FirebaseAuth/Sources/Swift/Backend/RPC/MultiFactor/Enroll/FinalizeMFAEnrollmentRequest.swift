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

private let kFinalizeMFAEnrollmentEndPoint = "accounts/mfaEnrollment:finalize"

/** @var kTenantIDKey
 @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

class FinalizeMFAEnrollmentRequest: IdentityToolkitRequest, AuthRPCRequest {
  var idToken: String?

  var displayName: String?

  var verificationInfo: AuthProtoFinalizeMFAPhoneRequestInfo?

  /** @var response
      @brief The corresponding response for this request
   */
  var response: FinalizeMFAEnrollmentResponse = FinalizeMFAEnrollmentResponse()

  init(idToken: String?, displayName: String?,
                    verificationInfo: AuthProtoFinalizeMFAPhoneRequestInfo?,
                    requestConfiguration: AuthRequestConfiguration) {
    self.idToken = idToken
    self.displayName = displayName
    self.verificationInfo = verificationInfo
    super.init(
      endpoint: kFinalizeMFAEnrollmentEndPoint,
      requestConfiguration: requestConfiguration,
      useIdentityPlatform: true,
      useStaging: false
    )
  }

  public func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var body: [String: AnyHashable] = [:]
    if let idToken = idToken {
      body["idToken"] = idToken
    }
    if let displayName = displayName {
      body["displayName"] = displayName
      if let verificationInfo = verificationInfo {
        body["phoneVerificationInfo"] = verificationInfo.dictionary
      }
    }

    if let tenantID = tenantID {
      body[kTenantIDKey] = tenantID
    }
    return body
  }
}
