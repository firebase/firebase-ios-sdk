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

#import <Foundation/Foundation.h>

#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kAppSectionTitle = @"APP";

static NSString *const kGetTokenTitle = @"Get Token";

static NSString *const kGetTokenForceRefreshTitle = @"Get Token Force Refresh";

static NSString *const kGetTokenResultButtonText = @"Get Token Result";

static NSString *const kGetTokenResultForceButtonText = @"Force Token Result";

static NSString *const kAddAuthStateListenerTitle = @"Add Auth State Change Listener";

static NSString *const kRemoveAuthStateListenerTitle = @"Remove Last Auth State Change Listener";

static NSString *const kAddIDTokenListenerTitle = @"Add ID Token Change Listener";

static NSString *const kRemoveIDTokenListenerTitle = @"Remove Last ID Token Change Listener";

static NSString *const kVerifyClientTitle = @"Verify Client";

static NSString *const kDeleteAppTitle = @"Delete App";

static NSString *const kTokenRefreshErrorAlertTitle = @"Get Token Error";

static NSString *const kTokenRefreshedAlertTitle = @"Token";

@interface MainViewController (App)

- (void)getUserTokenResultWithForce:(BOOL)force;

- (void)addAuthStateListener;

- (void)removeAuthStateListener;

- (void)addIDTokenListener;

- (void)removeIDTokenListener;

- (void)verifyClient;

- (void)deleteApp;

@end

NS_ASSUME_NONNULL_END
