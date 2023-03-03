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

#if COCOAPODS
  @_implementationOnly import FirebaseAuth_Private
#endif // COCOAPODS

// MARK: - URL response error codes

/** @var kURLResponseErrorCodeInvalidClientID
    @brief Error code that indicates that the client ID provided was invalid.
 */
private let kURLResponseErrorCodeInvalidClientID = "auth/invalid-oauth-client-id"

/** @var kURLResponseErrorCodeNetworkRequestFailed
    @brief Error code that indicates that a network request within the SFSafariViewController or
        WKWebView failed.
 */
private let kURLResponseErrorCodeNetworkRequestFailed = "auth/network-request-failed"

/** @var kURLResponseErrorCodeInternalError
    @brief Error code that indicates that an internal error occurred within the
        SFSafariViewController or WKWebView failed.
 */
private let kURLResponseErrorCodeInternalError = "auth/internal-error"

private let kFIRAuthErrorMessageMalformedJWT =
  "Failed to parse JWT. Check the userInfo dictionary for the full token."

@objc(FIRAuthErrorUtils) public class AuthErrorUtils: NSObject {
  private static let errorDomain = "FIRAuthErrorDomain"

  private static let internalErrorDomain = "FIRAuthInternalErrorDomain"

  static let userInfoDeserializedResponseKey =
    "FIRAuthErrorUserInfoDeserializedResponseKey"

  private static let userInfoDataKey = "FIRAuthErrorUserInfoDataKey"

  private static let userInfoEmailKey = "FIRAuthErrorUserInfoEmailKey"

  private static let userInfoUpdatedCredentialKey =
    "FIRAuthErrorUserInfoUpdatedCredentialKey"

  private static let userInfoNameKey = "FIRAuthErrorUserInfoNameKey"

  private static let userInfoMultiFactorResolverKey =
    "FIRAuthErrorUserInfoMultiFactorResolverKey"

  /** @var kServerErrorDetailMarker
      @brief This marker indicates that the server error message contains a detail error message which
          should be used instead of the hardcoded client error message.
   */
  private static let kServerErrorDetailMarker = " : "

  static func error(code: SharedErrorCode, userInfo: [String: Any]? = nil) -> Error {
    switch code {
    case let .public(publicCode):
      var errorUserInfo: [String: Any] = userInfo ?? [:]
      if errorUserInfo[NSLocalizedDescriptionKey] == nil {
        errorUserInfo[NSLocalizedDescriptionKey] = publicCode.errorDescription
      }
      errorUserInfo[userInfoNameKey] = publicCode.errorCodeString
      return NSError(
        domain: errorDomain,
        code: publicCode.rawValue,
        userInfo: errorUserInfo
      )
    case let .internal(internalCode):
      // This is an internal error. Wrap it in an internal error.
      let error = NSError(
        domain: internalErrorDomain,
        code: internalCode.rawValue,
        userInfo: userInfo
      )

      return self.error(code: .public(.internalError), underlyingError: error)
    }
  }

  static func error(code: SharedErrorCode, underlyingError: Error?) -> Error {
    var errorUserInfo: [String: Any]?
    if let underlyingError = underlyingError {
      errorUserInfo = [NSUnderlyingErrorKey: underlyingError]
    }
    return error(code: code, userInfo: errorUserInfo)
  }

  static func error(code: AuthErrorCode, underlyingError: Error?) -> Error {
    error(code: SharedErrorCode.public(code), underlyingError: underlyingError)
  }

  @objc public static func error(code: AuthErrorCode, userInfo: [String: Any]? = nil) -> Error {
    error(code: SharedErrorCode.public(code), userInfo: userInfo)
  }

  @objc public static func error(code: AuthErrorCode, message: String?) -> Error {
    let userInfo: [String: Any]?
    if let message {
      userInfo = [NSLocalizedDescriptionKey: message]
    } else {
      userInfo = nil
    }
    return error(code: SharedErrorCode.public(code), userInfo: userInfo)
  }

  @objc public static func userDisabledError(message: String?) -> Error {
    error(code: .userDisabled, message: message)
  }

  @objc public static func wrongPasswordError(message: String?) -> Error {
    error(code: .wrongPassword, message: message)
  }

  @objc public static func tooManyRequestsError(message: String?) -> Error {
    error(code: .tooManyRequests, message: message)
  }

  @objc public static func invalidCustomTokenError(message: String?) -> Error {
    error(code: .invalidCustomToken, message: message)
  }

  @objc public static func customTokenMismatchError(message: String?) -> Error {
    error(code: .customTokenMismatch, message: message)
  }

  @objc public static func invalidCredentialError(message: String?) -> Error {
    error(code: .invalidCredential, message: message)
  }

  @objc public static func requiresRecentLoginError(message: String?) -> Error {
    error(code: .requiresRecentLogin, message: message)
  }

  @objc public static func invalidUserTokenError(message: String?) -> Error {
    error(code: .invalidUserToken, message: message)
  }

  @objc public static func invalidEmailError(message: String?) -> Error {
    error(code: .invalidEmail, message: message)
  }

  @objc public static func providerAlreadyLinkedError() -> Error {
    error(code: .providerAlreadyLinked)
  }

  @objc public static func noSuchProviderError() -> Error {
    error(code: .noSuchProvider)
  }

  @objc public static func userTokenExpiredError(message: String?) -> Error {
    error(code: .userTokenExpired, message: message)
  }

  @objc public static func userNotFoundError(message: String?) -> Error {
    error(code: .userNotFound, message: message)
  }

  @objc public static func invalidAPIKeyError() -> Error {
    error(code: .invalidAPIKey)
  }

  @objc public static func userMismatchError() -> Error {
    error(code: .userMismatch)
  }

  @objc public static func operationNotAllowedError(message: String?) -> Error {
    error(code: .operationNotAllowed, message: message)
  }

  @objc public static func weakPasswordError(serverResponseReason reason: String?) -> Error {
    let userInfo: [String: Any]?
    if let reason, !reason.isEmpty {
      userInfo = [
        NSLocalizedFailureReasonErrorKey: reason,
      ]
    } else {
      userInfo = nil
    }
    return error(code: .weakPassword, userInfo: userInfo)
  }

  @objc public static func appNotAuthorizedError() -> Error {
    error(code: .appNotAuthorized)
  }

  @objc public static func expiredActionCodeError(message: String?) -> Error {
    error(code: .expiredActionCode, message: message)
  }

  @objc public static func invalidActionCodeError(message: String?) -> Error {
    error(code: .invalidActionCode, message: message)
  }

  @objc public static func invalidMessagePayloadError(message: String?) -> Error {
    error(code: .invalidMessagePayload, message: message)
  }

  @objc public static func invalidSenderError(message: String?) -> Error {
    error(code: .invalidSender, message: message)
  }

  @objc public static func invalidRecipientEmailError(message: String?) -> Error {
    error(code: .invalidRecipientEmail, message: message)
  }

  @objc public static func missingIosBundleIDError(message: String?) -> Error {
    error(code: .missingIosBundleID, message: message)
  }

  @objc public static func missingAndroidPackageNameError(message: String?) -> Error {
    error(code: .missingAndroidPackageName, message: message)
  }

  @objc public static func unauthorizedDomainError(message: String?) -> Error {
    error(code: .unauthorizedDomain, message: message)
  }

  @objc public static func invalidContinueURIError(message: String?) -> Error {
    error(code: .invalidContinueURI, message: message)
  }

  @objc public static func missingContinueURIError(message: String?) -> Error {
    error(code: .missingContinueURI, message: message)
  }

  @objc public static func missingEmailError(message: String?) -> Error {
    error(code: .missingEmail, message: message)
  }

  @objc public static func missingPhoneNumberError(message: String?) -> Error {
    error(code: .missingPhoneNumber, message: message)
  }

  @objc public static func invalidPhoneNumberError(message: String?) -> Error {
    error(code: .invalidPhoneNumber, message: message)
  }

  @objc public static func missingVerificationCodeError(message: String?) -> Error {
    error(code: .missingVerificationCode, message: message)
  }

  @objc public static func invalidVerificationCodeError(message: String?) -> Error {
    error(code: .invalidVerificationCode, message: message)
  }

  @objc public static func missingVerificationIDError(message: String?) -> Error {
    error(code: .missingVerificationID, message: message)
  }

  @objc public static func invalidVerificationIDError(message: String?) -> Error {
    error(code: .invalidVerificationID, message: message)
  }

  @objc public static func sessionExpiredError(message: String?) -> Error {
    error(code: .sessionExpired, message: message)
  }

  @objc public static func missingAppCredential(message: String?) -> Error {
    error(code: .missingAppCredential, message: message)
  }

  @objc public static func invalidAppCredential(message: String?) -> Error {
    error(code: .invalidAppCredential, message: message)
  }

  @objc public static func quotaExceededError(message: String?) -> Error {
    error(code: .quotaExceeded, message: message)
  }

  @objc public static func missingAppTokenError(underlyingError: Error?) -> Error {
    error(code: .missingAppToken, underlyingError: underlyingError)
  }

  @objc public static func localPlayerNotAuthenticatedError() -> Error {
    error(code: .localPlayerNotAuthenticated)
  }

  @objc public static func gameKitNotLinkedError() -> Error {
    error(code: .gameKitNotLinked)
  }

  @objc public static func RPCRequestEncodingError(underlyingError: Error) -> Error {
    error(code: .internal(.RPCRequestEncodingError), underlyingError: underlyingError)
  }

  @objc public static func JSONSerializationErrorForUnencodableType() -> Error {
    error(code: .internal(.JSONSerializationError))
  }

  @objc public static func JSONSerializationError(underlyingError: Error) -> Error {
    error(code: .internal(.JSONSerializationError), underlyingError: underlyingError)
  }

  @objc public static func networkError(underlyingError: Error) -> Error {
    error(code: .networkError, underlyingError: underlyingError)
  }

  @objc public static func emailAlreadyInUseError(email: String?) -> Error {
    var userInfo: [String: Any]?
    if let email, !email.isEmpty {
      userInfo = [userInfoEmailKey: email]
    }
    return error(code: .emailAlreadyInUse, userInfo: userInfo)
  }

  @objc public static func credentialAlreadyInUseError(message: String?,
                                                       credential: AuthCredential?,
                                                       email: String?) -> Error {
    var userInfo: [String: Any] = [:]
    if let credential {
      userInfo[userInfoUpdatedCredentialKey] = credential
    }
    if let email, !email.isEmpty {
      userInfo[userInfoEmailKey] = email
    }
    if !userInfo.isEmpty {
      return error(code: .credentialAlreadyInUse, userInfo: userInfo)
    }
    return error(code: .credentialAlreadyInUse, message: message)
  }

  @objc public static func webContextAlreadyPresentedError(message: String?) -> Error {
    error(code: .webContextAlreadyPresented, message: message)
  }

  @objc public static func webContextCancelledError(message: String?) -> Error {
    error(code: .webContextCancelled, message: message)
  }

  @objc public static func appVerificationUserInteractionFailure(reason: String?) -> Error {
    let userInfo: [String: Any]?
    if let reason, !reason.isEmpty {
      userInfo = [NSLocalizedFailureReasonErrorKey: reason]
    } else {
      userInfo = nil
    }
    return error(code: .appVerificationUserInteractionFailure, userInfo: userInfo)
  }

  @objc public static func webSignInUserInteractionFailure(reason: String?) -> Error {
    let userInfo: [String: Any]?
    if let reason, !reason.isEmpty {
      userInfo = [NSLocalizedFailureReasonErrorKey: reason]
    } else {
      userInfo = nil
    }
    return error(code: .webSignInUserInteractionFailure, userInfo: userInfo)
  }

  @objc public static func urlResponseError(code: String, message: String?) -> Error {
    let errorCode: AuthErrorCode
    switch code {
    case kURLResponseErrorCodeInvalidClientID:
      errorCode = .invalidClientID
    case kURLResponseErrorCodeNetworkRequestFailed:
      errorCode = .webNetworkRequestFailed
    case kURLResponseErrorCodeInternalError:
      errorCode = .webInternalError
    default:
      return AuthErrorUtils.webSignInUserInteractionFailure(reason: "[\(code)] - \(message ?? "")")
    }
    return error(code: errorCode, message: message)
  }

  @objc public static func nullUserError(message: String?) -> Error {
    error(code: .nullUser, message: message)
  }

  @objc public static func invalidProviderIDError(message: String?) -> Error {
    error(code: .invalidProviderID, message: message)
  }

  @objc public static func invalidDynamicLinkDomainError(message: String?) -> Error {
    error(code: .invalidDynamicLinkDomain, message: message)
  }

  @objc public static func missingOrInvalidNonceError(message: String?) -> Error {
    error(code: .missingOrInvalidNonce, message: message)
  }

  @objc public static func keychainError(function: String, status: OSStatus) -> Error {
    let reason = "\(function) (\(status))"
    return error(code: .keychainError, userInfo: [NSLocalizedFailureReasonErrorKey: reason])
  }

  @objc public static func tenantIDMismatchError() -> Error {
    error(code: .tenantIDMismatch)
  }

  @objc public static func unsupportedTenantOperationError() -> Error {
    error(code: .unsupportedTenantOperation)
  }

  @objc public static func notificationNotForwardedError() -> Error {
    error(code: .notificationNotForwarded)
  }

  @objc public static func appNotVerifiedError(message: String?) -> Error {
    error(code: .appNotVerified, message: message)
  }

  @objc public static func missingClientIdentifierError(message: String?) -> Error {
    error(code: .missingClientIdentifier, message: message)
  }

  @objc public static func captchaCheckFailedError(message: String?) -> Error {
    error(code: .captchaCheckFailed, message: message)
  }

  @objc public static func unexpectedResponse(data: Data?, underlyingError: Error?) -> Error {
    var userInfo: [String: Any] = [:]
    if let data {
      userInfo[userInfoDataKey] = data
    }
    if let underlyingError {
      userInfo[NSUnderlyingErrorKey] = underlyingError
    }
    return error(code: .internal(.unexpectedResponse), userInfo: userInfo)
  }

  @objc public static func unexpectedErrorResponse(data: Data?,
                                                   underlyingError: Error?) -> Error {
    var userInfo: [String: Any] = [:]
    if let data {
      userInfo[userInfoDataKey] = data
    }
    if let underlyingError {
      userInfo[NSUnderlyingErrorKey] = underlyingError
    }
    return error(code: .internal(.unexpectedErrorResponse), userInfo: userInfo)
  }

  @objc public static func unexpectedErrorResponse(deserializedResponse: Any?) -> Error {
    var userInfo: [String: Any]?
    if let deserializedResponse {
      userInfo = [userInfoDeserializedResponseKey: deserializedResponse]
    }
    return error(code: .internal(.unexpectedErrorResponse), userInfo: userInfo)
  }

  @objc public static func unexpectedResponse(deserializedResponse: Any?) -> Error {
    var userInfo: [String: Any]?
    if let deserializedResponse {
      userInfo = [userInfoDeserializedResponseKey: deserializedResponse]
    }
    return error(code: .internal(.unexpectedResponse), userInfo: userInfo)
  }

  @objc public static func unexpectedResponse(deserializedResponse: Any?,
                                              underlyingError: Error?) -> Error {
    var userInfo: [String: Any] = [:]
    if let deserializedResponse {
      userInfo[userInfoDeserializedResponseKey] = deserializedResponse
    }
    if let underlyingError {
      userInfo[NSUnderlyingErrorKey] = underlyingError
    }
    return error(code: .internal(.unexpectedResponse), userInfo: userInfo)
  }

  @objc public static func unexpectedErrorResponse(deserializedResponse: Any?,
                                                   underlyingError: Error?) -> Error {
    var userInfo: [String: Any] = [:]
    if let deserializedResponse {
      userInfo[userInfoDeserializedResponseKey] = deserializedResponse
    }
    if let underlyingError {
      userInfo[NSUnderlyingErrorKey] = underlyingError
    }
    return error(
      code: .internal(.unexpectedErrorResponse),
      userInfo: userInfo.isEmpty ? nil : userInfo
    )
  }

  @objc public static func malformedJWTError(token: String, underlyingError: Error?) -> Error {
    var userInfo: [String: Any] = [
      NSLocalizedDescriptionKey: kFIRAuthErrorMessageMalformedJWT,
      userInfoDataKey: token,
    ]
    if let underlyingError {
      userInfo[NSUnderlyingErrorKey] = underlyingError
    }
    return error(code: .malformedJWT, userInfo: userInfo)
  }

  @objc public static func RPCResponseDecodingError(deserializedResponse: Any?,
                                                    underlyingError: Error?) -> Error {
    var userInfo: [String: Any] = [:]
    if let deserializedResponse {
      userInfo[userInfoDeserializedResponseKey] = deserializedResponse
    }
    if let underlyingError {
      userInfo[NSUnderlyingErrorKey] = underlyingError
    }
    return error(code: .internal(.RPCResponseDecodingError), userInfo: userInfo)
  }

  @objc public static func accountExistsWithDifferentCredentialError(email: String?,
                                                                     updatedCredential: AuthCredential?)
    -> Error {
    var userInfo: [String: Any] = [:]
    if let email {
      userInfo[userInfoEmailKey] = email
    }
    if let updatedCredential {
      userInfo[userInfoUpdatedCredentialKey] = updatedCredential
    }
    return error(code: .accountExistsWithDifferentCredential, userInfo: userInfo)
  }

  @objc public static func blockingCloudFunctionServerResponse(message: String?) -> Error {
    guard let message else {
      return error(code: .blockingCloudFunctionError, message: message)
    }
    var jsonString = message.replacingOccurrences(
      of: "HTTP Cloud Function returned an error:",
      with: ""
    )
    jsonString = jsonString.trimmingCharacters(in: .whitespaces)
    let jsonData = jsonString.data(using: .utf8) ?? Data()
    do {
      let jsonDict = try JSONSerialization
        .jsonObject(with: jsonData, options: []) as? [String: Any] ?? [:]
      let errorDict = jsonDict["error"] as? [String: Any] ?? [:]
      let errorMessage = errorDict["message"] as? String
      return error(code: .blockingCloudFunctionError, message: errorMessage)
    } catch {
      return JSONSerializationError(underlyingError: error)
    }
  }

  #if os(iOS)
    // TODO(ncooke3): Address the optionality of these arguments.
    @objc public static func secondFactorRequiredError(pendingCredential: String?,
                                                       hints: [MultiFactorInfo]?,
                                                       auth: Auth?)
      -> Error {
      var userInfo: [String: Any] = [:]
      if let pendingCredential = pendingCredential, let hints = hints {
        let resolver = MultiFactorResolver(
          mfaPendingCredential: pendingCredential,
          hints: hints,
          auth: auth
        )
        userInfo[userInfoMultiFactorResolverKey] = resolver
      }

      return error(code: .secondFactorRequired, userInfo: userInfo)
    }
  #endif // os(iOS)
}

@objc public protocol MultiFactorResolverWrapper: NSObjectProtocol {}
