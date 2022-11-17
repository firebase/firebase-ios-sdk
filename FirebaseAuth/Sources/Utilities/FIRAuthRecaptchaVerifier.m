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

@implementation FIRAuthRecaptchaVerifier

+ (id)sharedRecaptchaVerifier {
    static FIRAuthRecaptchaVerifier *sharedRecaptchaVerifier = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedRecaptchaVerifier = [[self alloc] init];
    });
    return sharedRecaptchaVerifier;
}

- (void)verifyWithCompletion:(nullable FIRAuthRecaptchaTokenCallback)completion {
    [self retrieveSiteKeyForceRefresh:YES
                           completion:^(NSString * _Nullable siteKey, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
        }
        if (self->_recaptchaClient) {
            [self retrieveRecaptchaToken:completion];
        } else {
            [Recaptcha getClientWithSiteKey:siteKey
                          completionHandler:^void(RecaptchaClient* recaptchaClient, RecaptchaError* error) {
                if (!recaptchaClient) {
                    completion(nil, error);
                    return;
                }
                self->_recaptchaClient = recaptchaClient;
                [self retrieveRecaptchaToken:completion];
            }];
        }
    }];
}

- (void)retrieveSiteKeyForceRefresh:(BOOL)forceRefresh completion:(nullable FIRAuthSiteKeyCallback)completion {
    _agentSiteKey = @"6LeDgfohAAAAAB1WlMyMxg4WqgRw5-Gl4A2YUYB0";
    if (!forceRefresh) {
        if ([FIRAuth auth].tenantID == nil && _agentSiteKey != nil) {
            completion(_agentSiteKey, nil);
        }
        if ([FIRAuth auth].tenantID != nil && _tenantSiteKeys[[FIRAuth auth].tenantID] != nil) {
            completion(_tenantSiteKeys[[FIRAuth auth].tenantID], nil);
        }
    }
    FIRGetRecaptchaConfigRequest *request =
          [[FIRGetRecaptchaConfigRequest alloc] initWithClientType:@"CLIENT_TYPE_IOS"
                                                           version:@"RECAPTCHA_ENTERPRISE"
                                              requestConfiguration:[FIRAuth auth].requestConfiguration];
    [FIRAuthBackend getRecaptchaConfig:request callback:^(FIRGetRecaptchaConfigResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
        }
        NSString *siteKey =[response.recaptchaKey componentsSeparatedByString:@"/"][3];
        if ([FIRAuth auth].tenantID == nil) {
            self->_agentSiteKey = siteKey;
            completion(siteKey, nil);
        }
        if ([FIRAuth auth].tenantID != nil) {
            self->_tenantSiteKeys[[FIRAuth auth].tenantID] = siteKey;
            completion(siteKey, nil);
        }
    }];
}

- (void)retrieveRecaptchaToken:(nullable FIRAuthRecaptchaTokenCallback)completion {
    [_recaptchaClient execute:[[RecaptchaAction alloc] initWithAction: RecaptchaActionTypeLogin]
            completionHandler:^void(RecaptchaToken* _Nullable token, RecaptchaError* _Nullable error) {
        if (!token) {
          NSLog (@ "%@", error);
          return;
        }
        NSLog (@ "%@", token);
      }];
}

@end
