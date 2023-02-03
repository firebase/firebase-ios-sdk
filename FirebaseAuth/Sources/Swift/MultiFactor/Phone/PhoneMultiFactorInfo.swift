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

  @objc(FIRPhoneMultiFactorInfo) public class PhoneMultiFactorInfo: MultiFactorInfo {
    @objc public static let FIRPhoneMultiFactorID = "FIRPhoneMultiFactorID"

    @objc public var phoneNumber: String?
    @objc override public init(proto: AuthProtoMFAEnrollment) {
      super.init(proto: proto)
      factorID = Self.FIRPhoneMultiFactorID
      phoneNumber = proto.phoneInfo
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }

#endif
