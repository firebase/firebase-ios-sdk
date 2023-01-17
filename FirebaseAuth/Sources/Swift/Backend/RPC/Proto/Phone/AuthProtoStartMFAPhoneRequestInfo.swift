//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 25/09/2022.
//

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
    required init(dictionary: [String : Any]) {
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

    var dictionary: [String: Any] {
        var dict: [String: Any] = [:]
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
