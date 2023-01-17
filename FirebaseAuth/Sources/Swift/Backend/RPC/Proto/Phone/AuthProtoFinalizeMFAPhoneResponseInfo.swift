//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 25/09/2022.
//

import Foundation

public class AuthProtoFinalizeMFAPhoneResponseInfo: NSObject, AuthProto {
    var phoneNumber: String?

    required public init(dictionary: [String: Any]) {
        self.phoneNumber = dictionary["phoneNumber"] as? String
    }
}
