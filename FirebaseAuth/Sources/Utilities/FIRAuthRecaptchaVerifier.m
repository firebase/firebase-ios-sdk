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

#import "FIRAuthRecaptchaVerifier.h"

#import <FirebaseAuth/FIRAuth.h>
#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetRecaptchaConfigRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetRecaptchaConfigResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyPasswordRequest.h"

@implementation FIRAuthRecaptchaVerifier

+ (id)sharedRecaptchaVerifier {
  static FIRAuthRecaptchaVerifier *sharedRecaptchaVerifier = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedRecaptchaVerifier = [[self alloc] init];
  });
  return sharedRecaptchaVerifier;
}

- (void)verifyForceRefresh:(BOOL)forceRefresh
                completion:(nullable FIRAuthRecaptchaTokenCallback)completion {
  // Enablement?
  [self retrieveSiteKeyForceRefresh:forceRefresh
                         completion:^(NSString *_Nullable siteKey, NSError *_Nullable error) {
                           if (error) {
                             completion(nil, error);
                           }
                           if (self->_recaptchaClient) {
                             [self retrieveRecaptchaToken:completion];
                           } else {
                             dispatch_async(dispatch_get_main_queue(), ^{
                               [Recaptcha
                                   getClientWithSiteKey:siteKey
                                      completionHandler:^void(RecaptchaClient *recaptchaClient,
                                                              RecaptchaError *error) {
                                        if (!recaptchaClient) {
                                          completion(nil, error);
                                          return;
                                        }
                                        self->_recaptchaClient = recaptchaClient;
                                        [self retrieveRecaptchaToken:completion];
                                      }];
                             });
                           }
                         }];
}

- (void)retrieveSiteKeyForceRefresh:(BOOL)forceRefresh
                         completion:(nullable FIRAuthSiteKeyCallback)completion {
  _agentSiteKey = @"6LeDgfohAAAAAB1WlMyMxg4WqgRw5-Gl4A2YUYB0";
  if (!forceRefresh) {
    if ([FIRAuth auth].tenantID == nil && _agentSiteKey != nil) {
      completion(_agentSiteKey, nil);
      return;
    }
    if ([FIRAuth auth].tenantID != nil && _tenantSiteKeys[[FIRAuth auth].tenantID] != nil) {
      completion(_tenantSiteKeys[[FIRAuth auth].tenantID], nil);
      return;
    }
  }
  FIRGetRecaptchaConfigRequest *request =
      [[FIRGetRecaptchaConfigRequest alloc] initWithClientType:@"CLIENT_TYPE_IOS"
                                                       version:@"RECAPTCHA_ENTERPRISE"
                                          requestConfiguration:[FIRAuth auth].requestConfiguration];
  [FIRAuthBackend getRecaptchaConfig:request
                            callback:^(FIRGetRecaptchaConfigResponse *_Nullable response,
                                       NSError *_Nullable error) {
                              if (error) {
                                completion(nil, error);
                              }
                              NSString *siteKey =
                                  [response.recaptchaKey componentsSeparatedByString:@"/"][3];
                              if ([FIRAuth auth].tenantID == nil) {
                                self->_agentSiteKey = siteKey;
                                completion(siteKey, nil);
                                return;
                              }
                              if ([FIRAuth auth].tenantID != nil) {
                                self->_tenantSiteKeys[[FIRAuth auth].tenantID] = siteKey;
                                completion(siteKey, nil);
                                return;
                              }
                            }];
}

- (void)retrieveEnablementStatusForceRefresh:(BOOL)forceRefresh
                                 forProvider:(NSString *)provider
                                  completion:(nullable FIRAuthEnablementStatusCallback)completion {
  // TODO(chuanr@): retrieve provider enablement status when backend is ready
  completion(NO, nil);
}

- (void)retrieveRecaptchaToken:(nullable FIRAuthRecaptchaTokenCallback)completion {
  [_recaptchaClient
                execute:[[RecaptchaAction alloc] initWithAction:RecaptchaActionTypeLogin]
      completionHandler:^void(RecaptchaToken *_Nullable token, RecaptchaError *_Nullable error) {
        if (!token) {
          completion(nil, error);
          return;
        }
        completion(token.recaptchaToken, nil);
        return;
      }];
}

+ (void)injectRecaptchaFields:(FIRIdentityToolkitRequest<FIRAuthRPCRequest> *)request
                 forceRefresh:(BOOL)forceRefresh
                  forProvider:(NSString *)provider
                   completion:(nullable FIRAuthInjectRequestCallback)completion {
  [[FIRAuthRecaptchaVerifier sharedRecaptchaVerifier]
      retrieveEnablementStatusForceRefresh:forceRefresh
                               forProvider:provider
                                completion:^(BOOL enablemnetStatus, NSError *_Nullable error) {
                                  if (enablemnetStatus) {  // FIRAuthRecaptchaVerifier.recaptchaConfig.emailPasswordEnabled
                                    [[FIRAuthRecaptchaVerifier sharedRecaptchaVerifier]
                                        verifyForceRefresh:forceRefresh
                                                completion:^(NSString *_Nullable token,
                                                             NSError *_Nullable error) {
                                                  [request
                                                      injectRecaptchaFields:token
                                                           recaptchaVersion:@"RECAPTCHA_ENTERPRISE"
                                                                 clientType:@"CLIENT_TYPE_IOS"];
                                                  completion(request);
                                                }];
                                  } else {
                                    [request injectRecaptchaFields:nil
                                                  recaptchaVersion:@"RECAPTCHA_ENTERPRISE"
                                                        clientType:@"CLIENT_TYPE_IOS"];
                                    completion(request);
                                  }
                                }];
}

@end
