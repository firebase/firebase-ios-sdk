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
    @objc override public init(proto: AuthProtoMFAEnrollment) {
      super.init(proto: proto)
      factorID = FIRPhoneMultiFactorID
      phoneNumber = proto.MFAValue
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }

#endif
