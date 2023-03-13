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

#import "MainViewController+Phone.h"

#import "AppManager.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MainViewController (Phone)

- (StaticContentTableViewSection *)phoneAuthSection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"Phone Auth" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Sign in With Phone Number"
                                       action:^{ [weakSelf signInWithPhoneNumberWithPrompt]; }],
    [StaticContentTableViewCell cellWithTitle:@"Link Phone Number"
                                       action:^{ [weakSelf linkPhoneNumberWithPrompt]; }],
    [StaticContentTableViewCell cellWithTitle:@"Unlink Phone Number"
                                       action:^{ [weakSelf unlinkFromProvider:FIRPhoneAuthProvider.id completion:nil]; }],
    ]];
}

- (void)signInWithPhoneNumber:(NSString *_Nullable)phoneNumber
                   completion:(nullable TestAutomationCallback)completion {
  [self showSpinner:^{
    [[AppManager phoneAuthProvider] verifyPhoneNumber:phoneNumber
                                           UIDelegate:nil
                                           completion:^(NSString *_Nullable verificationID,
                                                        NSError *_Nullable error) {
     [self hideSpinner:^{
       if (error) {
         [self logFailure:@"failed to send verification code" error:error];
         [self showMessagePrompt:error.localizedDescription];
         if (completion) {
           completion(error);
         }
         return;
       }
       [self logSuccess:@"Code sent"];
       [self commonPhoneNumberInputWithTitle:@"Code"
                                  completion:^(NSString *_Nullable verificationCode) {
        [self commontPhoneVerificationWithVerificationID:verificationID
                                        verificationCode:verificationCode];
        if (completion) {
          completion(nil);
        }
      }];
     }];
   }];
  }];
}

- (void)signInWithPhoneNumberWithPrompt {
  [self commonPhoneNumberInputWithTitle:@"Phone #"
                             completion:^(NSString *_Nullable phone) {
                               [self signInWithPhoneNumber:phone completion:nil];
                             }];
}

- (void)commonPhoneNumberInputWithTitle:(NSString *)title
                             completion:(TextInputCompletionBlock)completion {
  [self showTextInputPromptWithMessage:title
                          keyboardType:UIKeyboardTypePhonePad
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable phoneNumber) {
                         if (!userPressedOK) {
                           return;
                         }
                         completion(phoneNumber);
                       }];
}

- (void)commontPhoneVerificationWithVerificationID:(NSString *)verificationID
                                  verificationCode:(NSString *)verificationCode {
  [self showSpinner:^{
    FIRAuthCredential *credential =
    [[AppManager phoneAuthProvider] credentialWithVerificationID:verificationID
                                                verificationCode:verificationCode];
    [[AppManager auth] signInWithCredential:credential
                                 completion:^(FIRAuthDataResult *_Nullable result,
                                              NSError *_Nullable error) {
     [self hideSpinner:^{
       if (error) {
         [self logFailure:@"failed to verify phone number" error:error];
         [self showMessagePrompt:error.localizedDescription];
         return;
       }
       if (self.isNewUserToggleOn) {
         NSString *newUserString = result.additionalUserInfo.isNewUser ?
         @"New user" : @"Existing user";
         [self showMessagePromptWithTitle:@"New or Existing"
                                  message:newUserString
                         showCancelButton:NO
                               completion:nil];
       }
     }];
   }];
  }];
}

- (void)linkPhoneNumber:(NSString *_Nullable)phoneNumber
             completion:(nullable TestAutomationCallback)completion {
  [self showSpinner:^{
    [[AppManager phoneAuthProvider] verifyPhoneNumber:phoneNumber
                                           UIDelegate:nil
                                           completion:^(NSString *_Nullable verificationID,
                                                        NSError *_Nullable error) {
     [self hideSpinner:^{
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
          [[self user] linkWithCredential:credential
                                              completion:^(FIRAuthDataResult *_Nullable result,
                                                           NSError *_Nullable error) {
            [self hideSpinner:^{
              if (error) {
                if (error.code == FIRAuthErrorCodeCredentialAlreadyInUse) {
                  [self showMessagePromptWithTitle:@"Phone number is already linked to "
                   @"another user"
                                           message:@"Tap Ok to sign in with that user now."
                                  showCancelButton:YES
                                        completion:^(BOOL userPressedOK,
                                                     NSString *_Nullable userInput) {
                    if (userPressedOK) {
                      // If FIRAuthErrorCodeCredentialAlreadyInUse error, sign in with the
                      // provided credential.
                      [self showSpinner:^{
                        FIRPhoneAuthCredential *credential =
                        error.userInfo[FIRAuthErrors.userInfoUpdatedCredentialKey];
                        [[AppManager auth] signInWithCredential:credential
                                                    completion:^(FIRAuthDataResult *_Nullable result,
                                                                 NSError *_Nullable error) {
                          [self hideSpinner:^{
                            if (error) {
                              [self logFailure:@"failed to verify phone number" error:error];
                              [self showMessagePrompt:error.localizedDescription];
                              if (completion) {
                                completion(error);
                              }
                              return;
                            }
                          }];
                        }];
                      }];
                    }
                  }];
                } else {
                  [self logFailure:@"link phone number failed" error:error];
                  [self showMessagePrompt:error.localizedDescription];
                }
                return;
              }
              [self logSuccess:@"link phone number succeeded."];
              if (completion) {
                completion(nil);
              }
            }];
          }];
        }];
      }];
     }];
   }];
  }];
}

- (void)linkPhoneNumberWithPrompt {
  [self showTextInputPromptWithMessage:@"Phone #:"
                          keyboardType:UIKeyboardTypePhonePad
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable phoneNumber) {
                         if (!userPressedOK || !phoneNumber.length) {
                           return;
                         }
                         [self linkPhoneNumber:phoneNumber completion:nil];
                       }];
}


@end

NS_ASSUME_NONNULL_END
