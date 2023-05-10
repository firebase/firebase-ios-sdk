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

  /** @class FIRMultiFactor
   @brief The interface defining the multi factor related properties and operations pertaining to a
       user.
       This class is available on iOS only.
   */
  @objc(FIRMultiFactor) public class MultiFactor: NSObject, NSSecureCoding {
    @objc public var enrolledFactors: [MultiFactorInfo]?

    /** @fn getSessionWithCompletion:
     @brief Get a session for a second factor enrollment operation.
     @param completion A block with the session identifier for a second factor enrollment operation.
     This is used to identify the current user trying to enroll a second factor.
     */
    @objc(getSessionWithCompletion:)
    public func getSessionWithCompletion(_ completion: ((MultiFactorSession?, Error?) -> Void)?) {
      let session = MultiFactorSession.sessionForCurrentUser
      if let completion {
        completion(session, nil)
      }
    }

    /** @fn getSessionWithCompletion:
     @brief Get a session for a second factor enrollment operation.
     @param completion A block with the session identifier for a second factor enrollment operation.
     This is used to identify the current user trying to enroll a second factor.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    public func session() async throws -> MultiFactorSession {
      return try await withCheckedThrowingContinuation { continuation in
        self.getSessionWithCompletion { session, error in
          if let session {
            continuation.resume(returning: session)
          } else {
            continuation.resume(throwing: error!)
          }
        }
      }
    }

    /** @fn enrollWithAssertion:displayName:completion:
     @brief Enrolls a second factor as identified by the `MultiFactorAssertion` parameter for the
     current user.
     @param displayName An optional display name associated with the multi factor to enroll.
     @param completion The block invoked when the request is complete, or fails.
     */
    @objc(enrollWithAssertion:displayName:completion:)
    public func enroll(with assertion: MultiFactorAssertion,
                       displayName: String?,
                       completion: ((Error?) -> Void)?) {
      let phoneAssertion = assertion as? PhoneMultiFactorAssertion
      let finalizeMFAPhoneRequestInfo = AuthProtoFinalizeMFAPhoneRequestInfo(
        sessionInfo: phoneAssertion?.authCredential?.verificationID,
        verificationCode: phoneAssertion?.authCredential?.verificationCode
      )
      guard let user = user else {
        fatalError("Internal Auth error: failed to get user enrolling in MultiFactor")
      }
      let request = FinalizeMFAEnrollmentRequest(
        idToken: self.user?.rawAccessToken(),
        displayName: displayName,
        verificationInfo: finalizeMFAPhoneRequestInfo,
        requestConfiguration: user.requestConfiguration
      )

      AuthBackend.post(withRequest: request) { rawResponse, error in
        if let error {
          if let completion {
            completion(error)
          }
        } else if let response = rawResponse as? FinalizeMFAEnrollmentResponse {
          user.auth?.completeSignIn(withAccessToken: response.idToken,
                                    accessTokenExpirationDate: nil,
                                    refreshToken: response.refreshToken,
                                    anonymous: false) { user, error in
            if let completion {
              completion(error)
            }
          }
        }
      }
    }

    /** @fn enrollWithAssertion:displayName:completion:
     @brief Enrolls a second factor as identified by the `MultiFactorAssertion` parameter for the
     current user.
     @param displayName An optional display name associated with the multi factor to enroll.
     @param completion The block invoked when the request is complete, or fails.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    public func enroll(with assertion: MultiFactorAssertion, displayName: String?) async throws {
      return try await withCheckedThrowingContinuation { continuation in
        self.enroll(with: assertion, displayName: displayName) { error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume()
          }
        }
      }
    }

    /** @fn unenrollWithInfo:completion:
     @brief Unenroll the given multi factor.
     @param completion The block invoked when the request to send the verification email is complete,
     or fails.
     */
    @objc(unenrollWithInfo:completion:)
    public func unenroll(with factorInfo: MultiFactorInfo,
                         completion: ((Error?) -> Void)?) {
      unenroll(withFactorUID: factorInfo.uid, completion: completion)
    }

    /** @fn unenrollWithInfo:completion:
     @brief Unenroll the given multi factor.
     @param completion The block invoked when the request to send the verification email is complete,
     or fails.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    public func unenroll(with factorInfo: MultiFactorInfo) async throws {
      try await unenroll(withFactorUID: factorInfo.uid)
    }

    /** @fn unenrollWithFactorUID:completion:
     @brief Unenroll the given multi factor.
     @param completion The block invoked when the request to send the verification email is complete,
     or fails.
     */
    @objc(unenrollWithFactorUID:completion:)
    public func unenroll(withFactorUID factorUID: String,
                         completion: ((Error?) -> Void)?) {
      guard let user = user else {
        fatalError("Internal Auth error: failed to get user unenrolling in MultiFactor")
      }
      let request = WithdrawMFARequest(idToken: user.rawAccessToken(),
                                       mfaEnrollmentID: factorUID,
                                       requestConfiguration: user.requestConfiguration)
      AuthBackend.post(withRequest: request) { rawResponse, error in
        if let error {
          if let completion {
            completion(error)
          }
        } else {
          guard let response = rawResponse as? WithdrawMFAResponse else {
            fatalError("TODO")
          }
          user.auth?.completeSignIn(withAccessToken: response.idToken,
                                    accessTokenExpirationDate: nil,
                                    refreshToken: response.refreshToken,
                                    anonymous: false) { signInUser, error in
            if let completion {
              completion(error)
            }
          }
        }
      }
    }

    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    public func unenroll(withFactorUID factorUID: String) async throws {
      return try await withCheckedThrowingContinuation { continuation in
        self.unenroll(withFactorUID: factorUID) { error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume()
          }
        }
      }
    }

    weak var user: User?

    convenience init(withMFAEnrollments mfaEnrollments: [AuthProtoMFAEnrollment]) {
      self.init()
      var multiFactorInfoArray: [MultiFactorInfo] = []
      for enrollment in mfaEnrollments {
        let multiFactorInfo = PhoneMultiFactorInfo(proto: enrollment)
        multiFactorInfoArray.append(multiFactorInfo)
      }
      enrolledFactors = multiFactorInfoArray
    }

    override init() {}

    // MARK: - NSSecureCoding

    private let kEnrolledFactorsCodingKey = "enrolledFactors"

    public static var supportsSecureCoding: Bool {
      true
    }

    public func encode(with coder: NSCoder) {
      coder.encode(enrolledFactors, forKey: kEnrolledFactorsCodingKey)
      // Do not encode `user` weak property.
    }

    public required init?(coder: NSCoder) {
      let enrolledFactors = coder
        .decodeObject(forKey: kEnrolledFactorsCodingKey) as? [MultiFactorInfo]
      self.enrolledFactors = enrolledFactors
      // Do not decode `user` weak property.
    }
  }
#endif
