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

#import "googlemac/iPhone/Identity/Firebear/Testing/Source/FIRAuthFakeBackendImplementation.h"

#import "googlemac/iPhone/Identity/Firebear/Auth/Source/FIRAuthErrorUtils.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/FIRAuthGlobalWorkQueue.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRAuthRPCRequest.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRAuthRPCResponse.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRCreateAuthURIRequest.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRCreateAuthURIResponse.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRDeleteAccountRequest.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRDeleteAccountResponse.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRGetAccountInfoRequest.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRGetAccountInfoResponse.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRGetOOBConfirmationCodeRequest.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRGetOOBConfirmationCodeResponse.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRSecureTokenRequest.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRSecureTokenResponse.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRSetAccountInfoRequest.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRSetAccountInfoResponse.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRSignUpNewUserRequest.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRSignUpNewUserResponse.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRVerifyAssertionRequest.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRVerifyAssertionResponse.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRVerifyCustomTokenRequest.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRVerifyCustomTokenResponse.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRVerifyPasswordRequest.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/RPCs/FIRVerifyPasswordResponse.h"
#import "googlemac/iPhone/Identity/Firebear/Testing/Source/FIRAuthFakeBackendEmailValidator.h"
#import "googlemac/iPhone/Identity/Firebear/Testing/Source/FIRAuthFakeBackendUser.h"

NSString *const FIRAuthFakeBackendExpectedAPIKey = @"FakeAPIKey";

@implementation FIRAuthFakeBackendImplementation {
  /** @var _backgroundQueue
      @brief The background queue on which simulated RPCs occur.
      @remarks To simulate the asyncronous nature of the real backend implementation, all backend
          methods are immediately dispatched to this background queue and the methods return
          immediately. Callbacks are invoked from this background queue as well, and are not
          enqueued on the main thread.
   */
  dispatch_queue_t _backgroundQueue;

  /** @var _usersByID
      @brief Contains users, indexed by user ID.
   */
  NSMutableDictionary<NSString *, FIRAuthFakeBackendUser *> *_usersByID;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _backgroundQueue = FIRAuthGlobalWorkQueue();
    [self reset];
  }
  return self;
}

- (void)reset {
  _usersByID = [NSMutableDictionary dictionary];
}

- (void)install {
  [FIRAuthBackend setBackendImplementation:self];
}

- (void)uninstall {
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
}

#pragma mark - Shared

/** @fn isValidAPIKey
    @brief Checks the API Key to see if it is known to the backend.
    @return YES when the API Key should be treated as valid, NO otherwise.
 */
- (BOOL)isValidAPIKey:(NSString *)APIKey {
  return [APIKey isEqualToString:FIRAuthFakeBackendExpectedAPIKey];
}

/** @fn assertUnsupportedParameterWithName:isNil:
    @brief Raises an exception is the value of @c parameter is not @c nil.
    @param name The name of the parameter to report in the exception.
    @param parameter The value which is expected to be nil.
 */
- (void)assertUnsupportedParameterWithName:(NSString *)name isNil:(id)parameter {
  if (parameter) {
    [NSException raise:NSInvalidArgumentException
                format:@"The parameter |%@| (%@) was expected to be nil, and the fake backend has "
                       "not been programmed to respond correctly when this parameter is non-nil.",
                       name,
                       [parameter description]];
  }
}

/** @fn assertExpectedParameterWithName:isNotNil:
    @brief Raises an exception is the value of @c parameter is @c nil.
    @param name The name of the parameter to report in the exception.
    @param parameter The value which is expected to be not nil.
 */
- (void)assertExpectedParameterWithName:(NSString *)name isNotNil:(id)parameter {
  if (!parameter) {
    [NSException raise:NSInvalidArgumentException
                format:@"The parameter |%@| was expected to be non-nil, and the fake backend has "
                       "not been programmed to respond correctly when this parameter is nil.",
                       name];
  }
}

/** @fn userWithIdentifier:
    @brief Retrieves the user with the specified identifier, if one exists.
    @param identifier One of the user's identifiers.
 */
- (FIRAuthFakeBackendUser *)userWithIdentifier:(NSString *)identifier {
  return _usersByID[identifier];
}

/** @fn isValidEmail:
    @brief Determines if a string passes Inbox's email validation check. May or may not be a perfect
        implementation of the spec... but, this shouldn't be critically important for our uses.
        If there is a problem with Inbox's checks, then it's very likely the email in question
        represents a very odd case.
    @param email The string to check.
    @see https://tools.ietf.org/html/rfc3696#section-3
    @see //depot/google3/googlemac/iPhone/Bigtop/ShareExtension/EmailValidation.m
 */
- (BOOL)isValidEmail:(NSString *)email {
  return [FIRAuthFakeBackendEmailValidator isValidEmailAddress:email];
}

#pragma mark - FIRAuthBackendImplementation

- (void)createAuthURI:(FIRCreateAuthURIRequest *)request
             callback:(FIRCreateAuthURIResponseCallback)callback {
  dispatch_async(_backgroundQueue, ^{
    if (![self isValidAPIKey:request.APIKey]) {
      callback(nil, [FIRAuthErrorUtils invalidAPIKeyError]);
    }

    // It is assumed that these parameters are always present, for all requests to this
    // endpoint:
    [self assertExpectedParameterWithName:@"continueURI" isNotNil:request.continueURI];
    [self assertExpectedParameterWithName:@"identifier" isNotNil:request.identifier];

    // At the moment, this method is only used for
    // @c FIRAuth.fetchProvidersForEmail:completion:. We do not supply any additional
    // parameters.
    [self assertUnsupportedParameterWithName:@"context" isNil:request.context];
    [self assertUnsupportedParameterWithName:@"clientID" isNil:request.clientID];
    [self assertUnsupportedParameterWithName:@"appID" isNil:request.appID];
    [self assertUnsupportedParameterWithName:@"providerID" isNil:request.providerID];
    [self assertUnsupportedParameterWithName:@"openIDRealm" isNil:request.openIDRealm];

    // At this point there are five possibilities for this RPC;
    // - An out-of-band network error occurs.
    // - An infrastructure error occurs, or we respond with an otherwise incoherent response.
    // - Parameter sanity checks throw a server error.
    // - The user is found, in which case we want to return a response which includes the list
    //   of provider IDs for the credentials we have associated with the user.
    // - The user is not found we return an empty array.
    // We are not currently simulating cases #1 and #2.

    // Server checks for invalid email address and returns "INVALID_IDENTIFIER" error.
    if (![self isValidEmail:request.identifier]) {
      callback(nil, [FIRAuthErrorUtils invalidEmailError]);
      return;
    }

    // Server checks continue URI
    if (![NSURL URLWithString:request.continueURI]) {
      callback(nil, [FIRAuthErrorUtils unexpectedErrorResponseWithDeserializedResponse:@{
        @"code" : @(400),
        @"errors" : @[
          @{
            @"domain" : @"global",
            @"message" : @"INVALID_CONTINUE_URI",
            @"reason" : @"invalid",
          }
        ],
        @"message" : @"INVALID_CONTINUE_URI"
      }]);
    }

    // At the moment, the only expected response property is "allProviders".
    FIRAuthFakeBackendUser *user = [self userWithIdentifier:request.identifier];
    FIRCreateAuthURIResponse *response = [[FIRCreateAuthURIResponse alloc] init];
    NSMutableDictionary *responseDictionary = [NSMutableDictionary dictionary];
    NSArray<NSString *> *userProviderIDs = user.credentialsByProviderID.allKeys;
    responseDictionary[@"allProviders"] = userProviderIDs ? userProviderIDs : @[ ];
    [response setValuesForKeysWithDictionary:responseDictionary];
    callback(response, nil);
  });
}

- (void)getAccountInfo:(FIRGetAccountInfoRequest *)request
              callback:(FIRGetAccountInfoResponseCallback)callback {
  dispatch_async(_backgroundQueue, ^{
    if (![self isValidAPIKey:request.APIKey]) {
      callback(nil, [FIRAuthErrorUtils invalidAPIKeyError]);
    }

    #warning TODO(stevewright) Implement.
    [NSException raise:NSGenericException format:@"Not yet implemented."];
  });
}

- (void)setAccountInfo:(FIRSetAccountInfoRequest *)request
              callback:(FIRSetAccountInfoResponseCallback)callback {
  dispatch_async(_backgroundQueue, ^{
    if (![self isValidAPIKey:request.APIKey]) {
      callback(nil, [FIRAuthErrorUtils invalidAPIKeyError]);
    }

    #warning TODO(stevewright) Implement.
    [NSException raise:NSGenericException format:@"Not yet implemented."];
  });
}

- (void)verifyAssertion:(FIRVerifyAssertionRequest *)request
               callback:(FIRVerifyAssertionResponseCallback)callback {
  dispatch_async(_backgroundQueue, ^{
    if (![self isValidAPIKey:request.APIKey]) {
      callback(nil, [FIRAuthErrorUtils invalidAPIKeyError]);
    }

    #warning TODO(stevewright) Implement.
    [NSException raise:NSGenericException format:@"Not yet implemented."];
  });
}

- (void)verifyCustomToken:(FIRVerifyCustomTokenRequest *)request
                 callback:(FIRVerifyCustomTokenResponseCallback)callback {
  dispatch_async(_backgroundQueue, ^{
    if (![self isValidAPIKey:request.APIKey]) {
      callback(nil, [FIRAuthErrorUtils invalidAPIKeyError]);
    }

    #warning TODO(stevewright) Implement.
    [NSException raise:NSGenericException format:@"Not yet implemented."];
  });
}

- (void)verifyPassword:(FIRVerifyPasswordRequest *)request
              callback:(FIRVerifyPasswordResponseCallback)callback {
  dispatch_async(_backgroundQueue, ^{
    if (![self isValidAPIKey:request.APIKey]) {
      callback(nil, [FIRAuthErrorUtils invalidAPIKeyError]);
    }

    #warning TODO(stevewright) Implement.
    [NSException raise:NSGenericException format:@"Not yet implemented."];
  });
}

- (void)secureToken:(FIRSecureTokenRequest *)request
           callback:(FIRSecureTokenResponseCallback)callback {
  dispatch_async(_backgroundQueue, ^{
    if (![self isValidAPIKey:request.APIKey]) {
      callback(nil, [FIRAuthErrorUtils invalidAPIKeyError]);
    }

    #warning TODO(stevewright) Implement.
    [NSException raise:NSGenericException format:@"Not yet implemented."];
  });
}

- (void)getOOBConfirmationCode:(FIRGetOOBConfirmationCodeRequest *)request
                      callback:(FIRGetOOBConfirmationCodeResponseCallback)callback {
  dispatch_async(_backgroundQueue, ^{
    if (![self isValidAPIKey:request.APIKey]) {
      callback(nil, [FIRAuthErrorUtils invalidAPIKeyError]);
    }

    #warning TODO(stevewright) Implement.
    [NSException raise:NSGenericException format:@"Not yet implemented."];
  });
}

- (void)signUpNewUser:(FIRSignUpNewUserRequest *)request
             callback:(FIRSignupNewUserCallback)callback {
  dispatch_async(_backgroundQueue, ^{
    if (![self isValidAPIKey:request.APIKey]) {
      callback(nil, [FIRAuthErrorUtils invalidAPIKeyError]);
    }

    #warning TODO(stevewright) Implement.
    [NSException raise:NSGenericException format:@"Not yet implemented."];
  });
}

- (void)deleteAccount:(FIRDeleteAccountRequest *)request callback:(FIRDeleteCallBack)callback {
  dispatch_async(_backgroundQueue, ^{
    if (![self isValidAPIKey:request.APIKey]) {
      callback([FIRAuthErrorUtils invalidAPIKeyError]);
    }

    #warning TODO(stevewright) Implement.
    [NSException raise:NSGenericException format:@"Not yet implemented."];
  });
}

@end
