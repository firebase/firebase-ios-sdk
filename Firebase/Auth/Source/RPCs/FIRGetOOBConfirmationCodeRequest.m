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

#import "../Private/FIRAuthErrorUtils.h"
#import "../Private/FIRAuth_Internal.h"

/** @var kEndpoint
    @brief The getOobConfirmationCode endpoint name.
 */
static NSString *const kEndpoint = @"getOobConfirmationCode";

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

/** @var kPasswordResetRequestTypeValue
    @brief The value for the "PASSWORD_RESET" request type.
 */
static NSString *const kPasswordResetRequestTypeValue = @"PASSWORD_RESET";

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
    @param APIKey The client's API Key.
 */
- (nullable instancetype)initWithRequestType:(FIRGetOOBConfirmationCodeRequestType)requestType
                                       email:(nullable NSString *)email
                                 accessToken:(nullable NSString *)accessToken
                                      APIKey:(nullable NSString *)APIKey
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
    // No default case so that we get a compiler warning if a new value was added to the enum.
  }
}

+ (FIRGetOOBConfirmationCodeRequest *)passwordResetRequestWithEmail:(NSString *)email
                                                             APIKey:(NSString *)APIKey {
  return [[self alloc] initWithRequestType:FIRGetOOBConfirmationCodeRequestTypePasswordReset
                                     email:email
                               accessToken:nil
                                    APIKey:APIKey];
}

+ (FIRGetOOBConfirmationCodeRequest *)
    verifyEmailRequestWithAccessToken:(NSString *)accessToken APIKey:(NSString *)APIKey {
  return [[self alloc] initWithRequestType:FIRGetOOBConfirmationCodeRequestTypeVerifyEmail
                                     email:nil
                               accessToken:accessToken
                                    APIKey:APIKey];
}

- (nullable instancetype)initWithRequestType:(FIRGetOOBConfirmationCodeRequestType)requestType
                                       email:(nullable NSString *)email
                                 accessToken:(nullable NSString *)accessToken
                                      APIKey:(nullable NSString *)APIKey {
  self = [super initWithEndpoint:kEndpoint APIKey:APIKey];
  if (self) {
    _requestType = requestType;
    _email = email;
    _accessToken = accessToken;
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

  return body;
}

@end
