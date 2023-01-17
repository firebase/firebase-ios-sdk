//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 26/09/2022.
//

import Foundation

@objc(FIRFinalizeMFASignInResponse) public class FinalizeMFASignInResponse: NSObject, AuthRPCResponse {
    @objc public var IDToken: String?
    @objc public var refreshToken: String?

    public func setFields(dictionary: [String : Any]) throws {
        self.IDToken = dictionary["idToken"] as? String
        self.refreshToken = dictionary["refreshToken"] as? String
    }
}
