//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 25/09/2022.
//

import Foundation

/** @protocol FIRAuthRPCResponse
    @brief The generic interface for an RPC response needed by @c FIRAuthBackend.
 */
@objc(FIRAuthRPCResponse) public protocol AuthRPCResponse: NSObjectProtocol {
    /** @fn setFieldsWithDictionary:error:
        @brief Sets the response instance from the decoded JSON response.
        @param dictionary The dictionary decoded from HTTP JSON response.
        @param error An out field for an error which occurred constructing the request.
        @return Whether the operation was successful or not.
     */
    @objc(setWithDictionary:error:) func setFields(dictionary: [String: Any]) throws

    /** @fn clientErrorWithshortErrorMessage:detailErrorMessage
        @brief This optional method allows response classes to create client errors given a short error
            message and a detail error message from the server.
        @param shortErrorMessage The short error message from the server.
        @param detailErrorMessage The detailed error message from the server.
        @return A client error, if any.
     */

    @objc optional func clientError(shortErrorMessage: String, detailErrorMessage: String?) -> Error?
}

//extension AuthRPCResponse {
//    func clientError(shortErrorMessage: String, detailErrorMessage: String?) -> Error? {
//        nil
//    }
//}
