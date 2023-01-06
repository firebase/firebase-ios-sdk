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

#import "MainViewController+Facebook.h"

#import "AuthProviders.h"
#import "MainViewController+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MainViewController (Facebook)

- (StaticContentTableViewSection *)facebookAuthSection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"Facebook Auth" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Facebook"
                                      action:^{ [weakSelf signInFacebook]; }],
    [StaticContentTableViewCell cellWithTitle:@"Link with Facebook"
                                      action:^{ [weakSelf linkWithFacebook]; }],
    [StaticContentTableViewCell cellWithTitle:@"Unlink from Facebook"
                                      action:^{
                                        [weakSelf unlinkFromProvider:FIRFacebookAuthProvider.id completion:nil];
                                      }],
    [StaticContentTableViewCell cellWithTitle:@"Reauthenticate Facebook"
                                      action:^{ [weakSelf reauthenticateFacebook]; }],
    ]];
}

- (void)signInFacebook {
  [self signinWithProvider:[AuthProviders facebook] retrieveData:YES];
}

- (void)linkWithFacebook {
  [self linkWithAuthProvider:[AuthProviders facebook] retrieveData:NO];
}

- (void)reauthenticateFacebook {
  [self reauthenticate:[AuthProviders facebook] retrieveData:NO];
}

@end

NS_ASSUME_NONNULL_END
