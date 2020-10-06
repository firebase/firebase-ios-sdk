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

#import "MainViewController+Email.h"

#import "AppManager.h"
#import <FirebaseAuth/FIRPhoneMultiFactorInfo.h>
#import "MainViewController+Internal.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const FIRAuthErrorUserInfoMultiFactorResolverKey;

typedef void (^ShowEmailDialogCompletion)(FIRAuthCredential *credential);

@implementation MainViewController (Email)

- (StaticContentTableViewSection *)emailAuthSection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"Email Auth" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Create User"
                                       action:^{ [weakSelf createUser]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Email Password"
                                       action:^{ [weakSelf signInEmailPassword]; }],
    [StaticContentTableViewCell cellWithTitle:@"Link with Email Password"
                                       action:^{ [weakSelf linkWithEmailPassword]; }],
    [StaticContentTableViewCell cellWithTitle:@"Reauthenticate Email Password"
                                       action:^{ [weakSelf reauthenticateEmailPassword]; }],
    [StaticContentTableViewCell cellWithTitle:@"Send Email Sign in Link"
                                       action:^{ [weakSelf sendEmailSignInLink]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Email Link"
                                       action:^{ [weakSelf signInWithEmailLink]; }],
    [StaticContentTableViewCell cellWithTitle:@"Link with Email Link"
                                       action:^{ [weakSelf linkWithEmailLink]; }],
    [StaticContentTableViewCell cellWithTitle:@"Unlink from Email"
                                       action:^{ [weakSelf unlinkFromProvider:FIREmailAuthProviderID
                                                                   completion:nil]; }],
    ]];
}

- (void)createUser {
  [self showTextInputPromptWithMessage:@"Email:"
                          keyboardType:UIKeyboardTypeEmailAddress
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable email) {
  if (!userPressedOK || !email.length) {
    return;
  }
  [self showTextInputPromptWithMessage:@"Password:"
                      completionBlock:^(BOOL userPressedOK, NSString *_Nullable password) {
      if (!userPressedOK) {
        return;
      }
      [self showSpinner:^{
        [[AppManager auth] createUserWithEmail:email
                                      password:password
                                    completion:^(FIRAuthDataResult *_Nullable result,
                                                 NSError *_Nullable error) {
          if (error) {
            [self logFailure:@"create user failed" error:error];
          } else {
            [self logSuccess:@"create user succeeded."];
            [self log:result.user.uid];
          }
          [self hideSpinner:^{
            [self showTypicalUIForUserUpdateResultsWithTitle:@"Create User" error:error];
          }];
        }];
      }];
    }];
  }];
}

- (void)signUpNewEmail:(NSString *)email
              password:(NSString *)password
              callback:(nullable FIRAuthResultCallback)callback {
  [[AppManager auth] createUserWithEmail:email
                                password:password
                              completion:^(FIRAuthDataResult *_Nullable result,
                                           NSError *_Nullable error) {
    if (error) {
      [self logFailure:@"sign-up with Email/Password failed" error:error];
      if (callback) {
        callback(nil, error);
      }
    } else {
      [self logSuccess:@"sign-up with Email/Password succeeded."];
      if (callback) {
        callback(result.user, nil);
      }
    }
    [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In" error:error];
  }];
}

- (void)signInEmailPassword {
  [self showTextInputPromptWithMessage:@"Email Address"
                          keyboardType:UIKeyboardTypeEmailAddress
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable email) {
    if (!userPressedOK || !email.length) {
      return;
    }
    [self showTextInputPromptWithMessage:@"Password"
                        completionBlock:^(BOOL userPressedOK, NSString *_Nullable password) {
        if (!userPressedOK) {
          return;
        }
        [self showSpinner:^{
          [[AppManager auth] signInWithEmail:email
                                    password:password
                                  completion:^(FIRAuthDataResult *_Nullable authResult,
                                               NSError *_Nullable error) {
            [self hideSpinner:^{
              if (error) {
                if (error.code == FIRAuthErrorCodeSecondFactorRequired) {
                  FIRMultiFactorResolver *resolver = error.userInfo[FIRAuthErrorUserInfoMultiFactorResolverKey];
                  NSMutableString *displayNameString = [NSMutableString string];
                  for (FIRMultiFactorInfo *tmpFactorInfo in resolver.hints) {
                    [displayNameString appendString:tmpFactorInfo.displayName];
                    [displayNameString appendString:@" "];
                  }
                  [self showTextInputPromptWithMessage:[NSString stringWithFormat:@"Select factor to sign in\n%@", displayNameString]
                                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable displayName) {
                    FIRPhoneMultiFactorInfo* selectedHint;
                    for (FIRMultiFactorInfo *tmpFactorInfo in resolver.hints) {
                      if ([displayName isEqualToString:tmpFactorInfo.displayName]) {
                        selectedHint = (FIRPhoneMultiFactorInfo *)tmpFactorInfo;
                      }
                    }
                  [FIRPhoneAuthProvider.provider
                     verifyPhoneNumberWithMultiFactorInfo:selectedHint
                     UIDelegate:nil
                     multiFactorSession:resolver.session
                     completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
                      if (error) {
                        [self logFailure:@"Multi factor start sign in failed." error:error];
                      } else {
                        [self showTextInputPromptWithMessage:[NSString stringWithFormat:@"Verification code for %@", selectedHint.displayName]
                                             completionBlock:^(BOOL userPressedOK, NSString *_Nullable verificationCode) {
                         FIRPhoneAuthCredential *credential =
                         [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationID
                                                                      verificationCode:verificationCode];
                         FIRMultiFactorAssertion *assertion = [FIRPhoneMultiFactorGenerator assertionWithCredential:credential];
                         [resolver resolveSignInWithAssertion:assertion completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
                           if (error) {
                             [self logFailure:@"Multi factor finalize sign in failed." error:error];
                           } else {
                             [self logSuccess:@"Multi factor finalize sign in succeeded."];
                           }
                         }];
                       }];
                      }
                    }];
                  }];
                } else {
                  [self logFailure:@"sign-in with Email/Password failed" error:error];
                }
              } else {
                [self logSuccess:@"sign-in with Email/Password succeeded."];
                [self log:[NSString stringWithFormat:@"UID: %@",authResult.user.uid]];
              }
            }];
          }];
        }];
      }];
    }];
}

- (void)linkWithEmailPassword {
  [self showEmailPasswordDialogWithCompletion:^(FIRAuthCredential *credential) {
    [self showSpinner:^{
      [[self user] linkWithCredential:credential
                           completion:^(FIRAuthDataResult *result, NSError *error) {
        if (error) {
          [self logFailure:@"link Email Password failed." error:error];
        } else {
          [self logSuccess:@"link Email Password succeeded."];
        }
        [self hideSpinner:^{
          [self showTypicalUIForUserUpdateResultsWithTitle:@"Link with Email Password" error:error];
        }];
      }];
    }];
  }];
}

- (void)reauthenticateEmailPassword {
  FIRUser *user = [self user];
  if (!user) {
    NSString *title = @"Missing User";
    NSString *message = @"There is no signed-in email/password user.";
    [self showMessagePromptWithTitle:title message:message showCancelButton:NO completion:nil];
    return;
  }
  [self showEmailPasswordDialogWithCompletion:^(FIRAuthCredential *credential) {
    [self showSpinner:^{
      [[self user] reauthenticateWithCredential:credential
                                     completion:^(FIRAuthDataResult *_Nullable result,
                                                  NSError *_Nullable error) {
        if (error) {
          [self logFailure:@"reauthicate with email password failed." error:error];
        } else {
          [self logSuccess:@"reauthicate with email password succeeded."];
        }
        [self hideSpinner:^{
          [self showTypicalUIForUserUpdateResultsWithTitle:@"Reauthenticate Email Password" error:error];
        }];
      }];
    }];
  }];
}

- (void)signInWithEmailLink {
  [self showTextInputPromptWithMessage:@"Email Address:"
                          keyboardType:UIKeyboardTypeEmailAddress
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable email) {
  if (!userPressedOK || !email.length) {
    return;
  }
  [self showTextInputPromptWithMessage:@"Email Sign-In Link:"
                      completionBlock:^(BOOL userPressedOK, NSString *_Nullable link) {
      if (!userPressedOK) {
        return;
      }
      if ([[FIRAuth auth] isSignInWithEmailLink:link]) {
        [self showSpinner:^{
          [[AppManager auth] signInWithEmail:email
                                        link:link
                                  completion:^(FIRAuthDataResult *_Nullable authResult,
                                               NSError *_Nullable error) {
            [self hideSpinner:^{
              if (error) {
                [self logFailure:@"sign-in with Email/Sign-In failed" error:error];
              } else {
                [self logSuccess:@"sign-in with Email/Sign-In link succeeded."];
                [self log:[NSString stringWithFormat:@"UID: %@",authResult.user.uid]];
              }
              [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In Error" error:error];
            }];
          }];
        }];
      } else {
        [self log:@"The sign-in link is invalid"];
      }
    }];
  }];
}

- (void)sendEmailSignInLink {
  [self showTextInputPromptWithMessage:@"Email:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable userInput) {
    if (!userPressedOK) {
      return;
    }
    [self showSpinner:^{
    void (^requestEmailSignInLink)(void (^)(NSError *)) = ^(void (^completion)(NSError *)) {
      [[AppManager auth] sendSignInLinkToEmail:userInput
                            actionCodeSettings:[self actionCodeSettings]
                                    completion:completion];
    };
      requestEmailSignInLink(^(NSError *_Nullable error) {
        [self hideSpinner:^{
         if (error) {
           [self logFailure:@"Email Link request failed" error:error];
           [self showMessagePrompt:error.localizedDescription];
           return;
         }
         [self logSuccess:@"Email Link request succeeded."];
         [self showMessagePrompt:@"Sent"];
        }];
      });
    }];
  }];
}

- (void)linkWithEmailLink {
  [self showEmailLinkDialogWithCompletion:^(FIRAuthCredential *credential) {
    [self showSpinner:^{
      [[self user] linkWithCredential:credential
                           completion:^(FIRAuthDataResult *result, NSError *error) {
        if (error) {
          [self logFailure:@"link Email Link failed." error:error];
        } else {
          [self logSuccess:@"link Email Link succeeded."];
        }
        [self hideSpinner:^{
          [self showTypicalUIForUserUpdateResultsWithTitle:@"Link with Email Link" error:error];
        }];
      }];
    }];
  }];
}

- (void)showEmailPasswordDialogWithCompletion:(ShowEmailDialogCompletion)completion {
  [self showTextInputPromptWithMessage:@"Email Address:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable email) {
    if (!userPressedOK || !email.length) {
      return;
    }
    [self showTextInputPromptWithMessage:@"Password:"
                         completionBlock:^(BOOL userPressedOK, NSString *_Nullable password) {
        if (!userPressedOK || !password.length) {
          return;
        }
        FIRAuthCredential *credential = [FIREmailAuthProvider credentialWithEmail:email
                                                                         password:password];
        completion(credential);
      }];
    }];
}

- (void)showEmailLinkDialogWithCompletion:(ShowEmailDialogCompletion)completion {
  [self showTextInputPromptWithMessage:@"Email Address:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable email) {
    if (!userPressedOK || !email.length) {
      return;
    }
    [self showTextInputPromptWithMessage:@"Link:"
                         completionBlock:^(BOOL userPressedOK, NSString *_Nullable link) {
      if (!userPressedOK || !link.length) {
        return;
      }
      FIRAuthCredential *credential = [FIREmailAuthProvider credentialWithEmail:email
                                                                           link:link];
      completion(credential);
    }];
  }];
}

@end

NS_ASSUME_NONNULL_END
