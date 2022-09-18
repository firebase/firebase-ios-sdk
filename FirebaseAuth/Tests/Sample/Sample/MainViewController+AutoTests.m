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

#import "MainViewController+AutoTests.h"

#import "AppManager.h"
#import "AuthProviders.h"
#import "MainViewController+Internal.h"
#import "MainViewController+GameCenter.h"
#import "MainViewController+Phone.h"
#import "MainViewController+User.h"
#import "MainViewController+OOB.h"
#import "MainViewController+App.h"
#import "MainViewController+Email.h"
#import "MainViewController+Google.h"
#import "MainViewController+Facebook.h"
#import "MainViewController+Auth.h"
#import "MainViewController+OAuth.h"
#import "MainViewController+Custom.h"
#import "MainViewController+AutoTests.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kCustomTokenUrl = @"https://gcip-testapps.wl.r.appspot.com/token";

static NSString *const kExpiredCustomTokenUrl = @"https://gcip-testapps.wl.r.appspot.com/expired_token";

static NSString *const kInvalidCustomToken = @"invalid custom token.";

static NSString *const kSafariGoogleSignOutMessagePrompt = @"This automated test assumes that no "
"Google account is signed in on Safari, if your are not prompted for a password, sign out on "
"Safari and rerun the test.";

static NSString *const kSafariFacebookSignOutMessagePrompt = @"This automated test assumes that no "
"Facebook account is signed in on Safari, if your are not prompted for a password, sign out on "
"Safari and rerun the test.";

static NSString *const kUnlinkAccountMessagePrompt = @"Sign into gmail with an email address "
"that has not been linked to this sample application before. Delete account if necessary.";

static NSString *const kFakeDisplayPhotoUrl =
@"https://www.gstatic.com/images/branding/product/1x/play_apps_48dp.png";

static NSString *const kFakeDisplayName = @"John GoogleSpeed";

static NSString *const kFakeEmail = @"firemail@example.com";

static NSString *const kFakePassword = @"fakePassword";

@implementation MainViewController (AutoTests)

- (StaticContentTableViewSection *)autoTestsSection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"Automated Tests" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"BYOAuth"
                                       action:^{ [weakSelf automatedBYOAuth]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign In With Google"
                                       action:^{ [weakSelf automatedSignInGoogle]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign In With Facebook"
                                       action:^{ [weakSelf automatedSignInFacebook]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign Up With Email/Password"
                                       action:^{ [weakSelf automatedEmailSignUp]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign In Anonymously"
                                       action:^{ [weakSelf automatedAnonymousSignIn]; }],
    [StaticContentTableViewCell cellWithTitle:@"Link with Google"
                                       action:^{ [weakSelf automatedAccountLinking]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in With Phone Number"
                                       action:^{ [weakSelf automatedPhoneNumberSignIn]; }]
    ]];
}

- (void)automatedBYOAuth {
  [self log:@"INITIATING AUTOMATED MANUAL TEST FOR BYOAUTH:"];
  [self showSpinner:^{
    NSError *error;
    NSString *customToken = [NSString stringWithContentsOfURL:[NSURL URLWithString:kCustomTokenUrl]
                                                     encoding:NSUTF8StringEncoding
                                                        error:&error];
    NSString *expiredCustomToken =
    [NSString stringWithContentsOfURL:[NSURL URLWithString:kExpiredCustomTokenUrl]
                             encoding:NSUTF8StringEncoding
                                error:&error];
    [self hideSpinner:^{
      if (error) {
        [self log:@"There was an error retrieving the custom token."];
        return;
      }
      FIRAuth *auth = [AppManager auth];
      [auth signInWithCustomToken:customToken
                       completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
        if (error) {
          [self logFailure:@"sign-in with custom token failed" error:error];
          [self logFailedTest:@"A fresh custom token should succeed in signing-in."];
          return;
        }
        [self logSuccess:@"sign-in with custom token succeeded."];
        [auth.currentUser getIDTokenForcingRefresh:NO
                                       completion:^(NSString *_Nullable token,
                                                    NSError *_Nullable error) {
           if (error) {
             [self logFailure:@"refresh token failed" error:error];
             [self logFailedTest:@"Refresh token should be available."];
             return;
           }
           [self logSuccess:@"refresh token succeeded."];
           [auth signOut:NULL];
           [auth signInWithCustomToken:expiredCustomToken
                            completion:^(FIRAuthDataResult *_Nullable result,
                                         NSError *_Nullable error) {
              if (!error) {
                [self logSuccess:@"sign-in with custom token succeeded."];
                [self logFailedTest:@"sign-in with an expired custom token should NOT succeed."];
                return;
              }
              [self logFailure:@"sign-in with custom token failed" error:error];
              [auth signInWithCustomToken:kInvalidCustomToken
                               completion:^(FIRAuthDataResult *_Nullable result,
                                            NSError *_Nullable error) {
                 if (!error) {
                   [self logSuccess:@"sign-in with custom token succeeded."];
                   [self logFailedTest:@"sign-in with an invalid custom token should NOT succeed."];
                   return;
                 }
                 [self logFailure:@"sign-in with custom token failed" error:error];
                 //next step of automated test.
                 [self automatedBYOAuthEmailPassword];
               }];
            }];
         }];
      }];
    }];
  }];
}

- (void)automatedSignInGoogle {
  [self showMessagePromptWithTitle:@"Sign In With Google"
                           message:kSafariGoogleSignOutMessagePrompt
                  showCancelButton:NO
                        completion:^(BOOL userPressedOK, NSString *_Nullable userInput) {
                          FIRAuth *auth = [AppManager auth];
                          if (!auth) {
                            [self logFailedTest:@"Could not obtain auth object."];
                            return;
                          }
                          [auth signOut:NULL];
                          [self log:@"INITIATING AUTOMATED MANUAL TEST FOR GOOGLE SIGN IN:"];
                          [self signInWithProvider:[AuthProviders google] callback:^{
                            [self logSuccess:@"sign-in with Google provider succeeded."];
                            [auth signOut:NULL];
                            [self signInWithProvider:[AuthProviders google] callback:^{
                              [self logSuccess:@"sign-in with Google provider succeeded."];
                              [self updateEmailPasswordWithCompletion:^{
                                [self automatedSignInGoogleDisplayNamePhotoURL];
                              }];
                            }];
                          }];
                        }];
}

- (void)automatedSignInGoogleDisplayNamePhotoURL {
  [self signInWithProvider:[AuthProviders google] callback:^{
    [self updateDisplayNameAndPhotoURlWithCompletion:^{
      [self log:@"FINISHED AUTOMATED MANUAL TEST FOR SIGN-IN WITH GOOGlE."];
      [self reloadUser];
    }];
  }];
}

- (void)automatedSignInFacebook {
  [self showMessagePromptWithTitle:@"Sign In With Facebook"
                           message:kSafariFacebookSignOutMessagePrompt
                  showCancelButton:NO
                        completion:^(BOOL userPressedOK, NSString *_Nullable userInput) {
                          FIRAuth *auth = [AppManager auth];
                          if (!auth) {
                            [self logFailedTest:@"Could not obtain auth object."];
                            return;
                          }
                          [auth signOut:NULL];
                          [self log:@"INITIATING AUTOMATED MANUAL TEST FOR FACEBOOK SIGN IN:"];
                          [self signInWithProvider:[AuthProviders facebook] callback:^{
                            [self logSuccess:@"sign-in with Facebook provider succeeded."];
                            [auth signOut:NULL];
                            [self signInWithProvider:[AuthProviders facebook] callback:^{
                              [self logSuccess:@"sign-in with Facebook provider succeeded."];
                              [self updateEmailPasswordWithCompletion:^{
                                [self automatedSignInFacebookDisplayNamePhotoURL];
                              }];
                            }];
                          }];
                        }];
}

- (void)automatedPhoneNumberSignIn {
  [self log:@"Automated phone number sign in"];
  FIRAuth *auth = [AppManager auth];
  if (!auth) {
    [self logFailedTest:@"Could not obtain auth object."];
    return;
  }
  [auth signOut:NULL];
  [self log:@"INITIATING AUTOMATED MANUAL TEST FOR PHONE NUMBER SIGN IN:"];
  [self commonPhoneNumberInputWithTitle:@"Phone for automation"
                             completion:^(NSString *_Nullable phone) {
     [self signInWithPhoneNumber:phone completion:^(NSError *error) {
       if (error) {
         [self logFailedTest:@"Could not sign in with phone number reCAPTCHA."];
       }
       [self logSuccess:@"sign-in with phone number reCAPTCHA test succeeded."];
       [auth signOut:NULL];
       [self signInWithPhoneNumber:phone completion:^(NSError *error) {
         if (error) {
           [self logFailedTest:@"Could not sign in with phone number reCAPTCHA."];
         }
         [self logSuccess:@"second sign-in with phone number reCAPTCHA test succeeded."];
         [self updatePhoneNumber:phone completion:^(NSError *error) {
           if (error) {
             [self logFailedTest:@"Could not update phone number."];
           }
           [self logSuccess:@"update phone number test succeeded."];
           [self unlinkFromProvider:FIRPhoneAuthProviderID completion:^(NSError *error) {
             if (error) {
               [self logFailedTest:@"Could not unlink phone number."];
             }
             [self logSuccess:@"unlink phone number test succeeded."];
             [self linkPhoneNumber:phone completion:^(NSError *error) {
               if (error) {
                 [self logFailedTest:@"Could not link phone number."];
               }
               [self logSuccess:@"link phone number test succeeded."];
               [self log:@"FINISHED AUTOMATED MANUAL TEST FOR PHONE NUMBER SIGN IN."];
             }];
           }];
         }];
       }];
     }];
    }];
}

- (void)automatedEmailSignUp {
  [self log:@"INITIATING AUTOMATED MANUAL TEST FOR FACEBOOK SIGN IN:"];
  FIRAuth *auth = [AppManager auth];
  if (!auth) {
    [self logFailedTest:@"Could not obtain auth object."];
    return;
  }
  [self signUpNewEmail:kFakeEmail password:kFakePassword callback:^(FIRUser *_Nullable user,
                                                                    NSError *_Nullable error) {
    if (error) {
      [self logFailedTest: @" Email/Password Account account creation failed"];
      return;
    }
    [auth signOut:NULL];
    FIRAuthCredential *credential = [FIREmailAuthProvider credentialWithEmail:kFakeEmail
                                                                     password:kFakePassword];
    [auth signInWithCredential:credential
                    completion:^(FIRAuthDataResult *_Nullable result,
                                 NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with Email/Password failed" error:error];
        [self logFailedTest:@"sign-in with Email/Password should succeed."];
        return;
      }
      [self logSuccess:@"sign-in with Email/Password succeeded."];
      [self log:@"FINISHED AUTOMATED MANUAL TEST FOR SIGN-IN WITH EMAIL/PASSWORD."];
      // Delete the user so that we can reuse the fake email address for subsequent tests.
      [auth.currentUser deleteWithCompletion:^(NSError *_Nullable error) {
        if (error) {
          [self logFailure:@"Failed to delete user" error:error];
          [self logFailedTest:@"Deleting a user that was recently signed-in should succeed."];
          return;
        }
        [self logSuccess:@"User deleted."];
      }];
    }];
  }];
}

- (void)automatedAnonymousSignIn {
  [self log:@"INITIATING AUTOMATED MANUAL TEST FOR ANONYMOUS SIGN IN:"];
  FIRAuth *auth = [AppManager auth];
  if (!auth) {
    [self logFailedTest:@"Could not obtain auth object."];
    return;
  }
  [auth signOut:NULL];
  [self signInAnonymouslyWithCallback:^(FIRAuthDataResult *_Nullable result,
                                        NSError *_Nullable error) {
    if (result.user) {
      NSString *anonymousUID = result.user.uid;
      [self signInAnonymouslyWithCallback:^(FIRAuthDataResult *_Nullable user,
                                            NSError *_Nullable error) {
        if (![result.user.uid isEqual:anonymousUID]) {
          [self logFailedTest:@"Consecutive anonymous sign-ins should yeild the same User ID"];
          return;
        }
        [self log:@"FINISHED AUTOMATED MANUAL TEST FOR ANONYMOUS SIGN IN."];
      }];
    }
  }];
}

- (void)automatedBYOAuthEmailPassword {
  [self showSpinner:^{
    NSError *error;
    NSString *customToken = [NSString stringWithContentsOfURL:[NSURL URLWithString:kCustomTokenUrl]
                                                     encoding:NSUTF8StringEncoding
                                                        error:&error];
    [self hideSpinner:^{
      if (error) {
        [self log:@"There was an error retrieving the custom token."];
        return;
      }
      [[AppManager auth] signInWithCustomToken:customToken
                                    completion:^(FIRAuthDataResult *_Nullable user,
                                                 NSError *_Nullable error) {
        if (error) {
          [self logFailure:@"sign-in with custom token failed" error:error];
          [self logFailedTest:@"A fresh custom token should succeed in signing-in."];
          return;
        }
        [self logSuccess:@"sign-in with custom token succeeded."];
        [self updateEmailPasswordWithCompletion:^{
          [self automatedBYOAuthDisplayNameAndPhotoURl];
        }];
      }];
    }];
  }];
}

- (void)automatedBYOAuthDisplayNameAndPhotoURl {
  [self showSpinner:^{
    NSError *error;
    NSString *customToken = [NSString stringWithContentsOfURL:[NSURL URLWithString:kCustomTokenUrl]
                                                     encoding:NSUTF8StringEncoding
                                                        error:&error];
    [self hideSpinner:^{
      if (error) {
        [self log:@"There was an error retrieving the custom token."];
        return;
      }
      [[AppManager auth] signInWithCustomToken:customToken
                                    completion:^(FIRAuthDataResult *_Nullable result,
                                                 NSError *_Nullable error) {
        if (error) {
          [self logFailure:@"sign-in with custom token failed" error:error];
          [self logFailedTest:@"A fresh custom token should succeed in signing-in."];
          return;
        }
        [self logSuccess:@"sign-in with custom token succeeded."];
        [self updateDisplayNameAndPhotoURlWithCompletion:^{
          [self log:@"FINISHED AUTOMATED MANUAL TEST FOR BYOAUTH."];
          [self reloadUser];
        }];
      }];
    }];
  }];
}

- (void)updateEmailPasswordWithCompletion:(void(^)(void))completion {
  FIRAuth *auth = [AppManager auth];
  [auth.currentUser updateEmail:kFakeEmail completion:^(NSError *_Nullable error) {
    if (error) {
      [self logFailure:@"update email failed" error:error];
      [self logFailedTest:@"Update email should succeed when properly signed-in."];
      return;
    }
    [self logSuccess:@"update email succeeded."];
    [auth.currentUser updatePassword:kFakePassword completion:^(NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"update password failed" error:error];
        [self logFailedTest:@"Update password should succeed when properly signed-in."];
        return;
      }
      [self logSuccess:@"update password succeeded."];
      [auth signOut:NULL];
      FIRAuthCredential *credential =
      [FIREmailAuthProvider credentialWithEmail:kFakeEmail password:kFakePassword];
      [auth signInWithCredential:credential
                      completion:^(FIRAuthDataResult *_Nullable result,
                                   NSError *_Nullable error) {
        if (error) {
          [self logFailure:@"sign-in with Email/Password failed" error:error];
          [self logFailedTest:@"sign-in with Email/Password should succeed."];
          return;
        }
        [self logSuccess:@"sign-in with Email/Password succeeded."];
        // Delete the user so that we can reuse the fake email address for subsequent tests.
        [auth.currentUser deleteWithCompletion:^(NSError *_Nullable error) {
          if (error) {
            [self logFailure:@"Failed to delete user." error:error];
            [self logFailedTest:@"Deleting a user that was recently signed-in should succeed"];
            return;
          }
          [self logSuccess:@"User deleted."];
          completion();
        }];
      }];
    }];
  }];
}

- (void)updateDisplayNameAndPhotoURlWithCompletion:(void(^)(void))completion {
  FIRAuth *auth = [AppManager auth];
  FIRUserProfileChangeRequest *changeRequest = [auth.currentUser profileChangeRequest];
  changeRequest.photoURL = [NSURL URLWithString:kFakeDisplayPhotoUrl];
  [changeRequest commitChangesWithCompletion:^(NSError *_Nullable error) {
    if (error) {
      [self logFailure:@"set photo URL failed" error:error];
      [self logFailedTest:@"Change photo Url should succeed when signed-in."];
      return;
    }
    [self logSuccess:@"set PhotoURL succeeded."];
    FIRUserProfileChangeRequest *changeRequest = [auth.currentUser profileChangeRequest];
    changeRequest.displayName = kFakeDisplayName;
    [changeRequest commitChangesWithCompletion:^(NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"set display name failed" error:error];
        [self logFailedTest:@"Change display name should succeed when signed-in."];
        return;
      }
      [self logSuccess:@"set display name succeeded."];
      completion();
    }];
  }];
}

- (void)automatedSignInFacebookDisplayNamePhotoURL {
  [self signInWithProvider:[AuthProviders facebook] callback:^{
    [self updateDisplayNameAndPhotoURlWithCompletion:^{
      [self log:@"FINISHED AUTOMATED MANUAL TEST FOR SIGN-IN WITH FACEBOOK."];
      [self reloadUser];
    }];
  }];
}

- (void)automatedAccountLinking {
  [self log:@"INITIATING AUTOMATED MANUAL TEST FOR ACCOUNT LINKING:"];
  FIRAuth *auth = [AppManager auth];
  if (!auth) {
    [self logFailedTest:@"Could not obtain auth object."];
    return;
  }
  [auth signOut:NULL];
  [self signInAnonymouslyWithCallback:^(FIRAuthDataResult *_Nullable result,
                                        NSError *_Nullable error) {
    if (result.user) {
      NSString *anonymousUID = result.user.uid;
      [self showMessagePromptWithTitle:@"Sign In Instructions"
                               message:kUnlinkAccountMessagePrompt
                      showCancelButton:NO
                            completion:^(BOOL userPressedOK, NSString *_Nullable userInput) {
        [[AuthProviders google]
         getAuthCredentialWithPresentingViewController:self
         callback:^(FIRAuthCredential *credential,
                    NSError *error) {
           if (credential) {
             [result.user linkWithCredential:credential completion:^(FIRAuthDataResult *result,
                                                                     NSError *error) {
               FIRUser *user = result.user;
               if (error) {
                 [self logFailure:@"link auth provider failed" error:error];
                 [self logFailedTest:@"Account needs to be linked to complete the test."];
                 return;
               }
               [self logSuccess:@"link auth provider succeeded."];
               if (user.isAnonymous) {
                 [self logFailure:@"link auth provider failed, user still anonymous" error:error];
                 [self logFailedTest:@"Account needs to be linked to complete the test."];
               }
               if (![user.uid isEqual:anonymousUID]){
                 [self logFailedTest:@"link auth provider failed, UID's are different. Make sure "
                  "you link an account that has NOT been Linked nor Signed-In before."];
                 return;
               }
               [self log:@"FINISHED AUTOMATED MANUAL TEST FOR ACCOUNT LINKING."];
             }];
           }
         }];
      }];
    }
  }];
}

@end

NS_ASSUME_NONNULL_END
