/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"

#if SWIFT_PACKAGE
@import GTMSessionFetcherCore;
#else
#import <GTMSessionFetcher/GTMSessionFetcher.h>
#import <GTMSessionFetcher/GTMSessionFetcherService.h>
#endif

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FirebaseAuth.h"

#import "FirebaseAuth/Sources/Auth/FIRAuthGlobalWorkQueue.h"
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

#import "FirebaseAuth-Swift.h"

NS_ASSUME_NONNULL_BEGIN

/** @var kClientVersionHeader
    @brief HTTP header name for the client version.
 */
static NSString *const kClientVersionHeader = @"X-Client-Version";

/** @var kIosBundleIdentifierHeader
    @brief HTTP header name for iOS bundle ID.
 */
static NSString *const kIosBundleIdentifierHeader = @"X-Ios-Bundle-Identifier";

/** @var kFirebaseLocalHeader
    @brief HTTP header name for the firebase locale.
 */
static NSString *const kFirebaseLocalHeader = @"X-Firebase-Locale";

/** @var kFirebaseAppIDHeader
    @brief HTTP header name for the Firebase app ID.
 */
static NSString *const kFirebaseAppIDHeader = @"X-Firebase-GMPID";

/** @var kFirebaseHeartbeatHeader
    @brief HTTP header name for a Firebase heartbeats payload.
 */
static NSString *const kFirebaseHeartbeatHeader = @"X-Firebase-Client";

/** @var kFirebaseAuthCoreFrameworkMarker
    @brief The marker in the HTTP header that indicates the request comes from Firebase Auth Core.
 */
static NSString *const kFirebaseAuthCoreFrameworkMarker = @"FirebaseCore-iOS";

/** @var kJSONContentType
    @brief The value of the HTTP content-type header for JSON payloads.
 */
static NSString *const kJSONContentType = @"application/json";

/** @var kErrorDataKey
    @brief Key for error data in NSError returned by @c GTMSessionFetcher.
 */
static NSString *const kErrorDataKey = @"data";

/** @var kErrorKey
    @brief The key for the "error" value in JSON responses from the server.
 */
static NSString *const kErrorKey = @"error";

/** @var kErrorsKey
    @brief The key for the "errors" value in JSON responses from the server.
 */
static NSString *const kErrorsKey = @"errors";

/** @var kReasonKey
    @brief The key for the "reason" value in JSON responses from the server.
 */
static NSString *const kReasonKey = @"reason";

/** @var kInvalidKeyReasonValue
    @brief The value for the "reason" key indicating an invalid API Key was received by the server.
 */
static NSString *const kInvalidKeyReasonValue = @"keyInvalid";

/** @var kAppNotAuthorizedReasonValue
    @brief The value for the "reason" key indicating the App is not authorized to use Firebase
        Authentication.
 */
static NSString *const kAppNotAuthorizedReasonValue = @"ipRefererBlocked";

/** @var kErrorMessageKey
    @brief The key for an error's "message" value in JSON responses from the server.
 */
static NSString *const kErrorMessageKey = @"message";

/** @var kReturnIDPCredentialErrorMessageKey
    @brief The key for "errorMessage" value in JSON responses from the server, In case
        returnIDPCredential of a verifyAssertion request is set to @YES.
 */
static NSString *const kReturnIDPCredentialErrorMessageKey = @"errorMessage";

/** @var kUserNotFoundErrorMessage
    @brief This is the error message returned when the user is not found, which means the user
        account has been deleted given the token was once valid.
 */
static NSString *const kUserNotFoundErrorMessage = @"USER_NOT_FOUND";

/** @var kUserDeletedErrorMessage
    @brief This is the error message the server will respond with if the user entered an invalid
        email address.
 */
static NSString *const kUserDeletedErrorMessage = @"EMAIL_NOT_FOUND";

/** @var kInvalidLocalIDErrorMessage
    @brief This is the error message the server responds with if the user local id in the id token
        does not exit.
 */
static NSString *const kInvalidLocalIDErrorMessage = @"INVALID_LOCAL_ID";

/** @var kUserTokenExpiredErrorMessage
    @brief The error returned by the server if the token issue time is older than the account's
        valid_since time.
 */
static NSString *const kUserTokenExpiredErrorMessage = @"TOKEN_EXPIRED";

/** @var kTooManyRequestsErrorMessage
    @brief This is the error message the server will respond with if too many requests were made to
        a server method.
 */
static NSString *const kTooManyRequestsErrorMessage = @"TOO_MANY_ATTEMPTS_TRY_LATER";

/** @var kInvalidCustomTokenErrorMessage
    @brief This is the error message the server will respond with if there is a validation error
        with the custom token.
 */
static NSString *const kInvalidCustomTokenErrorMessage = @"INVALID_CUSTOM_TOKEN";

/** @var kCustomTokenMismatch
    @brief This is the error message the server will respond with if the service account and API key
        belong to different projects.
 */
static NSString *const kCustomTokenMismatch = @"CREDENTIAL_MISMATCH";

/** @var kInvalidCredentialErrorMessage
    @brief This is the error message the server responds with if the IDP token or requestUri is
        invalid.
 */
static NSString *const kInvalidCredentialErrorMessage = @"INVALID_IDP_RESPONSE";

/** @var kUserDisabledErrorMessage
    @brief The error returned by the server if the user account is diabled.
 */
static NSString *const kUserDisabledErrorMessage = @"USER_DISABLED";

/** @var kOperationNotAllowedErrorMessage
    @brief This is the error message the server will respond with if Admin disables IDP specified by
        provider.
 */
static NSString *const kOperationNotAllowedErrorMessage = @"OPERATION_NOT_ALLOWED";

/** @var kPasswordLoginDisabledErrorMessage
    @brief This is the error message the server responds with if password login is disabled.
 */
static NSString *const kPasswordLoginDisabledErrorMessage = @"PASSWORD_LOGIN_DISABLED";

/** @var kEmailAlreadyInUseErrorMessage
    @brief This is the error message the server responds with if the email address already exists.
 */
static NSString *const kEmailAlreadyInUseErrorMessage = @"EMAIL_EXISTS";

/** @var kInvalidEmailErrorMessage
    @brief The error returned by the server if the email is invalid.
 */
static NSString *const kInvalidEmailErrorMessage = @"INVALID_EMAIL";

/** @var kInvalidIdentifierErrorMessage
    @brief The error returned by the server if the identifier is invalid.
 */
static NSString *const kInvalidIdentifierErrorMessage = @"INVALID_IDENTIFIER";

/** @var kWrongPasswordErrorMessage
    @brief This is the error message the server will respond with if the user entered a wrong
        password.
 */
static NSString *const kWrongPasswordErrorMessage = @"INVALID_PASSWORD";

/** @var kCredentialTooOldErrorMessage
    @brief This is the error message the server responds with if account change is attempted 5
        minutes after signing in.
 */
static NSString *const kCredentialTooOldErrorMessage = @"CREDENTIAL_TOO_OLD_LOGIN_AGAIN";

/** @var kFederatedUserIDAlreadyLinkedMessage
    @brief This is the error message the server will respond with if the federated user ID has been
        already linked with another account.
 */
static NSString *const kFederatedUserIDAlreadyLinkedMessage = @"FEDERATED_USER_ID_ALREADY_LINKED";

/** @var kInvalidUserTokenErrorMessage
    @brief This is the error message the server responds with if user's saved auth credential is
        invalid, and the user needs to sign in again.
 */
static NSString *const kInvalidUserTokenErrorMessage = @"INVALID_ID_TOKEN";

/** @var kWeakPasswordErrorMessagePrefix
    @brief This is the prefix for the error message the server responds with if user's new password
        to be set is too weak.
 */
static NSString *const kWeakPasswordErrorMessagePrefix = @"WEAK_PASSWORD";

/** @var kExpiredActionCodeErrorMessage
    @brief This is the error message the server will respond with if the action code is expired.
 */
static NSString *const kExpiredActionCodeErrorMessage = @"EXPIRED_OOB_CODE";

/** @var kInvalidActionCodeErrorMessage
    @brief This is the error message the server will respond with if the action code is invalid.
 */
static NSString *const kInvalidActionCodeErrorMessage = @"INVALID_OOB_CODE";

/** @var kMissingEmailErrorMessage
    @brief This is the error message the server will respond with if the email address is missing
        during a "send password reset email" attempt.
 */
static NSString *const kMissingEmailErrorMessage = @"MISSING_EMAIL";

/** @var kInvalidSenderEmailErrorMessage
    @brief This is the error message the server will respond with if the sender email is invalid
        during a "send password reset email" attempt.
 */
static NSString *const kInvalidSenderEmailErrorMessage = @"INVALID_SENDER";

/** @var kInvalidMessagePayloadErrorMessage
    @brief This is the error message the server will respond with if there are invalid parameters in
        the payload during a "send password reset email" attempt.
 */
static NSString *const kInvalidMessagePayloadErrorMessage = @"INVALID_MESSAGE_PAYLOAD";

/** @var kInvalidRecipientEmailErrorMessage
    @brief This is the error message the server will respond with if the recipient email is invalid.
 */
static NSString *const kInvalidRecipientEmailErrorMessage = @"INVALID_RECIPIENT_EMAIL";

/** @var kMissingIosBundleIDErrorMessage
    @brief This is the error message the server will respond with if iOS bundle ID is missing but
        the iOS App store ID is provided.
 */
static NSString *const kMissingIosBundleIDErrorMessage = @"MISSING_IOS_BUNDLE_ID";

/** @var kMissingAndroidPackageNameErrorMessage
    @brief This is the error message the server will respond with if Android Package Name is missing
        but the flag indicating the app should be installed is set to true.
 */
static NSString *const kMissingAndroidPackageNameErrorMessage = @"MISSING_ANDROID_PACKAGE_NAME";

/** @var kUnauthorizedDomainErrorMessage
    @brief This is the error message the server will respond with if the domain of the continue URL
        specified is not allowlisted in the Firebase console.
 */
static NSString *const kUnauthorizedDomainErrorMessage = @"UNAUTHORIZED_DOMAIN";

/** @var kInvalidProviderIDErrorMessage
    @brief This is the error message the server will respond with if the provider id given for the
        web operation is invalid.
 */
static NSString *const kInvalidProviderIDErrorMessage = @"INVALID_PROVIDER_ID";

/** @var kInvalidDynamicLinkDomainErrorMessage
    @brief This is the error message the server will respond with if the dynamic link domain
        provided in the request is invalid.
 */
static NSString *const kInvalidDynamicLinkDomainErrorMessage = @"INVALID_DYNAMIC_LINK_DOMAIN";

/** @var kInvalidContinueURIErrorMessage
    @brief This is the error message the server will respond with if the continue URL provided in
        the request is invalid.
 */
static NSString *const kInvalidContinueURIErrorMessage = @"INVALID_CONTINUE_URI";

/** @var kMissingContinueURIErrorMessage
    @brief This is the error message the server will respond with if there was no continue URI
        present in a request that required one.
 */
static NSString *const kMissingContinueURIErrorMessage = @"MISSING_CONTINUE_URI";

/** @var kInvalidPhoneNumberErrorMessage
    @brief This is the error message the server will respond with if an incorrectly formatted phone
        number is provided.
 */
static NSString *const kInvalidPhoneNumberErrorMessage = @"INVALID_PHONE_NUMBER";

/** @var kInvalidVerificationCodeErrorMessage
    @brief This is the error message the server will respond with if an invalid verification code is
        provided.
 */
static NSString *const kInvalidVerificationCodeErrorMessage = @"INVALID_CODE";

/** @var kInvalidSessionInfoErrorMessage
    @brief This is the error message the server will respond with if an invalid session info
        (verification ID) is provided.
 */
static NSString *const kInvalidSessionInfoErrorMessage = @"INVALID_SESSION_INFO";

/** @var kSessionExpiredErrorMessage
    @brief This is the error message the server will respond with if the SMS code has expired before
        it is used.
 */
static NSString *const kSessionExpiredErrorMessage = @"SESSION_EXPIRED";

/** @var kMissingOrInvalidNonceErrorMessage
    @brief This is the error message the server will respond with if the nonce is missing or
   invalid.
 */
static NSString *const kMissingOrInvalidNonceErrorMessage = @"MISSING_OR_INVALID_NONCE";

/** @var kMissingAppTokenErrorMessage
    @brief This is the error message the server will respond with if the APNS token is missing in a
        verifyClient request.
 */
static NSString *const kMissingAppTokenErrorMessage = @"MISSING_IOS_APP_TOKEN";

/** @var kMissingAppCredentialErrorMessage
    @brief This is the error message the server will respond with if the app token is missing in a
        sendVerificationCode request.
 */
static NSString *const kMissingAppCredentialErrorMessage = @"MISSING_APP_CREDENTIAL";

/** @var kInvalidAppCredentialErrorMessage
    @brief This is the error message the server will respond with if the app credential in a
        sendVerificationCode request is invalid.
 */
static NSString *const kInvalidAppCredentialErrorMessage = @"INVALID_APP_CREDENTIAL";

/** @var kQuoutaExceededErrorMessage
    @brief This is the error message the server will respond with if the quota for SMS text messages
        has been exceeded for the project.
 */
static NSString *const kQuoutaExceededErrorMessage = @"QUOTA_EXCEEDED";

/** @var kAppNotVerifiedErrorMessage
    @brief This is the error message the server will respond with if Firebase could not verify the
        app during a phone authentication flow.
 */
static NSString *const kAppNotVerifiedErrorMessage = @"APP_NOT_VERIFIED";

/** @var kMissingClientIdentifier
    @brief This is the error message the server will respond with if Firebase could not verify the
        app during a phone authentication flow when a real phone number is used and app verification
        is disabled for testing.
 */
static NSString *const kMissingClientIdentifier = @"MISSING_CLIENT_IDENTIFIER";

/** @var kCaptchaCheckFailedErrorMessage
    @brief This is the error message the server will respond with if the reCAPTCHA token provided is
        invalid.
 */
static NSString *const kCaptchaCheckFailedErrorMessage = @"CAPTCHA_CHECK_FAILED";

/** @var kTenantIDMismatch
    @brief This is the error message the server will respond with if the tenant id mismatches.
 */
static NSString *const kTenantIDMismatch = @"TENANT_ID_MISMATCH";

/** @var kUnsupportedTenantOperation
    @brief This is the error message the server will respond with if the operation does not support
   multi-tenant.
 */
static NSString *const kUnsupportedTenantOperation = @"UNSUPPORTED_TENANT_OPERATION";

/** @var kMissingMFAPendingCredentialErrorMessage
 @brief This is the error message the server will respond with if the MFA pending credential is
 missing.
 */
static NSString *const kMissingMFAPendingCredentialErrorMessage = @"MISSING_MFA_PENDING_CREDENTIAL";

/** @var kMissingMFAEnrollmentIDErrorMessage
 @brief This is the error message the server will respond with if the MFA enrollment ID is missing.
 */
static NSString *const kMissingMFAEnrollmentIDErrorMessage = @"MISSING_MFA_ENROLLMENT_ID";

/** @var kInvalidMFAPendingCredentialErrorMessage
 @brief This is the error message the server will respond with if the MFA pending credential is
 invalid.
 */
static NSString *const kInvalidMFAPendingCredentialErrorMessage = @"INVALID_MFA_PENDING_CREDENTIAL";

/** @var kMFAEnrollmentNotFoundErrorMessage
 @brief This is the error message the server will respond with if the MFA enrollment info is not
 found.
 */
static NSString *const kMFAEnrollmentNotFoundErrorMessage = @"MFA_ENROLLMENT_NOT_FOUND";

/** @var kAdminOnlyOperationErrorMessage
 @brief This is the error message the server will respond with if the operation is admin only.
 */
static NSString *const kAdminOnlyOperationErrorMessage = @"ADMIN_ONLY_OPERATION";

/** @var kUnverifiedEmailErrorMessage
 @brief This is the error message the server will respond with if the email is unverified.
 */
static NSString *const kUnverifiedEmailErrorMessage = @"UNVERIFIED_EMAIL";

/** @var kSecondFactorExistsErrorMessage
 @brief This is the error message the server will respond with if the second factor already exsists.
 */
static NSString *const kSecondFactorExistsErrorMessage = @"SECOND_FACTOR_EXISTS";

/** @var kSecondFactorLimitExceededErrorMessage
 @brief This is the error message the server will respond with if the number of second factor
 reaches the limit.
 */
static NSString *const kSecondFactorLimitExceededErrorMessage = @"SECOND_FACTOR_LIMIT_EXCEEDED";

/** @var kUnsupportedFirstFactorErrorMessage
 @brief This is the error message the server will respond with if the first factor doesn't support
 MFA.
 */
static NSString *const kUnsupportedFirstFactorErrorMessage = @"UNSUPPORTED_FIRST_FACTOR";

/** @var kBlockingCloudFunctionErrorResponse
 @brief This is the error message blocking Cloud Functions.
 */
static NSString *const kBlockingCloudFunctionErrorResponse = @"BLOCKING_FUNCTION_ERROR_RESPONSE";

/** @var kEmailChangeNeedsVerificationErrorMessage
 @brief This is the error message the server will respond with if changing an unverified email.
 */
static NSString *const kEmailChangeNeedsVerificationErrorMessage =
    @"EMAIL_CHANGE_NEEDS_VERIFICATION";

/** @var kInvalidPendingToken
    @brief Generic IDP error codes.
 */
static NSString *const kInvalidPendingToken = @"INVALID_PENDING_TOKEN";

/** @var gBackendImplementation
    @brief The singleton FIRAuthBackendImplementation instance to use.
 */
static id<FIRAuthBackendImplementation> gBackendImplementation;

/** @class FIRAuthBackendRPCImplementation
    @brief The default RPC-based backend implementation.
 */
@interface FIRAuthBackendRPCImplementation : NSObject <FIRAuthBackendImplementation>

/** @property RPCIssuer
    @brief An instance of FIRAuthBackendRPCIssuer for making RPC requests. Allows the RPC
        requests/responses to be easily faked.
 */
@property(nonatomic, strong) id<FIRAuthBackendRPCIssuer> RPCIssuer;

@end

@implementation FIRAuthBackend

+ (id<FIRAuthBackendImplementation>)implementation {
  if (!gBackendImplementation) {
    gBackendImplementation = [[FIRAuthBackendRPCImplementation alloc] init];
  }
  return gBackendImplementation;
}

+ (void)setBackendImplementation:(id<FIRAuthBackendImplementation>)backendImplementation {
  gBackendImplementation = backendImplementation;
}

+ (void)setDefaultBackendImplementationWithRPCIssuer:
    (nullable id<FIRAuthBackendRPCIssuer>)RPCIssuer {
  FIRAuthBackendRPCImplementation *defaultImplementation =
      [[FIRAuthBackendRPCImplementation alloc] init];
  if (RPCIssuer) {
    defaultImplementation.RPCIssuer = RPCIssuer;
  }
  gBackendImplementation = defaultImplementation;
}

+ (NSString *)authUserAgent {
  return [NSString stringWithFormat:@"FirebaseAuth.iOS/%@ %@", FIRFirebaseVersion(),
                                    GTMFetcherStandardUserAgentString(nil)];
}

+ (NSMutableURLRequest *)requestWithURL:(NSURL *)URL
                            contentType:(NSString *)contentType
                   requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
  [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
  NSString *additionalFrameworkMarker =
      requestConfiguration.additionalFrameworkMarker ?: kFirebaseAuthCoreFrameworkMarker;
  NSString *clientVersion = [NSString
      stringWithFormat:@"iOS/FirebaseSDK/%@/%@", FIRFirebaseVersion(), additionalFrameworkMarker];
  [request setValue:clientVersion forHTTPHeaderField:kClientVersionHeader];
  NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
  [request setValue:bundleID forHTTPHeaderField:kIosBundleIdentifierHeader];
  NSString *appID = requestConfiguration.appID;
  [request setValue:appID forHTTPHeaderField:kFirebaseAppIDHeader];
  [request setValue:FIRHeaderValueFromHeartbeatsPayload(
                        [requestConfiguration.heartbeatLogger flushHeartbeatsIntoPayload])
      forHTTPHeaderField:kFirebaseHeartbeatHeader];
  NSArray<NSString *> *preferredLocalizations = [NSBundle mainBundle].preferredLocalizations;
  if (preferredLocalizations.count) {
    NSString *acceptLanguage = preferredLocalizations.firstObject;
    [request setValue:acceptLanguage forHTTPHeaderField:@"Accept-Language"];
  }
  NSString *languageCode = requestConfiguration.languageCode;
  if (languageCode.length) {
    [request setValue:languageCode forHTTPHeaderField:kFirebaseLocalHeader];
  }
  return request;
}

@end

@interface FIRAuthBackendRPCIssuerImplementation : NSObject <FIRAuthBackendRPCIssuer>
@end


@implementation FIRAuthBackendRPCImplementation


@end

NS_ASSUME_NONNULL_END
