//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 28/10/2022.
//

import Foundation

#if os(iOS)

@objc(FIRPhoneMultiFactorInfo) public class PhoneMultiFactorInfo: MultiFactorInfo {
    @objc public var phoneNumber: String?
    @objc public override init(proto: AuthProtoMFAEnrollment) {
        super.init(proto: proto)
        self.factorID = FIRPhoneMultiFactorID
        self.phoneNumber = proto.MFAValue
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif
