//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 25/09/2022.
//

import Foundation

@objc(FIRStartMFAEnrollmentResponse) public class StartMFAEnrollmentResponse: NSObject, AuthRPCResponse {
    public func setFields(dictionary: [String : Any]) throws {
        if let data = dictionary["phoneSessionInfo"] as? [String: Any] {
            enrollmentResponse = AuthProtoStartMFAPhoneResponseInfo(dictionary: data)
        } else {
            fatalError() // XXX TODO: throw something. original code does not strictly follow
            // obj-c error conventions. returning 'false' should be accompanied by an error, but
            // in the code there was none. importing this into swift would throw a built-in 'error missing' error
//            throw xxx
        }
    }

    var enrollmentResponse: AuthProtoStartMFAPhoneResponseInfo?
}
