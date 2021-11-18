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

#import "MainViewController+User.h"

#import "AppManager.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MainViewController (User)

- (StaticContentTableViewSection *)userSection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"User" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Set Display Name"
                                      action:^{ [weakSelf setDisplayName]; }],
    [StaticContentTableViewCell cellWithTitle:@"Set Photo URL"
                                      action:^{ [weakSelf setPhotoURL]; }],
    [StaticContentTableViewCell cellWithTitle:@"Update Email"
                                      action:^{ [weakSelf updateEmail]; }],
    [StaticContentTableViewCell cellWithTitle:@"Update Password"
                                      action:^{ [weakSelf updatePassword]; }],
    [StaticContentTableViewCell cellWithTitle:@"Update Phone Number"
                                      action:^{ [weakSelf updatePhoneNumber]; }],
    [StaticContentTableViewCell cellWithTitle:@"Get Sign-in methods for Email"
                                      action:^{ [weakSelf getAllSignInMethodsForEmail]; }],
    [StaticContentTableViewCell cellWithTitle:@"Reload User"
                                      action:^{ [weakSelf reloadUser]; }],
    [StaticContentTableViewCell cellWithTitle:@"Delete User"
                                       action:^{ [weakSelf deleteAccount]; }],
    [StaticContentTableViewCell cellWithTitle:@"Verify before update email"
                                       action:^{ [weakSelf verifyBeforeUpdateEmail]; }],
    ]];
}

- (void)setDisplayName {
  [self showTextInputPromptWithMessage:@"Display Name:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable userInput) {
   if (!userPressedOK || !userInput.length) {
     return;
   }
   [self showSpinner:^{
     FIRUserProfileChangeRequest *changeRequest = [[self user] profileChangeRequest];
     changeRequest.displayName = userInput;
     [changeRequest commitChangesWithCompletion:^(NSError *_Nullable error) {
       [self hideSpinner:^{
         if (error) {
           [self logFailure:@"set display name failed" error:error];
         } else {
           [FIRAuth.auth.currentUser getIDTokenResultWithCompletion:^(FIRAuthTokenResult *_Nullable tokenResult,
                                                                      NSError *_Nullable error) {
             [self logSuccess:@"set display name succeeded."];
           }];
         }
         [self showTypicalUIForUserUpdateResultsWithTitle:@"Set Display Name" error:error];
       }];
     }];
   }];
 }];
}

- (void)setPhotoURL {
  [self showTextInputPromptWithMessage:@"Photo URL:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable userInput) {
   if (!userPressedOK || !userInput.length) {
     return;
   }
   [self showSpinner:^{
     FIRUserProfileChangeRequest *changeRequest = [[self user] profileChangeRequest];
     changeRequest.photoURL = [NSURL URLWithString:userInput];
     [changeRequest commitChangesWithCompletion:^(NSError *_Nullable error) {
       if (error) {
         [self logFailure:@"set photo URL failed" error:error];
       } else {
         [self logSuccess:@"set Photo URL succeeded."];
       }
       [self hideSpinner:^{
         [self showTypicalUIForUserUpdateResultsWithTitle:@"Set Photo URL" error:error];
       }];
     }];
   }];
 }];
}

- (void)reloadUser {
  [self showSpinner:^() {
    [[self user] reloadWithCompletion:^(NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"reload user failed" error:error];
      } else {
        [self logSuccess:@"reload user succeeded."];
      }
      [self hideSpinner:^() {
        [self showTypicalUIForUserUpdateResultsWithTitle:@"Reload User" error:error];
      }];
    }];
  }];
}

- (void)getAllSignInMethodsForEmail {
  [self showTextInputPromptWithMessage:@"Email:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable userInput) {
   if (!userPressedOK || !userInput.length) {
     return;
   }
   [self showSpinner:^{
     [[AppManager auth] fetchSignInMethodsForEmail:userInput
                                        completion:^(NSArray<NSString *> *_Nullable signInMethods,
                                                     NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"get sign-in methods for email failed" error:error];
      } else {
        [self logSuccess:@"get sign-in methods for email succeeded."];
      }
      [self hideSpinner:^{
        if (error) {
          [self showMessagePrompt:error.localizedDescription];
          return;
        }
        [self showMessagePrompt:[signInMethods componentsJoinedByString:@", "]];
      }];
    }];
   }];
 }];
}
- (void)updateEmail {
  [self showTextInputPromptWithMessage:@"Email Address:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable userInput) {
   if (!userPressedOK || !userInput.length) {
     return;
   }
   [self showSpinner:^{
     [[self user] updateEmail:userInput completion:^(NSError *_Nullable error) {
       if (error) {
         [self logFailure:@"update email failed" error:error];
       } else {
         [self logSuccess:@"update email succeeded."];
       }
       [self hideSpinner:^{
         [self showTypicalUIForUserUpdateResultsWithTitle:@"Update Email" error:error];
       }];
     }];
   }];
 }];
}

- (void)verifyBeforeUpdateEmail {
  [self showTextInputPromptWithMessage:@"Email Address:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable userInput) {
  if (!userPressedOK || !userInput.length) {
   return;
  }
  [self showSpinner:^{
    [[self user] sendEmailVerificationBeforeUpdatingEmail:userInput
                                       actionCodeSettings:[self actionCodeSettings]
                                               completion:^(NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"verify before update email failed." error:error];
      } else {
       [self logSuccess:@"verify before update email succeeded."];
      }
      [self hideSpinner:^{
        [self showTypicalUIForUserUpdateResultsWithTitle:@"Update Email" error:error];
      }];
    }];
   }];
  }];
}

- (void)updatePassword {
  [self showTextInputPromptWithMessage:@"New Password:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable userInput) {
   if (!userPressedOK) {
     return;
   }
   [self showSpinner:^{
     [[self user] updatePassword:userInput completion:^(NSError *_Nullable error) {
       if (error) {
         [self logFailure:@"update password failed" error:error];
       } else {
         [self logSuccess:@"update password succeeded."];
       }
       [self hideSpinner:^{
         [self showTypicalUIForUserUpdateResultsWithTitle:@"Update Password" error:error];
       }];
     }];
   }];
 }];
}

- (void)deleteAccount {
  FIRUser *user = [self user];
  [user deleteWithCompletion:^(NSError *_Nullable error) {
    if (error) {
      [self logFailure:@"delete account failed" error:error];
    }
    [self showTypicalUIForUserUpdateResultsWithTitle:@"Delete User" error:error];
  }];
}

- (void)updatePhoneNumber:(NSString *_Nullable)phoneNumber
               completion:(nullable TestAutomationCallback)completion {
  [self showSpinner:^{
    [[AppManager phoneAuthProvider] verifyPhoneNumber:phoneNumber
                                           UIDelegate:nil
                                           completion:^(NSString *_Nullable verificationID,
                                                        NSError *_Nullable error) {
     if (error) {
       [self logFailure:@"failed to send verification code" error:error];
       [self showMessagePrompt:error.localizedDescription];
       if (completion) {
         completion(error);
       }
       return;
     }
     [self logSuccess:@"Code sent"];

     [self showTextInputPromptWithMessage:@"Verification code:"
                             keyboardType:UIKeyboardTypeNumberPad
                          completionBlock:^(BOOL userPressedOK,
                                            NSString *_Nullable verificationCode) {
      if (!userPressedOK || !verificationCode.length) {
        return;
      }
      [self showSpinner:^{
        FIRPhoneAuthCredential *credential =
        [[AppManager phoneAuthProvider] credentialWithVerificationID:verificationID
                                                    verificationCode:verificationCode];
        [[self user] updatePhoneNumberCredential:credential
                                      completion:^(NSError *_Nullable error) {
          if (error) {
            [self logFailure:@"update phone number failed" error:error];
            [self showMessagePrompt:error.localizedDescription];
            if (completion) {
              completion(error);
            }
          } else {
            [self logSuccess:@"update phone number succeeded."];
            if (completion) {
              completion(nil);
            }
          }
        }];
      }];
    }];
   }];
  }];
}

- (void)updatePhoneNumber {
  [self showTextInputPromptWithMessage:@"Update Phone #:"
                          keyboardType:UIKeyboardTypePhonePad
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable phoneNumber) {
    if (!userPressedOK || !phoneNumber.length) {
      return;
    }
    [self updatePhoneNumber:phoneNumber completion:nil];
  }];
}

@end

NS_ASSUME_NONNULL_END
