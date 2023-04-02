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
@_implementationOnly import FirebaseCoreExtension
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

public protocol AuthBackendRPCIssuer: NSObjectProtocol {
  /** @fn
      @brief Asynchronously sends a POST request.
      @param requestConfiguration The request to be made.
      @param URL The request URL.
      @param body Request body.
      @param contentType Content type of the body.
      @param handler provided that handles POST response. Invoked asynchronously on the auth global
          work queue in the future.
   */
  func asyncPostToURL(withRequest request: AuthRPCRequest,
                      body: Data?,
                      contentType: String,
                      completionHandler: @escaping ((Data?, Error?) -> Void))
}

public class AuthBackendRPCIssuerImplementation: NSObject, AuthBackendRPCIssuer {
  let fetcherService: GTMSessionFetcherService

  override init() {
    fetcherService = GTMSessionFetcherService()
    fetcherService.userAgent = AuthBackend.authUserAgent()
    fetcherService.callbackQueue = kAuthGlobalWorkQueue

    // Avoid reusing the session to prevent
    // https://github.com/firebase/firebase-ios-sdk/issues/1261
    fetcherService.reuseSession = false
  }

  public func asyncPostToURL(withRequest request: AuthRPCRequest,
                             body: Data?,
                             contentType: String,
                             completionHandler: @escaping ((Data?, Error?) -> Void)) {
    let requestConfiguration = request.requestConfiguration()
    AuthBackend.request(withURL: request.requestURL(),
                        contentType: contentType,
                        requestConfiguration: requestConfiguration) { request in
      let fetcher = self.fetcherService.fetcher(with: request)
      if let _ = requestConfiguration.emulatorHostAndPort {
        fetcher.allowLocalhostRequest = true
        fetcher.allowedInsecureSchemes = ["http"]
      }
      fetcher.bodyData = body
      fetcher.beginFetch(completionHandler: completionHandler)
    }
  }
}

@objc(FIRAuthBackend2) public class AuthBackend: NSObject {
  static func authUserAgent() -> String {
    return "FirebaseAuth.iOS/\(FirebaseVersion()) \(GTMFetcherStandardUserAgentString(nil))"
  }

  private static var gBackendImplementation: AuthBackendImplementation?

  class func setDefaultBackendImplementationWithRPCIssuer(issuer: AuthBackendRPCIssuer?) {
    let defaultImplementation = AuthBackendRPCImplementation()
    if let issuer = issuer {
      defaultImplementation.rpcIssuer = issuer
    }
    gBackendImplementation = defaultImplementation
  }

  class func implementation() -> AuthBackendImplementation {
    if gBackendImplementation == nil {
      gBackendImplementation = AuthBackendRPCImplementation()
    }
    return (gBackendImplementation)!
  }

  /** @fn postWithRequest:response:callback:
      @brief Calls the RPC using HTTP POST.
      @remarks Possible error responses:
          @see FIRAuthInternalErrorCodeRPCRequestEncodingError
          @see FIRAuthInternalErrorCodeJSONSerializationError
          @see FIRAuthInternalErrorCodeNetworkError
          @see FIRAuthInternalErrorCodeUnexpectedErrorResponse
          @see FIRAuthInternalErrorCodeUnexpectedResponse
          @see FIRAuthInternalErrorCodeRPCResponseDecodingError
      @param request The request.
      @param callback The callback for both success and failure.
   */
  @objc public class func post(withRequest request: AuthRPCRequest,
                               callback: @escaping ((AuthRPCResponse?, Error?) -> Void)) {
    implementation().post(withRequest: request, callback: callback)
  }

  // TODO: Why does this need to be public to be visible by unit tests?
  public class func request(withURL url: URL,
                            contentType: String,
                            requestConfiguration: AuthRequestConfiguration,
                            completion: @escaping (URLRequest) -> Void) -> Void {
    var request = URLRequest(url: url)
    request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    let additionalFrameworkMarker = requestConfiguration
      .additionalFrameworkMarker ?? "FirebaseCore-iOS"
    let clientVersion = "iOS/FirebaseSDK/\(FirebaseVersion())/\(additionalFrameworkMarker)"
    request.setValue(clientVersion, forHTTPHeaderField: "X-Client-Version")
    request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
    request.setValue(requestConfiguration.appID, forHTTPHeaderField: "X-Firebase-GMPID")
    if let heartbeatLogger = requestConfiguration.heartbeatLogger {
      request.setValue(
        FIRHeaderValueFromHeartbeatsPayload(heartbeatLogger.flushHeartbeatsIntoPayload()),
        forHTTPHeaderField: "X-Firebase-Client"
      )
    }
    let preferredLocalizations = Bundle.main.preferredLocalizations
    if preferredLocalizations.count > 0 {
      request.setValue(preferredLocalizations.first, forHTTPHeaderField: "Accept-Language")
    }
    if let languageCode = requestConfiguration.languageCode,
       languageCode.count > 0 {
      request.setValue(languageCode, forHTTPHeaderField: "X-Firebase-Locale")
    }
    if let appCheck = requestConfiguration.appCheck {
      appCheck.getToken(forcingRefresh: false) { tokenResult in
        if let error = tokenResult.error {
          AuthLog.logWarning(code: "I-AUT000018",
                             message: "Error getting App Check token; using placeholder " +
                             "token instead. Error: \(error)")
        }
        request.setValue(tokenResult.token, forHTTPHeaderField: "X-Firebase-AppCheck")
        completion(request)
      }
    } else {
      completion(request)
    }
  }
}


protocol AuthBackendImplementation {
  func post(withRequest request: AuthRPCRequest,
            callback: @escaping ((AuthRPCResponse?, Error?) -> Void))
  func post(withRequest request: AuthRPCRequest,
            response: AuthRPCResponse,
            callback: @escaping ((Error?) -> Void))
}

private class AuthBackendRPCImplementation: NSObject, AuthBackendImplementation {
  var rpcIssuer: AuthBackendRPCIssuer
  override init() {
    rpcIssuer = AuthBackendRPCIssuerImplementation()
  }

  /** @fn postWithRequest:response:callback:
      @brief Calls the RPC using HTTP POST.
      @remarks Possible error responses:
          @see FIRAuthInternalErrorCodeRPCRequestEncodingError
          @see FIRAuthInternalErrorCodeJSONSerializationError
          @see FIRAuthInternalErrorCodeNetworkError
          @see FIRAuthInternalErrorCodeUnexpectedErrorResponse
          @see FIRAuthInternalErrorCodeUnexpectedResponse
          @see FIRAuthInternalErrorCodeRPCResponseDecodingError
      @param request The request.
      @param response The empty response to be filled.
      @param callback The callback for both success and failure.
   */
  fileprivate func post(withRequest request: AuthRPCRequest,
                        callback: @escaping ((AuthRPCResponse?, Error?) -> Void)) {
    let response = request.response
    post(withRequest: request, response: response) { error in
      if let error = error {
        callback(nil, error)
      } else if let mfaError = AuthBackendRPCImplementation
        .generateMFAError(response: response,
                          auth: request.requestConfiguration().auth) {
        callback(nil, mfaError)
      } else if let error = AuthBackendRPCImplementation.phoneCredentialInUse(response: response) {
        callback(nil, error)
      } else {
        callback(response, nil)
      }
    }
  }

  #if os(iOS)
    private class func generateMFAError(response: AuthRPCResponse, auth: Auth?) -> Error? {
      if let mfaResponse = response as? EmailLinkSignInResponse,
         mfaResponse.idToken == nil,
         let enrollments = mfaResponse.MFAInfo {
        var info: [MultiFactorInfo] = []
        for enrollment in enrollments {
          info.append(MultiFactorInfo(proto: enrollment))
        }
        return AuthErrorUtils.secondFactorRequiredError(
          pendingCredential: mfaResponse.MFAPendingCredential,
          hints: info,
          auth: auth
        )
      } else {
        return nil
      }
    }
  #else
    private class func generateMFAError(response: AuthRPCResponse, auth: Auth?) -> Error? {
      return nil
    }
  #endif

  #if os(iOS)
    // Check whether or not the successful response is actually the special case phone
    // auth flow that returns a temporary proof and phone number.
    private class func phoneCredentialInUse(response: AuthRPCResponse) -> Error? {
      if let phoneAuthResponse = response as? VerifyPhoneNumberResponse,
         let phoneNumber = phoneAuthResponse.phoneNumber,
         phoneNumber.count > 0,
         let temporaryProof = phoneAuthResponse.temporaryProof,
         temporaryProof.count > 0 {
        let credential = PhoneAuthCredential(withTemporaryProof: temporaryProof,
                                             phoneNumber: phoneNumber,
                                             providerID: PhoneAuthProvider.id)
        return AuthErrorUtils.credentialAlreadyInUseError(message: nil,
                                                          credential: credential,
                                                          email: nil)
      } else {
        return nil
      }
    }
  #else
    private class func phoneCredentialInUse(response: AuthRPCResponse) -> Error? {
      return nil
    }
  #endif

  /** @fn postWithRequest:response:callback:
      @brief Calls the RPC using HTTP POST.
      @remarks Possible error responses:
          @see FIRAuthInternalErrorCodeRPCRequestEncodingError
          @see FIRAuthInternalErrorCodeJSONSerializationError
          @see FIRAuthInternalErrorCodeNetworkError
          @see FIRAuthInternalErrorCodeUnexpectedErrorResponse
          @see FIRAuthInternalErrorCodeUnexpectedResponse
          @see FIRAuthInternalErrorCodeRPCResponseDecodingError
      @param request The request.
      @param response The empty response to be filled.
      @param callback The callback for both success and failure.
   */
  fileprivate func post(withRequest request: AuthRPCRequest,
                        response: AuthRPCResponse,
                        callback: @escaping ((Error?) -> Void)) {
    var bodyData: Data?
    if let contains = request.containsPostBody,
       contains() {
      do {
        // TODO: Can unencodedHTTPRequestBody ever throw?
        // They don't today, but there are a few fatalErrors that might better be implemented as
        // thrown errors.. Although perhaps the case of 'containsPostBody' returning false could
        // perhaps be modeled differently so that the failing unencodedHTTPRequestBody could only
        // be called when a body exists...
        let postBody = try request.unencodedHTTPRequestBody()
        var JSONWritingOptions: JSONSerialization.WritingOptions = .init(rawValue: 0)
        #if DEBUG
          JSONWritingOptions = JSONSerialization.WritingOptions.prettyPrinted
        #endif

        guard JSONSerialization.isValidJSONObject(postBody) else {
          callback(AuthErrorUtils.JSONSerializationErrorForUnencodableType())
          return
        }
        bodyData = try? JSONSerialization.data(
          withJSONObject: postBody,
          options: JSONWritingOptions
        )
        if bodyData == nil {
          // This is an untested case. This happens exclusively when there is an error in the
          // framework implementation of dataWithJSONObject:options:error:. This shouldn't normally
          // occur as isValidJSONObject: should return NO in any case we should encounter an error.
          callback(AuthErrorUtils.JSONSerializationErrorForUnencodableType())
          return
        }
      } catch {
        callback(AuthErrorUtils.RPCRequestEncodingError(underlyingError: error))
        return
      }
    }
    rpcIssuer
      .asyncPostToURL(withRequest: request, body: bodyData, contentType: "application/json") {
        data, error in
        // If there is an error with no body data at all, then this must be a
        // network error.
        guard let data = data else {
          if let error = error {
            callback(AuthErrorUtils.networkError(underlyingError: error))
            return
          } else {
            // TODO: this was ignored before
            fatalError("Internal error")
          }
        }
        // Try to decode the HTTP response data which may contain either a
        // successful response or error message.
        var dictionary: [String: AnyHashable]
        do {
          let rawDecode = try JSONSerialization.jsonObject(with: data,
                                                           options: JSONSerialization.ReadingOptions
                                                             .mutableLeaves)
          guard let decodedDictionary = rawDecode as? [String: AnyHashable] else {
            if error != nil {
              callback(AuthErrorUtils.unexpectedErrorResponse(deserializedResponse: rawDecode,
                                                              underlyingError: error))
            } else {
              callback(AuthErrorUtils.unexpectedResponse(deserializedResponse: rawDecode))
            }
            return
          }
          dictionary = decodedDictionary
        } catch let jsonError {
          if error != nil {
            // We have an error, but we couldn't decode the body, so we have no
            // additional information other than the raw response and the
            // original NSError (the jsonError is inferred by the error code
            // (AuthErrorCodeUnexpectedHTTPResponse, and is irrelevant.)
            callback(AuthErrorUtils.unexpectedErrorResponse(data: data, underlyingError: error))
            return
          } else {
            // This is supposed to be a "successful" response, but we couldn't
            // deserialize the body.
            callback(AuthErrorUtils.unexpectedResponse(data: data, underlyingError: jsonError))
            return
          }
        }

        // At this point we either have an error with successfully decoded
        // details in the body, or we have a response which must pass further
        // validation before we know it's truly successful. We deal with the
        // case where we have an error with successfully decoded error details
        // first:
        if error != nil {
          if let errorDictionary = dictionary["error"] as? [String: AnyHashable] {
            if let errorMessage = errorDictionary["message"] as? String {
              if let clientError = AuthBackendRPCImplementation.clientError(
                withServerErrorMessage: errorMessage,
                errorDictionary: errorDictionary,
                response: response,
                error: error
              ) {
                callback(clientError)
                return
              }
            }
            // Not a message we know, return the message directly.
            callback(AuthErrorUtils.unexpectedErrorResponse(
              deserializedResponse: errorDictionary,
              underlyingError: error
            ))
            return
          }
          // No error message at all, return the decoded response.
          callback(AuthErrorUtils
            .unexpectedErrorResponse(deserializedResponse: dictionary, underlyingError: error))
          return
        }

        // Finally, we try to populate the response object with the JSON
        // values.
        do {
          try response.setFields(dictionary: dictionary)
        } catch {
          callback(AuthErrorUtils
            .RPCResponseDecodingError(deserializedResponse: dictionary, underlyingError: error))
          return
        }
        // In case returnIDPCredential of a verifyAssertion request is set to
        // @YES, the server may return a 200 with a response that may contain a
        // server error.
        if let verifyAssertionRequest = request as? VerifyAssertionRequest {
          if verifyAssertionRequest.returnIDPCredential {
            if let errorMessage = dictionary["errorMessage"] as? String {
              let clientError = AuthBackendRPCImplementation.clientError(
                withServerErrorMessage: errorMessage,
                errorDictionary: dictionary,
                response: response,
                error: error
              )
              callback(clientError)
              return
            }
          }
        }
        callback(nil)
      }
  }

  private class func clientError(withServerErrorMessage serverErrorMessage: String,
                                 errorDictionary: [String: Any],
                                 response: AuthRPCResponse,
                                 error: Error?) -> Error? {
    let split = serverErrorMessage.split(separator: ":")
    let shortErrorMessage = split.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    let serverDetailErrorMessage = String(split.count > 1 ? split[1] : "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    switch shortErrorMessage {
    case "USER_NOT_FOUND": return AuthErrorUtils
      .userNotFoundError(message: serverDetailErrorMessage)
    case "MISSING_CONTINUE_URI": return AuthErrorUtils
      .missingContinueURIError(message: serverDetailErrorMessage)
    // "INVALID_IDENTIFIER" can be returned by createAuthURI RPC. Considering email addresses are
    //  currently the only identifiers, we surface the FIRAuthErrorCodeInvalidEmail error code in this
    //  case.
    case "INVALID_IDENTIFIER": return AuthErrorUtils
      .invalidEmailError(message: serverDetailErrorMessage)
    case "INVALID_ID_TOKEN": return AuthErrorUtils
      .invalidUserTokenError(message: serverDetailErrorMessage)
    case "CREDENTIAL_TOO_OLD_LOGIN_AGAIN": return AuthErrorUtils
      .requiresRecentLoginError(message: serverDetailErrorMessage)
    case "EMAIL_EXISTS": return AuthErrorUtils
      .emailAlreadyInUseError(email: nil)
    case "OPERATION_NOT_ALLOWED": return AuthErrorUtils
      .operationNotAllowedError(message: serverDetailErrorMessage)
    case "PASSWORD_LOGIN_DISABLED": return AuthErrorUtils
      .operationNotAllowedError(message: serverDetailErrorMessage)
    case "USER_DISABLED": return AuthErrorUtils
      .userDisabledError(message: serverDetailErrorMessage)
    case "INVALID_EMAIL": return AuthErrorUtils
      .invalidEmailError(message: serverDetailErrorMessage)
    case "EXPIRED_OOB_CODE": return AuthErrorUtils
      .expiredActionCodeError(message: serverDetailErrorMessage)
    case "INVALID_OOB_CODE": return AuthErrorUtils
      .invalidActionCodeError(message: serverDetailErrorMessage)
    case "INVALID_MESSAGE_PAYLOAD": return AuthErrorUtils
      .invalidMessagePayloadError(message: serverDetailErrorMessage)
    case "INVALID_SENDER": return AuthErrorUtils
      .invalidSenderError(message: serverDetailErrorMessage)
    case "INVALID_RECIPIENT_EMAIL": return AuthErrorUtils
      .invalidRecipientEmailError(message: serverDetailErrorMessage)
    case "WEAK_PASSWORD": return AuthErrorUtils
      .weakPasswordError(serverResponseReason: serverDetailErrorMessage)
    case "TOO_MANY_ATTEMPTS_TRY_LATER": return AuthErrorUtils
      .tooManyRequestsError(message: serverDetailErrorMessage)
    case "EMAIL_NOT_FOUND": return AuthErrorUtils
      .userNotFoundError(message: serverDetailErrorMessage)
    case "MISSING_EMAIL": return AuthErrorUtils
      .missingEmailError(message: serverDetailErrorMessage)
    case "MISSING_IOS_BUNDLE_ID": return AuthErrorUtils
      .missingIosBundleIDError(message: serverDetailErrorMessage)
    case "MISSING_ANDROID_PACKAGE_NAME": return AuthErrorUtils
      .missingAndroidPackageNameError(message: serverDetailErrorMessage)
    case "UNAUTHORIZED_DOMAIN": return AuthErrorUtils
      .unauthorizedDomainError(message: serverDetailErrorMessage)
    case "INVALID_CONTINUE_URI": return AuthErrorUtils
      .invalidContinueURIError(message: serverDetailErrorMessage)
    case "INVALID_PASSWORD": return AuthErrorUtils
      .wrongPasswordError(message: serverDetailErrorMessage)
    case "INVALID_IDP_RESPONSE": return AuthErrorUtils
      .invalidCredentialError(message: serverDetailErrorMessage)
    case "INVALID_PENDING_TOKEN": return AuthErrorUtils
      .invalidCredentialError(message: serverDetailErrorMessage)
    case "INVALID_CUSTOM_TOKEN": return AuthErrorUtils
      .invalidCustomTokenError(message: serverDetailErrorMessage)
    case "CREDENTIAL_MISMATCH": return AuthErrorUtils
      .customTokenMismatchError(message: serverDetailErrorMessage)
    case "INVALID_PHONE_NUMBER": return AuthErrorUtils
      .invalidPhoneNumberError(message: serverDetailErrorMessage)
    case "QUOTA_EXCEEDED": return AuthErrorUtils
      .quotaExceededError(message: serverDetailErrorMessage)
    case "APP_NOT_VERIFIED": return AuthErrorUtils
      .appNotVerifiedError(message: serverDetailErrorMessage)
    case "CAPTCHA_CHECK_FAILED": return AuthErrorUtils
      .captchaCheckFailedError(message: serverDetailErrorMessage)
    case "INVALID_APP_CREDENTIAL": return AuthErrorUtils
      .invalidAppCredential(message: serverDetailErrorMessage)
    case "MISSING_APP_CREDENTIAL": return AuthErrorUtils
      .missingAppCredential(message: serverDetailErrorMessage)
    case "INVALID_CODE": return AuthErrorUtils
      .invalidVerificationCodeError(message: serverDetailErrorMessage)
    case "INVALID_SESSION_INFO": return AuthErrorUtils
      .invalidVerificationIDError(message: serverDetailErrorMessage)
    case "SESSION_EXPIRED": return AuthErrorUtils
      .sessionExpiredError(message: serverDetailErrorMessage)
    case "ADMIN_ONLY_OPERATION": return AuthErrorUtils
      .error(code: AuthErrorCode.adminRestrictedOperation, message: serverDetailErrorMessage)
    case "BLOCKING_FUNCTION_ERROR_RESPONSE": return AuthErrorUtils
      .blockingCloudFunctionServerResponse(message: serverDetailErrorMessage)
    case "EMAIL_CHANGE_NEEDS_VERIFICATION": return AuthErrorUtils
      .error(code: AuthErrorCode.emailChangeNeedsVerification, message: serverDetailErrorMessage)
    case "INVALID_MFA_PENDING_CREDENTIAL": return AuthErrorUtils
      .error(code: AuthErrorCode.invalidMultiFactorSession, message: serverDetailErrorMessage)
    case "INVALID_PROVIDER_ID": return AuthErrorUtils
      .invalidProviderIDError(message: serverDetailErrorMessage)
    case "MFA_ENROLLMENT_NOT_FOUND": return AuthErrorUtils
      .error(code: AuthErrorCode.multiFactorInfoNotFound, message: serverDetailErrorMessage)
    case "MISSING_CLIENT_IDENTIFIER": return AuthErrorUtils
      .missingClientIdentifierError(message: serverDetailErrorMessage)
    case "MISSING_IOS_APP_TOKEN": return AuthErrorUtils
      .missingAppTokenError(underlyingError: nil)
    case "MISSING_MFA_ENROLLMENT_ID": return AuthErrorUtils
      .error(code: AuthErrorCode.missingMultiFactorInfo, message: serverDetailErrorMessage)
    case "MISSING_MFA_PENDING_CREDENTIAL": return AuthErrorUtils
      .error(code: AuthErrorCode.missingMultiFactorSession, message: serverDetailErrorMessage)
    case "MISSING_OR_INVALID_NONCE": return AuthErrorUtils
      .missingOrInvalidNonceError(message: serverDetailErrorMessage)
    case "SECOND_FACTOR_EXISTS": return AuthErrorUtils
      .error(code: AuthErrorCode.secondFactorAlreadyEnrolled, message: serverDetailErrorMessage)
    case "SECOND_FACTOR_LIMIT_EXCEEDED": return AuthErrorUtils
      .error(
        code: AuthErrorCode.maximumSecondFactorCountExceeded,
        message: serverDetailErrorMessage
      )
    case "TENANT_ID_MISMATCH": return AuthErrorUtils
      .tenantIDMismatchError()
    case "TOKEN_EXPIRED": return AuthErrorUtils
      .userTokenExpiredError(message: serverDetailErrorMessage)
    case "UNSUPPORTED_FIRST_FACTOR": return AuthErrorUtils
      .error(code: AuthErrorCode.unsupportedFirstFactor, message: serverDetailErrorMessage)
    case "UNSUPPORTED_TENANT_OPERATION": return AuthErrorUtils
      .unsupportedTenantOperationError()
    case "UNVERIFIED_EMAIL": return AuthErrorUtils
      .error(code: AuthErrorCode.unverifiedEmail, message: serverDetailErrorMessage)
    case "FEDERATED_USER_ID_ALREADY_LINKED":
      guard let verifyAssertion = response as? VerifyAssertionResponse else {
        return AuthErrorUtils.credentialAlreadyInUseError(
          message: serverDetailErrorMessage, credential: nil, email: nil
        )
      }
      let credential = OAuthCredential(withVerifyAssertionResponse: verifyAssertion)
      let email = verifyAssertion.email
      return AuthErrorUtils.credentialAlreadyInUseError(
        message: serverDetailErrorMessage, credential: credential, email: email
      )

    default:
      if let underlyingErrors = errorDictionary["errors"] as? [[String: String]] {
        for underlyingError in underlyingErrors {
          if let reason = underlyingError["reason"] {
            if reason.starts(with: "keyInvalid") {
              return AuthErrorUtils.invalidAPIKeyError()
            }
            if underlyingError["reason"] == "ipRefererBlocked" {
              return AuthErrorUtils.appNotAuthorizedError()
            }
          }
        }
      }
    }
    return nil
  }
}
