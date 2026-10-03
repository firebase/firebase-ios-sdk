// Copyright 2026 Google LLC
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

public import Foundation

/// **[Experimental]** The Firebase Auth error domain.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public let AuthErrorDomain: String = "FIRAuthErrorDomain"

/// **[Experimental]** The key used in `NSError.userInfo` for the short string name of an Auth
/// error code.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public let AuthErrorUserInfoNameKey: String = "FIRAuthErrorUserInfoNameKey"

/// **[Experimental]** Error codes returned by Firebase Auth.
///
/// > Warning: This portable implementation is for development and testing use
/// > only. The Firebase Apple SDK is only officially supported on Apple
/// > platforms.
public enum AuthErrorCode: Int, Error, Sendable, CustomNSError {
  /// **[Experimental]** Indicates a validation error with the custom token.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case invalidCustomToken = 17000

  /// **[Experimental]** Indicates the service account and the API key belong to different
  /// projects.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case customTokenMismatch = 17002

  /// **[Experimental]** Indicates the IDP token or credential is invalid.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case invalidCredential = 17004

  /// **[Experimental]** Indicates the user's account is disabled on the server.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case userDisabled = 17005

  /// **[Experimental]** Indicates the administrator disabled sign in with the specified identity
  /// provider.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case operationNotAllowed = 17006

  /// **[Experimental]** Indicates the email used to attempt a sign up is already in use.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case emailAlreadyInUse = 17007

  /// **[Experimental]** Indicates the email is invalid.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case invalidEmail = 17008

  /// **[Experimental]** Indicates the user attempted sign in with a wrong password.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case wrongPassword = 17009

  /// **[Experimental]** Indicates that too many requests were made to a server method.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case tooManyRequests = 17010

  /// **[Experimental]** Indicates the user account was not found.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case userNotFound = 17011

  /// **[Experimental]** Indicates the user has attempted to change email or password more than 5
  /// minutes after signing in.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case requiresRecentLogin = 17014

  /// **[Experimental]** Indicates the user's saved auth credential is invalid and the user needs
  /// to sign in again.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case invalidUserToken = 17017

  /// **[Experimental]** Indicates a network error occurred.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case networkError = 17020

  /// **[Experimental]** Indicates the saved token has expired.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case userTokenExpired = 17021

  /// **[Experimental]** Indicates an invalid API key was supplied in the request.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case invalidAPIKey = 17023

  /// **[Experimental]** Indicates that an attempt was made to reauthenticate with a user which is
  /// not the current user.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case userMismatch = 17024

  /// **[Experimental]** Indicates an attempt to set a password that is considered too weak.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case weakPassword = 17026

  /// **[Experimental]** Indicates the app is not authorized to use Firebase Authentication with
  /// the provided API key.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case appNotAuthorized = 17028

  /// **[Experimental]** Indicates that an email address was expected but one was not provided.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case missingEmail = 17034

  /// **[Experimental]** Indicates that a non-null user was expected as an argument to the
  /// operation but a null user was provided.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case nullUser = 17067

  /// **[Experimental]** Indicates that the operation is admin restricted.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case adminRestrictedOperation = 17085

  /// **[Experimental]** Indicates an error occurred while attempting to access the keychain.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case keychainError = 17995

  /// **[Experimental]** Indicates an internal error occurred.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case internalError = 17999

  /// **[Experimental]** Raised when a JWT fails to parse correctly.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  case malformedJWT = 18000

  /// **[Experimental]** The domain of the error.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public static var errorDomain: String {
    AuthErrorDomain
  }

  /// **[Experimental]** The error code within the given domain.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var errorCode: Int {
    rawValue
  }

  /// **[Experimental]** The user-info dictionary for the error.
  ///
  /// > Warning: This portable implementation is for development and testing use
  /// > only. The Firebase Apple SDK is only officially supported on Apple
  /// > platforms.
  public var errorUserInfo: [String: Any] {
    [:]
  }
}

/// Internal utilities for constructing and mapping `FirebaseAuth` errors.
package enum AuthErrorUtil {
  private struct ServerErrorEnvelope: Decodable {
    struct ErrorDetail: Decodable {
      let code: Int?
      let message: String?
    }

    let error: ErrorDetail?
  }

  /// Creates an `NSError` in `AuthErrorDomain`.
  package static func error(code: AuthErrorCode,
                            message: String,
                            name: String? = nil,
                            underlyingError: (any Error)? = nil) -> NSError {
    var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]
    if let name {
      userInfo[AuthErrorUserInfoNameKey] = name
    }
    if let underlyingError {
      userInfo[NSUnderlyingErrorKey] = underlyingError
    }
    return NSError(domain: AuthErrorDomain, code: code.rawValue, userInfo: userInfo)
  }

  /// Maps a non-200 Identity Toolkit or Secure Token HTTP response payload to an `NSError` in
  /// `AuthErrorDomain`.
  package static func serverError(from data: Data, statusCode: Int) -> NSError {
    if let envelope = try? JSONDecoder().decode(ServerErrorEnvelope.self, from: data),
       let rawMessage = envelope.error?.message,
       !rawMessage.isEmpty {
      let token = rawMessage.split(separator: ":").first.map {
        $0.trimmingCharacters(in: .whitespaces)
      } ?? rawMessage
      let code = mapServerErrorCode(token)
      return error(
        code: code,
        message: "Firebase Auth request failed with HTTP \(statusCode): \(rawMessage)",
        name: token
      )
    }

    let bodyText = String(decoding: data, as: UTF8.self)
    return error(
      code: .internalError,
      message: "Firebase Auth request failed with HTTP \(statusCode): \(bodyText)"
    )
  }

  private static func mapServerErrorCode(_ serverCode: String) -> AuthErrorCode {
    switch serverCode {
    case "INVALID_CUSTOM_TOKEN":
      return .invalidCustomToken
    case "CREDENTIAL_MISMATCH":
      return .customTokenMismatch
    case "INVALID_LOGIN_CREDENTIALS", "INVALID_IDP_RESPONSE":
      return .invalidCredential
    case "USER_DISABLED":
      return .userDisabled
    case "OPERATION_NOT_ALLOWED":
      return .operationNotAllowed
    case "EMAIL_EXISTS":
      return .emailAlreadyInUse
    case "INVALID_EMAIL":
      return .invalidEmail
    case "INVALID_PASSWORD", "WRONG_PASSWORD":
      return .wrongPassword
    case "TOO_MANY_ATTEMPTS_TRY_LATER":
      return .tooManyRequests
    case "EMAIL_NOT_FOUND", "USER_NOT_FOUND":
      return .userNotFound
    case "CREDENTIAL_TOO_OLD_LOGIN_AGAIN":
      return .requiresRecentLogin
    case "INVALID_ID_TOKEN", "INVALID_REFRESH_TOKEN", "INVALID_GRANT":
      return .invalidUserToken
    case "TOKEN_EXPIRED":
      return .userTokenExpired
    case "API_KEY_INVALID":
      return .invalidAPIKey
    case "WEAK_PASSWORD":
      return .weakPassword
    case "MISSING_EMAIL":
      return .missingEmail
    case "ADMIN_ONLY_OPERATION":
      return .adminRestrictedOperation
    default:
      return .internalError
    }
  }
}
