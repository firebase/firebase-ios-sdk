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

/** @var kPhoneNumberKey
 @brief The key for the Phone Number parameter in the request.
 */
private let kPhoneNumberKey = "phoneNumber"

/** @var kReceiptKey
 @brief The key for the receipt parameter in the request.
 */
private let kReceiptKey = "iosReceipt"

/** @var kSecretKey
 @brief The key for the Secret parameter in the request.
 */
private let kSecretKey = "iosSecret"

/** @var kreCAPTCHATokenKey
 @brief The key for the reCAPTCHAToken parameter in the request.
 */
private let kreCAPTCHATokenKey = "recaptchaToken"

class AuthProtoStartMFAPhoneRequestInfo: NSObject, AuthProto {
  required init(dictionary: [String: AnyHashable]) {
    fatalError()
  }

  var phoneNumber: String?
  var appCredential: AuthAppCredential?
  var reCAPTCHAToken: String?
  init(phoneNumber: String?, appCredential: AuthAppCredential?, reCAPTCHAToken: String?) {
    self.phoneNumber = phoneNumber
    self.appCredential = appCredential
    self.reCAPTCHAToken = reCAPTCHAToken
  }

  var dictionary: [String: AnyHashable] {
    var dict: [String: AnyHashable] = [:]
    if let phoneNumber = phoneNumber {
      dict[kPhoneNumberKey] = phoneNumber
    }
    if let receipt = appCredential?.receipt {
      dict[kReceiptKey] = receipt
    }
    if let secret = appCredential?.secret {
      dict[kSecretKey] = secret
    }
    if let reCAPTCHAToken = reCAPTCHAToken {
      dict[kreCAPTCHATokenKey] = reCAPTCHAToken
    }
    return dict
  }
}
