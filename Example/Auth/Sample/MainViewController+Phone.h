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

#import "MainViewController+Internal.h"
#import "StaticContentTableViewManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (Phone)

- (StaticContentTableViewSection *)phoneAuthSection;

- (void)commonPhoneNumberInputWithTitle:(NSString *)title
                             completion:(TextInputCompletionBlock)completion;

- (void)signInWithPhoneNumber:(NSString *_Nullable)phoneNumber
                   completion:(nullable TestAutomationCallback)completion;

- (void)linkPhoneNumber:(NSString *_Nullable)phoneNumber
             completion:(nullable TestAutomationCallback)completion;

@end

NS_ASSUME_NONNULL_END
