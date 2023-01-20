//
//  File.swift
//
//
//  Created by Morten Bek Ditlevsen on 28/10/2022.
//

import Foundation

#if os(iOS)

  @objc(FIRPhoneMultiFactorAssertion) public class PhoneMultiFactorAssertion: MultiFactorAssertion {
    @objc public var authCredential: PhoneAuthCredential?

    @objc public init() {
      super.init(factorID: FIRPhoneMultiFactorID)
    }
  }

#endif
