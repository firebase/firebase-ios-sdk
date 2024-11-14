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

  /// The subclass of base class `MultiFactorAssertion`, used to assert ownership of a phone
  /// second factor.
  ///
  /// This class is available on iOS only.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @objc(FIRMultiFactorResolver)
  open class MultiFactorResolver: NSObject {
    /// The opaque session identifier for the current sign-in flow.
    @objc public let session: MultiFactorSession

    /// The list of hints for the second factors needed to complete the sign-in for the current
    /// session.
    @objc public let hints: [MultiFactorInfo]

    /// The Auth reference for the current `MultiResolver`.
    @objc public let auth: Auth

    /// A helper function to help users complete sign in with a second factor using a
    /// - Parameter assertion: The assertion confirming the user successfully
    ///  completed the second factor challenge.
    /// - Parameter completion: The block invoked when the request is complete, or fails.
    @objc(resolveSignInWithAssertion:completion:)
    open func resolveSignIn(with assertion: MultiFactorAssertion,
                            completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
      var finalizedMFARequestInfo: AuthProto?
      if let totpAssertion = assertion as? TOTPMultiFactorAssertion {
        switch totpAssertion.secretOrID {
        case .secret: fatalError("Missing enrollmentID in totpAssertion")
        case let .enrollmentID(enrollmentID):
          finalizedMFARequestInfo = AuthProtoFinalizeMFATOTPSignInRequestInfo(
            mfaEnrollmentID: enrollmentID,
            verificationCode: totpAssertion.oneTimePassword
          )
        }
      } else {
        let phoneAssertion = assertion as? PhoneMultiFactorAssertion
        guard let credential = phoneAssertion?.authCredential else {
          fatalError("Internal Error: Missing credential")
        }
        switch credential.credentialKind {
        case .phoneNumber: fatalError("Internal Error: Missing verificationCode")
        case let .verification(verificationID, code):
          finalizedMFARequestInfo =
            AuthProtoFinalizeMFAPhoneRequestInfo(
              sessionInfo: verificationID,
              verificationCode: code
            )
        }
      }
      let request = FinalizeMFASignInRequest(
        mfaPendingCredential: mfaPendingCredential,
        verificationInfo: finalizedMFARequestInfo,
        requestConfiguration: auth.requestConfiguration
      )
      Task {
        do {
          let response = try await self.auth.backend.call(with: request)
          let user = try await self.auth.completeSignIn(withAccessToken: response.idToken,
                                                        accessTokenExpirationDate: nil,
                                                        refreshToken: response.refreshToken,
                                                        anonymous: false)
          let result = AuthDataResult(withUser: user, additionalUserInfo: nil)
          let decoratedCallback = self.auth
            .signInFlowAuthDataResultCallback(byDecorating: completion)
          decoratedCallback(result, nil)
        } catch {
          if let completion {
            completion(nil, error)
          }
        }
      }
    }

    /// A helper function to help users complete sign in with a second factor using a
    /// - Parameter assertion: The assertion confirming the user successfully
    ///  completed the second factor challenge.
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    open func resolveSignIn(with assertion: MultiFactorAssertion) async throws -> AuthDataResult {
      return try await withCheckedThrowingContinuation { continuation in
        self.resolveSignIn(with: assertion) { result, error in
          if let result {
            continuation.resume(returning: result)
          } else {
            continuation.resume(throwing: error!)
          }
        }
      }
    }

    let mfaPendingCredential: String?

    init(with mfaPendingCredential: String?, hints: [MultiFactorInfo], auth: Auth) {
      self.mfaPendingCredential = mfaPendingCredential
      self.hints = hints
      self.auth = auth
      session = MultiFactorSession(mfaCredential: mfaPendingCredential)
    }
  }

#endif
