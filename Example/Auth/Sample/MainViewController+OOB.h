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
#import "FirebaseAuth.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kOOBSectionTitle = @"OOB";

static NSString *const kActionCodeTypeDescription = @"Action Type";

static NSString *const kContinueURLDescription = @"Continue URL";

static NSString *const kRequestVerifyEmail = @"Request Verify Email";

static NSString *const kRequestPasswordReset = @"Request Password Reset";

static NSString *const kResetPassword = @"Reset Password";

static NSString *const kVerifyPasswordResetCode = @"Verify Password Reset Code";

static NSString *const kCheckActionCode = @"Check Action Code";

static NSString *const kApplyActionCode = @"Apply Action Code";

static NSString *const kPasswordResetAction = @"resetPassword";

static NSString *const kVerifyEmailAction = @"verifyEmail";

@interface MainViewController (OOB)

- (void)changeActionCodeContinueURL;

- (void)toggleActionCodeRequestType;

- (NSString *)actionCodeRequestTypeString;

- (void)requestVerifyEmail;

- (void)requestPasswordReset;

- (void)verifyPasswordResetCode;

- (void)resetPassword;

- (void)checkActionCode;

- (void)applyActionCode;

@end

NS_ASSUME_NONNULL_END
