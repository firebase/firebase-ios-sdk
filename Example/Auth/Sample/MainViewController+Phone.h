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

#import "MainViewController_Internal.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kPhoneAuthSectionTitle = @"Phone Auth";

static NSString *const kPhoneNumberSignInReCaptchaTitle = @"Sign in With Phone Number";

static NSString *const kLinkPhoneNumber = @"Link Phone Number";

static NSString *const kUnlinkPhoneNumber = @"Unlink Phone Number";

@interface MainViewController (Phone)

- (void)signInWithPhoneNumber:(NSString *_Nullable)phoneNumber
                   completion:(nullable testAutomationCallback)completion;

- (void)signInWithPhoneNumberWithPrompt;

- (void)commonPhoneNumberInputWithTitle:(NSString *)title
                             Completion:(textInputCompletionBlock)completion;

- (void)commontPhoneVerificationWithVerificationID:(NSString *)verificationID
                                  verificationCode:(NSString *)verificationCode;

- (void)linkPhoneNumber:(NSString *_Nullable)phoneNumber
             completion:(nullable testAutomationCallback)completion;

- (void)linkPhoneNumberWithPrompt;

@end

NS_ASSUME_NONNULL_END
