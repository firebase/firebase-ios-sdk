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

private let kFinalizeMFASignInEndPoint = "accounts/mfaSignIn:finalize"

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class FinalizeMFASignInRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = FinalizeMFAEnrollmentResponse

  let mfaPendingCredential: String?
  let verificationInfo: AuthProto?

  init(mfaPendingCredential: String?,
       verificationInfo: AuthProto?,
       requestConfiguration: AuthRequestConfiguration) {
    self.mfaPendingCredential = mfaPendingCredential
    self.verificationInfo = verificationInfo
    super.init(endpoint: kFinalizeMFASignInEndPoint,
               requestConfiguration: requestConfiguration,
               useIdentityPlatform: true)
  }

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var body: [String: AnyHashable] = [:]
    if let mfaPendingCredential = mfaPendingCredential {
      body["mfaPendingCredential"] = mfaPendingCredential
    }
    if let verificationInfo = verificationInfo as? AuthProtoFinalizeMFAPhoneRequestInfo {
      body["phoneVerificationInfo"] = verificationInfo.dictionary
    }
    if let verificationInfo = verificationInfo as? AuthProtoFinalizeMFATOTPSignInRequestInfo {
      body["totpVerificationInfo"] = verificationInfo.dictionary
      // mfaEnrollmentID only required for TOTP
      body["mfaEnrollmentId"] = verificationInfo.mfaEnrollmentID
    }
    if let tenantID = tenantID {
      body[kTenantIDKey] = tenantID
    }
    return body
  }
}
