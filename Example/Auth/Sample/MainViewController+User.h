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

static NSString *const kUserSectionTitle = @"User";

static NSString *const kSetDisplayNameTitle = @"Set Display Name";

static NSString *const kSetPhotoURLText = @"Set Photo URL";

static NSString *const kUpdateEmailText = @"Update Email";

static NSString *const kUpdatePasswordText = @"Update Password";

static NSString *const kUpdatePhoneNumber = @"Update Phone Number";

static NSString *const kGetProvidersForEmail = @"Get Provider IDs for Email";

static NSString *const kGetAllSignInMethodsForEmail = @"Get Sign-in methods for Email";

static NSString *const kReloadText = @"Reload User";

static NSString *const kDeleteUserText = @"Delete User";

@interface MainViewController (User)

- (void)setDisplayName;

- (void)setPhotoURL;

- (void)updateEmail;

- (void)updatePassword;

- (void)updatePhoneNumber;

- (void)getProvidersForEmail;

- (void)getAllSignInMethodsForEmail;

- (void)reloadUser;

- (void)deleteAccount;

- (void)updatePhoneNumber:(NSString *_Nullable)phoneNumber
               completion:(nullable testAutomationCallback)completion;

@end

NS_ASSUME_NONNULL_END
