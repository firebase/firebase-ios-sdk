//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 17/01/2023.
//

import Foundation

private let kOOBCodeKey = "oobCode"

@objc(FIRGetOOBConfirmationCodeResponse) public class GetOOBConfirmationCodeResponse : NSObject, AuthRPCResponse {
    @objc public var OOBCode: String?

    public func setFields(dictionary: [String: Any]) throws {
        self.OOBCode = dictionary[kOOBCodeKey] as? String
    }
}
