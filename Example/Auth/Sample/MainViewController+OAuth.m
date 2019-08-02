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
#import "MainViewController+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MainViewController (OAuth)

- (StaticContentTableViewSection *)oAuthSection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"OAuth" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Google"
                                       action:^{ [weakSelf signInGoogleHeadfulLite]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Twitter"
                                       action:^{ [weakSelf signInTwitterHeadfulLite]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with GitHub"
                                       action:^{ [weakSelf signInGitHubHeadfulLite]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with GitHub (Access token)"
                                       action:^{ [weakSelf signInWithGitHub]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Microsoft"
                                       action:^{ [weakSelf signInMicrosoftHeadfulLite]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Yahoo"
                                       action:^{ [weakSelf signInYahooHeadfulLite]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Linkedin"
                                       action:^{ [weakSelf signInLinkedinHeadfulLite]; }],
    ]];
}

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

- (void)signInTwitterHeadfulLite {
  FIROAuthProvider *provider = self.twitterOAuthProvider;
  [self showSpinner:^{
    [provider getCredentialWithUIDelegate:nil completion:^(FIRAuthCredential *_Nullable credential,
                                                           NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with Twitter failed" error:error];
        return;
      }
      [[AppManager auth] signInWithCredential:credential
                                   completion:^(FIRAuthDataResult *_Nullable
                                                authResult,
                                                NSError *_Nullable error) {
         [self hideSpinner:^{
           if (error) {
             [self logFailure:@"sign-in with Twitter (headful-lite) failed" error:error];
             return;
           } else {
             [self logSuccess:@"sign-in with Twitter (headful-lite) succeeded."];
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

- (void)signInGitHubHeadfulLite {
  FIROAuthProvider *provider = self.gitHubOAuthProvider;
  [self showSpinner:^{
    [provider getCredentialWithUIDelegate:nil completion:^(FIRAuthCredential *_Nullable credential,
                                                           NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with GitHub failed" error:error];
        return;
      }
      [[AppManager auth] signInWithCredential:credential
                                   completion:^(FIRAuthDataResult *_Nullable
                                                authResult,
                                                NSError *_Nullable error) {
         [self hideSpinner:^{
           if (error) {
             [self logFailure:@"sign-in with GitHub (headful-lite) failed" error:error];
             return;
           } else {
             [self logSuccess:@"sign-in with GitHub (headful-lite) succeeded."];
           }
           [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In Error" error:error];
         }];
       }];
    }];
  }];
}

- (void)signInLinkedinHeadfulLite {
  FIROAuthProvider *provider = self.linkedinOAuthProvider;
  [self showSpinner:^{
    [provider getCredentialWithUIDelegate:nil completion:^(FIRAuthCredential *_Nullable credential,
                                                           NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with Linkedin failed" error:error];
        return;
      }
      [[AppManager auth] signInWithCredential:credential
                                   completion:^(FIRAuthDataResult *_Nullable
                                                authResult,
                                                NSError *_Nullable error) {
         [self hideSpinner:^{
           if (error) {
             [self logFailure:@"sign-in with Linkedin (headful-lite) failed" error:error];
             return;
           } else {
             [self logSuccess:@"sign-in with Linkedin (headful-lite) succeeded."];
           }
           [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In Error" error:error];
         }];
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

- (void)signInYahooHeadfulLite {
  FIROAuthProvider *provider = self.yahooOAuthProvider;
  [self showSpinner:^{
    [provider getCredentialWithUIDelegate:nil completion:^(FIRAuthCredential *_Nullable credential,
                                                           NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with Yahoo failed" error:error];
        return;
      }
      [[AppManager auth] signInWithCredential:credential
                                   completion:^(FIRAuthDataResult *_Nullable
                                                authResult,
                                                NSError *_Nullable error) {
         [self hideSpinner:^{
           if (error) {
             [self logFailure:@"sign-in with Yahoo (headful-lite) failed" error:error];
             return;
           } else {
             [self logSuccess:@"sign-in with Yahoo (headful-lite) succeeded."];
           }
           [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In Error" error:error];
         }];
       }];
    }];
  }];
}

@end

NS_ASSUME_NONNULL_END
