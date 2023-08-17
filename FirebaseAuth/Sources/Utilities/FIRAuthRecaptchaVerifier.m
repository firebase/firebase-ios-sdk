/*
 * Copyright 2023 Google LLC
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

#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST && (!defined(TARGET_OS_VISION) || !TARGET_OS_VISION)

#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetRecaptchaConfigRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetRecaptchaConfigResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyPasswordRequest.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuth.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthErrorUtils.h"

#import <RecaptchaInterop/RCAActionProtocol.h>
#import <RecaptchaInterop/RCARecaptchaProtocol.h>

static const NSDictionary *providerToStringMap;
static const NSDictionary *actionToStringMap;

static NSString *const kClientType = @"CLIENT_TYPE_IOS";
static NSString *const kRecaptchaVersion = @"RECAPTCHA_ENTERPRISE";
static NSString *const kFakeToken = @"NO_RECAPTCHA";

@implementation FIRAuthRecaptchaConfig

@end

@implementation FIRAuthRecaptchaVerifier

+ (id)sharedRecaptchaVerifier:(nullable FIRAuth *)auth {
  static FIRAuthRecaptchaVerifier *sharedRecaptchaVerifier = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedRecaptchaVerifier = [[self alloc] init];

    providerToStringMap = @{@(FIRAuthRecaptchaProviderPassword) : @"EMAIL_PASSWORD_PROVIDER"};

    actionToStringMap = @{
      @(FIRAuthRecaptchaActionSignInWithPassword) : @"signInWithPassword",
      @(FIRAuthRecaptchaActionGetOobCode) : @"getOobCode",
      @(FIRAuthRecaptchaActionSignUpPassword) : @"signUpPassword"
    };
  });
  if (sharedRecaptchaVerifier.auth != auth) {
    sharedRecaptchaVerifier.agentConfig = nil;
    sharedRecaptchaVerifier.tenantConfigs = nil;
    sharedRecaptchaVerifier.auth = auth;
  }
  return sharedRecaptchaVerifier;
}

- (NSString *)siteKey {
  if (self.auth.tenantID == nil) {
    return self->_agentConfig.siteKey;
  } else {
    FIRAuthRecaptchaConfig *config = self->_tenantConfigs[self.auth.tenantID];
    if (config) {
      return config.siteKey;
    } else {
      return nil;
    }
  }
}

- (BOOL)enablementStatusForProvider:(FIRAuthRecaptchaProvider)provider {
  if (self.auth.tenantID == nil) {
    return [self->_agentConfig.enablementStatus[providerToStringMap[@(provider)]] boolValue];
  } else {
    return
        [self->_tenantConfigs[self.auth.tenantID].enablementStatus[providerToStringMap[@(provider)]]
            boolValue];
  }
}

- (void)verifyForceRefresh:(BOOL)forceRefresh
                    action:(FIRAuthRecaptchaAction)action
                completion:(nullable FIRAuthRecaptchaTokenCallback)completion {
  [self
      retrieveRecaptchaConfigForceRefresh:forceRefresh
                               completion:^(NSError *_Nullable error) {
                                 if (error) {
                                   completion(nil, error);
                                 }
                                 if (!self.recaptchaClient) {
                                   NSString *siteKey = [self siteKey];
                                   Class RecaptchaClass = NSClassFromString(@"Recaptcha");
                                   if (RecaptchaClass) {
                                     SEL selector =
                                         NSSelectorFromString(@"getClientWithSiteKey:completion:");
                                     if ([RecaptchaClass respondsToSelector:selector]) {
                                       void (*funcWithoutTimeout)(
                                           id, SEL, NSString *,
                                           void (^)(
                                               id<RCARecaptchaClientProtocol> _Nullable recaptchaClient,
                                               NSError *_Nullable error)) =
                                           (void *)[RecaptchaClass methodForSelector:selector];
                                       funcWithoutTimeout(
                                           RecaptchaClass, selector, siteKey,
                                           ^(id<RCARecaptchaClientProtocol> _Nullable recaptchaClient,
                                             NSError *_Nullable error) {
                                             if (recaptchaClient) {
                                               self.recaptchaClient = recaptchaClient;
                                               [self retrieveRecaptchaTokenWithAction:action
                                                                           completion:completion];
                                             } else if (error) {
                                               completion(nil, error);
                                             }
                                           });
                                     } else {
                                       NSLog(@"reCAPTCHA verification faled because reCAPTCHA SDK "
                                             @"not linked.");
                                       completion(nil,
                                                  [FIRAuthErrorUtils recaptchaSDKNotLinkedError]);
                                     }
                                   } else {
                                     NSLog(@"reCAPTCHA verification faled because reCAPTCHA SDK "
                                           @"not linked.");
                                     completion(nil,
                                                [FIRAuthErrorUtils recaptchaSDKNotLinkedError]);
                                   }
                                 } else {
                                   NSLog(@"reCAPTCHA verification succeeded.");
                                   [self retrieveRecaptchaTokenWithAction:action
                                                               completion:completion];
                                 }
                               }];
}

- (void)retrieveRecaptchaConfigForceRefresh:(BOOL)forceRefresh
                                 completion:(nullable FIRAuthRecaptchaConfigCallback)completion {
  if (!forceRefresh) {
    if (self.auth.tenantID == nil && _agentConfig != nil) {
      completion(nil);
      return;
    }
    if (self.auth.tenantID != nil && _tenantConfigs[self.auth.tenantID] != nil) {
      completion(nil);
      return;
    }
  }
  FIRGetRecaptchaConfigRequest *request = [[FIRGetRecaptchaConfigRequest alloc]
      initWithRequestConfiguration:self.auth.requestConfiguration];
  [FIRAuthBackend
      getRecaptchaConfig:request
                callback:^(FIRGetRecaptchaConfigResponse *_Nullable response,
                           NSError *_Nullable error) {
                  if (error) {
                    NSLog(@"reCAPTCHA config retrieval failed.");
                    completion(error);
                  }
                  NSLog(@"reCAPTCHA config retrieval succeeded.");
                  FIRAuthRecaptchaConfig *config = [[FIRAuthRecaptchaConfig alloc] init];
                  // Response's site key is of the format projects/<project-id>/keys/<site-key>'
                  config.siteKey = [response.recaptchaKey componentsSeparatedByString:@"/"][3];
                  NSMutableDictionary *tmpEnablementStatus = [NSMutableDictionary dictionary];
                  for (NSDictionary *state in response.enforcementState) {
                    if ([state[@"provider"]
                            isEqualToString:providerToStringMap[
                                                @(FIRAuthRecaptchaProviderPassword)]]) {
                      if ([state[@"enforcementState"] isEqualToString:@"ENFORCE"]) {
                        tmpEnablementStatus[state[@"provider"]] = @YES;
                      } else if ([state[@"enforcementState"] isEqualToString:@"AUDIT"]) {
                        tmpEnablementStatus[state[@"provider"]] = @YES;
                      } else if ([state[@"enforcementState"] isEqualToString:@"OFF"]) {
                        tmpEnablementStatus[state[@"provider"]] = @NO;
                      }
                    }
                  }
                  config.enablementStatus = tmpEnablementStatus;

                  if (self.auth.tenantID == nil) {
                    self->_agentConfig = config;
                    completion(nil);
                    return;
                  } else {
                    if (!self->_tenantConfigs) {
                      self->_tenantConfigs = [[NSMutableDictionary alloc] init];
                    }
                    self->_tenantConfigs[self.auth.tenantID] = config;
                    completion(nil);
                    return;
                  }
                }];
}

- (void)retrieveRecaptchaTokenWithAction:(FIRAuthRecaptchaAction)action
                              completion:(nullable FIRAuthRecaptchaTokenCallback)completion {
  Class RecaptchaActionClass = NSClassFromString(@"RecaptchaAction");
  if (RecaptchaActionClass) {
    SEL customActionSelector = NSSelectorFromString(@"initWithCustomAction:");

    if ([RecaptchaActionClass instancesRespondToSelector:customActionSelector]) {
      // Initialize with a custom action
      id (*funcWithCustomAction)(id, SEL, NSString *) =
          (id(*)(id, SEL,
                 NSString *))[RecaptchaActionClass instanceMethodForSelector:customActionSelector];

      id<RCAActionProtocol> customAction = funcWithCustomAction(
          [[RecaptchaActionClass alloc] init], customActionSelector, actionToStringMap[@(action)]);

      if (customAction) {
        [self.recaptchaClient
               execute:customAction
            completion:^(NSString *_Nullable token, NSError *_Nullable error) {
              if (!error) {
                NSLog(@"reCAPTCHA token retrieval succeeded.");
                completion(token, nil);
                return;
              } else {
                NSLog(@"reCAPTCHA token retrieval failed. NO_RECAPTCHA sent as the fake code.");
                completion(kFakeToken, nil);
              }
            }];
      }
    } else {
      completion(nil, [FIRAuthErrorUtils recaptchaSDKNotLinkedError]);
    }
  } else {
    completion(nil, [FIRAuthErrorUtils recaptchaSDKNotLinkedError]);
  }
}

- (void)injectRecaptchaFields:(FIRIdentityToolkitRequest<FIRAuthRPCRequest> *)request
                     provider:(FIRAuthRecaptchaProvider)provider
                       action:(FIRAuthRecaptchaAction)action
                   completion:(nullable FIRAuthInjectRequestCallback)completion {
  [self retrieveRecaptchaConfigForceRefresh:false
                                 completion:^(NSError *_Nullable error) {
                                   if ([self enablementStatusForProvider:provider]) {
                                     [self verifyForceRefresh:false
                                                       action:action
                                                   completion:^(NSString *_Nullable token,
                                                                NSError *_Nullable error) {
                                                     [request
                                                         injectRecaptchaFields:token
                                                              recaptchaVersion:kRecaptchaVersion];
                                                     completion(request);
                                                   }];
                                   } else {
                                     [request injectRecaptchaFields:nil
                                                   recaptchaVersion:kRecaptchaVersion];
                                     completion(request);
                                   }
                                 }];
}

@end

#endif
