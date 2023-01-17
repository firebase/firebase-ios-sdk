//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 16/01/2023.
//

import Foundation

@objc(FIRSendVerificationCodeResponse) public class SendVerificationCodeResponse: NSObject, AuthRPCResponse {

    @objc public var verificationID: String?

    @objc public func setFields(dictionary: [String: Any]) throws {
        self.verificationID = dictionary["sessionInfo"] as? String
    }
}
