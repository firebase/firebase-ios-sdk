//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/09/2022.
//

import Foundation

/** @class FIRDeleteAccountResponse
    @brief Represents the response from the deleteAccount endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/deleteAccount
 */
@objc(FIRDeleteAccountResponse) public class DeleteAccountResponse: NSObject, AuthRPCResponse {
    public func setFields(dictionary: [String: Any]) throws {
    }
}
