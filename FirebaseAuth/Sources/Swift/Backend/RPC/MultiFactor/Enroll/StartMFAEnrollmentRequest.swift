//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 25/09/2022.
//

import Foundation

private let kStartMFAEnrollmentEndPoint = "accounts/mfaEnrollment:start"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

@objc(FIRStartMFAEnrollmentRequest) public class StartMFAEnrollmentRequest: IdentityToolkitRequest, AuthRPCRequest {
    private(set) var IDToken: String?
    private(set) var enrollmentInfo: AuthProtoStartMFAPhoneRequestInfo?

    init(
        IDToken: String?,
        enrollmentInfo: AuthProtoStartMFAPhoneRequestInfo?,
        requestConfiguration: AuthRequestConfiguration) {
            self.IDToken = IDToken
            self.enrollmentInfo = enrollmentInfo
            super.init(
                endpoint: kStartMFAEnrollmentEndPoint,
                requestConfiguration: requestConfiguration,
                useIdentityPlatform: true,
                useStaging: false)
        }
    public func unencodedHTTPRequestBody() throws -> Any {
        var body: [String: Any] = [:]
        if let IDToken = IDToken {
            body["idToken"] = IDToken
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
