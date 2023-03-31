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

/** @class PhoneAuthCredential
    @brief Implementation of FIRAuthCredential for Phone Auth credentials.
        This class is available on iOS only.
 */
@objc(FIRPhoneAuthCredential) public class PhoneAuthCredential: AuthCredential, NSSecureCoding {
  // TODO: delete objc's and public's below
  @objc public let temporaryProof: String?
  @objc public let phoneNumber: String?
  @objc public let verificationID: String?
  @objc public let verificationCode: String?

  // TODO: Remove public objc
  @objc public init(withTemporaryProof temporaryProof: String, phoneNumber: String,
                    providerID: String) {
    self.temporaryProof = temporaryProof
    self.phoneNumber = phoneNumber
    verificationID = nil
    verificationCode = nil
    super.init(provider: providerID)
  }

  init(withProviderID providerID: String, verificationID: String, verificationCode: String) {
    self.verificationID = verificationID
    self.verificationCode = verificationCode
    temporaryProof = nil
    phoneNumber = nil
    super.init(provider: providerID)
  }

  public static var supportsSecureCoding = true

  public func encode(with coder: NSCoder) {
    coder.encode(verificationID)
    coder.encode(verificationCode)
    coder.encode(temporaryProof)
    coder.encode(phoneNumber)
  }

  public required init?(coder: NSCoder) {
    let verificationID = coder.decodeObject(forKey: "verificationID") as? String
    let verificationCode = coder.decodeObject(forKey: "verificationCode") as? String
    let temporaryProof = coder.decodeObject(forKey: "temporaryProof") as? String
    let phoneNumber = coder.decodeObject(forKey: "phoneNumber") as? String
    if let temporaryProof = temporaryProof,
       let phoneNumber = phoneNumber {
      self.temporaryProof = temporaryProof
      self.phoneNumber = phoneNumber
      self.verificationID = nil
      self.verificationCode = nil
      super.init(provider: PhoneAuthProvider.id)
    } else if let verificationID = verificationID,
              let verificationCode = verificationCode {
      self.verificationID = verificationID
      self.verificationCode = verificationCode
      self.temporaryProof = nil
      self.phoneNumber = nil
      super.init(provider: PhoneAuthProvider.id)
    } else {
      return nil
    }
  }
}
