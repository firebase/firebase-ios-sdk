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

/// The key for the Phone Number parameter in the request.
private let kPhoneNumberKey = "phoneNumber"

/// The key for the receipt parameter in the request.
private let kReceiptKey = "iosReceipt"

/// The key for the Secret parameter in the request.
private let kSecretKey = "iosSecret"

/// The key for the reCAPTCHAToken parameter in the request.
private let kreCAPTCHATokenKey = "recaptchaToken"

/// The key for the "captchaResponse" value in the request.
private let kCaptchaResponseKey = "captchaResponse"

/// The key for the "recaptchaVersion" value in the request.
private let kRecaptchaVersion = "recaptchaVersion"

/// The key for the "clientType" value in the request.
private let kClientType = "clientType"

class AuthProtoStartMFAPhoneRequestInfo: NSObject, AuthProto {
  required init(dictionary: [String: AnyHashable]) {
    fatalError()
  }

  var phoneNumber: String?
  var codeIdentity: CodeIdentity
  var captchaResponse: String?
  var recaptchaVersion: String?
  var clientType: String?
  init(phoneNumber: String?, codeIdentity: CodeIdentity) {
    self.phoneNumber = phoneNumber
    self.codeIdentity = codeIdentity
  }

  var dictionary: [String: AnyHashable] {
    var dict: [String: AnyHashable] = [:]
    if let phoneNumber = phoneNumber {
      dict[kPhoneNumberKey] = phoneNumber
    }
    if let captchaResponse = captchaResponse {
      dict[kCaptchaResponseKey] = captchaResponse
    }
    if let recaptchaVersion = recaptchaVersion {
      dict[kRecaptchaVersion] = recaptchaVersion
    }
    if let clientType = clientType {
      dict[kClientType] = clientType
    }
    switch codeIdentity {
    case let .credential(appCredential):
      dict[kReceiptKey] = appCredential.receipt
      dict[kSecretKey] = appCredential.secret
    case let .recaptcha(reCAPTCHAToken):
      dict[kreCAPTCHATokenKey] = reCAPTCHAToken
    case .empty:
      break
    }
    return dict
  }

  func injectRecaptchaFields(recaptchaResponse: String?, recaptchaVersion: String,
                             clientType: String?) {
    captchaResponse = recaptchaResponse
    self.recaptchaVersion = recaptchaVersion
    self.clientType = clientType
  }
}
