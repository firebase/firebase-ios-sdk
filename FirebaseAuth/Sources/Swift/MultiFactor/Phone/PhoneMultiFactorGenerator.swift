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

  /// The data structure used to help initialize an assertion for a second factor entity to the
  /// Firebase Auth/CICP server.
  ///
  /// Depending on the type of second factor, this will help generate the assertion.
  ///
  ///  This class is available on iOS and macOS.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @objc(FIRPhoneMultiFactorGenerator)
  open class PhoneMultiFactorGenerator: NSObject {
    /// Initializes the MFA assertion to confirm ownership of the phone second factor.
    ///
    /// Note that this API is used for both enrolling and signing in with a phone second factor.
    /// - Parameter phoneAuthCredential: The phone auth credential used for multi factor flows.
    @objc(assertionWithCredential:)
    open class func assertion(with phoneAuthCredential: PhoneAuthCredential)
      -> PhoneMultiFactorAssertion {
      let assertion = PhoneMultiFactorAssertion()
      assertion.authCredential = phoneAuthCredential
      return assertion
    }
  }
#endif
