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

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

@objc(FIRFinalizeMFASignInRequest) public class FinalizeMFASignInRequest: IdentityToolkitRequest, AuthRPCRequest {
    var MFAPendingCredential: String?
    var verificationInfo: AuthProtoFinalizeMFAPhoneRequestInfo?

    @objc public init(MFAPendingCredential: String?, verificationInfo: AuthProtoFinalizeMFAPhoneRequestInfo?, requestConfiguration: AuthRequestConfiguration) {
        self.MFAPendingCredential = MFAPendingCredential
        self.verificationInfo = verificationInfo
        super.init(endpoint: kFinalizeMFASignInEndPoint,
                   requestConfiguration: requestConfiguration,
                   useIdentityPlatform: true,
                   useStaging: false)
    }

    public func unencodedHTTPRequestBody() throws -> Any {
        var body: [String: Any] = [:]
        if let MFAPendingCredential = MFAPendingCredential {
            body["mfaPendingCredential"] = MFAPendingCredential
        }
        if let verificationInfo = verificationInfo {
            body["phoneVerificationInfo"] = verificationInfo.dictionary
        }
        if let tenantID = tenantID {
            body[kTenantIDKey] = tenantID
        }
        return body
    }
}
