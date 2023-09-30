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
   @class FIRTOTPMultiFactorGenerator
   @brief The data structure used to help initialize an assertion for a second factor entity to the
   Firebase Auth/CICP server. Depending on the type of second factor, this will help generate
   the assertion.
   This class is available on iOS only.
   */
  @objc(FIRTOTPMultiFactorGenerator) public class TOTPMultiFactorGenerator: NSObject {
    /**
     @fn generateSecretWithMultiFactorSession
     @brief Creates a TOTP secret as part of enrolling a TOTP second factor. Used for generating a
     QR code URL or inputting into a TOTP app. This method uses the auth instance corresponding to the
     user in the multiFactorSession.
     @param session The multiFactorSession instance.
     @param completion Completion block
     */
    @objc public func generateSecretWithMultiFactorSession(session: MultiFactorSession,
                                                           completion: (TOTPSecret?, Error?)
                                                             -> Void) {
      // Saturday TODO
    }

    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    public func generateSecretWithMultiFactorSession(session: MultiFactorSession) async throws
      -> TOTPSecret {
      return try await withCheckedThrowingContinuation { continuation in
        self.generateSecretWithMultiFactorSession(session: session) { secret, error in
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
    public func assertionForEnrollment(secret: TOTPSecret,
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
    public func assertionForSignIn(enrollmentID: String,
                                   oneTimePassword: String) -> TOTPMultiFactorAssertion {
      return TOTPMultiFactorAssertion(secretOrID: SecretOrID.enrollmentID(enrollmentID),
                                      oneTimePassword: oneTimePassword)
    }
  }

#endif
