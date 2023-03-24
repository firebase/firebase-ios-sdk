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

#import "MainViewController+MultiFactor.h"

#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
@import FirebaseAuth;
#import "MainViewController+Internal.h"
#import <FirebaseCore/FIRApp.h>

NS_ASSUME_NONNULL_BEGIN

@implementation MainViewController (MultiFactor)

- (StaticContentTableViewSection *)multiFactorSection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"Multi Factor" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Phone Enroll"
                                       action:^{ [weakSelf phoneEnroll]; }],
    [StaticContentTableViewCell cellWithTitle:@"TOTP Enroll"
                                       action:^{ [weakSelf TOTPEnroll]; }],
    [StaticContentTableViewCell cellWithTitle:@"MultiFactor Unenroll"
                                       action:^{ [weakSelf mfaUnenroll]; }],
  ]];
}

- (void)phoneEnroll {
  FIRUser *user = FIRAuth.auth.currentUser;
  if (!user) {
    [self logFailure:@"Please sign in first." error:nil];
    return;
  }
  [self showTextInputPromptWithMessage:@"Phone Number"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable phoneNumber) {
    [user.multiFactor
     getSessionWithCompletion:^(FIRMultiFactorSession *_Nullable session, NSError *_Nullable error) {
      // this is the step verfication code has been send to the phone number along with validating the number
      [FIRPhoneAuthProvider.provider verifyPhoneNumber:phoneNumber
                                            UIDelegate:nil
                                    multiFactorSession:session
                                            completion:^(NSString * _Nullable verificationID,
                                                         NSError * _Nullable error) {
        if (error) {
          [self logFailure:@"Multi factor start enroll failed." error:error];
        } else {
          [self showTextInputPromptWithMessage:@"Verification code"
                               completionBlock:^(BOOL userPressedOK,
                                                 NSString *_Nullable verificationCode) {
            FIRPhoneAuthCredential *credential =
            [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationID
                                                         verificationCode:verificationCode];
            FIRMultiFactorAssertion *assertion =
            [FIRPhoneMultiFactorGenerator assertionWithCredential:credential];
            [self showTextInputPromptWithMessage:@"Display name"
                                 completionBlock:^(BOOL userPressedOK,
                                                   NSString *_Nullable displayName) {
              [user.multiFactor enrollWithAssertion:assertion
                                        displayName:displayName
                                         completion:^(NSError *_Nullable error) {
                if (error) {
                  [self logFailure:@"Multi factor finalize enroll failed." error:error];
                } else {
                  [self logSuccess:@"Multi factor finalize enroll succeeded."];
                }
              }];
            }];
          }];
        }
      }];
    }];
  }];
}

- (void)TOTPEnroll {
  FIRUser *user = FIRAuth.auth.currentUser;
  if (!user) {
    [self logFailure:@"Please sign in first." error:nil];
    return;
  }
  [user.multiFactor getSessionWithCompletion:^(FIRMultiFactorSession *_Nullable session, NSError *_Nullable error) {
    if (error) {
      [self logFailure:@"Error getting multi-factor session." error:error];
      return;
    }
    [FIRTOTPMultiFactorGenerator generateSecretWithMultiFactorSession:session completion:^(FIRTOTPSecret *_Nullable secret, NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"Error generating TOTP secret." error:error];
        return;
      }
      NSString *accountName = user.email;
      NSString *issuer = FIRAuth.auth.app.name;
      dispatch_async(dispatch_get_main_queue(), ^{
        NSString *url = [secret generateQRCodeURLWithAccountName:accountName issuer:issuer];
        if(!url.length) {
          [self logFailure: @"Multi factor finalize enroll failed. Could not generate url." error:nil];
          return;
        }
        [secret openInOTPAppWithQRCodeURL:url];
        [self showQRCodePromptWithTextInput:@"Scan this QR Code and enter OTP:"
                               qrCodeString:url
                            completionBlock:^(BOOL userPressedOK, NSString *_Nullable oneTimePassword) {
          FIRTOTPMultiFactorAssertion *assertion = [FIRTOTPMultiFactorGenerator assertionForEnrollmentWithSecret:secret oneTimePassword:oneTimePassword];
          [self showTextInputPromptWithMessage:@"Display name"
                               completionBlock:^(BOOL userPressedOK,
                                                 NSString *_Nullable displayName) {
            [user.multiFactor enrollWithAssertion:assertion
                                      displayName:displayName
                                       completion:^(NSError *_Nullable error) {
              if (error) {
                [self logFailure:@"Multi factor finalize enroll failed." error:error];
              } else {
                [self logSuccess:@"Multi factor finalize enroll succeeded."];
              }
            }];
          }];
        }];
      });
    }];
  }];
}

- (void)mfaUnenroll {
  NSMutableString *displayNameString = [NSMutableString string];
  for (FIRMultiFactorInfo *tmpFactorInfo in FIRAuth.auth.currentUser.multiFactor.enrolledFactors) {
    [displayNameString appendString:tmpFactorInfo.displayName];
    [displayNameString appendString:@" "];
  }
  [self showTextInputPromptWithMessage:[NSString stringWithFormat:@"Enter multi factor to unenroll\n%@", displayNameString]
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable displayName) {
    FIRMultiFactorInfo *factorInfo;
    for (FIRMultiFactorInfo *tmpFactorInfo in FIRAuth.auth.currentUser.multiFactor.enrolledFactors) {
      if ([displayName isEqualToString:tmpFactorInfo.displayName]) {
        factorInfo = tmpFactorInfo;
      }
    }
    [FIRAuth.auth.currentUser.multiFactor unenrollWithInfo:factorInfo
                                                completion:^(NSError * _Nullable error) {
      if (error) {
        [self logFailure:@"Multi factor unenroll failed." error:error];
      } else {
        [self logSuccess:@"Multi factor unenroll succeeded."];
      }
    }];
  }];
}

@end

NS_ASSUME_NONNULL_END
