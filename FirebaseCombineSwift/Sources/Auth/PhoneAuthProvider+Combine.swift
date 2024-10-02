// Copyright 2020 Google LLC
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

#if os(iOS)

  import Foundation

  import Combine
  import FirebaseAuth

  @available(iOS 13.0, *)
  @available(macOS, unavailable)
  @available(macCatalyst, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public extension PhoneAuthProvider {
    /// Starts the phone number authentication flow by sending a verification code to the
    /// specified phone number.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///     - phoneNumber: The phone number to be verified.
    ///     - uiDelegate: An object used to present the `SFSafariViewController`. The object is
    ///        retained by this method until the completion block is executed.
    ///
    /// - Returns: A publisher that emits an `VerificationID` when the verification flow completed
    ///   successfully, or an error otherwise. The publisher will emit on the *main* thread.
    ///
    /// - Remark:
    ///   Possible error codes:
    ///
    ///   - `FIRAuthErrorCodeCaptchaCheckFailed` - Indicates that the reCAPTCHA token obtained by
    ///      the Firebase Auth is invalid or has expired.
    ///   - `FIRAuthErrorCodeQuotaExceeded` - Indicates that the phone verification quota for this
    ///      project has been exceeded.
    ///   - `FIRAuthErrorCodeInvalidPhoneNumber` - Indicates that the phone number provided is
    ///      invalid.
    ///   - `FIRAuthErrorCodeMissingPhoneNumber` - Indicates that a phone number was not provided.
    @discardableResult
    func verifyPhoneNumber(_ phoneNumber: String,
                           uiDelegate: AuthUIDelegate? = nil)
      -> Future<String, Error> {
      Future<String, Error> { promise in
        self.verifyPhoneNumber(phoneNumber, uiDelegate: uiDelegate) { verificationID, error in
          if let error {
            promise(.failure(error))
          } else if let verificationID {
            promise(.success(verificationID))
          }
        }
      }
    }

    /// Verify ownership of the second factor phone number by the current user.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///     - phoneNumber: The phone number to be verified.
    ///     - uiDelegate: An object used to present the `SFSafariViewController`. The object is
    ///       retained by this method until the completion block is executed.
    ///     - session: A session to identify the MFA flow. For enrollment, this identifies the
    ///       user trying to enroll. For sign-in, this identifies that the user already passed the
    ///       first factor challenge.
    ///
    /// - Returns: A publisher that emits an `VerificationID` when the verification flow completed
    ///   successfully, or an error otherwise. The publisher will emit on the *main* thread.
    ///
    /// - Remark:
    ///   Possible error codes:
    ///
    ///   - `FIRAuthErrorCodeCaptchaCheckFailed` - Indicates that the reCAPTCHA token obtained by
    ///      the Firebase Auth is invalid or has expired.
    ///   - `FIRAuthErrorCodeQuotaExceeded` - Indicates that the phone verification quota for this
    ///      project has been exceeded.
    ///   - `FIRAuthErrorCodeInvalidPhoneNumber` - Indicates that the phone number provided is
    ///      invalid.
    ///   - `FIRAuthErrorCodeMissingPhoneNumber` - Indicates that a phone number was not provided.
    @discardableResult
    func verifyPhoneNumber(_ phoneNumber: String,
                           uiDelegate: AuthUIDelegate? = nil,
                           multiFactorSession: MultiFactorSession?)
      -> Future<String, Error> {
      Future<String, Error> { promise in
        self.verifyPhoneNumber(
          phoneNumber,
          uiDelegate: uiDelegate,
          multiFactorSession: multiFactorSession
        ) { verificationID, error in
          if let error {
            promise(.failure(error))
          } else if let verificationID {
            promise(.success(verificationID))
          }
        }
      }
    }

    /// Verify ownership of the second factor phone number by the current user.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - phoneNumber: The phone number to be verified.
    ///   - UIDelegate: An object used to present the SFSafariViewController. The object is
    ///   retained by this method until the completion block is executed.
    ///   - multiFactorSession: session A session to identify the MFA flow. For enrollment, this
    ///      identifies the user trying to enroll. For sign-in, this identifies that the user
    /// already
    ///      passed the first factor challenge.
    /// - Returns: A publisher that emits an `VerificationID` when the verification flow completed
    ///   successfully, or an error otherwise. The publisher will emit on the *main* thread.
    @discardableResult
    func verifyPhoneNumber(with phoneMultiFactorInfo: PhoneMultiFactorInfo,
                           uiDelegate: AuthUIDelegate? = nil,
                           multiFactorSession: MultiFactorSession?)
      -> Future<String, Error> {
      Future<String, Error> { promise in
        self.verifyPhoneNumber(with: phoneMultiFactorInfo,
                               uiDelegate: uiDelegate,
                               multiFactorSession: multiFactorSession) { verificationID, error in
          if let error {
            promise(.failure(error))
          } else if let verificationID {
            promise(.success(verificationID))
          }
        }
      }
    }
  }

#endif // os(iOS)
