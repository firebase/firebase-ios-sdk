//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 25/09/2022.
//

import Foundation

private let kWithdrawMFAEndPoint = "accounts/mfaEnrollment:withdraw"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"


@objc(FIRWithdrawMFARequest) public class WithdrawMFARequest: IdentityToolkitRequest, AuthRPCRequest {
    @objc public var IDToken: String?
    @objc public var MFAEnrollmentID: String?
    @objc public init(IDToken: String?, MFAEnrollmentID: String?, requestConfiguration: AuthRequestConfiguration) {
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
