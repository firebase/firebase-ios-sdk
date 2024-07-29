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

/// Error Codes common to all API Methods:
@objc(FIRAuthErrors) open class AuthErrors: NSObject {
  /// The Firebase Auth error domain.
  @objc public static let domain: String = "FIRAuthErrorDomain"

  /// The name of the key for the error short string of an error code.
  @objc public static let userInfoNameKey: String = "FIRAuthErrorUserInfoNameKey"

  /// Error codes for Email operations
  ///
  /// Errors with one of the following three codes:
  /// * `accountExistsWithDifferentCredential`
  /// * `credentialAlreadyInUse`
  /// * emailAlreadyInUse`
  ///
  /// may contain  an `NSError.userInfo` dictionary object which contains this key. The value
  /// associated with this key is an NSString of the email address of the account that already
  /// exists.
  @objc public static let userInfoEmailKey: String = "FIRAuthErrorUserInfoEmailKey"

  /// The key used to read the updated Auth credential from the userInfo dictionary of the
  /// NSError object returned. This is the updated auth credential the developer should use for
  /// recovery if applicable.
  @objc public static let userInfoUpdatedCredentialKey: String =
    "FIRAuthErrorUserInfoUpdatedCredentialKey"

  /// The key used to read the MFA resolver from the userInfo dictionary of the NSError object
  /// returned when 2FA is required for sign-incompletion.
  @objc(FIRAuthErrorUserInfoMultiFactorResolverKey)
  public static let userInfoMultiFactorResolverKey: String =
    "FIRAuthErrorUserInfoMultiFactorResolverKey"
}

/// Error codes used by Firebase Auth.
@objc(FIRAuthErrorCode) public enum AuthErrorCode: Int {
  /// Indicates a validation error with the custom token.
  case invalidCustomToken = 17000

  /// Indicates the service account and the API key belong to different projects.
  case customTokenMismatch = 17002

  /// Indicates the IDP token or requestUri is invalid.
  case invalidCredential = 17004

  /// Indicates the user's account is disabled on the server.
  case userDisabled = 17005

  /// Indicates the administrator disabled sign in with the specified identity provider.
  case operationNotAllowed = 17006

  /// Indicates the email used to attempt a sign up is already in use.
  case emailAlreadyInUse = 17007

  /// Indicates the email is invalid.
  case invalidEmail = 17008

  /// Indicates the user attempted sign in with a wrong password.
  case wrongPassword = 17009

  /// Indicates that too many requests were made to a server method.
  case tooManyRequests = 17010

  /// Indicates the user account was not found.
  case userNotFound = 17011

  /// Indicates account linking is required.
  case accountExistsWithDifferentCredential = 17012

  /// Indicates the user has attempted to change email or password more than 5 minutes after
  /// signing in.
  case requiresRecentLogin = 17014

  /// Indicates an attempt to link a provider to which the account is already linked.
  case providerAlreadyLinked = 17015

  /// Indicates an attempt to unlink a provider that is not linked.
  case noSuchProvider = 17016

  /// Indicates user's saved auth credential is invalid the user needs to sign in again.
  case invalidUserToken = 17017

  /// Indicates a network error occurred (such as a timeout interrupted connection or
  /// unreachable host). These types of errors are often recoverable with a retry. The
  /// `NSUnderlyingError` field in the `NSError.userInfo` dictionary will contain the error
  /// encountered.
  case networkError = 17020

  /// Indicates the saved token has expired for example the user may have changed account
  /// password on another device. The user needs to sign in again on the device that made this
  /// request.
  case userTokenExpired = 17021

  /// Indicates an invalid API key was supplied in the request.
  case invalidAPIKey = 17023

  /// Indicates that an attempt was made to reauthenticate with a user which is not the current
  /// user.
  case userMismatch = 17024

  /// Indicates an attempt to link with a credential that has already been linked with a
  /// different Firebase account.
  case credentialAlreadyInUse = 17025

  /// Indicates an attempt to set a password that is considered too weak.
  case weakPassword = 17026

  /// Indicates the App is not authorized to use Firebase Authentication with the
  /// provided API Key.
  case appNotAuthorized = 17028

  /// Indicates the OOB code is expired.
  case expiredActionCode = 17029

  /// Indicates the OOB code is invalid.
  case invalidActionCode = 17030

  /// Indicates that there are invalid parameters in the payload during a
  /// "send password reset email" attempt.
  case invalidMessagePayload = 17031

  /// Indicates that the sender email is invalid during a "send password reset email" attempt.
  case invalidSender = 17032

  /// Indicates that the recipient email is invalid.
  case invalidRecipientEmail = 17033

  /// Indicates that an email address was expected but one was not provided.
  case missingEmail = 17034

  // The enum values 17035 is reserved and should NOT be used for new error codes.

  /// Indicates that the iOS bundle ID is missing when a iOS App Store ID is provided.
  case missingIosBundleID = 17036

  /// Indicates that the android package name is missing when the `androidInstallApp` flag is set
  /// to `true`.
  case missingAndroidPackageName = 17037

  /// Indicates that the domain specified in the continue URL is not allowlisted in the Firebase
  /// console.
  case unauthorizedDomain = 17038

  /// Indicates that the domain specified in the continue URI is not valid.
  case invalidContinueURI = 17039

  /// Indicates that a continue URI was not provided in a request to the backend which requires one.
  case missingContinueURI = 17040

  /// Indicates that a phone number was not provided in a call to
  /// `verifyPhoneNumber:completion:`.
  case missingPhoneNumber = 17041

  /// Indicates that an invalid phone number was provided in a call to
  /// `verifyPhoneNumber:completion:`.
  case invalidPhoneNumber = 17042

  /// Indicates that the phone auth credential was created with an empty verification code.
  case missingVerificationCode = 17043

  /// Indicates that an invalid verification code was used in the verifyPhoneNumber request.
  case invalidVerificationCode = 17044

  /// Indicates that the phone auth credential was created with an empty verification ID.
  case missingVerificationID = 17045

  /// Indicates that an invalid verification ID was used in the verifyPhoneNumber request.
  case invalidVerificationID = 17046

  /// Indicates that the APNS device token is missing in the verifyClient request.
  case missingAppCredential = 17047

  /// Indicates that an invalid APNS device token was used in the verifyClient request.
  case invalidAppCredential = 17048

  // The enum values between 17048 and 17051 are reserved and should NOT be used for new error
  // codes.

  /// Indicates that the SMS code has expired.
  case sessionExpired = 17051

  /// Indicates that the quota of SMS messages for a given project has been exceeded.
  case quotaExceeded = 17052

  /// Indicates that the APNs device token could not be obtained. The app may not have set up
  /// remote notification correctly or may fail to forward the APNs device token to Auth
  /// if app delegate swizzling is disabled.
  case missingAppToken = 17053

  /// Indicates that the app fails to forward remote notification to FIRAuth.
  case notificationNotForwarded = 17054

  /// Indicates that the app could not be verified by Firebase during phone number authentication.
  case appNotVerified = 17055

  /// Indicates that the reCAPTCHA token is not valid.
  case captchaCheckFailed = 17056

  /// Indicates that an attempt was made to present a new web context while one was already being
  /// presented.
  case webContextAlreadyPresented = 17057

  /// Indicates that the URL presentation was cancelled prematurely by the user.
  case webContextCancelled = 17058

  /// Indicates a general failure during the app verification flow.
  case appVerificationUserInteractionFailure = 17059

  /// Indicates that the clientID used to invoke a web flow is invalid.
  case invalidClientID = 17060

  /// Indicates that a network request within a SFSafariViewController or WKWebView failed.
  case webNetworkRequestFailed = 17061

  /// Indicates that an internal error occurred within a SFSafariViewController or WKWebView.
  case webInternalError = 17062

  /// Indicates a general failure during a web sign-in flow.
  case webSignInUserInteractionFailure = 17063

  /// Indicates that the local player was not authenticated prior to attempting Game Center signin.
  case localPlayerNotAuthenticated = 17066

  /// Indicates that a non-null user was expected as an argument to the operation but a null
  /// user was provided.
  case nullUser = 17067

  /// Indicates that a Firebase Dynamic Link is not activated.
  case dynamicLinkNotActivated = 17068

  /// Represents the error code for when the given provider id for a web operation is invalid.
  case invalidProviderID = 17071

  /// Represents the error code for when an attempt is made to update the current user with a
  /// tenantId that differs from the current FirebaseAuth instance's tenantId.
  case tenantIDMismatch = 17072

  /// Represents the error code for when a request is made to the backend with an associated tenant
  /// ID for an operation that does not support multi-tenancy.
  case unsupportedTenantOperation = 17073

  /// Indicates that the Firebase Dynamic Link domain used is either not configured or is
  /// unauthorized for the current project.
  case invalidDynamicLinkDomain = 17074

  /// Indicates that the credential is rejected because it's malformed or mismatching.
  case rejectedCredential = 17075

  /// Indicates that the GameKit framework is not linked prior to attempting Game Center signin.
  case gameKitNotLinked = 17076

  /// Indicates that the second factor is required for signin.
  case secondFactorRequired = 17078

  /// Indicates that the multi factor session is missing.
  case missingMultiFactorSession = 17081

  /// Indicates that the multi factor info is missing.
  case missingMultiFactorInfo = 17082

  /// Indicates that the multi factor session is invalid.
  case invalidMultiFactorSession = 17083

  /// Indicates that the multi factor info is not found.
  case multiFactorInfoNotFound = 17084

  /// Indicates that the operation is admin restricted.
  case adminRestrictedOperation = 17085

  /// Indicates that the email is required for verification.
  case unverifiedEmail = 17086

  /// Indicates that the second factor is already enrolled.
  case secondFactorAlreadyEnrolled = 17087

  /// Indicates that the maximum second factor count is exceeded.
  case maximumSecondFactorCountExceeded = 17088

  /// Indicates that the first factor is not supported.
  case unsupportedFirstFactor = 17089

  /// Indicates that the a verified email is required to changed to.
  case emailChangeNeedsVerification = 17090

  /// Indicates that the request does not contain a client identifier.
  case missingClientIdentifier = 17093

  /// Indicates that the nonce is missing or invalid.
  case missingOrInvalidNonce = 17094

  /// Raised when n Cloud Function returns a blocking error. Will include a message returned from
  /// the function.
  case blockingCloudFunctionError = 17105

  /// Indicates that reCAPTCHA Enterprise integration is not enabled for this project.
  case recaptchaNotEnabled = 17200

  /// Indicates that the reCAPTCHA token is missing from the backend request.
  case missingRecaptchaToken = 17201

  /// Indicates that the reCAPTCHA token sent with the backend request is invalid.
  case invalidRecaptchaToken = 17202

  /// Indicates that the requested reCAPTCHA action is invalid.
  case invalidRecaptchaAction = 17203

  /// Indicates that the client type is missing from the request.
  case missingClientType = 17204

  /// Indicates that the reCAPTCHA version is missing from the request.
  case missingRecaptchaVersion = 17205

  /// Indicates that the reCAPTCHA version sent to the backend is invalid.
  case invalidRecaptchaVersion = 17206

  /// Indicates that the request type sent to the backend is invalid.
  case invalidReqType = 17207

  /// Indicates that the reCAPTCHA SDK is not linked to the app.
  case recaptchaSDKNotLinked = 17208

  /// Indicates that the reCAPTCHA SDK site key wasn't found.
  case recaptchaSiteKeyMissing = 17209

  /// Indicates that the reCAPTCHA SDK actions class failed to create.
  case recaptchaActionCreationFailed = 17210

  /// Indicates an error occurred while attempting to access the keychain.
  case keychainError = 17995

  /// Indicates an internal error occurred.
  case internalError = 17999

  /// Raised when a JWT fails to parse correctly. May be accompanied by an underlying error
  /// describing which step of the JWT parsing process failed.
  case malformedJWT = 18000

  var errorDescription: String {
    switch self {
    case .invalidCustomToken:
      return kErrorInvalidCustomToken
    case .customTokenMismatch:
      return kErrorCustomTokenMismatch
    case .invalidEmail:
      return kErrorInvalidEmail
    case .invalidCredential:
      return kErrorInvalidCredential
    case .userDisabled:
      return kErrorUserDisabled
    case .emailAlreadyInUse:
      return kErrorEmailAlreadyInUse
    case .wrongPassword:
      return kErrorWrongPassword
    case .tooManyRequests:
      return kErrorTooManyRequests
    case .accountExistsWithDifferentCredential:
      return kErrorAccountExistsWithDifferentCredential
    case .requiresRecentLogin:
      return kErrorRequiresRecentLogin
    case .providerAlreadyLinked:
      return kErrorProviderAlreadyLinked
    case .noSuchProvider:
      return kErrorNoSuchProvider
    case .invalidUserToken:
      return kErrorInvalidUserToken
    case .networkError:
      return kErrorNetworkError
    case .keychainError:
      return kErrorKeychainError
    case .missingClientIdentifier:
      return kErrorMissingClientIdentifier
    case .userTokenExpired:
      return kErrorUserTokenExpired
    case .userNotFound:
      return kErrorUserNotFound
    case .invalidAPIKey:
      return kErrorInvalidAPIKey
    case .credentialAlreadyInUse:
      return kErrorCredentialAlreadyInUse
    case .internalError:
      return kErrorInternalError
    case .userMismatch:
      return FIRAuthErrorMessageUserMismatch
    case .operationNotAllowed:
      return kErrorOperationNotAllowed
    case .weakPassword:
      return kErrorWeakPassword
    case .appNotAuthorized:
      return kErrorAppNotAuthorized
    case .expiredActionCode:
      return kErrorExpiredActionCode
    case .invalidActionCode:
      return kErrorInvalidActionCode
    case .invalidSender:
      return kErrorInvalidSender
    case .invalidMessagePayload:
      return kErrorInvalidMessagePayload
    case .invalidRecipientEmail:
      return kErrorInvalidRecipientEmail
    case .missingIosBundleID:
      return kErrorMissingIosBundleID
    case .missingAndroidPackageName:
      return kErrorMissingAndroidPackageName
    case .unauthorizedDomain:
      return kErrorUnauthorizedDomain
    case .invalidContinueURI:
      return kErrorInvalidContinueURI
    case .missingContinueURI:
      return kErrorMissingContinueURI
    case .missingEmail:
      return kErrorMissingEmail
    case .missingPhoneNumber:
      return kErrorMissingPhoneNumber
    case .invalidPhoneNumber:
      return kErrorInvalidPhoneNumber
    case .missingVerificationCode:
      return kErrorMissingVerificationCode
    case .invalidVerificationCode:
      return kErrorInvalidVerificationCode
    case .missingVerificationID:
      return kErrorMissingVerificationID
    case .invalidVerificationID:
      return kErrorInvalidVerificationID
    case .sessionExpired:
      return kErrorSessionExpired
    case .missingAppCredential:
      return kErrorMissingAppCredential
    case .invalidAppCredential:
      return kErrorInvalidAppCredential
    case .quotaExceeded:
      return kErrorQuotaExceeded
    case .missingAppToken:
      return kErrorMissingAppToken
    case .notificationNotForwarded:
      return kErrorNotificationNotForwarded
    case .appNotVerified:
      return kErrorAppNotVerified
    case .captchaCheckFailed:
      return kErrorCaptchaCheckFailed
    case .webContextAlreadyPresented:
      return kErrorWebContextAlreadyPresented
    case .webContextCancelled:
      return kErrorWebContextCancelled
    case .invalidClientID:
      return kErrorInvalidClientID
    case .appVerificationUserInteractionFailure:
      return kErrorAppVerificationUserInteractionFailure
    case .webNetworkRequestFailed:
      return kErrorWebRequestFailed
    case .nullUser:
      return kErrorNullUser
    case .invalidProviderID:
      return kErrorInvalidProviderID
    case .invalidDynamicLinkDomain:
      return kErrorInvalidDynamicLinkDomain
    case .webInternalError:
      return kErrorWebInternalError
    case .webSignInUserInteractionFailure:
      return kErrorAppVerificationUserInteractionFailure
    case .malformedJWT:
      return kErrorMalformedJWT
    case .localPlayerNotAuthenticated:
      return kErrorLocalPlayerNotAuthenticated
    case .gameKitNotLinked:
      return kErrorGameKitNotLinked
    case .secondFactorRequired:
      return kErrorSecondFactorRequired
    case .missingMultiFactorSession:
      return FIRAuthErrorMessageMissingMultiFactorSession
    case .missingMultiFactorInfo:
      return FIRAuthErrorMessageMissingMultiFactorInfo
    case .invalidMultiFactorSession:
      return FIRAuthErrorMessageInvalidMultiFactorSession
    case .multiFactorInfoNotFound:
      return FIRAuthErrorMessageMultiFactorInfoNotFound
    case .adminRestrictedOperation:
      return FIRAuthErrorMessageAdminRestrictedOperation
    case .unverifiedEmail:
      return FIRAuthErrorMessageUnverifiedEmail
    case .secondFactorAlreadyEnrolled:
      return FIRAuthErrorMessageSecondFactorAlreadyEnrolled
    case .maximumSecondFactorCountExceeded:
      return FIRAuthErrorMessageMaximumSecondFactorCountExceeded
    case .unsupportedFirstFactor:
      return FIRAuthErrorMessageUnsupportedFirstFactor
    case .emailChangeNeedsVerification:
      return FIRAuthErrorMessageEmailChangeNeedsVerification
    case .dynamicLinkNotActivated:
      return kErrorDynamicLinkNotActivated
    case .rejectedCredential:
      return kErrorRejectedCredential
    case .missingOrInvalidNonce:
      return kErrorMissingOrInvalidNonce
    case .tenantIDMismatch:
      return kErrorTenantIDMismatch
    case .unsupportedTenantOperation:
      return kErrorUnsupportedTenantOperation
    case .blockingCloudFunctionError:
      return kErrorBlockingCloudFunctionReturnedError
    case .recaptchaNotEnabled:
      return kErrorRecaptchaNotEnabled
    case .missingRecaptchaToken:
      return kErrorMissingRecaptchaToken
    case .invalidRecaptchaToken:
      return kErrorInvalidRecaptchaToken
    case .invalidRecaptchaAction:
      return kErrorInvalidRecaptchaAction
    case .missingClientType:
      return kErrorMissingClientType
    case .missingRecaptchaVersion:
      return kErrorMissingRecaptchaVersion
    case .invalidRecaptchaVersion:
      return kErrorInvalidRecaptchaVersion
    case .invalidReqType:
      return kErrorInvalidReqType
    case .recaptchaSDKNotLinked:
      return kErrorRecaptchaSDKNotLinked
    case .recaptchaSiteKeyMissing:
      return kErrorSiteKeyMissing
    case .recaptchaActionCreationFailed:
      return kErrorRecaptchaActionCreationFailed
    }
  }

  var errorCodeString: String {
    switch self {
    case .invalidCustomToken:
      return "ERROR_INVALID_CUSTOM_TOKEN"
    case .customTokenMismatch:
      return "ERROR_CUSTOM_TOKEN_MISMATCH"
    case .invalidEmail:
      return "ERROR_INVALID_EMAIL"
    case .invalidCredential:
      return "ERROR_INVALID_CREDENTIAL"
    case .userDisabled:
      return "ERROR_USER_DISABLED"
    case .emailAlreadyInUse:
      return "ERROR_EMAIL_ALREADY_IN_USE"
    case .wrongPassword:
      return "ERROR_WRONG_PASSWORD"
    case .tooManyRequests:
      return "ERROR_TOO_MANY_REQUESTS"
    case .accountExistsWithDifferentCredential:
      return "ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL"
    case .requiresRecentLogin:
      return "ERROR_REQUIRES_RECENT_LOGIN"
    case .providerAlreadyLinked:
      return "ERROR_PROVIDER_ALREADY_LINKED"
    case .noSuchProvider:
      return "ERROR_NO_SUCH_PROVIDER"
    case .invalidUserToken:
      return "ERROR_INVALID_USER_TOKEN"
    case .networkError:
      return "ERROR_NETWORK_REQUEST_FAILED"
    case .keychainError:
      return "ERROR_KEYCHAIN_ERROR"
    case .missingClientIdentifier:
      return "ERROR_MISSING_CLIENT_IDENTIFIER"
    case .userTokenExpired:
      return "ERROR_USER_TOKEN_EXPIRED"
    case .userNotFound:
      return "ERROR_USER_NOT_FOUND"
    case .invalidAPIKey:
      return "ERROR_INVALID_API_KEY"
    case .credentialAlreadyInUse:
      return "ERROR_CREDENTIAL_ALREADY_IN_USE"
    case .internalError:
      return "ERROR_INTERNAL_ERROR"
    case .userMismatch:
      return "ERROR_USER_MISMATCH"
    case .operationNotAllowed:
      return "ERROR_OPERATION_NOT_ALLOWED"
    case .weakPassword:
      return "ERROR_WEAK_PASSWORD"
    case .appNotAuthorized:
      return "ERROR_APP_NOT_AUTHORIZED"
    case .expiredActionCode:
      return "ERROR_EXPIRED_ACTION_CODE"
    case .invalidActionCode:
      return "ERROR_INVALID_ACTION_CODE"
    case .invalidMessagePayload:
      return "ERROR_INVALID_MESSAGE_PAYLOAD"
    case .invalidSender:
      return "ERROR_INVALID_SENDER"
    case .invalidRecipientEmail:
      return "ERROR_INVALID_RECIPIENT_EMAIL"
    case .missingIosBundleID:
      return "ERROR_MISSING_IOS_BUNDLE_ID"
    case .missingAndroidPackageName:
      return "ERROR_MISSING_ANDROID_PKG_NAME"
    case .unauthorizedDomain:
      return "ERROR_UNAUTHORIZED_DOMAIN"
    case .invalidContinueURI:
      return "ERROR_INVALID_CONTINUE_URI"
    case .missingContinueURI:
      return "ERROR_MISSING_CONTINUE_URI"
    case .missingEmail:
      return "ERROR_MISSING_EMAIL"
    case .missingPhoneNumber:
      return "ERROR_MISSING_PHONE_NUMBER"
    case .invalidPhoneNumber:
      return "ERROR_INVALID_PHONE_NUMBER"
    case .missingVerificationCode:
      return "ERROR_MISSING_VERIFICATION_CODE"
    case .invalidVerificationCode:
      return "ERROR_INVALID_VERIFICATION_CODE"
    case .missingVerificationID:
      return "ERROR_MISSING_VERIFICATION_ID"
    case .invalidVerificationID:
      return "ERROR_INVALID_VERIFICATION_ID"
    case .sessionExpired:
      return "ERROR_SESSION_EXPIRED"
    case .missingAppCredential:
      return "MISSING_APP_CREDENTIAL"
    case .invalidAppCredential:
      return "INVALID_APP_CREDENTIAL"
    case .quotaExceeded:
      return "ERROR_QUOTA_EXCEEDED"
    case .missingAppToken:
      return "ERROR_MISSING_APP_TOKEN"
    case .notificationNotForwarded:
      return "ERROR_NOTIFICATION_NOT_FORWARDED"
    case .appNotVerified:
      return "ERROR_APP_NOT_VERIFIED"
    case .captchaCheckFailed:
      return "ERROR_CAPTCHA_CHECK_FAILED"
    case .webContextAlreadyPresented:
      return "ERROR_WEB_CONTEXT_ALREADY_PRESENTED"
    case .webContextCancelled:
      return "ERROR_WEB_CONTEXT_CANCELLED"
    case .invalidClientID:
      return "ERROR_INVALID_CLIENT_ID"
    case .appVerificationUserInteractionFailure:
      return "ERROR_APP_VERIFICATION_FAILED"
    case .webNetworkRequestFailed:
      return "ERROR_WEB_NETWORK_REQUEST_FAILED"
    case .nullUser:
      return "ERROR_NULL_USER"
    case .invalidProviderID:
      return "ERROR_INVALID_PROVIDER_ID"
    case .invalidDynamicLinkDomain:
      return "ERROR_INVALID_DYNAMIC_LINK_DOMAIN"
    case .webInternalError:
      return "ERROR_WEB_INTERNAL_ERROR"
    case .webSignInUserInteractionFailure:
      return "ERROR_WEB_USER_INTERACTION_FAILURE"
    case .malformedJWT:
      return "ERROR_MALFORMED_JWT"
    case .localPlayerNotAuthenticated:
      return "ERROR_LOCAL_PLAYER_NOT_AUTHENTICATED"
    case .gameKitNotLinked:
      return "ERROR_GAME_KIT_NOT_LINKED"
    case .secondFactorRequired:
      return "ERROR_SECOND_FACTOR_REQUIRED"
    case .missingMultiFactorSession:
      return "ERROR_MISSING_MULTI_FACTOR_SESSION"
    case .missingMultiFactorInfo:
      return "ERROR_MISSING_MULTI_FACTOR_INFO"
    case .invalidMultiFactorSession:
      return "ERROR_INVALID_MULTI_FACTOR_SESSION"
    case .multiFactorInfoNotFound:
      return "ERROR_MULTI_FACTOR_INFO_NOT_FOUND"
    case .adminRestrictedOperation:
      return "ERROR_ADMIN_RESTRICTED_OPERATION"
    case .unverifiedEmail:
      return "ERROR_UNVERIFIED_EMAIL"
    case .secondFactorAlreadyEnrolled:
      return "ERROR_SECOND_FACTOR_ALREADY_ENROLLED"
    case .maximumSecondFactorCountExceeded:
      return "ERROR_MAXIMUM_SECOND_FACTOR_COUNT_EXCEEDED"
    case .unsupportedFirstFactor:
      return "ERROR_UNSUPPORTED_FIRST_FACTOR"
    case .emailChangeNeedsVerification:
      return "ERROR_EMAIL_CHANGE_NEEDS_VERIFICATION"
    case .dynamicLinkNotActivated:
      return "ERROR_DYNAMIC_LINK_NOT_ACTIVATED"
    case .rejectedCredential:
      return "ERROR_REJECTED_CREDENTIAL"
    case .missingOrInvalidNonce:
      return "ERROR_MISSING_OR_INVALID_NONCE"
    case .tenantIDMismatch:
      return "ERROR_TENANT_ID_MISMATCH"
    case .unsupportedTenantOperation:
      return "ERROR_UNSUPPORTED_TENANT_OPERATION"
    case .blockingCloudFunctionError:
      return "ERROR_BLOCKING_CLOUD_FUNCTION_RETURNED_ERROR"
    case .recaptchaNotEnabled:
      return "ERROR_RECAPTCHA_NOT_ENABLED"
    case .missingRecaptchaToken:
      return "ERROR_MISSING_RECAPTCHA_TOKEN"
    case .invalidRecaptchaToken:
      return "ERROR_INVALID_RECAPTCHA_TOKEN"
    case .invalidRecaptchaAction:
      return "ERROR_INVALID_RECAPTCHA_ACTION"
    case .missingClientType:
      return "ERROR_MISSING_CLIENT_TYPE"
    case .missingRecaptchaVersion:
      return "ERROR_MISSING_RECAPTCHA_VERSION"
    case .invalidRecaptchaVersion:
      return "ERROR_INVALID_RECAPTCHA_VERSION"
    case .invalidReqType:
      return "ERROR_INVALID_REQ_TYPE"
    case .recaptchaSDKNotLinked:
      return "ERROR_RECAPTCHA_SDK_NOT_LINKED"
    case .recaptchaSiteKeyMissing:
      return "ERROR_RECAPTCHA_SITE_KEY_MISSING"
    case .recaptchaActionCreationFailed:
      return "ERROR_RECAPTCHA_ACTION_CREATION_FAILED"
    }
  }
}

// MARK: - Standard Error Messages

private let kErrorInvalidCustomToken =
  "The custom token format is incorrect. Please check the documentation."

private let kErrorCustomTokenMismatch =
  "The custom token corresponds to a different audience."

private let kErrorInvalidEmail = "The email address is badly formatted."

private let kErrorInvalidCredential =
  "The supplied auth credential is malformed or has expired."

private let kErrorUserDisabled =
  "The user account has been disabled by an administrator."

private let kErrorEmailAlreadyInUse =
  "The email address is already in use by another account."

private let kErrorWrongPassword =
  "The password is invalid or the user does not have a password."

private let kErrorTooManyRequests =
  "We have blocked all requests from this device due to unusual activity. Try again later."

private let kErrorAccountExistsWithDifferentCredential =
  "An account already exists with the same email address but different sign-in credentials. Sign in using a provider associated with this email address."

private let kErrorRequiresRecentLogin =
  "This operation is sensitive and requires recent authentication. Log in again before retrying this request."

private let kErrorProviderAlreadyLinked =
  "[ERROR_PROVIDER_ALREADY_LINKED] - User can only be linked to one identity for the given provider."

private let kErrorNoSuchProvider =
  "User was not linked to an account with the given provider."

private let kErrorInvalidUserToken =
  "This user's credential isn't valid for this project. This can happen if the user's token has been tampered with, or if the user doesn’t belong to the project associated with the API key used in your request."

private let kErrorNetworkError =
  "Network error (such as timeout, interrupted connection or unreachable host) has occurred."

private let kErrorKeychainError =
  "An error occurred when accessing the keychain. The NSLocalizedFailureReasonErrorKey field in the NSError.userInfo dictionary will contain more information about the error encountered"

private let kErrorUserTokenExpired =
  "The user's credential is no longer valid. The user must sign in again."

private let kErrorUserNotFound =
  "There is no user record corresponding to this identifier. The user may have been deleted."

private let kErrorInvalidAPIKey = "An invalid API Key was supplied in the request."

private let FIRAuthErrorMessageUserMismatch =
  "The supplied credentials do not correspond to the previously signed in user."

private let kErrorCredentialAlreadyInUse =
  "This credential is already associated with a different user account."

private let kErrorOperationNotAllowed =
  "The given sign-in provider is disabled for this Firebase project. Enable it in the Firebase console, under the sign-in method tab of the Auth section."

private let kErrorWeakPassword = "The password must be 6 characters long or more."

private let kErrorAppNotAuthorized =
  "This app is not authorized to use Firebase Authentication with the provided API key. Review your key configuration in the Google API console and ensure that it accepts requests from your app's bundle ID."

private let kErrorExpiredActionCode = "The action code has expired."

private let kErrorInvalidActionCode =
  "The action code is invalid. This can happen if the code is malformed, expired, or has already been used."

private let kErrorInvalidMessagePayload =
  "The action code is invalid. This can happen if the code is malformed, expired, or has already been used."

private let kErrorInvalidSender =
  "The email template corresponding to this action contains invalid characters in its message. Please fix by going to the Auth email templates section in the Firebase Console."

private let kErrorInvalidRecipientEmail =
  "The action code is invalid. This can happen if the code is malformed, expired, or has already been used."

private let kErrorMissingIosBundleID =
  "An iOS Bundle ID must be provided if an App Store ID is provided."

private let kErrorMissingAndroidPackageName =
  "An Android Package Name must be provided if the Android App is required to be installed."

private let kErrorUnauthorizedDomain =
  "The domain of the continue URL is not allowlisted. Please allowlist the domain in the Firebase console."

private let kErrorInvalidContinueURI =
  "The continue URL provided in the request is invalid."

private let kErrorMissingEmail = "An email address must be provided."

private let kErrorMissingContinueURI =
  "A continue URL must be provided in the request."

private let kErrorMissingPhoneNumber =
  "To send verification codes, provide a phone number for the recipient."

private let kErrorInvalidPhoneNumber =
  "The format of the phone number provided is incorrect. Please enter the phone number in a format that can be parsed into E.164 format. E.164 phone numbers are written in the format [+][country code][subscriber number including area code]."

private let kErrorMissingVerificationCode =
  "The phone auth credential was created with an empty SMS verification Code."

private let kErrorInvalidVerificationCode =
  "The multifactor verification code used to create the auth credential is invalid. " +
  "Re-collect the verification code and be sure to use the verification code provided by the user."

private let kErrorMissingVerificationID =
  "The phone auth credential was created with an empty verification ID."

private let kErrorInvalidVerificationID =
  "The verification ID used to create the phone auth credential is invalid."

private let kErrorLocalPlayerNotAuthenticated =
  "The local player is not authenticated. Please log the local player in to Game Center."

private let kErrorGameKitNotLinked =
  "The GameKit framework is not linked. Please turn on the Game Center capability."

private let kErrorSessionExpired =
  "The SMS code has expired. Please re-send the verification code to try again."

private let kErrorMissingAppCredential =
  "The phone verification request is missing an APNs Device token. Firebase Auth automatically detects APNs Device Tokens, however, if method swizzling is disabled, the APNs token must be set via the APNSToken property on FIRAuth or by calling setAPNSToken:type on FIRAuth."

private let kErrorInvalidAppCredential =
  "The APNs device token provided is either incorrect or does not match the private certificate uploaded to the Firebase Console."

private let kErrorQuotaExceeded = "The quota for this operation has been exceeded."

private let kErrorMissingAppToken =
  "There seems to be a problem with your project's Firebase phone number authentication set-up, please make sure to follow the instructions found at https://firebase.google.com/docs/auth/ios/phone-auth"

private let kErrorNotificationNotForwarded =
  "If app delegate swizzling is disabled, remote notifications received by UIApplicationDelegate need to" +
  "be forwarded to FirebaseAuth's canHandleNotification method."

private let kErrorAppNotVerified =
  "Firebase could not retrieve the silent push notification and therefore could not verify your app. Ensure that you configured your app correctly to receive push notifications."

private let kErrorCaptchaCheckFailed =
  "The reCAPTCHA response token provided is either invalid, expired or already"

private let kErrorWebContextAlreadyPresented =
  "User interaction is still ongoing, another view cannot be presented."

private let kErrorWebContextCancelled = "The interaction was cancelled by the user."

private let kErrorInvalidClientID =
  "The OAuth client ID provided is either invalid or does not match the specified API key."

private let kErrorWebRequestFailed =
  "A network error (such as timeout, interrupted connection, or unreachable host) has occurred within the web context."

private let kErrorWebInternalError =
  "An internal error has occurred within the SFSafariViewController or WKWebView."

private let kErrorAppVerificationUserInteractionFailure =
  "The app verification process has failed, print and inspect the error details for more information"

private let kErrorNullUser =
  "A null user object was provided as the argument for an operation which requires a non-null user object."

private let kErrorInvalidProviderID =
  "The provider ID provided for the attempted web operation is invalid."

private let kErrorInvalidDynamicLinkDomain =
  "The Firebase Dynamic Link domain used is either not configured or is unauthorized for the current project."

private let kErrorInternalError =
  "An internal error has occurred, print and inspect the error details for more information."

private let kErrorMalformedJWT =
  "Failed to parse JWT. Check the userInfo dictionary for the full token."

private let kErrorSecondFactorRequired =
  "Please complete a second factor challenge to finish signing into this account."

private let FIRAuthErrorMessageMissingMultiFactorSession =
  "The request is missing proof of first factor successful sign-in."

private let FIRAuthErrorMessageMissingMultiFactorInfo =
  "No second factor identifier is provided."

private let FIRAuthErrorMessageInvalidMultiFactorSession =
  "The request does not contain a valid proof of first factor successful sign-in."

private let FIRAuthErrorMessageMultiFactorInfoNotFound =
  "The user does not have a second factor matching the identifier provided."

private let FIRAuthErrorMessageAdminRestrictedOperation =
  "This operation is restricted to administrators only."

private let FIRAuthErrorMessageUnverifiedEmail =
  "The operation requires a verified email."

private let FIRAuthErrorMessageSecondFactorAlreadyEnrolled =
  "The second factor is already enrolled on this account."

private let FIRAuthErrorMessageMaximumSecondFactorCountExceeded =
  "The maximum allowed number of second factors on a user has been exceeded."

private let FIRAuthErrorMessageUnsupportedFirstFactor =
  "Enrolling a second factor or signing in with a multi-factor account requires sign-in with a supported first factor."

private let FIRAuthErrorMessageEmailChangeNeedsVerification =
  "Multi-factor users must always have a verified email."

private let kErrorDynamicLinkNotActivated =
  "Please activate Dynamic Links in the Firebase Console and agree to the terms and conditions."

private let kErrorRejectedCredential =
  "The request contains malformed or mismatching credentials."

private let kErrorMissingClientIdentifier =
  "The request does not contain a client identifier."

private let kErrorMissingOrInvalidNonce =
  "The request contains malformed or mismatched credentials."

private let kErrorTenantIDMismatch =
  "The provided user's tenant ID does not match the Auth instance's tenant ID."

private let kErrorUnsupportedTenantOperation =
  "This operation is not supported in a multi-tenant context."

private let kErrorBlockingCloudFunctionReturnedError =
  "Blocking cloud function returned an error."

private let kErrorRecaptchaNotEnabled =
  "reCAPTCHA Enterprise is not enabled for this project."

private let kErrorMissingRecaptchaToken =
  "The backend request is missing the reCAPTCHA verification token."

private let kErrorInvalidRecaptchaToken =
  "The reCAPTCHA verification token is invalid or has expired."

private let kErrorInvalidRecaptchaAction =
  "The reCAPTCHA verification failed due to an invalid action."

private let kErrorMissingClientType =
  "The request is missing a client type or the client type is invalid."

private let kErrorMissingRecaptchaVersion =
  "The request is missing the reCAPTCHA version parameter."

private let kErrorInvalidRecaptchaVersion =
  "The request specifies an invalid version of reCAPTCHA."

private let kErrorInvalidReqType =
  "The request is not supported or is invalid."

// TODO(chuanr, ObjC): point the link to GCIP doc once available.
private let kErrorRecaptchaSDKNotLinked =
  "The reCAPTCHA SDK is not linked to your app. See " +
  "https://cloud.google.com/recaptcha-enterprise/docs/instrument-ios-apps"

private let kErrorSiteKeyMissing =
  "The reCAPTCHA SDK site key wasn't found. See " +
  "https://cloud.google.com/recaptcha-enterprise/docs/instrument-ios-apps"

private let kErrorRecaptchaActionCreationFailed =
  "The reCAPTCHA SDK action class failed to initialize. See " +
  "https://cloud.google.com/recaptcha-enterprise/docs/instrument-ios-apps"
