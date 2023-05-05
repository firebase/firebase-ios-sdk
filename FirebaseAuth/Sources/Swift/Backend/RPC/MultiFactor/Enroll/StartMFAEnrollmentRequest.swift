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

private let kStartMFAEnrollmentEndPoint = "accounts/mfaEnrollment:start"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

public class StartMFAEnrollmentRequest: IdentityToolkitRequest, AuthRPCRequest_NEW_ {
  private(set) var idToken: String?
  private(set) var enrollmentInfo: AuthProtoStartMFAPhoneRequestInfo?

  /** @var response
      @brief The corresponding response for this request
   */
  public var response: StartMFAEnrollmentResponse = StartMFAEnrollmentResponse()

  init(idToken: String?,
       enrollmentInfo: AuthProtoStartMFAPhoneRequestInfo?,
       requestConfiguration: AuthRequestConfiguration) {
    self.idToken = idToken
    self.enrollmentInfo = enrollmentInfo
    super.init(
      endpoint: kStartMFAEnrollmentEndPoint,
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
    if let enrollmentInfo = enrollmentInfo {
      body["phoneEnrollmentInfo"] = enrollmentInfo.dictionary
    }
    if let tenantID = tenantID {
      body[kTenantIDKey] = tenantID
    }
    return body
  }
}
