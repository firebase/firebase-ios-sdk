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

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class StartMFAEnrollmentRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = StartMFAEnrollmentResponse

  let idToken: String?
  let phoneEnrollmentInfo: AuthProtoStartMFAPhoneRequestInfo?
  let totpEnrollmentInfo: AuthProtoStartMFATOTPEnrollmentRequestInfo?

  convenience init(idToken: String?,
                   enrollmentInfo: AuthProtoStartMFAPhoneRequestInfo?,
                   requestConfiguration: AuthRequestConfiguration) {
    self.init(
      idToken: idToken,
      enrollmentInfo: enrollmentInfo,
      totpEnrollmentInfo: nil,
      requestConfiguration: requestConfiguration
    )
  }

  convenience init(idToken: String?,
                   totpEnrollmentInfo: AuthProtoStartMFATOTPEnrollmentRequestInfo?,
                   requestConfiguration: AuthRequestConfiguration) {
    self.init(
      idToken: idToken,
      enrollmentInfo: nil,
      totpEnrollmentInfo: totpEnrollmentInfo,
      requestConfiguration: requestConfiguration
    )
  }

  private init(idToken: String?,
               enrollmentInfo: AuthProtoStartMFAPhoneRequestInfo?,
               totpEnrollmentInfo: AuthProtoStartMFATOTPEnrollmentRequestInfo?,
               requestConfiguration: AuthRequestConfiguration) {
    self.idToken = idToken
    phoneEnrollmentInfo = enrollmentInfo
    self.totpEnrollmentInfo = totpEnrollmentInfo
    super.init(
      endpoint: kStartMFAEnrollmentEndPoint,
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
    if let phoneEnrollmentInfo {
      body["phoneEnrollmentInfo"] = phoneEnrollmentInfo.dictionary
    } else if let totpEnrollmentInfo {
      body["totpEnrollmentInfo"] = totpEnrollmentInfo.dictionary
    }
    if let tenantID = tenantID {
      body[kTenantIDKey] = tenantID
    }
    return body
  }
}
