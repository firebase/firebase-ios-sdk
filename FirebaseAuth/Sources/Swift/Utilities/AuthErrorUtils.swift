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

// MARK: - URL response error codes

/// Error code that indicates that the client ID provided was invalid.
private let kURLResponseErrorCodeInvalidClientID = "auth/invalid-oauth-client-id"

/// Error code that indicates that a network request within the SFSafariViewController or WKWebView
/// failed.
private let kURLResponseErrorCodeNetworkRequestFailed = "auth/network-request-failed"

/// Error code that indicates that an internal error occurred within the
/// SFSafariViewController or WKWebView failed.
private let kURLResponseErrorCodeInternalError = "auth/internal-error"

private let kFIRAuthErrorMessageMalformedJWT =
  "Failed to parse JWT. Check the userInfo dictionary for the full token."

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AuthErrorUtils {
  static let internalErrorDomain = "FIRAuthInternalErrorDomain"
  static let userInfoDeserializedResponseKey = "FIRAuthErrorUserInfoDeserializedResponseKey"
  static let userInfoDataKey = "FIRAuthErrorUserInfoDataKey"

  /// This marker indicates that the server error message contains a detail error message which
  /// should be used instead of the hardcoded client error message.
  private static let kServerErrorDetailMarker = " : "

  static func error(code: SharedErrorCode, userInfo: [String: Any]? = nil) -> Error {
    switch code {
    case let .public(publicCode):
      var errorUserInfo: [String: Any] = userInfo ?? [:]
      if errorUserInfo[NSLocalizedDescriptionKey] == nil {
        errorUserInfo[NSLocalizedDescriptionKey] = publicCode.errorDescription
      }
      if let localizedDescription = errorUserInfo[NSLocalizedDescriptionKey] as? String,
         localizedDescription == "" {
        errorUserInfo[NSLocalizedDescriptionKey] = publicCode.errorDescription
      }
      errorUserInfo[AuthErrors.userInfoNameKey] = publicCode.errorCodeString
      return NSError(
        domain: AuthErrors.domain,
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

  static func error(code: AuthErrorCode, userInfo: [String: Any]? = nil) -> Error {
    error(code: SharedErrorCode.public(code), userInfo: userInfo)
  }

  static func error(code: AuthErrorCode, message: String?) -> Error {
    let userInfo: [String: Any]?
    if let message {
      userInfo = [NSLocalizedDescriptionKey: message]
    } else {
      userInfo = nil
    }
    return error(code: SharedErrorCode.public(code), userInfo: userInfo)
  }

  static func userDisabledError(message: String?) -> Error {
    error(code: .userDisabled, message: message)
  }

  static func wrongPasswordError(message: String?) -> Error {
    error(code: .wrongPassword, message: message)
  }

  static func tooManyRequestsError(message: String?) -> Error {
    error(code: .tooManyRequests, message: message)
  }

  static func invalidCustomTokenError(message: String?) -> Error {
    error(code: .invalidCustomToken, message: message)
  }

  static func customTokenMismatchError(message: String?) -> Error {
    error(code: .customTokenMismatch, message: message)
  }

  static func invalidCredentialError(message: String?) -> Error {
    error(code: .invalidCredential, message: message)
  }

  static func requiresRecentLoginError(message: String?) -> Error {
    error(code: .requiresRecentLogin, message: message)
  }

  static func invalidUserTokenError(message: String?) -> Error {
    error(code: .invalidUserToken, message: message)
  }

  static func invalidEmailError(message: String?) -> Error {
    error(code: .invalidEmail, message: message)
  }

  static func providerAlreadyLinkedError() -> Error {
    error(code: .providerAlreadyLinked)
  }

  static func noSuchProviderError() -> Error {
    error(code: .noSuchProvider)
  }

  static func userTokenExpiredError(message: String?) -> Error {
    error(code: .userTokenExpired, message: message)
  }

  static func userNotFoundError(message: String?) -> Error {
    error(code: .userNotFound, message: message)
  }

  static func invalidAPIKeyError() -> Error {
    error(code: .invalidAPIKey)
  }

  static func userMismatchError() -> Error {
    error(code: .userMismatch)
  }

  static func operationNotAllowedError(message: String?) -> Error {
    error(code: .operationNotAllowed, message: message)
  }

  static func weakPasswordError(serverResponseReason reason: String?) -> Error {
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

  static func appNotAuthorizedError() -> Error {
    error(code: .appNotAuthorized)
  }

  static func expiredActionCodeError(message: String?) -> Error {
    error(code: .expiredActionCode, message: message)
  }

  static func invalidActionCodeError(message: String?) -> Error {
    error(code: .invalidActionCode, message: message)
  }

  static func invalidMessagePayloadError(message: String?) -> Error {
    error(code: .invalidMessagePayload, message: message)
  }

  static func invalidSenderError(message: String?) -> Error {
    error(code: .invalidSender, message: message)
  }

  static func invalidRecipientEmailError(message: String?) -> Error {
    error(code: .invalidRecipientEmail, message: message)
  }

  static func missingIosBundleIDError(message: String?) -> Error {
    error(code: .missingIosBundleID, message: message)
  }

  static func missingAndroidPackageNameError(message: String?) -> Error {
    error(code: .missingAndroidPackageName, message: message)
  }

  static func invalidRecaptchaTokenError() -> Error {
    error(code: .invalidRecaptchaToken)
  }

  static func unauthorizedDomainError(message: String?) -> Error {
    error(code: .unauthorizedDomain, message: message)
  }

  static func invalidContinueURIError(message: String?) -> Error {
    error(code: .invalidContinueURI, message: message)
  }

  static func missingContinueURIError(message: String?) -> Error {
    error(code: .missingContinueURI, message: message)
  }

  static func missingEmailError(message: String?) -> Error {
    error(code: .missingEmail, message: message)
  }

  static func missingPhoneNumberError(message: String?) -> Error {
    error(code: .missingPhoneNumber, message: message)
  }

  static func invalidPhoneNumberError(message: String?) -> Error {
    error(code: .invalidPhoneNumber, message: message)
  }

  static func missingVerificationCodeError(message: String?) -> Error {
    error(code: .missingVerificationCode, message: message)
  }

  static func invalidVerificationCodeError(message: String?) -> Error {
    error(code: .invalidVerificationCode, message: message)
  }

  static func missingVerificationIDError(message: String?) -> Error {
    error(code: .missingVerificationID, message: message)
  }

  static func invalidVerificationIDError(message: String?) -> Error {
    error(code: .invalidVerificationID, message: message)
  }

  static func sessionExpiredError(message: String?) -> Error {
    error(code: .sessionExpired, message: message)
  }

  static func missingAppCredential(message: String?) -> Error {
    error(code: .missingAppCredential, message: message)
  }

  static func invalidAppCredential(message: String?) -> Error {
    error(code: .invalidAppCredential, message: message)
  }

  static func quotaExceededError(message: String?) -> Error {
    error(code: .quotaExceeded, message: message)
  }

  static func missingAppTokenError(underlyingError: Error?) -> Error {
    error(code: .missingAppToken, underlyingError: underlyingError)
  }

  static func localPlayerNotAuthenticatedError() -> Error {
    error(code: .localPlayerNotAuthenticated)
  }

  static func gameKitNotLinkedError() -> Error {
    error(code: .gameKitNotLinked)
  }

  static func RPCRequestEncodingError(underlyingError: Error) -> Error {
    error(code: .internal(.RPCRequestEncodingError), underlyingError: underlyingError)
  }

  static func JSONSerializationErrorForUnencodableType() -> Error {
    error(code: .internal(.JSONSerializationError))
  }

  static func JSONSerializationError(underlyingError: Error) -> Error {
    error(code: .internal(.JSONSerializationError), underlyingError: underlyingError)
  }

  static func networkError(underlyingError: Error) -> Error {
    error(code: .networkError, underlyingError: underlyingError)
  }

  static func emailAlreadyInUseError(email: String?) -> Error {
    var userInfo: [String: Any]?
    if let email, !email.isEmpty {
      userInfo = [AuthErrors.userInfoEmailKey: email]
    }
    return error(code: .emailAlreadyInUse, userInfo: userInfo)
  }

  static func credentialAlreadyInUseError(message: String?,
                                          credential: AuthCredential?,
                                          email: String?) -> Error {
    var userInfo: [String: Any] = [:]
    if let credential {
      userInfo[AuthErrors.userInfoUpdatedCredentialKey] = credential
    }
    if let email, !email.isEmpty {
      userInfo[AuthErrors.userInfoEmailKey] = email
    }
    if !userInfo.isEmpty {
      return error(code: .credentialAlreadyInUse, userInfo: userInfo)
    }
    return error(code: .credentialAlreadyInUse, message: message)
  }

  static func webContextAlreadyPresentedError(message: String?) -> Error {
    error(code: .webContextAlreadyPresented, message: message)
  }

  static func webContextCancelledError(message: String?) -> Error {
    error(code: .webContextCancelled, message: message)
  }

  static func appVerificationUserInteractionFailure(reason: String?) -> Error {
    let userInfo: [String: Any]?
    if let reason, !reason.isEmpty {
      userInfo = [NSLocalizedFailureReasonErrorKey: reason]
    } else {
      userInfo = nil
    }
    return error(code: .appVerificationUserInteractionFailure, userInfo: userInfo)
  }

  static func webSignInUserInteractionFailure(reason: String?) -> Error {
    let userInfo: [String: Any]?
    if let reason, !reason.isEmpty {
      userInfo = [NSLocalizedFailureReasonErrorKey: reason]
    } else {
      userInfo = nil
    }
    return error(code: .webSignInUserInteractionFailure, userInfo: userInfo)
  }

  static func urlResponseError(code: String, message: String?) -> Error {
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

  static func nullUserError(message: String?) -> Error {
    error(code: .nullUser, message: message)
  }

  static func invalidProviderIDError(message: String?) -> Error {
    error(code: .invalidProviderID, message: message)
  }

  static func invalidHostingLinkDomainError(message: String?) -> Error {
    error(code: .invalidHostingLinkDomain, message: message)
  }

  static func missingOrInvalidNonceError(message: String?) -> Error {
    error(code: .missingOrInvalidNonce, message: message)
  }

  static func keychainError(function: String, status: OSStatus) -> Error {
    let message = SecCopyErrorMessageString(status, nil) as String? ?? ""
    let reason = "\(function) (\(status)) \(message)"
    return error(code: .keychainError, userInfo: [NSLocalizedFailureReasonErrorKey: reason])
  }

  static func tenantIDMismatchError() -> Error {
    error(code: .tenantIDMismatch)
  }

  static func unsupportedTenantOperationError() -> Error {
    error(code: .unsupportedTenantOperation)
  }

  static func notificationNotForwardedError() -> Error {
    error(code: .notificationNotForwarded)
  }

  static func appNotVerifiedError(message: String?) -> Error {
    error(code: .appNotVerified, message: message)
  }

  static func missingClientIdentifierError(message: String?) -> Error {
    error(code: .missingClientIdentifier, message: message)
  }

  static func missingClientType(message: String?) -> Error {
    error(code: .missingClientType, message: message)
  }

  static func captchaCheckFailedError(message: String?) -> Error {
    error(code: .captchaCheckFailed, message: message)
  }

  static func unexpectedResponse(data: Data?, underlyingError: Error?) -> Error {
    var userInfo: [String: Any] = [:]
    if let data {
      userInfo[userInfoDataKey] = data
    }
    if let underlyingError {
      userInfo[NSUnderlyingErrorKey] = underlyingError
    }
    return error(code: .internal(.unexpectedResponse), userInfo: userInfo)
  }

  static func unexpectedErrorResponse(data: Data?,
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

  static func unexpectedErrorResponse(deserializedResponse: Any?) -> Error {
    var userInfo: [String: Any]?
    if let deserializedResponse {
      userInfo = [userInfoDeserializedResponseKey: deserializedResponse]
    }
    return error(code: .internal(.unexpectedErrorResponse), userInfo: userInfo)
  }

  static func unexpectedResponse(deserializedResponse: Any?) -> Error {
    var userInfo: [String: Any]?
    if let deserializedResponse {
      userInfo = [userInfoDeserializedResponseKey: deserializedResponse]
    }
    return error(code: .internal(.unexpectedResponse), userInfo: userInfo)
  }

  static func unexpectedResponse(deserializedResponse: Any?,
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

  static func unexpectedErrorResponse(deserializedResponse: Any?,
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

  static func malformedJWTError(token: String, underlyingError: Error?) -> Error {
    var userInfo: [String: Any] = [
      NSLocalizedDescriptionKey: kFIRAuthErrorMessageMalformedJWT,
      userInfoDataKey: token,
    ]
    if let underlyingError {
      userInfo[NSUnderlyingErrorKey] = underlyingError
    }
    return error(code: .malformedJWT, userInfo: userInfo)
  }

  static func RPCResponseDecodingError(deserializedResponse: Any?,
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

  static func accountExistsWithDifferentCredentialError(email: String?,
                                                        updatedCredential: AuthCredential?)
    -> Error {
    var userInfo: [String: Any] = [:]
    if let email {
      userInfo[AuthErrors.userInfoEmailKey] = email
    }
    if let updatedCredential {
      userInfo[AuthErrors.userInfoUpdatedCredentialKey] = updatedCredential
    }
    return error(code: .accountExistsWithDifferentCredential, userInfo: userInfo)
  }

  private static func extractJSONObjectFromString(from string: String) -> [String: Any]? {
    // 1. Find the start of the JSON object.
    guard let start = string.firstIndex(of: "{") else {
      return nil // No JSON object found
    }
    // 2. Find the end of the JSON object.
    // Start from the first curly brace `{`
    var curlyLevel = 0
    var endIndex: String.Index?

    for index in string.indices.suffix(from: start) {
      let char = string[index]
      if char == "{" {
        curlyLevel += 1
      } else if char == "}" {
        curlyLevel -= 1
        if curlyLevel == 0 {
          endIndex = index
          break
        }
      }
    }
    guard let end = endIndex else {
      return nil // Unbalanced curly braces
    }

    // 3. Extract the JSON string.
    let jsonString = String(string[start ... end])

    // 4. Convert JSON String to JSON Object
    guard let jsonData = jsonString.data(using: .utf8) else {
      return nil // Could not convert String to Data
    }

    do {
      if let jsonObject = try JSONSerialization
        .jsonObject(with: jsonData, options: []) as? [String: Any] {
        return jsonObject
      } else {
        return nil // JSON Object is not a dictionary
      }
    } catch {
      return nil // Failed to deserialize JSON
    }
  }

  static func blockingCloudFunctionServerResponse(message: String?) -> Error {
    guard let message else {
      return error(code: .blockingCloudFunctionError, message: message)
    }
    guard let jsonDict = extractJSONObjectFromString(from: message) else {
      return error(code: .blockingCloudFunctionError, message: message)
    }
    let errorDict = jsonDict["error"] as? [String: Any] ?? [:]
    let errorMessage = errorDict["message"] as? String
    return error(code: .blockingCloudFunctionError, message: errorMessage)
  }

  #if os(iOS)
    static func secondFactorRequiredError(pendingCredential: String?,
                                          hints: [MultiFactorInfo],
                                          auth: Auth)
      -> Error {
      var userInfo: [String: Any] = [:]
      if let pendingCredential = pendingCredential {
        let resolver = MultiFactorResolver(with: pendingCredential, hints: hints, auth: auth)
        userInfo[AuthErrors.userInfoMultiFactorResolverKey] = resolver
      }

      return error(code: .secondFactorRequired, userInfo: userInfo)
    }
  #endif // os(iOS)

  static func recaptchaSDKNotLinkedError() -> Error {
    // TODO(ObjC): point the link to GCIP doc once available.
    let message = "The reCAPTCHA SDK is not linked to your app. See " +
      "https://cloud.google.com/recaptcha-enterprise/docs/instrument-ios-apps"
    return error(code: .recaptchaSDKNotLinked, message: message)
  }

  static func recaptchaSiteKeyMissing() -> Error {
    // TODO(ObjC): point the link to GCIP doc once available.
    let message = "The site key for the reCAPTCHA SDK was not found. See " +
      "https://cloud.google.com/recaptcha-enterprise/docs/instrument-ios-apps"
    return error(code: .recaptchaSiteKeyMissing, message: message)
  }

  static func recaptchaActionCreationFailed() -> Error {
    // TODO(ObjC): point the link to GCIP doc once available.
    let message = "The reCAPTCHA SDK action class creation failed. See " +
      "https://cloud.google.com/recaptcha-enterprise/docs/instrument-ios-apps"
    return error(code: .recaptchaActionCreationFailed, message: message)
  }
}
