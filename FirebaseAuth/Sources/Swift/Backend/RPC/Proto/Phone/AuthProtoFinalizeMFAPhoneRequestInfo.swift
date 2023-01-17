//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 25/09/2022.
//

import Foundation

@objc(FIRAuthProtoFinalizeMFAPhoneRequestInfo) public class AuthProtoFinalizeMFAPhoneRequestInfo: NSObject, AuthProto {
    public required init(dictionary: [String : Any]) {
        fatalError()
    }

    var sessionInfo: String?
    var code: String?
    @objc public init(sessionInfo: String?, verificationCode: String?) {
        self.sessionInfo = sessionInfo
        self.code = verificationCode
    }
    public var dictionary: [String: Any] {
        var dict: [String: Any] = [:]
        if let sessionInfo = sessionInfo {
            dict["sessionInfo"] = sessionInfo
        }
        if let code = code {
            dict["code"] = code
        }
        return dict
    }
}
