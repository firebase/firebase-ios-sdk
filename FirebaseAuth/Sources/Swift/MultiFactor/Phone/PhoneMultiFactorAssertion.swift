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

#if os(iOS) || os(macOS)

  /// The subclass of base class FIRMultiFactorAssertion, used to assert ownership of a phone
  /// second factor.
  ///
  /// This class is available on iOS and macOS.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @objc(FIRPhoneMultiFactorAssertion) open class PhoneMultiFactorAssertion: MultiFactorAssertion {
    var authCredential: PhoneAuthCredential?

    init() {
      super.init(factorID: PhoneMultiFactorInfo.PhoneMultiFactorID)
    }
  }

#endif
