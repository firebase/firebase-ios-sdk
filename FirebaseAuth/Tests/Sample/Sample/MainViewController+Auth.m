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

#import "MainViewController+Auth.h"

#import "AppManager.h"
#import "MainViewController+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MainViewController (Auth)

- (StaticContentTableViewSection *)authSection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection
      sectionWithTitle:@"Auth"
                 cells:@[
                   [StaticContentTableViewCell cellWithTitle:@"Sign in Anonymously"
                                                      action:^{
                                                        [weakSelf signInAnonymously];
                                                      }],
                   [StaticContentTableViewCell cellWithTitle:@"Sign out"
                                                      action:^{
                                                        [weakSelf signOut];
                                                      }]
                 ]];
}

- (void)signInAnonymously {
  [[AppManager auth] signInAnonymouslyWithCompletion:^(FIRAuthDataResult *_Nullable result,
                                                       NSError *_Nullable error) {
    if (error) {
      [self logFailure:@"sign-in anonymously failed" error:error];
    } else {
      [self logSuccess:@"sign-in anonymously succeeded."];
      [self log:[NSString stringWithFormat:@"User ID : %@", result.user.uid]];
    }
    [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign in Anonymously" error:error];
  }];
}

- (void)signInAnonymouslyWithCallback:(nullable FIRAuthDataResultCallback)callback {
  FIRAuth *auth = [AppManager auth];
  if (!auth) {
    [self logFailedTest:@"Could not obtain auth object."];
    return;
  }
  [auth signInAnonymouslyWithCompletion:^(FIRAuthDataResult *_Nullable result,
                                          NSError *_Nullable error) {
    if (error) {
      [self logFailure:@"sign-in anonymously failed" error:error];
      [self logFailedTest:@"Recently signed out user should be able to sign in anonymously."];
      return;
    }
    [self logSuccess:@"sign-in anonymously succeeded."];
    if (callback) {
      callback(result, nil);
    }
  }];
}

- (void)signOut {
  [[AuthProviders google] signOut];
  [[AuthProviders facebook] signOut];
  [[AppManager auth] signOut:NULL];
}

@end

NS_ASSUME_NONNULL_END
