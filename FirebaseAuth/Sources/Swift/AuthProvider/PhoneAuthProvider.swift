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
import FirebaseCore

/**
 @brief A concrete implementation of `AuthProvider` for phone auth providers.
     This class is available on iOS only.
 */
@objc(FIRPhoneAuthProvider) open class PhoneAuthProvider: NSObject {
  @objc public static let id = "phone"
  #if os(iOS)
    /**
     @brief Returns an instance of `PhoneAuthProvider` for the default `Auth` object.
     */
    @objc(provider) public class func provider() -> PhoneAuthProvider {
      return PhoneAuthProvider(auth: Auth.auth())
    }

    /**
     @brief Returns an instance of `PhoneAuthProvider` for the provided `Auth` object.
     @param auth The auth object to associate with the phone auth provider instance.
     */
    @objc(providerWithAuth:)
    public class func provider(auth: Auth) -> PhoneAuthProvider {
      return PhoneAuthProvider(auth: auth)
    }

    // TODO: review/remove public objc

    /**
     @brief Starts the phone number authentication flow by sending a verification code to the
     specified phone number.
     @param phoneNumber The phone number to be verified.
     @param uiDelegate An object used to present the SFSafariViewController. The object is retained
     by this method until the completion block is executed.
     @param completion The callback to be invoked when the verification flow is finished.
     @remarks Possible error codes:

     + `AuthErrorCodeCaptchaCheckFailed` - Indicates that the reCAPTCHA token obtained by
     the Firebase Auth is invalid or has expired.
     + `AuthErrorCodeQuotaExceeded` - Indicates that the phone verification quota for this
     project has been exceeded.
     + `AuthErrorCodeInvalidPhoneNumber` - Indicates that the phone number provided is
     invalid.
     + `AuthErrorCodeMissingPhoneNumber` - Indicates that a phone number was not provided.
     */
    @objc(verifyPhoneNumber:UIDelegate:completion:)
    public func verifyPhoneNumber(_ phoneNumber: String,
                                  uiDelegate: AuthUIDelegate?,
                                  completion: ((_: String?, _: Error?) -> Void)?) {
      guard AuthWebUtils.isCallbackSchemeRegistered(forCustomURLScheme: callbackScheme,
                                                    urlTypes: auth.mainBundleUrlTypes) else {
        fatalError(
          "Please register custom URL scheme \(callbackScheme) in the app's Info.plist file."
        )
      }
      kAuthGlobalWorkQueue.async {
        let callbackOnMainThread: (String?, Error?) -> Void = { verificationID, error in
          if let completion {
            DispatchQueue.main.async {
              completion(verificationID, error)
            }
          }
        }
        self.internalVerify(phoneNumber: phoneNumber,
                            uiDelegate: uiDelegate) { verificationID, error in
          if let error {
            callbackOnMainThread(nil, error)
          } else {
            callbackOnMainThread(verificationID, nil)
          }
        }
      }
    }

    /**
     @brief Verify ownership of the second factor phone number by the current user.
     @param phoneNumber The phone number to be verified.
     @param uiDelegate An object used to present the SFSafariViewController. The object is retained
     by this method until the completion block is executed.
     @param multiFactorSession A session to identify the MFA flow. For enrollment, this identifies the user
     trying to enroll. For sign-in, this identifies that the user already passed the first
     factor challenge.
     @param completion The callback to be invoked when the verification flow is finished.
     */

    @objc(verifyPhoneNumber:UIDelegate:multiFactorSession:completion:)
    public func verifyPhoneNumber(_ phoneNumber: String,
                                  uiDelegate: AuthUIDelegate?,
                                  multiFactorSession session: MultiFactorSession? = nil,
                                  completion: ((_: String?, _: Error?) -> Void)?) {
      guard let session else {
        verifyPhoneNumber(phoneNumber, uiDelegate: uiDelegate, completion: completion)
        return
      }
      guard AuthWebUtils.isCallbackSchemeRegistered(forCustomURLScheme: callbackScheme,
                                                    urlTypes: auth.mainBundleUrlTypes) else {
        fatalError(
          "Please register custom URL scheme \(callbackScheme) in the app's Info.plist file."
        )
      }
      kAuthGlobalWorkQueue.async {
        let callbackOnMainThread: (String?, Error?) -> Void = { verificationID, error in
          if let completion {
            DispatchQueue.main.async {
              completion(verificationID, error)
            }
          }
        }
        self.internalVerify(phoneNumber: phoneNumber,
                            uiDelegate: uiDelegate,
                            multiFactorSession: session) { verificationID, error in
          if let error {
            callbackOnMainThread(nil, error)
          } else {
            callbackOnMainThread(verificationID, nil)
          }
        }
      }
    }

    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    public func verifyPhoneNumber(_ phoneNumber: String,
                                  uiDelegate: AuthUIDelegate?,
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

    /**
         @brief Verify ownership of the second factor phone number by the current user.
         @param multiFactorInfo The phone multi factor whose number need to be verified.
         @param uiDelegate An object used to present the SFSafariViewController. The object is retained
             by this method until the completion block is executed.
         @param multiFactorSession A session to identify the MFA flow. For enrollment, this identifies the user
             trying to enroll. For sign-in, this identifies that the user already passed the first
             factor challenge.
         @param completion The callback to be invoked when the verification flow is finished.
     */
    @objc(verifyPhoneNumberWithMultiFactorInfo:UIDelegate:multiFactorSession:completion:)
    public func verifyPhoneNumber(with multiFactorInfo: PhoneMultiFactorInfo,
                                  uiDelegate: AuthUIDelegate?,
                                  multiFactorSession session: MultiFactorSession?,
                                  completion: ((_: String?, _: Error?) -> Void)?) {
      session?.multiFactorInfo = multiFactorInfo
      verifyPhoneNumber(multiFactorInfo.phoneNumber,
                        uiDelegate: uiDelegate,
                        multiFactorSession: session,
                        completion: completion)
    }

    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    public func verifyPhoneNumber(with multiFactorInfo: PhoneMultiFactorInfo,
                                  uiDelegate: AuthUIDelegate?,
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

    /**
        @brief Creates an `AuthCredential` for the phone number provider identified by the
            verification ID and verification code.

        @param verificationID The verification ID obtained from invoking
            verifyPhoneNumber:completion:
        @param verificationCode The verification code obtained from the user.
        @return The corresponding phone auth credential for the verification ID and verification code
            provided.
     */
    @objc(credentialWithVerificationID:verificationCode:)
    public func credential(withVerificationID verificationID: String,
                           verificationCode: String) -> PhoneAuthCredential {
      return PhoneAuthCredential(withProviderID: PhoneAuthProvider.id,
                                 verificationID: verificationID,
                                 verificationCode: verificationCode)
    }

    private func internalVerify(phoneNumber: String,
                                uiDelegate: AuthUIDelegate?,
                                multiFactorSession session: MultiFactorSession? = nil,
                                completion: @escaping ((String?, Error?) -> Void)) {
      guard phoneNumber.count > 0 else {
        completion(nil, AuthErrorUtils.missingPhoneNumberError(message: nil))
        return
      }
      auth.notificationManager.checkNotificationForwarding { isNotificationBeingForwarded in
        guard isNotificationBeingForwarded else {
          completion(nil, AuthErrorUtils.notificationNotForwardedError())
          return
        }
        self.verifyClAndSendVerificationCode(toPhoneNumber: phoneNumber,
                                             retryOnInvalidAppCredential: true,
                                             multiFactorSession: session,
                                             uiDelegate: uiDelegate) { verificationID, error in
          completion(verificationID, error)
        }
      }
    }

    /** @fn
     @brief Starts the flow to verify the client via silent push notification.
     @param retryOnInvalidAppCredential Whether of not the flow should be retried if an
       AuthErrorCodeInvalidAppCredential error is returned from the backend.
     @param phoneNumber The phone number to be verified.
     @param callback The callback to be invoked on the global work queue when the flow is
     finished.
     */
    private func verifyClAndSendVerificationCode(toPhoneNumber phoneNumber: String,
                                                 retryOnInvalidAppCredential: Bool,
                                                 uiDelegate: AuthUIDelegate?,
                                                 callback: @escaping (String?, Error?) -> Void) {
      verifyClient(withUIDelegate: uiDelegate) { appCredential, reCAPTCHAToken, error in
        if let error {
          callback(nil, error)
          return
        }
        var request: SendVerificationCodeRequest?
        if let appCredential {
          request = SendVerificationCodeRequest(phoneNumber: phoneNumber,
                                                appCredential: appCredential,
                                                reCAPTCHAToken: nil,
                                                requestConfiguration: self.auth
                                                  .requestConfiguration)
        } else if let reCAPTCHAToken {
          request = SendVerificationCodeRequest(phoneNumber: phoneNumber,
                                                appCredential: nil,
                                                reCAPTCHAToken: reCAPTCHAToken,
                                                requestConfiguration: self.auth
                                                  .requestConfiguration)
        } else {
          fatalError("Internal Phone Auth Error:Both reCAPTCHA token and app credential are nil")
        }
        if let request {
          AuthBackend.post(with: request) { response, error in
            if let error {
              self.handleVerifyErrorWithRetry(error: error,
                                              phoneNumber: phoneNumber,
                                              retryOnInvalidAppCredential: retryOnInvalidAppCredential,
                                              multiFactorSession: nil,
                                              uiDelegate: uiDelegate,
                                              callback: callback)
              return
            }
            callback(response?.verificationID, nil)
          }
        }
      }
    }

    /** @fn
     @brief Starts the flow to verify the client via silent push notification.
     @param retryOnInvalidAppCredential Whether of not the flow should be retried if an
       AuthErrorCodeInvalidAppCredential error is returned from the backend.
     @param phoneNumber The phone number to be verified.
     @param callback The callback to be invoked on the global work queue when the flow is
     finished.
     */
    private func verifyClAndSendVerificationCode(toPhoneNumber phoneNumber: String,
                                                 retryOnInvalidAppCredential: Bool,
                                                 multiFactorSession session: MultiFactorSession?,
                                                 uiDelegate: AuthUIDelegate?,
                                                 callback: @escaping (String?, Error?) -> Void) {
      if let settings = auth.settings,
         settings.isAppVerificationDisabledForTesting {
        let request = SendVerificationCodeRequest(
          phoneNumber: phoneNumber,
          appCredential: nil,
          reCAPTCHAToken: nil,
          requestConfiguration: auth.requestConfiguration
        )

        AuthBackend.post(with: request) { response, error in
          callback(response?.verificationID, error)
        }
        return
      }
      guard let session else {
        verifyClAndSendVerificationCode(toPhoneNumber: phoneNumber,
                                        retryOnInvalidAppCredential: retryOnInvalidAppCredential,
                                        uiDelegate: uiDelegate,
                                        callback: callback)
        return
      }

      verifyClient(withUIDelegate: uiDelegate) { appCredential, reCAPTCHAToken, error in
        if let error {
          callback(nil, error)
          return
        }
        let startMFARequestInfo = AuthProtoStartMFAPhoneRequestInfo(phoneNumber: phoneNumber,
                                                                    appCredential: appCredential,
                                                                    reCAPTCHAToken: reCAPTCHAToken)

        // XXX TODO: Figure out the right logic here, where we're assuming the callback is a certain
        // type.
        let request: any AuthRPCRequest = (session.idToken != nil) ?
          StartMFAEnrollmentRequest(idToken: session.idToken,
                                    enrollmentInfo: startMFARequestInfo,
                                    requestConfiguration: self.auth.requestConfiguration) :
          StartMFASignInRequest(MFAPendingCredential: session.mfaPendingCredential,
                                MFAEnrollmentID: session.multiFactorInfo?.uid,
                                signInInfo: startMFARequestInfo,
                                requestConfiguration: self.auth.requestConfiguration)

        AuthBackend.post(with: request) { response, error in
          if let error {
            self.handleVerifyErrorWithRetry(error: error,
                                            phoneNumber: phoneNumber,
                                            retryOnInvalidAppCredential: retryOnInvalidAppCredential,
                                            multiFactorSession: session,
                                            uiDelegate: uiDelegate,
                                            callback: callback)
            return
          }
          callback((response as? StartMFAEnrollmentResponse)?.enrollmentResponse?.sessionInfo, nil)
        }
      }
    }

    private func handleVerifyErrorWithRetry(error: Error,
                                            phoneNumber: String,
                                            retryOnInvalidAppCredential: Bool,
                                            multiFactorSession session: MultiFactorSession?,
                                            uiDelegate: AuthUIDelegate?,
                                            callback: @escaping (String?, Error?) -> Void) {
      if (error as NSError).code == AuthErrorCode.invalidAppCredential.rawValue {
        if retryOnInvalidAppCredential {
          auth.appCredentialManager.clearCredential()
          verifyClAndSendVerificationCode(toPhoneNumber: phoneNumber,
                                          retryOnInvalidAppCredential: false,
                                          multiFactorSession: session,
                                          uiDelegate: uiDelegate,
                                          callback: callback)
          return
        }
        callback(nil, AuthErrorUtils.unexpectedResponse(deserializedResponse: nil,
                                                        underlyingError: error))
        return
      }
      callback(nil, error)
    }

    /** @fn
     @brief Continues the flow to verify the client via silent push notification.
     @param completion The callback to be invoked when the client verification flow is finished.
     */
    private func verifyClient(withUIDelegate uiDelegate: AuthUIDelegate?,
                              completion: @escaping (AuthAppCredential?, String?, Error?) -> Void) {
      // Remove the simulator check below after FCM supports APNs in simulators
      #if targetEnvironment(simulator)
        let environment = ProcessInfo().environment
        if environment["XCTestConfigurationFilePath"] == nil {
          reCAPTCHAFlowWithUIDelegate(withUIDelegate: uiDelegate, completion: completion)
          return
        }
      #endif
      if let credential = auth.appCredentialManager.credential {
        completion(credential, nil, nil)
        return
      }
      auth.tokenManager.getToken { token, error in
        guard let token else {
          self.reCAPTCHAFlowWithUIDelegate(withUIDelegate: uiDelegate, completion: completion)
          return
        }
        let request = VerifyClientRequest(withAppToken: token.string,
                                          isSandbox: token.type == AuthAPNSTokenType.sandbox,
                                          requestConfiguration: self.auth.requestConfiguration)
        AuthBackend.post(with: request) { response, error in
          if let error {
            let nserror = error as NSError
            // reCAPTCHA Flow if it's an invalid app credential or a missing app token.
            if (nserror.code == AuthErrorCode.internalError.rawValue &&
              (nserror.userInfo[NSUnderlyingErrorKey] as? NSError)?.code ==
              AuthErrorCode.invalidAppCredential.rawValue) ||
              nserror.code == AuthErrorCode.missingAppToken.rawValue {
              self.reCAPTCHAFlowWithUIDelegate(withUIDelegate: uiDelegate, completion: completion)
              return
            } else {
              completion(nil, nil, error)
              return
            }
          }
          guard let verifyResponse = response,
                let receipt = verifyResponse.receipt,
                let timeout = verifyResponse.suggestedTimeOutDate?.timeIntervalSinceNow else {
            fatalError("Internal Auth Error: invalid VerifyClientResponse")
          }
          self.auth.appCredentialManager.didStartVerification(withReceipt: receipt,
                                                              timeout: timeout) { credential in
            if credential.secret == nil {
              AuthLog.logWarning(code: "I-AUT000014", message: "Failed to receive remote " +
                "notification to verify app identity within \(timeout) " +
                "second(s), falling back to reCAPTCHA verification.")
              self.reCAPTCHAFlowWithUIDelegate(withUIDelegate: uiDelegate, completion: completion)
              return
            }
            completion(credential, nil, nil)
          }
        }
      }
    }

    /** @fn
     @brief Continues the flow to verify the client via silent push notification.
     @param completion The callback to be invoked when the client verification flow is finished.
     */
    private func reCAPTCHAFlowWithUIDelegate(withUIDelegate uiDelegate: AuthUIDelegate?,
                                             completion: @escaping (AuthAppCredential?, String?,
                                                                    Error?) -> Void) {
      let eventID = AuthWebUtils.randomString(withLength: 10)
      reCAPTCHAURL(withEventID: eventID) { reCAPTCHAURL, error in
        if let error = error {
          completion(nil, nil, error)
          return
        }
        guard let reCAPTCHAURL = reCAPTCHAURL else {
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
        self.auth.authURLPresenter.present(reCAPTCHAURL,
                                           uiDelegate: uiDelegate,
                                           callbackMatcher: callbackMatcher) { callbackURL, error in
          if let error = error {
            completion(nil, nil, error)
            return
          }
          do {
            let reCAPTHAtoken = try self.reCAPTCHAToken(forURL: callbackURL)
            completion(nil, reCAPTHAtoken, nil)
          } catch {
            completion(nil, nil, error)
          }
        }
      }
    }

    /**
     @brief Parses the reCAPTCHA URL and returns the reCAPTCHA token.
     @param URL The url to be parsed for a reCAPTCHA token.
     @param error The error that occurred if any.
     @return The reCAPTCHA token if successful.
     */
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

    /** @fn
     @brief Constructs a URL used for opening a reCAPTCHA app verification flow using a given event
     ID.
     @param eventID The event ID used for this purpose.
     @param completion The callback invoked after the URL has been constructed or an error
     has been encountered.
     */
    private func reCAPTCHAURL(withEventID eventID: String,
                              completion: @escaping ((URL?, Error?) -> Void)) {
      AuthWebUtils
        .fetchAuthDomain(withRequestConfiguration: auth.requestConfiguration) { authDomain, error in
          if let error = error {
            completion(nil, error)
            return
          }
          if let authDomain = authDomain {
            let bundleID = Bundle.main.bundleIdentifier
            let clientID = self.auth.app?.options.clientID
            let appID = self.auth.app?.options.googleAppID
            let apiKey = self.auth.requestConfiguration.apiKey
            let appCheck = self.auth.requestConfiguration.appCheck
            var queryItems = [URLQueryItem(name: "apiKey", value: apiKey),
                              URLQueryItem(name: "authType", value: self.kAuthTypeVerifyApp),
                              URLQueryItem(name: "ibi", value: bundleID ?? ""),
                              URLQueryItem(name: "v", value: AuthBackend.authUserAgent()),
                              URLQueryItem(name: "eventId", value: eventID)]
            if self.usingClientIDScheme {
              queryItems.append(URLQueryItem(name: "clientId", value: clientID))
            } else {
              queryItems.append(URLQueryItem(name: "appId", value: appID))
            }
            if let languageCode = self.auth.requestConfiguration.languageCode {
              queryItems.append(URLQueryItem(name: "hl", value: languageCode))
            }
            var components = URLComponents(string: "https://\(authDomain)/__/auth/handler?")
            components?.queryItems = queryItems

            if let appCheck {
              appCheck.getToken(forcingRefresh: false) { tokenResult in
                if let error = tokenResult.error {
                  AuthLog.logWarning(code: "I-AUT000018",
                                     message: "Error getting App Check token; using placeholder " +
                                       "token instead. Error: \(error)")
                }
                let appCheckTokenFragment = "fac=\(tokenResult.token)"
                components?.fragment = appCheckTokenFragment
                completion(components?.url, nil)
              }
            } else {
              completion(components?.url, nil)
            }
          }
        }
    }

    private let auth: Auth
    private let callbackScheme: String
    private let usingClientIDScheme: Bool

    private init(auth: Auth) {
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
