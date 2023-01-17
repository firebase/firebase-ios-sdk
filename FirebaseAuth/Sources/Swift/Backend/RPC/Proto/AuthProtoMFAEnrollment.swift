//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 25/09/2022.
//

import Foundation

@objc(FIRAuthProtoMFAEnrollment) public class AuthProtoMFAEnrollment: NSObject, AuthProto {

    @objc public var MFAValue: String?

    @objc public var MFAEnrollmentID: String?

    @objc public var displayName: String?

    @objc public var enrolledAt: Date?

    public var dictionary: [String : Any]

    required public init(dictionary: [String: Any]) {
        self.dictionary = dictionary
        self.MFAValue = dictionary["phoneInfo"] as? String
        self.MFAEnrollmentID = dictionary["mfaEnrollmentId"] as? String
        self.displayName = dictionary["displayName"] as? String
        if let enrolledAt = dictionary["enrolledAt"] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            self.enrolledAt = dateFormatter.date(from: enrolledAt)
        }
    }
}
