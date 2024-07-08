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

/// The "sendVerificationCodeEnd" endpoint.
private let kSendVerificationCodeEndPoint = "sendVerificationCode"

/// The key for the Phone Number parameter in the request.
private let kPhoneNumberKey = "phoneNumber"

/// The key for the receipt parameter in the request.
private let kReceiptKey = "iosReceipt"

/// The key for the Secret parameter in the request.
private let kSecretKey = "iosSecret"

/// The key for the reCAPTCHAToken parameter in the request.
private let kreCAPTCHATokenKey = "recaptchaToken"

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

///  A verification code can be an appCredential or a reCaptcha Token
enum CodeIdentity {
  case credential(AuthAppCredential)
  case recaptcha(String)
  case empty
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class SendVerificationCodeRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = SendVerificationCodeResponse

  /// The phone number to which the verification code should be sent.
  let phoneNumber: String

  /// The credential or reCAPTCHA token to prove the identity of the app in order to send the
  /// verification code.
  let codeIdentity: CodeIdentity

  init(phoneNumber: String, codeIdentity: CodeIdentity,
       requestConfiguration: AuthRequestConfiguration) {
    self.phoneNumber = phoneNumber
    self.codeIdentity = codeIdentity
    super.init(
      endpoint: kSendVerificationCodeEndPoint,
      requestConfiguration: requestConfiguration
    )
  }

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var postBody: [String: AnyHashable] = [:]
    postBody[kPhoneNumberKey] = phoneNumber
    switch codeIdentity {
    case let .credential(appCredential):
      postBody[kReceiptKey] = appCredential.receipt
      postBody[kSecretKey] = appCredential.secret
    case let .recaptcha(reCAPTCHAToken):
      postBody[kreCAPTCHATokenKey] = reCAPTCHAToken
    case .empty: break
    }

    if let tenantID {
      postBody[kTenantIDKey] = tenantID
    }
    return postBody
  }
}
