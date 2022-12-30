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

#import "MainViewController+Google.h"

#import "AppManager.h"
#import "AuthProviders.h"
#import "FirebaseAuth/Sources/MultiFactor/FIRMultiFactorResolver+Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/FIRMultiFactorSession+Internal.h"
#import "MainViewController+Internal.h"
@import FirebaseAuth;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const FIRAuthErrorUserInfoMultiFactorResolverKey;

@implementation MainViewController (Google)

- (StaticContentTableViewSection *)googleAuthSection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"Google Auth" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Google"
                                      action:^{ [weakSelf signInGoogle]; }],
    [StaticContentTableViewCell cellWithTitle:@"Link with Google"
                                      action:^{ [weakSelf linkWithGoogle]; }],
    [StaticContentTableViewCell cellWithTitle:@"Unlink from Google"
                                      action:^{ [weakSelf unlinkFromProvider:FIRGoogleAuthProvider.string completion:nil]; }],
    [StaticContentTableViewCell cellWithTitle:@"Reauthenticate Google"
                                      action:^{ [weakSelf reauthenticateGoogle]; }],
    ]];
}

- (void)signInGoogle {
  FIRAuth *auth = [AppManager auth];
  if (!auth) {
    return;
  }
  [[AuthProviders google] getAuthCredentialWithPresentingViewController:self
                                                     callback:^(FIRAuthCredential *credential,
                                                                NSError *error) {
   if (credential) {
     FIRAuthDataResultCallback completion = ^(FIRAuthDataResult *_Nullable authResult,
                                              NSError *_Nullable error) {
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
           [self logFailure:@"sign-in with provider failed" error:error];
         }
       } else {
         [self logSuccess:@"sign-in with provider succeeded."];
       }
       if (authResult.additionalUserInfo) {
         [self logSuccess:[self stringWithAdditionalUserInfo:authResult.additionalUserInfo]];
         if (self.isNewUserToggleOn) {
           NSString *newUserString = authResult.additionalUserInfo.isNewUser ?
           @"New user" : @"Existing user";
           [self showMessagePromptWithTitle:@"New or Existing"
                                    message:newUserString
                           showCancelButton:NO
                                 completion:nil];
         }
       }
     };
     [auth signInWithCredential:credential completion:completion];
   }
 }];
}

- (void)linkWithGoogle {
  [self linkWithAuthProvider:[AuthProviders google] retrieveData:NO];
}

- (void)reauthenticateGoogle {
  [self reauthenticate:[AuthProviders google] retrieveData:NO];
}

@end

NS_ASSUME_NONNULL_END
