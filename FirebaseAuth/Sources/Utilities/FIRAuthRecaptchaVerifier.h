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

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
#import <RecaptchaEnterprise/RecaptchaEnterprise.h>
#endif

#import "FirebaseAuth/Sources/Backend/FIRIdentityToolkitRequest.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^FIRAuthRecaptchaTokenCallback)(NSString *_Nullable token, NSError *_Nullable error);

typedef void (^FIRAuthSiteKeyCallback)(NSString *_Nullable siteKey, NSError *_Nullable error);

typedef void (^FIRAuthEnablementStatusCallback)(BOOL enablemnetStatus, NSError *_Nullable error);

typedef void (^FIRAuthInjectRequestCallback)(FIRIdentityToolkitRequest<FIRAuthRPCRequest> *request);

@interface FIRAuthRecaptchaConfig : NSObject {
}

@end

@interface FIRAuthRecaptchaVerifier : NSObject {
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
  RecaptchaClient *_recaptchaClient;
#endif

  NSString *_agentSiteKey;
  NSMutableDictionary<NSString *, NSString *> *_tenantSiteKeys;

  FIRAuthRecaptchaConfig *_agentRecaptchaConfig;
  NSMutableDictionary<NSString *, FIRAuthRecaptchaConfig *> *_tenantRecaptchaConfigs;
}

+ (id)sharedRecaptchaVerifier;

- (void)verifyForceRefresh:(BOOL)forceRefresh
                completion:(nullable FIRAuthRecaptchaTokenCallback)completion
    API_AVAILABLE(ios(14));

+ (void)injectRecaptchaFields:(FIRIdentityToolkitRequest<FIRAuthRPCRequest> *)request
                 forceRefresh:(BOOL)forceRefresh
                  forProvider:(NSString *)provider
                   completion:(nullable FIRAuthInjectRequestCallback)completion
    API_AVAILABLE(ios(14));

@end

NS_ASSUME_NONNULL_END
