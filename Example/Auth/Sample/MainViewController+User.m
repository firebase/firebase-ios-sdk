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

#import "MainViewController+User.h"

#import "AppManager.h"
#import "MainViewController_Internal.h"

@implementation MainViewController (User)

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
           [self logSuccess:@"set display name succeeded."];
         }
         [self showTypicalUIForUserUpdateResultsWithTitle:kSetDisplayNameTitle error:error];
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
         [self showTypicalUIForUserUpdateResultsWithTitle:kSetPhotoURLText error:error];
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
        [self showTypicalUIForUserUpdateResultsWithTitle:kReloadText error:error];
      }];
    }];
  }];
}

- (void)getProvidersForEmail {
  [self showTextInputPromptWithMessage:@"Email:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable userInput) {
   if (!userPressedOK || !userInput.length) {
     return;
   }
   [self showSpinner:^{
     [[AppManager auth] fetchProvidersForEmail:userInput
                                    completion:^(NSArray<NSString *> *_Nullable providers,
                                                 NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"get providers for email failed" error:error];
      } else {
        [self logSuccess:@"get providers for email succeeded."];
      }
      [self hideSpinner:^{
        if (error) {
          [self showMessagePrompt:error.localizedDescription];
          return;
        }
        [self showMessagePrompt:[providers componentsJoinedByString:@", "]];
      }];
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
         [self showTypicalUIForUserUpdateResultsWithTitle:kUpdateEmailText error:error];
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
         [self showTypicalUIForUserUpdateResultsWithTitle:kUpdatePasswordText error:error];
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
    [self showTypicalUIForUserUpdateResultsWithTitle:kDeleteUserText error:error];
  }];
}

- (void)updatePhoneNumber:(NSString *_Nullable)phoneNumber
               completion:(nullable testAutomationCallback)completion {
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
