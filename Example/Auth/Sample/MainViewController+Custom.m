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

#import "MainViewController+Custom.h"

#import "AppManager.h"
#import "MainViewController+Internal.h"
#import "CustomTokenDataEntryViewController.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MainViewController (Custom)

- (StaticContentTableViewSection *)customAuthSection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"Custom Auth" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Custom Token"
                                      action:^{ [weakSelf signInWithCustomToken]; }],
    ]];
}

- (void)signInWithCustomToken {
  CustomTokenDataEntryViewControllerCompletion action =
  ^(BOOL cancelled, NSString *_Nullable userEnteredTokenText) {
    if (cancelled) {
      [self log:@"CANCELLED:sign-in with custom token cancelled."];
      return;
    }

    [self doSignInWithCustomToken:userEnteredTokenText];
  };
  CustomTokenDataEntryViewController *dataEntryViewController =
  [[CustomTokenDataEntryViewController alloc] initWithCompletion:action];
  [self presentViewController:dataEntryViewController animated:YES completion:nil];
}

- (void)doSignInWithCustomToken:(NSString *_Nullable)userEnteredTokenText {
  [[AppManager auth] signInWithCustomToken:userEnteredTokenText
                                completion:^(FIRAuthDataResult *_Nullable result,
                                             NSError *_Nullable error) {
  if (error) {
    [self logFailure:@"sign-in with custom token failed" error:error];
    [self showMessagePromptWithTitle:kSignInErrorAlertTitle
                             message:error.localizedDescription
                    showCancelButton:NO
                          completion:nil];
    return;
  }
  [self logSuccess:@"sign-in with custom token succeeded."];
  [self showMessagePromptWithTitle:kSignedInAlertTitle
                           message:result.user.displayName
                  showCancelButton:NO
                        completion:nil];
  }];
}

@end

NS_ASSUME_NONNULL_END
