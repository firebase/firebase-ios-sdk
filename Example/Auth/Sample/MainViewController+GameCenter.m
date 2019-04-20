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

#import "MainViewController+GameCenter.h"

#import "AppManager.h"
#import "FirebaseAuth.h"
#import "MainViewController_Internal.h"

@implementation MainViewController (GameCenter)

- (void)logInWithSystemGameCenter {
  GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
  localPlayer.authenticateHandler = ^(UIViewController * _Nullable viewController,
                                      NSError * _Nullable error) {
    if (error) {
      [self showTypicalUIForUserUpdateResultsWithTitle:@"Game Center Error" error:error];
    } else if (viewController != nil) {
      [self presentViewController:viewController animated:YES completion:nil];
    }
  };
}

- (void)signInWithGameCenter {
  [FIRGameCenterAuthProvider getCredentialWithCompletion:
   ^(FIRAuthCredential * _Nullable credential, NSError * _Nullable error) {
     if (error) {
       [self showTypicalUIForUserUpdateResultsWithTitle:@"Game Center Error" error:error];
     } else {
       [[AppManager auth] signInWithCredential:credential
                                    completion:^(FIRAuthDataResult * _Nullable result,
                                                 NSError * _Nullable error) {
        [self hideSpinner:^{
          if (error) {
            [self logFailure:@"Sign in with Game Center failed" error:error];
          } else {
            [self logSuccess:@"Sign in with Game Center succeeded."];
          }
          [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign In Error" error:error];
        }];
      }];
     }
   }];
}

- (void)linkWithGameCenter {
  [FIRGameCenterAuthProvider getCredentialWithCompletion:
   ^(FIRAuthCredential * _Nullable credential, NSError * _Nullable error) {
     if (error) {
       [self showTypicalUIForUserUpdateResultsWithTitle:@"Game Center Error" error:error];
     } else {
       [[self user] linkWithCredential:credential
                            completion:^(FIRAuthDataResult * _Nullable result,
                                         NSError * _Nullable error) {
        [self hideSpinner:^{
          if (error) {
            [self logFailure:@"Link with Game Center failed" error:error];
          } else {
            [self logSuccess:@"Link with Game Center succeeded."];
          }
          [self showTypicalUIForUserUpdateResultsWithTitle:@"Link Error" error:error];
        }];
      }];
     }
   }];
}

- (void)reauthenticateWithGameCenter {
  [FIRGameCenterAuthProvider getCredentialWithCompletion:
   ^(FIRAuthCredential * _Nullable credential, NSError * _Nullable error) {
     if (error) {
       [self showTypicalUIForUserUpdateResultsWithTitle:@"Game Center Error" error:error];
     } else {
       [[self user] reauthenticateWithCredential:credential
                                      completion:^(FIRAuthDataResult * _Nullable result,
                                                   NSError * _Nullable error) {
        [self hideSpinner:^{
          if (error) {
            [self logFailure:@"Reauthenticate with Game Center failed" error:error];
          } else {
            [self logSuccess:@"Reauthenticate with Game Center succeeded."];
          }
          [self showTypicalUIForUserUpdateResultsWithTitle:@"Reauthenticate Error" error:error];
        }];
      }];
     }
   }];
}

@end
