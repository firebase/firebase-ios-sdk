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

#import "FIRAuthCredential.h"
#import "MainViewController.h"
#import "FIRAuth.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^ShowEmailPasswordDialogCompletion)(FIRAuthCredential *credential);

static NSString *const kEmailAuthSectionTitle = @"Email Auth";

static NSString *const kCreateUserTitle = @"Create User";

static NSString *const kSignInEmailPasswordTitle = @"Sign in with Email password";

static NSString *const kLinkWithEmailPasswordText = @"Link with Email password";

static NSString *const kUnlinkFromEmailPassword = @"Unlink from Email Password";

static NSString *const kReauthenticateEmailText = @"Reauthenticate Email password";

static NSString *const kSignInWithEmailLink = @"Sign in with Email link";

static NSString *const kSendEmailSignInLink = @"Send Email Sign in link";

@interface MainViewController (Email)

- (void)createUser;

- (void)signUpNewEmail:(NSString *)email
              password:(NSString *)password
              callback:(nullable FIRAuthResultCallback)callback;

- (void)signInEmailPassword;

- (void)linkWithEmailPassword;

- (void)reauthenticateEmailPassword;

- (void)signInWithEmailLink;

- (void)sendEmailSignInLink;

@end

NS_ASSUME_NONNULL_END
