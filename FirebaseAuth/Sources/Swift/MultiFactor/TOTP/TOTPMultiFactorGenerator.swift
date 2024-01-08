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
  /**
   @class TOTPMultiFactorGenerator
   @brief The data structure used to help initialize an assertion for a second factor entity to the
   Firebase Auth/CICP server. Depending on the type of second factor, this will help generate
   the assertion.
   This class is available on iOS only.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @objc(FIRTOTPMultiFactorGenerator) open class TOTPMultiFactorGenerator: NSObject {
    /**
     @fn generateSecretWithMultiFactorSession
     @brief Creates a TOTP secret as part of enrolling a TOTP second factor. Used for generating a
     QR code URL or inputting into a TOTP app. This method uses the auth instance corresponding to the
     user in the multiFactorSession.
     @param session The multiFactorSession instance.
     @param completion Completion block
     */
    @objc(generateSecretWithMultiFactorSession:completion:)
    open class func generateSecret(with session: MultiFactorSession,
                                   completion: @escaping (TOTPSecret?, Error?) -> Void) {
      guard let currentUser = session.currentUser,
            let requestConfiguration = currentUser.auth?.requestConfiguration else {
        let error = AuthErrorUtils.error(code: AuthErrorCode.internalError,
                                         userInfo: [NSLocalizedDescriptionKey:
                                           "Invalid ID token."])
        completion(nil, error)
        return
      }
      let totpEnrollmentInfo = AuthProtoStartMFATOTPEnrollmentRequestInfo()
      let request = StartMFAEnrollmentRequest(idToken: session.idToken,
                                              totpEnrollmentInfo: totpEnrollmentInfo,
                                              requestConfiguration: requestConfiguration)
      Task {
        do {
          let response = try await AuthBackend.call(with: request)
          if let totpSessionInfo = response.totpSessionInfo {
            let secret = TOTPSecret(secretKey: totpSessionInfo.sharedSecretKey,
                                    hashingAlgorithm: totpSessionInfo.hashingAlgorithm,
                                    codeLength: totpSessionInfo.verificationCodeLength,
                                    codeIntervalSeconds: totpSessionInfo.periodSec,
                                    enrollmentCompletionDeadline: totpSessionInfo
                                      .finalizeEnrollmentTime,
                                    sessionInfo: totpSessionInfo.sessionInfo)
            completion(secret, nil)
          } else {
            let error = AuthErrorUtils.error(code: AuthErrorCode.internalError,
                                             userInfo: [NSLocalizedDescriptionKey:
                                               "Error generating TOTP secret."])
            completion(nil, error)
          }
        } catch {
          completion(nil, error)
        }
      }
    }

    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    open class func generateSecret(with session: MultiFactorSession) async throws
      -> TOTPSecret {
      return try await withCheckedThrowingContinuation { continuation in
        self.generateSecret(with: session) { secret, error in
          if let secret {
            continuation.resume(returning: secret)
          } else {
            continuation.resume(throwing: error!)
          }
        }
      }
    }

    /**
     @fn assertionForEnrollmentWithSecret:
     @brief Initializes the MFA assertion to confirm ownership of the TOTP second factor. This assertion
     is used to complete enrollment of TOTP as a second factor.
     @param secret The TOTP secret.
     @param oneTimePassword one time password string.
     */
    @objc(assertionForEnrollmentWithSecret:oneTimePassword:)
    open class func assertionForEnrollment(with secret: TOTPSecret,
                                           oneTimePassword: String) -> TOTPMultiFactorAssertion {
      return TOTPMultiFactorAssertion(secretOrID: SecretOrID.secret(secret),
                                      oneTimePassword: oneTimePassword)
    }

    /**
      @fn assertionForSignInWithenrollmentID:
      @brief Initializes the MFA assertion to confirm ownership of the TOTP second factor. This
      assertion is used to complete signIn with TOTP as a second factor.
      @param enrollmentID The ID that identifies the enrolled TOTP second factor.
      @param oneTimePassword one time password string.
     */
    @objc(assertionForSignInWithEnrollmentID:oneTimePassword:)
    open class func assertionForSignIn(withEnrollmentID enrollmentID: String,
                                       oneTimePassword: String) -> TOTPMultiFactorAssertion {
      return TOTPMultiFactorAssertion(secretOrID: SecretOrID.enrollmentID(enrollmentID),
                                      oneTimePassword: oneTimePassword)
    }
  }

#endif
