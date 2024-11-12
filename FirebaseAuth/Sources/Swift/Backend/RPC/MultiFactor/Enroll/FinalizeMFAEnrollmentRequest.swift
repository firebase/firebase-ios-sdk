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

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class FinalizeMFAEnrollmentRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = FinalizeMFAEnrollmentResponse

  let idToken: String?

  let displayName: String?

  let phoneVerificationInfo: AuthProtoFinalizeMFAPhoneRequestInfo?

  let totpVerificationInfo: AuthProtoFinalizeMFATOTPEnrollmentRequestInfo?

  convenience init(idToken: String?, displayName: String?,
                   phoneVerificationInfo: AuthProtoFinalizeMFAPhoneRequestInfo?,
                   requestConfiguration: AuthRequestConfiguration) {
    self.init(
      idToken: idToken,
      displayName: displayName,
      phoneVerificationInfo: phoneVerificationInfo,
      totpVerificationInfo: nil,
      requestConfiguration: requestConfiguration
    )
  }

  convenience init(idToken: String?, displayName: String?,
                   totpVerificationInfo: AuthProtoFinalizeMFATOTPEnrollmentRequestInfo?,
                   requestConfiguration: AuthRequestConfiguration) {
    self.init(
      idToken: idToken,
      displayName: displayName,
      phoneVerificationInfo: nil,
      totpVerificationInfo: totpVerificationInfo,
      requestConfiguration: requestConfiguration
    )
  }

  private init(idToken: String?, displayName: String?,
               phoneVerificationInfo: AuthProtoFinalizeMFAPhoneRequestInfo?,
               totpVerificationInfo: AuthProtoFinalizeMFATOTPEnrollmentRequestInfo?,
               requestConfiguration: AuthRequestConfiguration) {
    self.idToken = idToken
    self.displayName = displayName
    self.phoneVerificationInfo = phoneVerificationInfo
    self.totpVerificationInfo = totpVerificationInfo
    super.init(
      endpoint: kFinalizeMFAEnrollmentEndPoint,
      requestConfiguration: requestConfiguration,
      useIdentityPlatform: true,
      useStaging: false
    )
  }

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var body: [String: AnyHashable] = [:]
    if let idToken = idToken {
      body["idToken"] = idToken
    }
    if let displayName = displayName {
      body["displayName"] = displayName
    }
    if let phoneVerificationInfo {
      body["phoneVerificationInfo"] = phoneVerificationInfo.dictionary
    } else if let totpVerificationInfo {
      body["totpVerificationInfo"] = totpVerificationInfo.dictionary
    }

    if let tenantID = tenantID {
      body[kTenantIDKey] = tenantID
    }
    return body
  }
}
