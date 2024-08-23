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

import FirebaseCore
import Foundation

/// A concrete implementation of `AuthProvider` for phone auth providers.
///
/// This class is available on iOS only.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRPhoneAuthProvider) open class PhoneAuthProvider: NSObject {
  /// A string constant identifying the phone identity provider.
  @objc public static let id = "phone"
  #if os(iOS)
    /// Returns an instance of `PhoneAuthProvider` for the default `Auth` object.
    @objc(provider) open class func provider() -> PhoneAuthProvider {
      return PhoneAuthProvider(auth: Auth.auth())
    }

    /// Returns an instance of `PhoneAuthProvider` for the provided `Auth` object.
    /// - Parameter auth: The auth object to associate with the phone auth provider instance.
    @objc(providerWithAuth:)
    open class func provider(auth: Auth) -> PhoneAuthProvider {
      return PhoneAuthProvider(auth: auth)
    }

    /// Starts the phone number authentication flow by sending a verification code to the
    /// specified phone number.
    ///
    /// Possible error codes:
    /// * `AuthErrorCodeCaptchaCheckFailed` - Indicates that the reCAPTCHA token obtained by
    /// the Firebase Auth is invalid or has expired.
    /// * `AuthErrorCodeQuotaExceeded` - Indicates that the phone verification quota for this
    /// project has been exceeded.
    /// * `AuthErrorCodeInvalidPhoneNumber` - Indicates that the phone number provided is invalid.
    /// * `AuthErrorCodeMissingPhoneNumber` - Indicates that a phone number was not provided.
    /// - Parameter phoneNumber: The phone number to be verified.
    /// - Parameter uiDelegate: An object used to present the SFSafariViewController. The object is
    /// retained by this method until the completion block is executed.
    /// - Parameter completion: The callback to be invoked when the verification flow is finished.
    @objc(verifyPhoneNumber:UIDelegate:completion:)
    open func verifyPhoneNumber(_ phoneNumber: String,
                                uiDelegate: AuthUIDelegate? = nil,
                                completion: ((_: String?, _: Error?) -> Void)?) {
      verifyPhoneNumber(phoneNumber,
                        uiDelegate: uiDelegate,
                        multiFactorSession: nil,
                        completion: completion)
    }

    /// Verify ownership of the second factor phone number by the current user.
    /// - Parameter phoneNumber: The phone number to be verified.
    /// - Parameter uiDelegate: An object used to present the SFSafariViewController. The object is
    /// retained by this method until the completion block is executed.
    /// - Parameter multiFactorSession: A session to identify the MFA flow. For enrollment, this
    /// identifies the user trying to enroll. For sign-in, this identifies that the user already
    /// passed the first factor challenge.
    /// - Parameter completion: The callback to be invoked when the verification flow is finished.
    @objc(verifyPhoneNumber:UIDelegate:multiFactorSession:completion:)
    open func verifyPhoneNumber(_ phoneNumber: String,
                                uiDelegate: AuthUIDelegate? = nil,
                                multiFactorSession: MultiFactorSession? = nil,
                                completion: ((_: String?, _: Error?) -> Void)?) {
      guard AuthWebUtils.isCallbackSchemeRegistered(forCustomURLScheme: callbackScheme,
                                                    urlTypes: auth.mainBundleUrlTypes) else {
        fatalError(
          "Please register custom URL scheme \(callbackScheme) in the app's Info.plist file."
        )
      }
      kAuthGlobalWorkQueue.async {
        Task {
          do {
            let verificationID = try await self.internalVerify(
              phoneNumber: phoneNumber,
              uiDelegate: uiDelegate,
              multiFactorSession: multiFactorSession
            )
            Auth.wrapMainAsync(callback: completion, withParam: verificationID, error: nil)
          } catch {
            Auth.wrapMainAsync(callback: completion, withParam: nil, error: error)
          }
        }
      }
    }

    /// Verify ownership of the second factor phone number by the current user.
    /// - Parameter phoneNumber: The phone number to be verified.
    /// - Parameter uiDelegate: An object used to present the SFSafariViewController. The object is
    /// retained by this method until the completion block is executed.
    /// - Parameter multiFactorSession: A session to identify the MFA flow. For enrollment, this
    /// identifies the user trying to enroll. For sign-in, this identifies that the user already
    /// passed the first factor challenge.
    /// - Returns: The verification ID
    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    open func verifyPhoneNumber(_ phoneNumber: String,
                                uiDelegate: AuthUIDelegate? = nil,
                                multiFactorSession: MultiFactorSession? = nil) async throws
      -> String {
      return try await withCheckedThrowingContinuation { continuation in
        self.verifyPhoneNumber(phoneNumber,
                               uiDelegate: uiDelegate,
                               multiFactorSession: multiFactorSession) { result, error in
          if let error {
            continuation.resume(throwing: error)
          } else if let result {
            continuation.resume(returning: result)
          }
        }
      }
    }

    /// Verify ownership of the second factor phone number by the current user.
    /// - Parameter multiFactorInfo: The phone multi factor whose number need to be verified.
    /// - Parameter uiDelegate: An object used to present the SFSafariViewController. The object is
    /// retained by this method until the completion block is executed.
    /// - Parameter multiFactorSession: A session to identify the MFA flow. For enrollment, this
    /// identifies the user trying to enroll. For sign-in, this identifies that the user already
    /// passed the first factor challenge.
    /// - Parameter completion: The callback to be invoked when the verification flow is finished.
    @objc(verifyPhoneNumberWithMultiFactorInfo:UIDelegate:multiFactorSession:completion:)
    open func verifyPhoneNumber(with multiFactorInfo: PhoneMultiFactorInfo,
                                uiDelegate: AuthUIDelegate? = nil,
                                multiFactorSession: MultiFactorSession?,
                                completion: ((_: String?, _: Error?) -> Void)?) {
      multiFactorSession?.multiFactorInfo = multiFactorInfo
      verifyPhoneNumber(multiFactorInfo.phoneNumber,
                        uiDelegate: uiDelegate,
                        multiFactorSession: multiFactorSession,
                        completion: completion)
    }

    /// Verify ownership of the second factor phone number by the current user.
    /// - Parameter multiFactorInfo: The phone multi factor whose number need to be verified.
    /// - Parameter uiDelegate: An object used to present the SFSafariViewController. The object is
    /// retained by this method until the completion block is executed.
    /// - Parameter multiFactorSession: A session to identify the MFA flow. For enrollment, this
    /// identifies the user trying to enroll. For sign-in, this identifies that the user already
    /// passed the first factor challenge.
    /// - Returns: The verification ID.
    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    open func verifyPhoneNumber(with multiFactorInfo: PhoneMultiFactorInfo,
                                uiDelegate: AuthUIDelegate? = nil,
                                multiFactorSession: MultiFactorSession?) async throws -> String {
      return try await withCheckedThrowingContinuation { continuation in
        self.verifyPhoneNumber(with: multiFactorInfo,
                               uiDelegate: uiDelegate,
                               multiFactorSession: multiFactorSession) { result, error in
          if let error {
            continuation.resume(throwing: error)
          } else if let result {
            continuation.resume(returning: result)
          }
        }
      }
    }

    /// Creates an `AuthCredential` for the phone number provider identified by the
    ///    verification ID and verification code.
    ///
    /// - Parameter verificationID: The verification ID obtained from invoking
    ///    verifyPhoneNumber:completion:
    /// - Parameter verificationCode: The verification code obtained from the user.
    /// - Returns: The corresponding phone auth credential for the verification ID and verification
    /// code provided.
    @objc(credentialWithVerificationID:verificationCode:)
    open func credential(withVerificationID verificationID: String,
                         verificationCode: String) -> PhoneAuthCredential {
      return PhoneAuthCredential(withProviderID: PhoneAuthProvider.id,
                                 verificationID: verificationID,
                                 verificationCode: verificationCode)
    }

    private func internalVerify(phoneNumber: String,
                                uiDelegate: AuthUIDelegate?,
                                multiFactorSession: MultiFactorSession? = nil) async throws
      -> String? {
      guard phoneNumber.count > 0 else {
        throw AuthErrorUtils.missingPhoneNumberError(message: nil)
      }
      guard let manager = auth.notificationManager else {
        throw AuthErrorUtils.notificationNotForwardedError()
      }
      guard await manager.checkNotificationForwarding() else {
        throw AuthErrorUtils.notificationNotForwardedError()
      }
      return try await verifyClAndSendVerificationCode(toPhoneNumber: phoneNumber,
                                                       retryOnInvalidAppCredential: true,
                                                       multiFactorSession: multiFactorSession,
                                                       uiDelegate: uiDelegate)
    }

    /// Starts the flow to verify the client via silent push notification.
    /// - Parameter retryOnInvalidAppCredential: Whether or not the flow should be retried if an
    ///  AuthErrorCodeInvalidAppCredential error is returned from the backend.
    /// - Parameter phoneNumber: The phone number to be verified.
    /// - Parameter callback: The callback to be invoked on the global work queue when the flow is
    /// finished.
    private func verifyClAndSendVerificationCode(toPhoneNumber phoneNumber: String,
                                                 retryOnInvalidAppCredential: Bool,
                                                 uiDelegate: AuthUIDelegate?) async throws
      -> String? {
      let codeIdentity = try await verifyClient(withUIDelegate: uiDelegate)
      let request = SendVerificationCodeRequest(phoneNumber: phoneNumber,
                                                codeIdentity: codeIdentity,
                                                requestConfiguration: auth
                                                  .requestConfiguration)

      do {
        let response = try await AuthBackend.call(with: request)
        return response.verificationID
      } catch {
        return try await handleVerifyErrorWithRetry(error: error,
                                                    phoneNumber: phoneNumber,
                                                    retryOnInvalidAppCredential: retryOnInvalidAppCredential,
                                                    multiFactorSession: nil,
                                                    uiDelegate: uiDelegate)
      }
    }

    /// Starts the flow to verify the client via silent push notification.
    /// - Parameter retryOnInvalidAppCredential: Whether of not the flow should be retried if an
    /// AuthErrorCodeInvalidAppCredential error is returned from the backend.
    /// - Parameter phoneNumber: The phone number to be verified.
    private func verifyClAndSendVerificationCode(toPhoneNumber phoneNumber: String,
                                                 retryOnInvalidAppCredential: Bool,
                                                 multiFactorSession session: MultiFactorSession?,
                                                 uiDelegate: AuthUIDelegate?) async throws
      -> String? {
      if let settings = auth.settings,
         settings.isAppVerificationDisabledForTesting {
        let request = SendVerificationCodeRequest(
          phoneNumber: phoneNumber,
          codeIdentity: CodeIdentity.empty,
          requestConfiguration: auth.requestConfiguration
        )

        let response = try await AuthBackend.call(with: request)
        return response.verificationID
      }
      guard let session else {
        return try await verifyClAndSendVerificationCode(
          toPhoneNumber: phoneNumber,
          retryOnInvalidAppCredential: retryOnInvalidAppCredential,
          uiDelegate: uiDelegate
        )
      }
      let codeIdentity = try await verifyClient(withUIDelegate: uiDelegate)
      let startMFARequestInfo = AuthProtoStartMFAPhoneRequestInfo(phoneNumber: phoneNumber,
                                                                  codeIdentity: codeIdentity)
      do {
        if let idToken = session.idToken {
          let request = StartMFAEnrollmentRequest(idToken: idToken,
                                                  enrollmentInfo: startMFARequestInfo,
                                                  requestConfiguration: auth.requestConfiguration)
          let response = try await AuthBackend.call(with: request)
          return response.phoneSessionInfo?.sessionInfo
        } else {
          let request = StartMFASignInRequest(MFAPendingCredential: session.mfaPendingCredential,
                                              MFAEnrollmentID: session.multiFactorInfo?.uid,
                                              signInInfo: startMFARequestInfo,
                                              requestConfiguration: auth.requestConfiguration)

          let response = try await AuthBackend.call(with: request)
          return response.responseInfo?.sessionInfo
        }
      } catch {
        return try await handleVerifyErrorWithRetry(
          error: error,
          phoneNumber: phoneNumber,
          retryOnInvalidAppCredential: retryOnInvalidAppCredential,
          multiFactorSession: session,
          uiDelegate: uiDelegate
        )
      }
    }

    private func handleVerifyErrorWithRetry(error: Error,
                                            phoneNumber: String,
                                            retryOnInvalidAppCredential: Bool,
                                            multiFactorSession session: MultiFactorSession?,
                                            uiDelegate: AuthUIDelegate?) async throws -> String? {
      if (error as NSError).code == AuthErrorCode.invalidAppCredential.rawValue {
        if retryOnInvalidAppCredential {
          auth.appCredentialManager.clearCredential()
          return try await verifyClAndSendVerificationCode(toPhoneNumber: phoneNumber,
                                                           retryOnInvalidAppCredential: false,
                                                           multiFactorSession: session,
                                                           uiDelegate: uiDelegate)
        }
        throw AuthErrorUtils.unexpectedResponse(deserializedResponse: nil, underlyingError: error)
      }
      throw error
    }

    /// Continues the flow to verify the client via silent push notification.
    private func verifyClient(withUIDelegate uiDelegate: AuthUIDelegate?) async throws
      -> CodeIdentity {
      // Remove the simulator check below after FCM supports APNs in simulators
      #if targetEnvironment(simulator)
        let environment = ProcessInfo().environment
        if environment["XCTestConfigurationFilePath"] == nil {
          return try await CodeIdentity
            .recaptcha(reCAPTCHAFlowWithUIDelegate(withUIDelegate: uiDelegate))
        }
      #endif
      if let credential = auth.appCredentialManager.credential {
        return CodeIdentity.credential(credential)
      }
      var token: AuthAPNSToken
      do {
        token = try await auth.tokenManager.getToken()
      } catch {
        return try await CodeIdentity
          .recaptcha(reCAPTCHAFlowWithUIDelegate(withUIDelegate: uiDelegate))
      }
      let request = VerifyClientRequest(withAppToken: token.string,
                                        isSandbox: token.type == AuthAPNSTokenType.sandbox,
                                        requestConfiguration: auth.requestConfiguration)
      do {
        let verifyResponse = try await AuthBackend.call(with: request)
        guard let receipt = verifyResponse.receipt,
              let timeout = verifyResponse.suggestedTimeOutDate?.timeIntervalSinceNow else {
          fatalError("Internal Auth Error: invalid VerifyClientResponse")
        }
        let credential = await
          auth.appCredentialManager.didStartVerification(withReceipt: receipt, timeout: timeout)
        if credential.secret == nil {
          AuthLog.logWarning(code: "I-AUT000014", message: "Failed to receive remote " +
            "notification to verify app identity within \(timeout) " +
            "second(s), falling back to reCAPTCHA verification.")
          return try await CodeIdentity
            .recaptcha(reCAPTCHAFlowWithUIDelegate(withUIDelegate: uiDelegate))
        }
        return CodeIdentity.credential(credential)
      } catch {
        let nserror = error as NSError
        // reCAPTCHA Flow if it's an invalid app credential or a missing app token.
        guard nserror.code == AuthErrorCode.invalidAppCredential.rawValue || nserror
          .code == AuthErrorCode.missingAppToken.rawValue else {
          throw error
        }
        return try await CodeIdentity
          .recaptcha(reCAPTCHAFlowWithUIDelegate(withUIDelegate: uiDelegate))
      }
    }

    /// Continues the flow to verify the client via silent push notification.
    private func reCAPTCHAFlowWithUIDelegate(withUIDelegate uiDelegate: AuthUIDelegate?) async throws
      -> String {
      let eventID = AuthWebUtils.randomString(withLength: 10)
      guard let url = try await reCAPTCHAURL(withEventID: eventID) else {
        fatalError(
          "Internal error: reCAPTCHAURL returned neither a value nor an error. Report issue"
        )
      }
      let callbackMatcher: (URL?) -> Bool = { callbackURL in
        AuthWebUtils.isExpectedCallbackURL(
          callbackURL,
          eventID: eventID,
          authType: self.kAuthTypeVerifyApp,
          callbackScheme: self.callbackScheme
        )
      }

      return try await withCheckedThrowingContinuation { continuation in
        self.auth.authURLPresenter.present(url,
                                           uiDelegate: uiDelegate,
                                           callbackMatcher: callbackMatcher) { callbackURL, error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            do {
              try continuation.resume(returning: self.reCAPTCHAToken(forURL: callbackURL))
            } catch {
              continuation.resume(throwing: error)
            }
          }
        }
      }
    }

    /// Parses the reCAPTCHA URL and returns the reCAPTCHA token.
    /// - Parameter url: The url to be parsed for a reCAPTCHA token.
    /// - Returns: The reCAPTCHA token if successful.
    private func reCAPTCHAToken(forURL url: URL?) throws -> String {
      guard let url = url else {
        let reason = "Internal Auth Error: nil URL trying to access RECAPTCHA token"
        throw AuthErrorUtils.appVerificationUserInteractionFailure(reason: reason)
      }
      let actualURLComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
      if let queryItems = actualURLComponents?.queryItems,
         let deepLinkURL = AuthWebUtils.queryItemValue(name: "deep_link_id", from: queryItems) {
        let deepLinkComponents = URLComponents(string: deepLinkURL)
        if let queryItems = deepLinkComponents?.queryItems {
          if let token = AuthWebUtils.queryItemValue(name: "recaptchaToken", from: queryItems) {
            return token
          }
          if let firebaseError = AuthWebUtils.queryItemValue(
            name: "firebaseError",
            from: queryItems
          ) {
            if let errorData = firebaseError.data(using: .utf8) {
              var errorDict: [AnyHashable: Any]?
              do {
                errorDict = try JSONSerialization.jsonObject(with: errorData) as? [AnyHashable: Any]
              } catch {
                throw AuthErrorUtils.JSONSerializationError(underlyingError: error)
              }
              if let errorDict,
                 let code = errorDict["code"] as? String,
                 let message = errorDict["message"] as? String {
                throw AuthErrorUtils.urlResponseError(code: code, message: message)
              }
            }
          }
        }
        let reason = "An unknown error occurred with the following response: \(deepLinkURL)"
        throw AuthErrorUtils.appVerificationUserInteractionFailure(reason: reason)
      }
      let reason = "Failed to get url Components for url: \(url)"
      throw AuthErrorUtils.appVerificationUserInteractionFailure(reason: reason)
    }

    /// Constructs a URL used for opening a reCAPTCHA app verification flow using a given event ID.
    /// - Parameter eventID: The event ID used for this purpose.
    private func reCAPTCHAURL(withEventID eventID: String) async throws -> URL? {
      let authDomain = try await AuthWebUtils
        .fetchAuthDomain(withRequestConfiguration: auth.requestConfiguration)
      let bundleID = Bundle.main.bundleIdentifier
      let clientID = auth.app?.options.clientID
      let appID = auth.app?.options.googleAppID
      let apiKey = auth.requestConfiguration.apiKey
      let appCheck = auth.requestConfiguration.appCheck
      var queryItems = [URLQueryItem(name: "apiKey", value: apiKey),
                        URLQueryItem(name: "authType", value: kAuthTypeVerifyApp),
                        URLQueryItem(name: "ibi", value: bundleID ?? ""),
                        URLQueryItem(name: "v", value: AuthBackend.authUserAgent()),
                        URLQueryItem(name: "eventId", value: eventID)]
      if usingClientIDScheme {
        queryItems.append(URLQueryItem(name: "clientId", value: clientID))
      } else {
        queryItems.append(URLQueryItem(name: "appId", value: appID))
      }
      if let languageCode = auth.requestConfiguration.languageCode {
        queryItems.append(URLQueryItem(name: "hl", value: languageCode))
      }
      var components = URLComponents(string: "https://\(authDomain)/__/auth/handler?")
      components?.queryItems = queryItems

      if let appCheck {
        let tokenResult = await appCheck.getToken(forcingRefresh: false)
        if let error = tokenResult.error {
          AuthLog.logWarning(code: "I-AUT000018",
                             message: "Error getting App Check token; using placeholder " +
                               "token instead. Error: \(error)")
        }
        let appCheckTokenFragment = "fac=\(tokenResult.token)"
        components?.fragment = appCheckTokenFragment
      }
      return components?.url
    }

    private let auth: Auth
    private let callbackScheme: String
    private let usingClientIDScheme: Bool

    init(auth: Auth) {
      self.auth = auth
      if let clientID = auth.app?.options.clientID {
        let reverseClientIDScheme = clientID.components(separatedBy: ".").reversed()
          .joined(separator: ".")
        if AuthWebUtils.isCallbackSchemeRegistered(forCustomURLScheme: reverseClientIDScheme,
                                                   urlTypes: auth.mainBundleUrlTypes) {
          callbackScheme = reverseClientIDScheme
          usingClientIDScheme = true
          return
        }
      }
      usingClientIDScheme = false
      if let appID = auth.app?.options.googleAppID {
        let dashedAppID = appID.replacingOccurrences(of: ":", with: "-")
        callbackScheme = "app-\(dashedAppID)"
        return
      }
      callbackScheme = ""
    }

    private let kAuthTypeVerifyApp = "verifyApp"
  #endif
}
