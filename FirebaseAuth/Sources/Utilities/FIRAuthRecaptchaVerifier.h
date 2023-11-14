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

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST && (!defined(TARGET_OS_VISION) || !TARGET_OS_VISION)
#import <RecaptchaInterop/RCARecaptchaProtocol.h>

#import "FirebaseAuth/Sources/Backend/FIRIdentityToolkitRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRAuthRecaptchaConfig : NSObject

@property(nonatomic, nonnull, copy) NSString *siteKey;

@property(nonatomic, nonnull, strong) NSDictionary<NSString *, NSNumber *> *enablementStatus;

@end

typedef void (^FIRAuthRecaptchaTokenCallback)(NSString *_Nullable token, NSError *_Nullable error);

typedef void (^FIRAuthRecaptchaConfigCallback)(NSError *_Nullable error);

typedef void (^FIRAuthInjectRequestCallback)(FIRIdentityToolkitRequest<FIRAuthRPCRequest> *request);

typedef NS_ENUM(NSInteger, FIRAuthRecaptchaProvider) {
  FIRAuthRecaptchaProviderPassword,
};

typedef NS_ENUM(NSInteger, FIRAuthRecaptchaAction) {
  FIRAuthRecaptchaActionDefault,
  FIRAuthRecaptchaActionSignInWithPassword,
  FIRAuthRecaptchaActionGetOobCode,
  FIRAuthRecaptchaActionSignUpPassword
};

@interface FIRAuthRecaptchaVerifier : NSObject

@property(nonatomic, weak, nullable) FIRAuth *auth;

@property(nonatomic, strong, nullable) FIRAuthRecaptchaConfig *agentConfig;

@property(nonatomic, strong, nullable)
    NSMutableDictionary<NSString *, FIRAuthRecaptchaConfig *> *tenantConfigs;

@property(nonatomic, strong) id<RCARecaptchaClientProtocol> recaptchaClient;

- (void)verifyForceRefresh:(BOOL)forceRefresh
                    action:(FIRAuthRecaptchaAction)action
                completion:(nullable FIRAuthRecaptchaTokenCallback)completion;

- (void)injectRecaptchaFields:(FIRIdentityToolkitRequest<FIRAuthRPCRequest> *)request
                     provider:(FIRAuthRecaptchaProvider)provider
                       action:(FIRAuthRecaptchaAction)action
                   completion:(nullable FIRAuthInjectRequestCallback)completion;

- (BOOL)enablementStatusForProvider:(FIRAuthRecaptchaProvider)provider;

+ (id)sharedRecaptchaVerifier:(nullable FIRAuth *)auth;

@end

NS_ASSUME_NONNULL_END

#endif
