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

#import <RecaptchaEnterprise/RecaptchaEnterprise.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^FIRAuthRecaptchaTokenCallback)(NSString *_Nullable token, NSError *_Nullable error);

typedef void (^FIRAuthSiteKeyCallback)(NSString *_Nullable siteKey, NSError *_Nullable error);

@interface FIRAuthRecaptchaVerifier : NSObject {
    RecaptchaClient *_recaptchaClient;
    
    NSString *_agentSiteKey;
    NSMutableDictionary<NSString *, NSString *> *_tenantSiteKeys;
}

+ (id)sharedRecaptchaVerifier;

- (void)verifyWithCompletion:(nullable FIRAuthRecaptchaTokenCallback)completion;

@end

NS_ASSUME_NONNULL_END
