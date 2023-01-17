//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 26/09/2022.
//

import Foundation

@objc(FIRStartMFASignInResponse) public class StartMFASignInResponse: NSObject, AuthRPCResponse {
    var responseInfo: AuthProtoStartMFAPhoneResponseInfo?

    public func setFields(dictionary: [String : Any]) throws {
        if let data = dictionary["phoneResponseInfo"] as? [String: Any] {
            self.responseInfo = AuthProtoStartMFAPhoneResponseInfo(dictionary: data)
        } else {
            fatalError() // XXX TODO: throw something. original code does not strictly follow
            // obj-c error conventions. returning 'false' should be accompanied by an error, but
            // in the code there was none. importing this into swift would throw a built-in 'error missing' error
//            throw xxx
        }
    }
}
