//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 25/09/2022.
//

import Foundation

private let kFinalizeMFAEnrollmentEndPoint = "accounts/mfaEnrollment:finalize"

/** @var kTenantIDKey
 @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"


@objc(FIRFinalizeMFAEnrollmentRequest) public class FinalizeMFAEnrollmentRequest: IdentityToolkitRequest, AuthRPCRequest {
    @objc public var IDToken: String?

    @objc public var displayName: String?

    @objc public var verificationInfo: AuthProtoFinalizeMFAPhoneRequestInfo?

    @objc public init(IDToken: String?, displayName: String?,
         verificationInfo: AuthProtoFinalizeMFAPhoneRequestInfo?,
         requestConfiguration: AuthRequestConfiguration) {
        self.IDToken = IDToken
        self.displayName = displayName
        self.verificationInfo = verificationInfo
        super.init(endpoint: kFinalizeMFAEnrollmentEndPoint, requestConfiguration: requestConfiguration, useIdentityPlatform: true, useStaging: false)
    }

    public func unencodedHTTPRequestBody() throws -> Any {
        var body: [String: Any] = [:]
        if let IDToken = IDToken {
            body["idToken"] = IDToken
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
