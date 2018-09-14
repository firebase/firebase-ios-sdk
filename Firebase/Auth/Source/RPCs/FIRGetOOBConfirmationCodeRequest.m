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

#import "FIRGetOOBConfirmationCodeRequest.h"

#import "FIRActionCodeSettings.h"

#import "FIRAuthErrorUtils.h"
#import "FIRAuth_Internal.h"

/** @var kEndpoint
    @brief The getOobConfirmationCode endpoint name.
 */
static NSString *const kGetOobConfirmationCodeEndpoint = @"getOobConfirmationCode";

/** @var kRequestTypeKey
    @brief The name of the required "requestType" property in the request.
 */
static NSString *const kRequestTypeKey = @"requestType";

/** @var kEmailKey
    @brief The name of the "email" property in the request.
 */
static NSString *const kEmailKey = @"email";

/** @var kIDTokenKey
    @brief The key for the "idToken" value in the request. This is actually the STS Access Token,
        despite it's confusing (backwards compatiable) parameter name.
 */
static NSString *const kIDTokenKey = @"idToken";

/** @var kContinueURLKey
    @brief The key for the "continue URL" value in the request.
 */
static NSString *const kContinueURLKey = @"continueUrl";

/** @var kIosBundeIDKey
    @brief The key for the "iOS Bundle Identifier" value in the request.
 */
static NSString *const kIosBundleIDKey = @"iOSBundleId";

/** @var kAndroidPackageNameKey
    @brief The key for the "Android Package Name" value in the request.
 */
static NSString *const kAndroidPackageNameKey = @"androidPackageName";

/** @var kAndroidInstallAppKey
    @brief The key for the request parameter indicating whether the android app should be installed
        or not.
 */
static NSString *const kAndroidInstallAppKey = @"androidInstallApp";

/** @var kAndroidMinimumVersionKey
    @brief The key for the "minimum Android version supported" value in the request.
 */
static NSString *const kAndroidMinimumVersionKey = @"androidMinimumVersion";

/** @var kCanHandleCodeInAppKey
    @brief The key for the request parameter indicating whether the action code can be handled in
        the app or not.
 */
static NSString *const kCanHandleCodeInAppKey = @"canHandleCodeInApp";

/** @var kPasswordResetRequestTypeValue
    @brief The value for the "PASSWORD_RESET" request type.
 */
static NSString *const kPasswordResetRequestTypeValue = @"PASSWORD_RESET";

/** @var kEmailLinkSignInTypeValue
    @brief The value for the "EMAIL_SIGNIN" request type.
 */
static NSString *const kEmailLinkSignInTypeValue= @"EMAIL_SIGNIN";

/** @var kVerifyEmailRequestTypeValue
    @brief The value for the "VERIFY_EMAIL" request type.
 */
static NSString *const kVerifyEmailRequestTypeValue = @"VERIFY_EMAIL";

@interface FIRGetOOBConfirmationCodeRequest ()

/** @fn initWithRequestType:email:APIKey:
    @brief Designated initializer.
    @param requestType The types of OOB Confirmation Code to request.
    @param email The email of the user.
    @param accessToken The STS Access Token of the currently signed in user.
    @param actionCodeSettings An object of FIRActionCodeSettings which specifies action code
        settings to be applied to the OOB code request.
    @param requestConfiguration An object containing configurations to be added to the request.
 */
- (nullable instancetype)initWithRequestType:(FIRGetOOBConfirmationCodeRequestType)requestType
                                       email:(nullable NSString *)email
                                 accessToken:(nullable NSString *)accessToken
                          actionCodeSettings:(nullable FIRActionCodeSettings *)actionCodeSettings
                        requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration
                              NS_DESIGNATED_INITIALIZER;

@end

@implementation FIRGetOOBConfirmationCodeRequest

/** @var requestTypeStringValueForRequestType:
    @brief Returns the string equivilent for an @c FIRGetOOBConfirmationCodeRequestType value.
 */
+ (NSString *)requestTypeStringValueForRequestType:
    (FIRGetOOBConfirmationCodeRequestType)requestType {
  switch (requestType) {
    case FIRGetOOBConfirmationCodeRequestTypePasswordReset:
      return kPasswordResetRequestTypeValue;
    case FIRGetOOBConfirmationCodeRequestTypeVerifyEmail:
      return kVerifyEmailRequestTypeValue;
    case FIRGetOOBConfirmationCodeRequestTypeEmailLink:
      return kEmailLinkSignInTypeValue;
    // No default case so that we get a compiler warning if a new value was added to the enum.
  }
}

+ (FIRGetOOBConfirmationCodeRequest *)
    passwordResetRequestWithEmail:(NSString *)email
               actionCodeSettings:(nullable FIRActionCodeSettings *)actionCodeSettings
             requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  return [[self alloc] initWithRequestType:FIRGetOOBConfirmationCodeRequestTypePasswordReset
                                     email:email
                               accessToken:nil
                        actionCodeSettings:actionCodeSettings
                      requestConfiguration:requestConfiguration];
}

+ (FIRGetOOBConfirmationCodeRequest *)
    verifyEmailRequestWithAccessToken:(NSString *)accessToken
                   actionCodeSettings:(nullable FIRActionCodeSettings *)actionCodeSettings
                 requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  return [[self alloc] initWithRequestType:FIRGetOOBConfirmationCodeRequestTypeVerifyEmail
                                     email:nil
                               accessToken:accessToken
                        actionCodeSettings:actionCodeSettings
                      requestConfiguration:requestConfiguration];
}

+ (FIRGetOOBConfirmationCodeRequest *)
    signInWithEmailLinkRequest:(NSString *)email
            actionCodeSettings:(nullable FIRActionCodeSettings *)actionCodeSettings
          requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  return [[self alloc] initWithRequestType:FIRGetOOBConfirmationCodeRequestTypeEmailLink
                                     email:email
                               accessToken:nil
                        actionCodeSettings:actionCodeSettings
                      requestConfiguration:requestConfiguration];
}

- (nullable instancetype)initWithRequestType:(FIRGetOOBConfirmationCodeRequestType)requestType
                                       email:(nullable NSString *)email
                                 accessToken:(nullable NSString *)accessToken
                          actionCodeSettings:(nullable FIRActionCodeSettings *)actionCodeSettings
                        requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kGetOobConfirmationCodeEndpoint
            requestConfiguration:requestConfiguration];
  if (self) {
    _requestType = requestType;
    _email = email;
    _accessToken = accessToken;
    _continueURL = actionCodeSettings.URL.absoluteString;
    _iOSBundleID = actionCodeSettings.iOSBundleID;
    _androidPackageName = actionCodeSettings.androidPackageName;
    _androidMinimumVersion = actionCodeSettings.androidMinimumVersion;
    _androidInstallApp = actionCodeSettings.androidInstallIfNotAvailable;
    _handleCodeInApp = actionCodeSettings.handleCodeInApp;
  }
  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *_Nullable *_Nullable)error {
  NSMutableDictionary *body = [@{
    kRequestTypeKey : [[self class] requestTypeStringValueForRequestType:_requestType]
  } mutableCopy];

  // For password reset requests, we only need an email address in addition to the already required
  // fields.
  if (_requestType == FIRGetOOBConfirmationCodeRequestTypePasswordReset) {
    body[kEmailKey] = _email;
  }

  // For verify email requests, we only need an STS Access Token in addition to the already required
  // fields.
  if (_requestType == FIRGetOOBConfirmationCodeRequestTypeVerifyEmail) {
    body[kIDTokenKey] = _accessToken;
  }

  // For email sign-in link requests, we only need an email address in addition to the already
  // required fields.
  if (_requestType == FIRGetOOBConfirmationCodeRequestTypeEmailLink) {
    body[kEmailKey] = _email;
  }

  if (_continueURL) {
    body[kContinueURLKey] = _continueURL;
  }

  if (_iOSBundleID) {
    body[kIosBundleIDKey] = _iOSBundleID;
  }

  if (_androidPackageName) {
    body[kAndroidPackageNameKey] = _androidPackageName;
  }

  if (_androidMinimumVersion) {
    body[kAndroidMinimumVersionKey] = _androidMinimumVersion;
  }

  if (_androidInstallApp) {
    body[kAndroidInstallAppKey] = @YES;
  }

  if (_handleCodeInApp) {
    body[kCanHandleCodeInAppKey] = @YES;
  }

  return body;
}

@end
