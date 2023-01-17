//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 26/06/2022.
//

import Foundation


/** @protocol FIRAuthRPCRequest
    @brief The generic interface for an RPC request needed by @c FIRAuthBackend.
 */
@objc(FIRAuthRPCRequest) public protocol AuthRPCRequest: NSObjectProtocol {
    /** @fn requestURL
        @brief Gets the request's full URL.
     */

    func requestURL() -> URL

    /** @fn containsPostBody
        @brief Returns whether the request contains a post body or not. Requests without a post body
            are get requests.
        @remarks The default implementation returns YES.
     */
    @objc optional func containsPostBody() -> Bool

    /** @fn UnencodedHTTPRequestBodyWithError:
        @brief Creates unencoded HTTP body representing the request.
        @param error An out field for an error which occurred constructing the request.
        @return The HTTP body data representing the request before any encoding, or nil for error.
     */
    @objc(unencodedHTTPRequestBodyWithError:) func unencodedHTTPRequestBody() throws -> Any

    /** @fn requestConfiguration
        @brief Obtains the request configurations if available.
        @return Returns the request configurations.
     */
    func requestConfiguration() -> AuthRequestConfiguration
}
