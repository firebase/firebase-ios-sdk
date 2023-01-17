//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 26/09/2022.
//

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
