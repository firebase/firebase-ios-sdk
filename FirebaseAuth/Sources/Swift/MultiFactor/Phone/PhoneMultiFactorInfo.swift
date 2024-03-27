// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

#if os(iOS)

  /// Extends the MultiFactorInfo class for phone number second factors.
  ///
  /// The identifier of this second factor is "phone".
  ///
  /// This class is available on iOS only.
  @objc(FIRPhoneMultiFactorInfo) open class PhoneMultiFactorInfo: MultiFactorInfo {
    /// The string identifier for using phone as a second factor.
    @objc(FIRPhoneMultiFactorID) public static let PhoneMultiFactorID = "phone"

    /// The string identifier for using TOTP as a second factor.
    @objc(FIRTOTPMultiFactorID) public static let TOTPMultiFactorID = "totp"

    /// This is the phone number associated with the current second factor.
    @objc open var phoneNumber: String

    init(proto: AuthProtoMFAEnrollment) {
      guard let phoneInfo = proto.phoneInfo else {
        fatalError("Internal Auth Error: Missing phone number in Multi Factor Enrollment")
      }
      phoneNumber = phoneInfo
      super.init(proto: proto, factorID: Self.PhoneMultiFactorID)
    }

    // MARK: NSSecureCoding

    private let kPhoneNumberCodingKey = "phoneNumber"

    override public class var supportsSecureCoding: Bool { return true }

    public required init?(coder: NSCoder) {
      guard let phoneNumber = coder.decodeObject(of: NSString.self,
                                                 forKey: kPhoneNumberCodingKey) else {
        return nil
      }
      self.phoneNumber = phoneNumber as String
      super.init(coder: coder)
    }

    override public func encode(with coder: NSCoder) {
      super.encode(with: coder)
      coder.encode(phoneNumber, forKey: kPhoneNumberCodingKey)
    }
  }

#endif
