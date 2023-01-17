//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 16/01/2023.
//

import Foundation

/** @var kVerifyCustomTokenEndpoint
    @brief The "verifyPassword" endpoint.
 */
private let kVerifyCustomTokenEndpoint = "verifyCustomToken"

/** @var kTokenKey
    @brief The key for the "token" value in the request.
 */
private let kTokenKey = "token"

/** @var kReturnSecureTokenKey
    @brief The key for the "returnSecureToken" value in the request.
 */
private let kReturnSecureTokenKey = "returnSecureToken"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

@objc(FIRVerifyCustomTokenRequest) public class VerifyCustomTokenRequest: IdentityToolkitRequest, AuthRPCRequest {

    @objc public let token: String

    @objc public var returnSecureToken: Bool

    @objc public init(token: String, requestConfiguration: AuthRequestConfiguration) {
        self.token = token
        self.returnSecureToken = true
        super.init(endpoint: kVerifyCustomTokenEndpoint, requestConfiguration: requestConfiguration)
    }

    public func unencodedHTTPRequestBody() throws -> Any {
        var postBody: [String: Any] = [
            kTokenKey: token
        ]
        if returnSecureToken {
            postBody[kReturnSecureTokenKey] = true
        }
        if let tenantID = tenantID {
            postBody[kTenantIDKey] = tenantID
        }
        return postBody
    }
}
