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
@_implementationOnly import FirebaseCore

// When building for CocoaPods, non-public headers are exposed to Swift via a
// private module map.
#if COCOAPODS
  @_implementationOnly import FirebaseAuth_Private
#endif // COCOAPODS

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
      Auth.globalWorkQueue().async {
        let callbackOnMainThread = {}
      }
    }

    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    public func verifyPhoneNumber(_ phoneNumber: String,
                                  uiDelegate: AuthUIDelegate?) async throws -> String {
      return try await withCheckedThrowingContinuation { continuation in
        self.verifyPhoneNumber(phoneNumber, uiDelegate: uiDelegate) { result, error in
          if let error {
            continuation.resume(throwing: error)
          } else if let result {
            continuation.resume(returning: result)
          }
        }
      }
    }

    private func internalVerify(phoneNumber: String,
                                UIDelegate: AuthUIDelegate,
                                completion: ((String?, Error?) -> Void)?) {
      guard phoneNumber.count > 0 else {
        if let completion = completion {
          completion(nil, AuthErrorUtils.missingPhoneNumberError(message: nil))
        }
        return
      }
      auth.notificationManager.checkNotificationForwarding { isNotificationBeingForwarded in
        guard isNotificationBeingForwarded else {
          if let completion = completion {
            completion(nil, AuthErrorUtils.notificationNotForwardedError())
          }
          return
        }
        self.verifyClAndSendVerificationCode(toPhoneNumber: phoneNumber,
                                             retryOnInvalidAppCredential: true,
                                             UIDelegate: UIDelegate) { verificationID, error in
          if let completion = completion {
            completion(verificationID, error)
          }
        }
      }
    }

    /** @fn
     @brief Starts the flow to verify the client via silent push notification.
     @param retryOnInvalidAppCredential Whether of not the flow should be retried if an
     FIRAuthErrorCodeInvalidAppCredential error is returned from the backend.
     @param phoneNumber The phone number to be verified.
     @param callback The callback to be invoked on the global work queue when the flow is
     finished.
     */
    private func verifyClAndSendVerificationCode(toPhoneNumber phoneNumber: String,
                                                 retryOnInvalidAppCredential: Bool,
                                                 UIDelegate: AuthUIDelegate,
                                                 callback: @escaping (String?, Error?) -> Void) {
      // TODO(ncooke3): Uncomment below lines when `FIRAuthBackend` is
      // written in Swift.
      //      if let settings = auth.settings,
      //         settings.isAppVerificationDisabledForTesting {
      //        let request = SendVerificationCodeRequest(
      //          phoneNumber: phoneNumber,
      //          appCredential: nil,
      //          reCAPTCHAToken: nil,
      //          requestConfiguration: auth.requestConfiguration
      //        )
      //
      //        FIRAuthBackend.sendVerificationCode(request) { response, error in
      //          callback(response?.verificationID, error)
      //        }
      //        return
      //      }
      // self.verifyClient(withUIDelegate ...
    }

    //  - (void)verifyClientAndSendVerificationCodeToPhoneNumber:(NSString *)phoneNumber
    //                               retryOnInvalidAppCredential:(BOOL)retryOnInvalidAppCredential
    //                                                UIDelegate:(nullable id<FIRAuthUIDelegate>)UIDelegate
    //                                                  callback:(FIRVerificationResultCallback)callback {

    //    [self
    //        verifyClientWithUIDelegate:UIDelegate
    //                        completion:^(FIRAuthAppCredential *_Nullable appCredential,
    //                                     NSString *_Nullable reCAPTCHAToken, NSError *_Nullable error) {
    //                          if (error) {
    //                            callback(nil, error);
    //                            return;
    //                          }
    //                          FIRSendVerificationCodeRequest *_Nullable request;
    //                          if (appCredential) {
    //                            request = [[FIRSendVerificationCodeRequest alloc]
    //                                 initWithPhoneNumber:phoneNumber
    //                                       appCredential:appCredential
    //                                      reCAPTCHAToken:nil
    //                                requestConfiguration:self->_auth.requestConfiguration];
    //                          } else if (reCAPTCHAToken) {
    //                            request = [[FIRSendVerificationCodeRequest alloc]
    //                                 initWithPhoneNumber:phoneNumber
    //                                       appCredential:nil
    //                                      reCAPTCHAToken:reCAPTCHAToken
    //                                requestConfiguration:self->_auth.requestConfiguration];
    //                          }
    //                          if (request) {
    //                            [FIRAuthBackend
    //                                sendVerificationCode:request
    //                                            callback:^(
    //                                                FIRSendVerificationCodeResponse *_Nullable response,
    //                                                NSError *_Nullable error) {
    //                                              if (error) {
    //                                                if (error.code ==
    //                                                    FIRAuthErrorCodeInvalidAppCredential) {
    //                                                  if (retryOnInvalidAppCredential) {
    //                                                    [self->_auth
    //                                                            .appCredentialManager clearCredential];
    //                                                    [self
    //                                                        verifyClientAndSendVerificationCodeToPhoneNumber:
    //                                                            phoneNumber
    //                                                                             retryOnInvalidAppCredential:
    //                                                                                 NO
    //                                                                                              UIDelegate:
    //                                                                                                  UIDelegate
    //                                                                                                callback:
    //                                                                                                    callback];
    //                                                    return;
    //                                                  }
    //                                                  callback(
    //                                                      nil,
    //                                                      [FIRAuthErrorUtils
    //                                                          unexpectedResponseWithDeserializedResponse:
    //                                                              nil
    //                                                                                     underlyingError:
    //                                                                                         error]);
    //                                                  return;
    //                                                }
    //                                                callback(nil, error);
    //                                                return;
    //                                              }
    //                                              callback(response.verificationID, nil);
    //                                            }];
    //                          }
    //                        }];
    //  }

    /** @fn
     @brief Continues the flow to verify the client via silent push notification.
     @param completion The callback to be invoked when the client verification flow is finished.
     */
    private func verifyClient(withUIDelegate UIDelegate: AuthUIDelegate,
                              completion: (AuthAppCredential?, Error?)) {
      // Remove the simulator check below after FCM supports APNs in simulators
      #if targetEnvironment(simulator)
        let environment = ProcessInfo().environment
        if environment["XCTestConfigurationFilePath"] == nil {
          // self.
        }
      #endif
    }

    /** @fn
     @brief Continues the flow to verify the client via silent push notification.
     @param completion The callback to be invoked when the client verification flow is finished.
     */
    private func reCAPTCHAFlowWithUIDelegate(withUIDelegate UIDelegate: AuthUIDelegate,
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
                                           uiDelegate: UIDelegate,
                                           callbackMatcher: callbackMatcher) { callbackURL, error in
          if let error = error {
            completion(nil, nil, error)
            return
          }
          let reCAPTHAtoken = self.reCAPTCHAToken
        }
      }
    }

    /**
     @brief Parses the reCAPTCHA URL and returns the reCAPTCHA token.
     @param URL The url to be parsed for a reCAPTCHA token.
     @param error The error that occurred if any.
     @return The reCAPTCHA token if successful.
     */
    private func reCAPTCHAToken(forURL url: URL, error: NSError) -> String? {
      let actualURLComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
      guard let queryItems = actualURLComponents?.queryItems else {
        return nil
      }
      guard let deepLinkURL = AuthWebUtils.queryItemValue(name: "deep_link_id", from: queryItems)
      else {
        return nil
      }
      let deepLinkComponents = URLComponents(string: deepLinkURL)
      if let queryItems = deepLinkComponents?.queryItems {
        return AuthWebUtils.queryItemValue(name: "recaptchaToken", from: queryItems)
      }
      return nil
    }

    //  - (nullable NSString *)reCAPTCHATokenForURL:(NSURL *)URL error:(NSError **_Nonnull)error {
    //    NSURLComponents *actualURLComponents = [NSURLComponents componentsWithURL:URL
    //                                                      resolvingAgainstBaseURL:NO];
    //    NSArray<NSURLQueryItem *> *queryItems = [actualURLComponents queryItems];
    //    NSString *deepLinkURL = [FIRAuthWebUtils queryItemValue:@"deep_link_id" from:queryItems];
    //    NSData *errorData;
    //    if (deepLinkURL) {
    //      actualURLComponents = [NSURLComponents componentsWithString:deepLinkURL];
    //      queryItems = [actualURLComponents queryItems];
    //      NSString *recaptchaToken = [FIRAuthWebUtils queryItemValue:@"recaptchaToken" from:queryItems];
    //      if (recaptchaToken) {
    //        return recaptchaToken;
    //      }
    //      NSString *firebaseError = [FIRAuthWebUtils queryItemValue:@"firebaseError" from:queryItems];
    //      errorData = [firebaseError dataUsingEncoding:NSUTF8StringEncoding];
    //    } else {
    //      errorData = nil;
    //    }
    //    if (error != NULL && errorData != nil) {
    //      NSError *jsonError;
    //      NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:errorData
    //                                                                options:0
    //                                                                  error:&jsonError];
    //      if (jsonError) {
    //        *error = [FIRAuthErrorUtils JSONSerializationErrorWithUnderlyingError:jsonError];
    //        return nil;
    //      }
    //      *error = [FIRAuthErrorUtils URLResponseErrorWithCode:errorDict[@"code"]
    //                                                   message:errorDict[@"message"]];
    //      if (!*error) {
    //        NSString *reason;
    //        if (errorDict[@"code"] && errorDict[@"message"]) {
    //          reason =
    //              [NSString stringWithFormat:@"[%@] - %@", errorDict[@"code"], errorDict[@"message"]];
    //        } else {
    //          reason = [NSString stringWithFormat:@"An unknown error occurred with the following "
    //                                               "response: %@",
    //                                              deepLinkURL];
    //        }
    //        *error = [FIRAuthErrorUtils appVerificationUserInteractionFailureWithReason:reason];
    //      }
    //    }
    //    return nil;
    //  }

    //                                completion:^(NSURL *_Nullable callbackURL, NSError *_Nullable error) {
    //                                  if (error) {
    //                                    completion(nil, nil, error);
    //                                    return;
    //                                  }
    //                                  NSError *reCAPTCHAError;
    //                                  NSString *reCAPTCHAToken =
    //                                      [self reCAPTCHATokenForURL:callbackURL error:&reCAPTCHAError];
    //                                  if (!reCAPTCHAToken) {
    //                                    completion(nil, nil, reCAPTCHAError);
    //                                    return;
    //                                  } else {
    //                                    completion(nil, reCAPTCHAToken, nil);
    //                                    return;
    //                                  }
    //                                }];
    //                     }];
    //  }

    // POp back up with ObjC below after this

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
            let apiKey = self.auth.requestConfiguration.APIKey
            var queryItems = [URLQueryItem(name: "apiKey", value: apiKey),
                              URLQueryItem(name: "authType", value: self.kAuthTypeVerifyApp),
                              URLQueryItem(name: "ibi", value: bundleID ?? ""),
                              URLQueryItem(name: "v", value: FIRAuthBackend.authUserAgent()),
                              URLQueryItem(name: "eventID", value: eventID)]
            if self.usingClientIDScheme {
              queryItems.append(URLQueryItem(name: "clientID", value: clientID))
            } else {
              queryItems.append(URLQueryItem(name: "appId", value: appID))
            }
            if let languageCode = self.auth.requestConfiguration.languageCode {
              queryItems.append(URLQueryItem(name: "hl", value: languageCode))
            }
            var components = URLComponents(string: "https://\(authDomain)/__/auth/handler?")
            components?.queryItems = queryItems
            if let url = components?.url {
              completion(url, nil)
            }
          }
        }
    }

    //  - (void)verifyClientWithUIDelegate:(nullable id<FIRAuthUIDelegate>)UIDelegate
    //                          completion:(FIRVerifyClientCallback)completion {
    //  // Remove the simulator check below after FCM supports APNs in simulators
    //  #if TARGET_OS_SIMULATOR
    //    if (@available(iOS 16, *)) {
    //      NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    //      if ((environment[@"XCTestConfigurationFilePath"] == nil)) {
    //        [self reCAPTCHAFlowWithUIDelegate:UIDelegate completion:completion];
    //        return;
    //      }
    //    }
    //  #endif
    //
    //    if (_auth.appCredentialManager.credential) {
    //      completion(_auth.appCredentialManager.credential, nil, nil);
    //      return;
    //    }
    //    [_auth.tokenManager getTokenWithCallback:^(FIRAuthAPNSToken *_Nullable token,
    //                                               NSError *_Nullable error) {
    //      if (!token) {
    //        [self reCAPTCHAFlowWithUIDelegate:UIDelegate completion:completion];
    //        return;
    //      }
    //      FIRVerifyClientRequest *request =
    //          [[FIRVerifyClientRequest alloc] initWithAppToken:token.string
    //                                                 isSandbox:token.type == FIRAuthAPNSTokenTypeSandbox
    //                                      requestConfiguration:self->_auth.requestConfiguration];
    //      [FIRAuthBackend
    //          verifyClient:request
    //              callback:^(FIRVerifyClientResponse *_Nullable response, NSError *_Nullable error) {
    //                if (error) {
    //                  NSError *underlyingError = error.userInfo[NSUnderlyingErrorKey];
    //                  BOOL isInvalidAppCredential =
    //                      error.code == FIRAuthErrorCodeInternalError &&
    //                      underlyingError.code == FIRAuthErrorCodeInvalidAppCredential;
    //                  if (error.code != FIRAuthErrorCodeMissingAppToken && !isInvalidAppCredential) {
    //                    completion(nil, nil, error);
    //                    return;
    //                  } else {
    //                    [self reCAPTCHAFlowWithUIDelegate:UIDelegate completion:completion];
    //                    return;
    //                  }
    //                }
    //                NSTimeInterval timeout = [response.suggestedTimeOutDate timeIntervalSinceNow];
    //                [self->_auth.appCredentialManager
    //                    didStartVerificationWithReceipt:response.receipt
    //                                            timeout:timeout
    //                                           callback:^(FIRAuthAppCredential *credential) {
    //                                             if (!credential.secret) {
    //                                               FIRLogWarning(kFIRLoggerAuth, @"I-AUT000014",
    //                                                             @"Failed to receive remote notification "
    //                                                             @"to verify app identity within "
    //                                                             @"%.0f second(s), falling back to "
    //                                                             @"reCAPTCHA verification.",
    //                                                             timeout);
    //                                               [self reCAPTCHAFlowWithUIDelegate:UIDelegate
    //                                                                      completion:completion];
    //                                               return;
    //                                             }
    //                                             completion(credential, nil, nil);
    //                                           }];
    //              }];
    //    }];
    //  }

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
    public func verifyPhoneNumber(_ phoneNumber: String, uiDelegate: AuthUIDelegate?,
                                  multiFactorSession: MultiFactorSession?,
                                  completion: ((_: String?, _: Error?) -> Void)?) {
      // TODO:
    }

    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    public func verifyPhoneNumber(_ phoneNumber: String,
                                  uiDelegate: AuthUIDelegate?,
                                  multiFactorSession: MultiFactorSession?) async throws -> String {
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
                                  multiFactorSession: MultiFactorSession?,
                                  completion: ((_: String?, _: Error?) -> Void)?) {
      // TODO:
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
      callbackScheme = ""
      usingClientIDScheme = false
    }

    private let kAuthTypeVerifyApp = "verifyApp"
  #endif
}

#if os(iOS)
  @objc(FIRPhoneAuthCredential) public class PhoneAuthCredential: AuthCredential, NSSecureCoding {
    // TODO: delete objc's and public's below
    @objc public let temporaryProof: String?
    @objc public let phoneNumber: String?
    @objc public let verificationID: String?
    @objc public let verificationCode: String?

    // TODO: Remove public objc
    @objc public init(withTemporaryProof temporaryProof: String, phoneNumber: String,
                      providerID: String) {
      self.temporaryProof = temporaryProof
      self.phoneNumber = phoneNumber
      verificationID = nil
      verificationCode = nil
      super.init(provider: providerID)
    }

    init(withProviderID providerID: String, verificationID: String, verificationCode: String) {
      self.verificationID = verificationID
      self.verificationCode = verificationCode
      temporaryProof = nil
      phoneNumber = nil
      super.init(provider: providerID)
    }

    public static var supportsSecureCoding = true

    public func encode(with coder: NSCoder) {
      coder.encode(verificationID)
      coder.encode(verificationCode)
      coder.encode(temporaryProof)
      coder.encode(phoneNumber)
    }

    public required init?(coder: NSCoder) {
      let verificationID = coder.decodeObject(forKey: "verificationID") as? String
      let verificationCode = coder.decodeObject(forKey: "verificationCode") as? String
      let temporaryProof = coder.decodeObject(forKey: "temporaryProof") as? String
      let phoneNumber = coder.decodeObject(forKey: "phoneNumber") as? String
      if let temporaryProof = temporaryProof,
         let phoneNumber = phoneNumber {
        self.temporaryProof = temporaryProof
        self.phoneNumber = phoneNumber
        self.verificationID = nil
        self.verificationCode = nil
        super.init(provider: PhoneAuthProvider.id)
      } else if let verificationID = verificationID,
                let verificationCode = verificationCode {
        self.verificationID = verificationID
        self.verificationCode = verificationCode
        self.temporaryProof = nil
        self.phoneNumber = nil
        super.init(provider: PhoneAuthProvider.id)
      } else {
        return nil
      }
    }
  }
#endif // iOS
