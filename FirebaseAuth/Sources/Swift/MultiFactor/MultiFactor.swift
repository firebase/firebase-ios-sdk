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

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  extension MultiFactor: NSSecureCoding {}

  /// The interface defining the multi factor related properties and operations pertaining to a
  /// user.
  ///
  /// This class is available on iOS only.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @objc(FIRMultiFactor) open class MultiFactor: NSObject {
    @objc open var enrolledFactors: [MultiFactorInfo]

    /// Get a session for a second factor enrollment operation.
    ///
    /// This is used to identify the current user trying to enroll a second factor.
    /// - Parameter completion: A block with the session identifier for a second factor enrollment
    /// operation.
    @objc(getSessionWithCompletion:)
    open func getSessionWithCompletion(_ completion: ((MultiFactorSession?, Error?) -> Void)?) {
      let session = MultiFactorSession.sessionForCurrentUser
      if let completion {
        completion(session, nil)
      }
    }

    /// Get a session for a second factor enrollment operation.
    ///
    /// This is used to identify the current user trying to enroll a second factor.
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    open func session() async throws -> MultiFactorSession {
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

    /// Enrolls a second factor as identified by the `MultiFactorAssertion` parameter for the
    /// current user.
    /// - Parameter assertion: The `MultiFactorAssertion`.
    /// - Parameter displayName: An optional display name associated with the multi factor to
    /// enroll.
    /// - Parameter completion: The block invoked when the request is complete, or fails.
    @objc(enrollWithAssertion:displayName:completion:)
    open func enroll(with assertion: MultiFactorAssertion,
                     displayName: String?,
                     completion: ((Error?) -> Void)?) {
      // TODO: Refactor classes so this duplicated code isn't necessary for phone and totp.
      if assertion.factorID == PhoneMultiFactorInfo.TOTPMultiFactorID {
        guard let totpAssertion = assertion as? TOTPMultiFactorAssertion else {
          fatalError("Auth Internal Error: Failed to find TOTPMultiFactorAssertion")
        }
        switch totpAssertion.secretOrID {
        case .enrollmentID: fatalError("Missing secret in totpAssertion")
        case let .secret(secret):
          guard let user = user, let auth = user.auth else {
            fatalError("Internal Auth error: failed to get user enrolling in MultiFactor")
          }
          let finalizeMFATOTPRequestInfo =
            AuthProtoFinalizeMFATOTPEnrollmentRequestInfo(sessionInfo: secret.sessionInfo,
                                                          verificationCode: totpAssertion
                                                            .oneTimePassword)
          let request = FinalizeMFAEnrollmentRequest(idToken: self.user?.rawAccessToken(),
                                                     displayName: displayName,
                                                     totpVerificationInfo: finalizeMFATOTPRequestInfo,
                                                     requestConfiguration: user
                                                       .requestConfiguration)
          Task {
            do {
              let response = try await AuthBackend.call(with: request)
              do {
                let user = try await auth.completeSignIn(withAccessToken: response.idToken,
                                                         accessTokenExpirationDate: nil,
                                                         refreshToken: response.refreshToken,
                                                         anonymous: false)
                try auth.updateCurrentUser(user, byForce: false, savingToDisk: true)
                if let completion {
                  DispatchQueue.main.async {
                    completion(nil)
                  }
                }
              } catch {
                DispatchQueue.main.async {
                  if let completion {
                    completion(error)
                  }
                }
              }
            } catch {
              if let completion {
                completion(error)
              }
            }
          }
        }
      } else if assertion.factorID != PhoneMultiFactorInfo.PhoneMultiFactorID {
        return
      }
      let phoneAssertion = assertion as? PhoneMultiFactorAssertion
      guard let credential = phoneAssertion?.authCredential else {
        fatalError("Internal Error: Missing credential")
      }
      switch credential.credentialKind {
      case .phoneNumber: fatalError("Internal Error: Missing verificationCode")
      case let .verification(verificationID, code):
        let finalizeMFAPhoneRequestInfo =
          AuthProtoFinalizeMFAPhoneRequestInfo(sessionInfo: verificationID, verificationCode: code)
        guard let user = user, let auth = user.auth else {
          fatalError("Internal Auth error: failed to get user enrolling in MultiFactor")
        }
        let request = FinalizeMFAEnrollmentRequest(
          idToken: self.user?.rawAccessToken(),
          displayName: displayName,
          phoneVerificationInfo: finalizeMFAPhoneRequestInfo,
          requestConfiguration: user.requestConfiguration
        )

        Task {
          do {
            let response = try await AuthBackend.call(with: request)
            do {
              let user = try await auth.completeSignIn(withAccessToken: response.idToken,
                                                       accessTokenExpirationDate: nil,
                                                       refreshToken: response.refreshToken,
                                                       anonymous: false)
              try auth.updateCurrentUser(user, byForce: false, savingToDisk: true)
              if let completion {
                DispatchQueue.main.async {
                  completion(nil)
                }
              }
            } catch {
              DispatchQueue.main.async {
                if let completion {
                  completion(error)
                }
              }
            }
          } catch {
            if let completion {
              completion(error)
            }
          }
        }
      }
    }

    /// Enrolls a second factor as identified by the `MultiFactorAssertion` parameter for the
    /// current user.
    /// - Parameter assertion: The `MultiFactorAssertion`.
    /// - Parameter displayName: An optional display name associated with the multi factor to
    /// enroll.
    /// - Parameter completion: The block invoked when the request is complete, or fails.
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    open func enroll(with assertion: MultiFactorAssertion, displayName: String?) async throws {
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

    /// Unenroll the given multi factor.
    /// - Parameter completion: The block invoked when the request to send the verification email is
    /// complete, or fails.
    @objc(unenrollWithInfo:completion:)
    open func unenroll(with factorInfo: MultiFactorInfo,
                       completion: ((Error?) -> Void)?) {
      unenroll(withFactorUID: factorInfo.uid, completion: completion)
    }

    /// Unenroll the given multi factor.
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    open func unenroll(with factorInfo: MultiFactorInfo) async throws {
      try await unenroll(withFactorUID: factorInfo.uid)
    }

    /// Unenroll the given multi factor.
    /// - Parameter completion: The block invoked when the request to send the verification email is
    /// complete, or fails.
    @objc(unenrollWithFactorUID:completion:)
    open func unenroll(withFactorUID factorUID: String,
                       completion: ((Error?) -> Void)?) {
      guard let user = user, let auth = user.auth else {
        fatalError("Internal Auth error: failed to get user unenrolling in MultiFactor")
      }
      let request = WithdrawMFARequest(idToken: user.rawAccessToken(),
                                       mfaEnrollmentID: factorUID,
                                       requestConfiguration: user.requestConfiguration)
      Task {
        do {
          let response = try await AuthBackend.call(with: request)
          do {
            let user = try await auth.completeSignIn(withAccessToken: response.idToken,
                                                     accessTokenExpirationDate: nil,
                                                     refreshToken: response.refreshToken,
                                                     anonymous: false)
            try auth.updateCurrentUser(user, byForce: false, savingToDisk: true)
            if let completion {
              DispatchQueue.main.async {
                completion(nil)
              }
            }
          } catch {
            DispatchQueue.main.async {
              try? auth.signOut()
              if let completion {
                completion(error)
              }
            }
          }
        } catch {
          if let completion {
            completion(error)
          }
        }
      }
    }

    /// Unenroll the given multi factor.
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    open func unenroll(withFactorUID factorUID: String) async throws {
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
        if enrollment.phoneInfo != nil {
          let multiFactorInfo = PhoneMultiFactorInfo(proto: enrollment)
          multiFactorInfoArray.append(multiFactorInfo)
        } else if enrollment.totpInfo != nil {
          let multiFactorInfo = TOTPMultiFactorInfo(proto: enrollment)
          multiFactorInfoArray.append(multiFactorInfo)
        }
      }
      enrolledFactors = multiFactorInfoArray
    }

    override init() {
      enrolledFactors = []
    }

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
      let classes = [NSArray.self, MultiFactorInfo.self, PhoneMultiFactorInfo.self,
                     TOTPMultiFactorInfo.self]
      let enrolledFactors = coder
        .decodeObject(of: classes, forKey: kEnrolledFactorsCodingKey) as? [MultiFactorInfo]
      self.enrolledFactors = enrolledFactors ?? []
      // Do not decode `user` weak property.
    }
  }
#endif
