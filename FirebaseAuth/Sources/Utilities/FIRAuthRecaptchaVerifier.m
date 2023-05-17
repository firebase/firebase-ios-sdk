/*
 * Copyright 2022 Google LLC
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

#import "FirebaseAuth/Sources/Utilities/FIRAuthRecaptchaVerifier.h"

#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetRecaptchaConfigRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetRecaptchaConfigResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyPasswordRequest.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuth.h"

#import <RecaptchaInterop/RCAActionProtocol.h>
#import <RecaptchaInterop/RCARecaptchaProtocol.h>

static const NSDictionary *providerToStringMap;
static const NSDictionary *actionToStringMap;

static NSString *const kClientType = @"CLIENT_TYPE_IOS";
static NSString *const kRecaptchaVersion = @"RECAPTCHA_ENTERPRISE";

@implementation FIRAuthRecaptchaConfig

@end

@implementation FIRAuthRecaptchaVerifier

+ (id)sharedRecaptchaVerifier {
  static FIRAuthRecaptchaVerifier *sharedRecaptchaVerifier = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedRecaptchaVerifier = [[self alloc] init];

    providerToStringMap = @{@(FIRAuthRecaptchaProviderPassword) : @"password"};

    actionToStringMap = @{
      @(FIRAuthRecaptchaActionSignInWithPassword) : @"signInWithPassword",
      @(FIRAuthRecaptchaActionGetOobCode) : @"getOobCode",
      @(FIRAuthRecaptchaActionSignUpPassword) : @"signUpPassword"
    };
  });
  return sharedRecaptchaVerifier;
}

- (NSString *)siteKey {
  if ([FIRAuth auth].tenantID == nil) {
    return self->_agentConfig.siteKey;
  } else {
    return self->_tenantConfigs[[FIRAuth auth].tenantID].siteKey;
  }
}

- (BOOL)enablementStatusForProvider:(FIRAuthRecaptchaProvider)provider {
  if ([FIRAuth auth].tenantID == nil) {
    return [self->_agentConfig.enablementStatus[providerToStringMap[@(provider)]] boolValue];
  } else {
    return [self->_tenantConfigs[[FIRAuth auth].tenantID]
                .enablementStatus[providerToStringMap[@(provider)]] boolValue];
  }
}

- (void)verifyForceRefresh:(BOOL)forceRefresh
                    action:(FIRAuthRecaptchaAction)action
                completion:(nullable FIRAuthRecaptchaTokenCallback)completion
    API_AVAILABLE(ios(14)) {
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
  [self retrieveRecaptchaConfigForceRefresh:forceRefresh
                                 completion:^(NSError *_Nullable error) {
                                   if (error) {
                                     completion(nil, error);
                                   }
                                   if (self.recaptchaClient) {
                                     [self retrieveRecaptchaTokenWithAction:action
                                                                 completion:completion];
                                   } else {
                                     //                                     dispatch_async(dispatch_get_main_queue(),
                                     //                                     ^{
                                     //                                         id<RCAActionProtocol>
                                     //                                         action;
                                     //                                         id<RCARecaptchaProtocol>
                                     //                                         p;
                                     //                                       [id<RCARecaptchaProtocol>
                                     //                                            getClientWithSiteKey:[self
                                     //                                            siteKey]
                                     //                                        completion:^(id<RCARecaptchaClientProtocol>
                                     //                                        _Nullable
                                     //                                        recaptchaClient,
                                     //                                                                                     NSError *_Nullable error) {
                                     //                                                if
                                     //                                                (!recaptchaClient)
                                     //                                                {
                                     //                                                  completion(nil,
                                     //                                                  error);
                                     //                                                  return;
                                     //                                                }
                                     //                                                self->_recaptchaClient
                                     //                                                =
                                     //                                                recaptchaClient;
                                     //                                                [self
                                     //                                                retrieveRecaptchaTokenWithAction:action
                                     //                                                                            completion:completion];
                                     //                                              }];
                                     //                                     });
                                   }
                                 }];
#endif
}

- (void)retrieveRecaptchaConfigForceRefresh:(BOOL)forceRefresh
                                 completion:(nullable FIRAuthRecaptchaConfigCallback)completion {
  if (!forceRefresh) {
    if ([FIRAuth auth].tenantID == nil && _agentConfig != nil) {
      completion(nil);
      return;
    }
    if ([FIRAuth auth].tenantID != nil && _tenantConfigs[[FIRAuth auth].tenantID] != nil) {
      completion(nil);
      return;
    }
  }
  FIRGetRecaptchaConfigRequest *request =
      [[FIRGetRecaptchaConfigRequest alloc] initWithClientType:kClientType
                                                       version:kRecaptchaVersion
                                          requestConfiguration:[FIRAuth auth].requestConfiguration];
  [FIRAuthBackend
      getRecaptchaConfig:request
                callback:^(FIRGetRecaptchaConfigResponse *_Nullable response,
                           NSError *_Nullable error) {
                  if (error) {
                    completion(error);
                  }
                  FIRAuthRecaptchaConfig *config = [[FIRAuthRecaptchaConfig alloc] init];
                  config.siteKey = [response.recaptchaKey componentsSeparatedByString:@"/"][3];

                  // TODO(chuanr@): retrieve provider enablement status when backend is ready
                  if (!forceRefresh) {
                    config.enablementStatus = @{@"password" : @NO};
                  } else {
                    config.enablementStatus = @{@"password" : @YES};
                  }

                  if ([FIRAuth auth].tenantID == nil) {
                    self->_agentConfig = config;
                    completion(nil);
                    return;
                  } else {
                    if (!self->_tenantConfigs) {
                      self->_tenantConfigs = [[NSMutableDictionary alloc] init];
                    }
                    self->_tenantConfigs[[FIRAuth auth].tenantID] = config;
                    completion(nil);
                    return;
                  }
                }];
}

- (void)retrieveRecaptchaTokenWithAction:(FIRAuthRecaptchaAction)action
                              completion:(nullable FIRAuthRecaptchaTokenCallback)completion {
  // #if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
  //   [_recaptchaClient
  //                 execute:[[RecaptchaAction alloc]
  //                 initWithCustomAction:actionToStringMap[@(action)]]
  //       completionHandler:^void(RecaptchaToken *_Nullable token, RecaptchaError *_Nullable error)
  //       {
  //         if (!token) {
  //           completion(nil, error);
  //           return;
  //         }
  //         completion(token.recaptchaToken, nil);
  //         return;
  //       }];
  // #endif
}

- (void)injectRecaptchaFields:(FIRIdentityToolkitRequest<FIRAuthRPCRequest> *)request
                 forceRefresh:(BOOL)forceRefresh
                     provider:(FIRAuthRecaptchaProvider)provider
                       action:(FIRAuthRecaptchaAction)action
                   completion:(nullable FIRAuthInjectRequestCallback)completion {
  [self retrieveRecaptchaConfigForceRefresh:forceRefresh
                                 completion:^(NSError *_Nullable error) {
                                   if ([self enablementStatusForProvider:provider]) {
                                     [self verifyForceRefresh:forceRefresh
                                                       action:action
                                                   completion:^(NSString *_Nullable token,
                                                                NSError *_Nullable error) {
                                                     [request
                                                         injectRecaptchaFields:token
                                                              recaptchaVersion:kRecaptchaVersion
                                                                    clientType:kClientType];
                                                     completion(request);
                                                   }];
                                   } else {
                                     [request injectRecaptchaFields:nil
                                                   recaptchaVersion:kRecaptchaVersion
                                                         clientType:kClientType];
                                     completion(request);
                                   }
                                 }];
}

@end
