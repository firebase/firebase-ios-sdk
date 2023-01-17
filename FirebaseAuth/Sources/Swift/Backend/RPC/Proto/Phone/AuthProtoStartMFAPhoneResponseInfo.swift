//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 25/09/2022.
//

import Foundation

class AuthProtoStartMFAPhoneResponseInfo: NSObject, AuthProto {
    var sessionInfo: String?

    required init(dictionary: [String: Any]) {
        self.sessionInfo = dictionary["sessionInfo"] as? String
    }
}
