//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 26/09/2022.
//

import Foundation

private let kStartMFASignInEndPoint = "accounts/mfaSignIn:start"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

@objc(FIRStartMFASignInRequest) public class StartMFASignInRequest: IdentityToolkitRequest, AuthRPCRequest {
    var MFAPendingCredential: String?
    var MFAEnrollmentID: String?
    var signInInfo: AuthProtoStartMFAPhoneRequestInfo?
    init(MFAPendingCredential: String?, MFAEnrollmentID: String?, signInInfo: AuthProtoStartMFAPhoneRequestInfo?, requestConfiguration: AuthRequestConfiguration) {

        self.MFAPendingCredential = MFAPendingCredential
        self.MFAEnrollmentID = MFAEnrollmentID
        self.signInInfo = signInInfo
        super.init(endpoint: kStartMFASignInEndPoint, requestConfiguration: requestConfiguration, useIdentityPlatform: true, useStaging: false)
    }

    public func unencodedHTTPRequestBody() throws -> Any {
        var body: [String: Any] = [:]
        if let MFAPendingCredential = MFAPendingCredential {
            body["mfaPendingCredential"] = MFAPendingCredential
        }
        if let MFAEnrollmentID = MFAEnrollmentID {
            body["mfaEnrollmentId"] = MFAEnrollmentID
        }
        if let signInInfo = signInInfo {
            body["phoneSignInInfo"] = signInInfo.dictionary
        }
        if let tenantID = tenantID {
            body[kTenantIDKey] = tenantID
        }
        return body
    }
}
