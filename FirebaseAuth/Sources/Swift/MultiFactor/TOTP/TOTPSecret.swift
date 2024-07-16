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
#if COCOAPODS
  @_implementationOnly import GoogleUtilities
#else
  @_implementationOnly import GoogleUtilities_Environment
#endif

#if os(iOS)
  import UIKit

  /// The subclass of base class MultiFactorAssertion, used to assert ownership of a TOTP
  /// (Time-based One Time Password) second factor.
  ///
  /// This class is available on iOS only.
  @objc(FIRTOTPSecret) open class TOTPSecret: NSObject {
    /// Returns the shared secret key/seed used to generate time-based one-time passwords.
    @objc open func sharedSecretKey() -> String {
      return secretKey
    }

    /// Returns a QRCode URL as described in
    /// https://github.com/google/google-authenticator/wiki/Key-Uri-Format.
    ///
    /// This can be displayed to the user as a QRCode to be scanned into a TOTP app like Google
    /// Authenticator.
    /// - Parameter accountName: The name of the account/app.
    /// - Parameter issuer: Issuer of the TOTP(likely the app name).
    /// - Returns: A QRCode URL string.
    @objc(generateQRCodeURLWithAccountName:issuer:)
    open func generateQRCodeURL(withAccountName accountName: String,
                                issuer: String) -> String {
      guard let hashingAlgorithm, codeLength > 0 else {
        return ""
      }
      return "otpauth://totp/\(issuer):\(accountName)?secret=\(secretKey)&issuer=\(issuer)" +
        "&algorithm=%\(hashingAlgorithm)&digits=\(codeLength)"
    }

    /// Opens the specified QR Code URL in a password manager like iCloud Keychain.
    ///
    /// See more details
    /// [here](https://developer.apple.com/documentation/authenticationservices/securing_logins_with_icloud_keychain_verification_codes)
    @objc(openInOTPAppWithQRCodeURL:)
    open func openInOTPApp(withQRCodeURL qrCodeURL: String) {
      if GULAppEnvironmentUtil.isAppExtension() {
        // iOS App extensions should not call [UIApplication sharedApplication], even if
        // UIApplication responds to it.
        return
      }

      // Using reflection here to avoid build errors in extensions.
      let sel = NSSelectorFromString("sharedApplication")
      guard UIApplication.responds(to: sel),
            let rawApplication = UIApplication.perform(sel),
            let application = rawApplication.takeUnretainedValue() as? UIApplication else {
        return
      }
      if let url = URL(string: qrCodeURL), application.canOpenURL(url) {
        application.open(url, options: [:], completionHandler: nil)
      } else {
        AuthLog.logError(code: "I-AUT000019",
                         message: "URL: \(qrCodeURL) cannot be opened")
      }
    }

    /// Shared secret key/seed used for enrolling in TOTP MFA and generating OTPs.
    private let secretKey: String

    /// Hashing algorithm used.
    private let hashingAlgorithm: String?

    /// Length of the one-time passwords to be generated.
    private let codeLength: Int

    /// The interval (in seconds) when the OTP codes should change.
    private let codeIntervalSeconds: Int

    /// The timestamp by which TOTP enrollment should be completed. This can be used by callers to
    /// show a countdown of when to enter OTP code by.
    private let enrollmentCompletionDeadline: Date?

    /// Additional session information.
    let sessionInfo: String?

    init(secretKey: String, hashingAlgorithm: String?, codeLength: Int, codeIntervalSeconds: Int,
         enrollmentCompletionDeadline: Date?, sessionInfo: String?) {
      self.secretKey = secretKey
      self.hashingAlgorithm = hashingAlgorithm
      self.codeLength = codeLength
      self.codeIntervalSeconds = codeIntervalSeconds
      self.enrollmentCompletionDeadline = enrollmentCompletionDeadline
      self.sessionInfo = sessionInfo
    }
  }

#endif
