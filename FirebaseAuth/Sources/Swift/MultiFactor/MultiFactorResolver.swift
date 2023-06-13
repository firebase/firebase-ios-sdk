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
  /** @class FIRPhoneMultiFactorAssertion
   @brief The subclass of base class FIRMultiFactorAssertion, used to assert ownership of a phone
       second factor.
       This class is available on iOS only.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @objc(FIRMultiFactorResolver)
  public class MultiFactorResolver: NSObject {
    /**
        @brief The opaque session identifier for the current sign-in flow.
     */
    @objc public let session: MultiFactorSession

    /**
        @brief The list of hints for the second factors needed to complete the sign-in for the current
            session.
     */
    @objc public let hints: [MultiFactorInfo]

    /**
        @brief The Auth reference for the current FIRMultiResolver.
     */
    @objc public let auth: Auth

    /** @fn resolveSignInWithAssertion:completion:
         @brief A helper function to help users complete sign in with a second factor using an
             FIRMultiFactorAssertion confirming the user successfully completed the second factor
        challenge.
         @param completion The block invoked when the request is complete, or fails.
     */
    @objc(resolveSignInWithAssertion:completion:)
    public func resolveSignIn(with assertion: MultiFactorAssertion,
                              completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
      let phoneAssertion = assertion as? PhoneMultiFactorAssertion
      let finalizeMFAPhoneRequestInfo = AuthProtoFinalizeMFAPhoneRequestInfo(
        sessionInfo: phoneAssertion?.authCredential?.verificationID,
        verificationCode: phoneAssertion?.authCredential?.verificationCode
      )
      let request = FinalizeMFASignInRequest(
        mfaPendingCredential: mfaPendingCredential,
        verificationInfo: finalizeMFAPhoneRequestInfo,
        requestConfiguration: auth.requestConfiguration
      )
      AuthBackend.post(withRequest: request) { rawResponse, error in
        if let error {
          if let completion {
            completion(nil, error)
          }
        } else if let response = rawResponse as? FinalizeMFAEnrollmentResponse {
          self.auth.completeSignIn(withAccessToken: response.idToken,
                                   accessTokenExpirationDate: nil,
                                   refreshToken: response.refreshToken,
                                   anonymous: false) { user, error in
            guard let user else {
              fatalError("Internal Auth Error: completeSignIn didn't pass back a user")
            }
            let result = AuthDataResult(withUser: user, additionalUserInfo: nil)
            let decoratedCallback = self.auth
              .signInFlowAuthDataResultCallback(byDecorating: completion)
            decoratedCallback(result, nil)
          }
        }
      }
    }

    /** @fn resolveSignInWithAssertion:completion:
         @brief A helper function to help users complete sign in with a second factor using an
             FIRMultiFactorAssertion confirming the user successfully completed the second factor
        challenge.
         @param completion The block invoked when the request is complete, or fails.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    public func resolveSignIn(with assertion: MultiFactorAssertion) async throws -> AuthDataResult {
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
      session = MultiFactorSession()
      session.mfaPendingCredential = mfaPendingCredential
    }
  }

#endif
