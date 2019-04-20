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

static NSString *const kSectionTitleManualTests = @"Automated Tests";

static NSString *const kAutoBYOAuthTitle = @"BYOAuth";

static NSString *const kAutoSignInAnonymously = @"Sign In Anonymously";

static NSString *const kAutoSignInGoogle = @"Sign In With Google";

static NSString *const kAutoSignInFacebook = @"Sign In With Facebook";

static NSString *const kAutoSignUpEmailPassword = @"Sign Up With Email/Password";

static NSString *const kAutoAccountLinking = @"Link with Google";

static NSString *const kAutoPhoneNumberSignIn = @"Sign in With Phone Number";

static NSString *const kCustomTokenUrl = @"https://fb-sa-1211.appspot.com/token";

static NSString *const kExpiredCustomTokenUrl = @"https://fb-sa-1211.appspot.com/expired_token";

static NSString *const kInvalidCustomToken = @"invalid custom token.";

static NSString *const kSafariGoogleSignOutMessagePrompt = @"This automated test assumes that no "
"Google account is signed in on Safari, if your are not prompted for a password, sign out on "
"Safari and rerun the test.";

static NSString *const kSafariFacebookSignOutMessagePrompt = @"This automated test assumes that no "
"Facebook account is signed in on Safari, if your are not prompted for a password, sign out on "
"Safari and rerun the test.";

static NSString *const kUnlinkAccountMessagePrompt = @"Sign into gmail with an email address "
"that has not been linked to this sample application before. Delete account if necessary.";

static NSString *const kFakeDisplayPhotoUrl =
@"https://www.gstatic.com/images/branding/product/1x/play_apps_48dp.png";

static NSString *const kFakeDisplayName = @"John GoogleSpeed";

static NSString *const kFakeEmail =@"firemail@example.com";

static NSString *const kFakePassword =@"fakePassword";

@interface MainViewController (AutoTests)

- (void)automatedBYOAuth;

- (void)automatedAnonymousSignIn;

- (void)automatedEmailSignUp;

- (void)automatedSignInGoogle;

- (void)automatedSignInFacebook;

- (void)automatedPhoneNumberSignIn;

- (void)automatedAccountLinking;

@end

NS_ASSUME_NONNULL_END
