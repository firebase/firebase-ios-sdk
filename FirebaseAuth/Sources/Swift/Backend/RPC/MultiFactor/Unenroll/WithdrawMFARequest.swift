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

private let kWithdrawMFAEndPoint = "accounts/mfaEnrollment:withdraw"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

@objc(FIRWithdrawMFARequest) public class WithdrawMFARequest: IdentityToolkitRequest,
  AuthRPCRequest {
  @objc public var IDToken: String?
  @objc public var MFAEnrollmentID: String?

  /** @var response
      @brief The corresponding response for this request
   */
  @objc public var response: AuthRPCResponse = WithdrawMFAResponse()

  @objc public init(IDToken: String?, MFAEnrollmentID: String?,
                    requestConfiguration: AuthRequestConfiguration) {
    self.IDToken = IDToken
    self.MFAEnrollmentID = MFAEnrollmentID
    super.init(endpoint: kWithdrawMFAEndPoint, requestConfiguration: requestConfiguration)
  }

  public func unencodedHTTPRequestBody() throws -> Any {
    var postBody: [String: Any] = [:]
    if let IDToken = IDToken {
      postBody["idToken"] = IDToken
    }
    if let MFAEnrollmentID = MFAEnrollmentID {
      postBody["mfaEnrollmentId"] = MFAEnrollmentID
    }
    if let tenantID = tenantID {
      postBody[kTenantIDKey] = tenantID
    }
    return postBody
  }
}
