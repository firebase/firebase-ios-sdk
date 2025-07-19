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
import FirebaseCoreExtension
import Foundation
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
protocol AuthBackendProtocol: Sendable {
  func call<T: AuthRPCRequest>(with request: T) async throws -> T.Response
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
final class AuthBackend: AuthBackendProtocol {
  static func authUserAgent() -> String {
    return "FirebaseAuth.iOS/\(FirebaseVersion()) \(GTMFetcherStandardUserAgentString(nil))"
  }

  private let rpcIssuer: any AuthBackendRPCIssuerProtocol

  init(rpcIssuer: any AuthBackendRPCIssuerProtocol) {
    self.rpcIssuer = rpcIssuer
  }

  /// Calls the RPC using HTTP request.
  /// Possible error responses:
  /// * See FIRAuthInternalErrorCodeRPCRequestEncodingError
  /// * See FIRAuthInternalErrorCodeJSONSerializationError
  /// * See FIRAuthInternalErrorCodeNetworkError
  /// * See FIRAuthInternalErrorCodeUnexpectedErrorResponse
  /// * See FIRAuthInternalErrorCodeUnexpectedResponse
  /// * See FIRAuthInternalErrorCodeRPCResponseDecodingError
  /// - Parameter request: The request.
  /// - Returns: The response.
  func call<T: AuthRPCRequest>(with request: T) async throws -> T.Response {
    let response = try await callInternal(with: request)
    if let auth = request.requestConfiguration().auth,
       let mfaError = Self.generateMFAError(response: response, auth: auth) {
      throw mfaError
    } else if let error = Self.phoneCredentialInUse(response: response) {
      throw error
    } else {
      return response
    }
  }

  static func request(for url: URL,
                      httpMethod: String,
                      contentType: String,
                      requestConfiguration: AuthRequestConfiguration) async -> URLRequest {
    // Kick off tasks for the async header values.
    async let heartbeatsHeaderValue = requestConfiguration.heartbeatLogger?.asyncHeaderValue()
    async let appCheckTokenHeaderValue = requestConfiguration.appCheck?
      .getToken(forcingRefresh: true)

    var request = URLRequest(url: url)
    request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    let additionalFrameworkMarker = requestConfiguration.additionalFrameworkMarker
    let clientVersion = "iOS/FirebaseSDK/\(FirebaseVersion())/\(additionalFrameworkMarker)"
    request.setValue(clientVersion, forHTTPHeaderField: "X-Client-Version")
    request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
    request.setValue(requestConfiguration.appID, forHTTPHeaderField: "X-Firebase-GMPID")
    request.httpMethod = httpMethod
    let preferredLocalizations = Bundle.main.preferredLocalizations
    if preferredLocalizations.count > 0 {
      request.setValue(preferredLocalizations.first, forHTTPHeaderField: "Accept-Language")
    }
    if let languageCode = requestConfiguration.languageCode,
       languageCode.count > 0 {
      request.setValue(languageCode, forHTTPHeaderField: "X-Firebase-Locale")
    }
    // Wait for the async header values.
    await request.setValue(heartbeatsHeaderValue, forHTTPHeaderField: "X-Firebase-Client")
    if let tokenResult = await appCheckTokenHeaderValue {
      if let error = tokenResult.error {
        AuthLog.logWarning(code: "I-AUT000018",
                           message: "Error getting App Check token; using placeholder " +
                             "token instead. Error: \(error)")
      }
      request.setValue(tokenResult.token, forHTTPHeaderField: "X-Firebase-AppCheck")
    }
    return request
  }

  private static func generateMFAError(response: AuthRPCResponse, auth: Auth) -> Error? {
    #if os(iOS) || os(macOS)
      if let mfaResponse = response as? AuthMFAResponse,
         mfaResponse.idToken == nil,
         let enrollments = mfaResponse.mfaInfo {
        var info: [MultiFactorInfo] = []
        for enrollment in enrollments {
          // check which MFA factors are enabled.
          if let _ = enrollment.phoneInfo {
            info.append(PhoneMultiFactorInfo(proto: enrollment))
          } else if let _ = enrollment.totpInfo {
            info.append(TOTPMultiFactorInfo(proto: enrollment))
          } else {
            AuthLog.logError(code: "I-AUT000021", message: "Multifactor type is not supported")
          }
        }
        return AuthErrorUtils.secondFactorRequiredError(
          pendingCredential: mfaResponse.mfaPendingCredential,
          hints: info,
          auth: auth
        )
      } else {
        return nil
      }
    #else
      return nil
    #endif // os(iOS) || os(macOS)
  }

  // Check whether or not the successful response is actually the special case phone
  // auth flow that returns a temporary proof and phone number.
  private static func phoneCredentialInUse(response: AuthRPCResponse) -> Error? {
    #if !os(iOS)
      return nil
    #else
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
    #endif // !os(iOS)
  }

  /// Calls the RPC using HTTP request.
  ///
  /// Possible error responses:
  /// * See FIRAuthInternalErrorCodeRPCRequestEncodingError
  /// * See FIRAuthInternalErrorCodeJSONSerializationError
  /// * See FIRAuthInternalErrorCodeNetworkError
  /// * See FIRAuthInternalErrorCodeUnexpectedErrorResponse
  /// * See FIRAuthInternalErrorCodeUnexpectedResponse
  /// * See FIRAuthInternalErrorCodeRPCResponseDecodingError
  /// - Parameter request: The request.
  /// - Returns: The response.
  fileprivate func callInternal<T: AuthRPCRequest>(with request: T) async throws -> T.Response {
    var bodyData: Data?
    if let postBody = request.unencodedHTTPRequestBody {
      #if DEBUG
        let JSONWritingOptions = JSONSerialization.WritingOptions.prettyPrinted
      #else
        let JSONWritingOptions = JSONSerialization.WritingOptions(rawValue: 0)
      #endif

      guard JSONSerialization.isValidJSONObject(postBody) else {
        throw AuthErrorUtils.JSONSerializationErrorForUnencodableType()
      }
      bodyData = try? JSONSerialization.data(
        withJSONObject: postBody,
        options: JSONWritingOptions
      )

      if bodyData == nil {
        // This is an untested case. This happens exclusively when there is an error in the
        // framework implementation of dataWithJSONObject:options:error:. This shouldn't normally
        // occur as isValidJSONObject: should return NO in any case we should encounter an error.
        throw AuthErrorUtils.JSONSerializationErrorForUnencodableType()
      }
    }
    let (data, error) = await rpcIssuer
      .asyncCallToURL(with: request, body: bodyData, contentType: "application/json")
    // If there is an error with no body data at all, then this must be a
    // network error.
    guard let data = data else {
      if let error = error {
        throw AuthErrorUtils.networkError(underlyingError: error)
      } else {
        // TODO: this was ignored before
        fatalError("Auth Internal error: RPC call didn't return data or an error.")
      }
    }
    // Try to decode the HTTP response data which may contain either a
    // successful response or error message.
    var dictionary: [String: AnyHashable]
    var rawDecode: Any
    do {
      rawDecode = try JSONSerialization.jsonObject(
        with: data, options: JSONSerialization.ReadingOptions.mutableLeaves
      )
    } catch let jsonError {
      if error != nil {
        // We have an error, but we couldn't decode the body, so we have no
        // additional information other than the raw response and the
        // original NSError (the jsonError is inferred by the error code
        // (AuthErrorCodeUnexpectedHTTPResponse, and is irrelevant.)
        throw AuthErrorUtils.unexpectedErrorResponse(data: data, underlyingError: error)
      } else {
        // This is supposed to be a "successful" response, but we couldn't
        // deserialize the body.
        throw AuthErrorUtils.unexpectedResponse(data: data, underlyingError: jsonError)
      }
    }
    guard let decodedDictionary = rawDecode as? [String: AnyHashable] else {
      if error != nil {
        throw AuthErrorUtils.unexpectedErrorResponse(deserializedResponse: rawDecode,
                                                     underlyingError: error)
      } else {
        throw AuthErrorUtils.unexpectedResponse(deserializedResponse: rawDecode)
      }
    }
    dictionary = decodedDictionary

    let responseResult = Result {
      try T.Response(dictionary: dictionary)
    }

    // At this point we either have an error with successfully decoded
    // details in the body, or we have a response which must pass further
    // validation before we know it's truly successful. We deal with the
    // case where we have an error with successfully decoded error details
    // first:
    switch responseResult {
    case let .success(response):
      try propagateError(error, dictionary: dictionary, response: response)
      // In case returnIDPCredential of a verifyAssertion request is set to
      // @YES, the server may return a 200 with a response that may contain a
      // server error.
      if let verifyAssertionRequest = request as? VerifyAssertionRequest {
        if verifyAssertionRequest.returnIDPCredential {
          if let errorMessage = dictionary["errorMessage"] as? String {
            if let clientError = Self.clientError(
              withServerErrorMessage: errorMessage,
              errorDictionary: dictionary,
              response: response,
              error: error
            ) {
              throw clientError
            }
          }
        }
      }
      return response
    case let .failure(failure):
      try propagateError(error, dictionary: dictionary, response: nil)
      throw AuthErrorUtils
        .RPCResponseDecodingError(deserializedResponse: dictionary, underlyingError: failure)
    }
  }

  private func propagateError(_ error: Error?, dictionary: [String: AnyHashable],
                              response: AuthRPCResponse?) throws {
    guard let error else {
      return
    }

    if let errorDictionary = dictionary["error"] as? [String: AnyHashable] {
      if let errorMessage = errorDictionary["message"] as? String {
        if let clientError = Self.clientError(
          withServerErrorMessage: errorMessage,
          errorDictionary: errorDictionary,
          response: response,
          error: error
        ) {
          throw clientError
        }
      }
      // Not a message we know, return the message directly.
      throw AuthErrorUtils.unexpectedErrorResponse(
        deserializedResponse: errorDictionary,
        underlyingError: error
      )
    }
    // No error message at all, return the decoded response.
    throw AuthErrorUtils
      .unexpectedErrorResponse(deserializedResponse: dictionary, underlyingError: error)
  }

  private static func splitStringAtFirstColon(_ input: String) -> (before: String, after: String) {
    guard let colonIndex = input.firstIndex(of: ":") else {
      return (input, "") // No colon, return original string before and empty after
    }
    let before = String(input.prefix(upTo: colonIndex))
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let after = String(input.suffix(from: input.index(after: colonIndex)))
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return (before, after.isEmpty ? "" : after) // Return empty after if it's empty
  }

  private static func clientError(withServerErrorMessage serverErrorMessage: String,
                                  errorDictionary: [String: Any],
                                  response: AuthRPCResponse?,
                                  error: Error?) -> Error? {
    let (shortErrorMessage, serverDetailErrorMessage) = splitStringAtFirstColon(serverErrorMessage)
    switch shortErrorMessage {
    case "USER_NOT_FOUND": return AuthErrorUtils
      .userNotFoundError(message: serverDetailErrorMessage)
    case "MISSING_CONTINUE_URI": return AuthErrorUtils
      .missingContinueURIError(message: serverDetailErrorMessage)
    // "INVALID_IDENTIFIER" can be returned by createAuthURI RPC. Considering email addresses are
    // currently the only identifiers, we surface the FIRAuthErrorCodeInvalidEmail error code in
    // this case.
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
    case "INVALID_LOGIN_CREDENTIALS": return AuthErrorUtils
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
    case "INVALID_HOSTING_LINK_DOMAIN": return AuthErrorUtils
      .invalidHostingLinkDomainError(message: serverDetailErrorMessage)
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
    case "TENANT_ID_MISMATCH": return AuthErrorUtils.tenantIDMismatchError()
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
