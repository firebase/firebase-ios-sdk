//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/06/2022.
//

import Foundation

/** @var kGetAccountInfoEndpoint
    @brief The "getAccountInfo" endpoint.
 */
private let kGetAccountInfoEndpoint = "getAccountInfo"

/** @var kIDTokenKey
    @brief The key for the "idToken" value in the request. This is actually the STS Access Token,
        despite it's confusing (backwards compatiable) parameter name.
 */
private let kIDTokenKey = "idToken"

/** @class FIRGetAccountInfoRequest
    @brief Represents the parameters for the getAccountInfo endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/getAccountInfo
 */
@objc(FIRGetAccountInfoRequest) public class GetAccountInfoRequest: IdentityToolkitRequest, AuthRPCRequest {

    /** @property accessToken
        @brief The STS Access Token for the authenticated user.
     */
    let accessToken: String

    /** @fn initWithEndpoint:requestConfiguration:requestConfiguration
        @brief Please use initWithAccessToken:requestConfiguration: instead.
     */
    override init(endpoint: String, requestConfiguration: AuthRequestConfiguration) {
        fatalError("-")
    }

    /** @fn initWithAccessToken:requestConfiguration
        @brief Designated initializer.
        @param accessToken The Access Token of the authenticated user.
        @param requestConfiguration An object containing configurations to be added to the request.
     */
    @objc public init(accessToken: String, requestConfiguration: AuthRequestConfiguration) {
        self.accessToken = accessToken
        super.init(endpoint: kGetAccountInfoEndpoint, requestConfiguration: requestConfiguration)
    }

    public func unencodedHTTPRequestBody() throws -> Any {
        return [kIDTokenKey: accessToken]
    }
}
