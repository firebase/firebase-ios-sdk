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

#import "MainViewController+OAuth.h"

#import "AppManager.h"
#import "FIROAuthProvider.h"
#import "MainViewController_Internal.h"

@implementation MainViewController (OAuth)

- (void)signInGoogleHeadfulLite {
  FIROAuthProvider *provider = self.googleOAuthProvider;
  provider.customParameters = @{
                                @"prompt" : @"consent",
                                };
  provider.scopes = @[ @"profile", @"email", @"https://www.googleapis.com/auth/plus.me" ];
  [self showSpinner:^{
    [[AppManager auth] signInWithProvider:provider
                               UIDelegate:nil
                               completion:^(FIRAuthDataResult *_Nullable authResult,
                                            NSError *_Nullable error) {
       [self hideSpinner:^{
         if (error) {
           [self logFailure:@"sign-in with provider (Google) failed" error:error];
         } else if (authResult.additionalUserInfo) {
           [self logSuccess:[self stringWithAdditionalUserInfo:authResult.additionalUserInfo]];
           if (self.isNewUserToggleOn) {
             NSString *newUserString = authResult.additionalUserInfo.newUser ?
             @"New user" : @"Existing user";
             [self showMessagePromptWithTitle:@"New or Existing"
                                      message:newUserString
                             showCancelButton:NO
                                   completion:nil];
           }
         }
         [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In Error" error:error];
       }];
     }];
  }];
}

- (void)signInMicrosoftHeadfulLite {
  FIROAuthProvider *provider = self.microsoftOAuthProvider;
  provider.customParameters = @{
                                @"prompt" : @"consent",
                                @"login_hint" : @"tu8731@gmail.com",
                                };
  provider.scopes = @[ @"user.readwrite,calendars.read" ];
  [self showSpinner:^{
    [provider getCredentialWithUIDelegate:nil completion:^(FIRAuthCredential *_Nullable credential,
                                                           NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with Microsoft failed" error:error];
        return;
      }
      [[AppManager auth] signInWithCredential:credential
                                   completion:^(FIRAuthDataResult *_Nullable
                                                authResult,
                                                NSError *_Nullable error) {
         [self hideSpinner:^{
           if (error) {
             [self logFailure:@"sign-in with Microsoft failed" error:error];
             return;
           } else {
             [self logSuccess:@"sign-in with Microsoft (headful-lite) succeeded."];
           }
           [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In Error" error:error];
         }];
       }];
    }];
  }];
}

- (void)signInWithGitHub {
  [self showTextInputPromptWithMessage:@"GitHub Access Token:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable accessToken) {
   if (!userPressedOK || !accessToken.length) {
     return;
   }
   FIROAuthCredential *credential =
   [FIROAuthProvider credentialWithProviderID:FIRGitHubAuthProviderID accessToken:accessToken];
   if (credential) {
     [[AppManager auth] signInWithCredential:credential
                                  completion:^(FIRAuthDataResult *_Nullable result,
                                               NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with provider failed" error:error];
      } else {
        [self logSuccess:@"sign-in with provider succeeded."];
      }
      [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In" error:error];
    }];
   }
 }];
}

@end
