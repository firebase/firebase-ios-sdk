//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/06/2022.
//

import Foundation

/** @var kCreateAuthURIEndpoint
    @brief The "deleteAccount" endpoint.
 */
private let kDeleteAccountEndpoint = "deleteAccount"

/** @var kIDTokenKey
    @brief The key for the "idToken" value in the request. This is actually the STS Access Token,
        despite it's confusing (backwards compatiable) parameter name.
 */
private let kIDTokenKey = "idToken"

/** @var kLocalIDKey
    @brief The key for the "localID" value in the request.
 */
private let kLocalIDKey = "localId"

@objc(FIRDeleteAccountRequest) public class DeleteAccountRequest: IdentityToolkitRequest, AuthRPCRequest {

    /** @var _accessToken
        @brief The STS Access Token of the authenticated user.
     */
    @objc public let accessToken: String

    /** @var _localID
        @brief The localID of the user.
     */
    @objc public let localID: String

    @objc(initWithLocalID:accessToken:requestConfiguration:) public init(localID: String, accessToken: String, requestConfiguration: AuthRequestConfiguration) {
        self.localID = localID
        self.accessToken = accessToken
        super.init(endpoint: kDeleteAccountEndpoint, requestConfiguration: requestConfiguration)
    }

    public func unencodedHTTPRequestBody() throws -> Any {
        [
            kIDTokenKey: accessToken,
            kLocalIDKey: localID
        ]
    }
}
