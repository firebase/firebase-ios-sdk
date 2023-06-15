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
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRPhoneAuthCredential) public class PhoneAuthCredential: AuthCredential, NSSecureCoding {
  enum CredentialKind {
    case phoneNumber(_ phoneNumber: String, _ temporaryProof: String)
    case verification(_ id: String, _ code: String)
  }

  let credentialKind: CredentialKind

  init(withTemporaryProof temporaryProof: String, phoneNumber: String,
       providerID: String) {
    credentialKind = .phoneNumber(phoneNumber, temporaryProof)
    super.init(provider: providerID)
  }

  init(withProviderID providerID: String, verificationID: String, verificationCode: String) {
    credentialKind = .verification(verificationID, verificationCode)
    super.init(provider: providerID)
  }

  public static var supportsSecureCoding = true

  public func encode(with coder: NSCoder) {
    switch credentialKind {
    case let .phoneNumber(phoneNumber, temporaryProof):
      coder.encode(phoneNumber, forKey: "phoneNumber")
      coder.encode(temporaryProof, forKey: "temporaryProof")
    case let .verification(id, code):
      coder.encode(id, forKey: "verificationID")
      coder.encode(code, forKey: "verificationCode")
    }
  }

  public required init?(coder: NSCoder) {
    if let verificationID = coder.decodeObject(forKey: "verificationID") as? String,
       let verificationCode = coder.decodeObject(forKey: "verificationCode") as? String {
      credentialKind = .verification(verificationID, verificationCode)
      super.init(provider: PhoneAuthProvider.id)
    } else if let temporaryProof = coder.decodeObject(forKey: "temporaryProof") as? String,
              let phoneNumber = coder.decodeObject(forKey: "phoneNumber") as? String {
      credentialKind = .phoneNumber(phoneNumber, temporaryProof)
      super.init(provider: PhoneAuthProvider.id)
    } else {
      return nil
    }
  }
}
