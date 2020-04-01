//

/*
 * Copyright 2018 Google
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

#import <AppAuth/AppAuth.h>
#import "FIRAppDistribution.h"

@class FIRApp;

NS_ASSUME_NONNULL_BEGIN

@protocol FIRAppDistributionAuthProtocol

- (void)discoverService:(NSURL *)issuerURL completion:(OIDDiscoveryCallback)completion;

@end

@interface FIRAppDistribution ()

- (instancetype)initWithApp:(FIRApp *)app appInfo:(NSDictionary *)appInfo authHandler:(id<FIRAppDistributionAuthProtocol>) auth;

/**
 * Current view controller presenting the `SFSafariViewController` if any.
 */
@property(nullable, nonatomic) UIViewController *safariHostingViewController;

/**
 * Current auth state for app distribution tester
 */
@property(nullable, nonatomic) OIDAuthState *authState;

@property(nullable, nonatomic) UIWindow *window;

@end
//
///** Encodes the API key in a query parameter string. */
// NSString *_Nullable FIRDynamicLinkAPIKeyParameter(NSString *apiKey);
//
///** Creates and returns an NSData object from an NSDictionary along with any error. */
// NSData *_Nullable FIRDataWithDictionary(NSDictionary *dictionary, NSError **_Nullable error);
//
NS_ASSUME_NONNULL_END
