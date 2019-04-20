/*
 * Copyright 2019 Google
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

static NSString *const kFacebookAuthSectionTitle = @"Facebook Auth";

static NSString *const kSignInFacebookTitle = @"Sign in with Facebook";

static NSString *const kLinkWithFacebookText = @"Link with Facebook";

static NSString *const kUnlinkFromFacebook = @"Unlink from Facebook";

static NSString *const kReauthenticateFacebookTitle = @"Reauthenticate Facebook";

@interface MainViewController (Facebook)

- (void)signInFacebook;

- (void)linkWithFacebook;

- (void)reauthenticateFacebook;

@end

NS_ASSUME_NONNULL_END
