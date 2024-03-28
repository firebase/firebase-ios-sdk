/*
 * Copyright 2023 Google LLC
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
#import "MainViewController+Passkey.h"
#import "AppManager.h"
#import "MainViewController+Internal.h"
#import <AuthenticationServices/AuthenticationServices.h>


NS_ASSUME_NONNULL_BEGIN
@interface MainViewController () <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding>
@end

@implementation MainViewController (Passkey)

- (StaticContentTableViewSection *)passkeySection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"Passkey" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Sign Up With Passkey"
                                       action:^{ [weakSelf passkeySignUp]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign In With Passkey"
                                       action:^{ [weakSelf passkeySignIn]; }],
    [StaticContentTableViewCell cellWithTitle:@"Enroll with Passkey"
                                       action:^{ [weakSelf passkeyEnroll]; }],
  ]];
}

- (void)passkeySignUp {
  // sign in anoymously
  [[AppManager auth] signInAnonymouslyWithCompletion:^(FIRAuthDataResult *_Nullable result,
                                                       NSError *_Nullable error) {
    if (error) {
      [self logFailure:@"sign-in anonymously failed" error:error];
    } else {
      [self logSuccess:@"sign-in anonymously succeeded."];
      [self log:[NSString stringWithFormat:@"User ID : %@", result.user.uid]];
      [self passkeyEnroll];
    }
  }];
}

- (void)passkeyEnroll {
  FIRUser *user = FIRAuth.auth.currentUser;
  if (!user) {
    [self logFailure:@"Please sign in first." error:nil];
    return;
  }
  [self showTextInputPromptWithMessage:@"passkey name"
                          keyboardType:UIKeyboardTypeEmailAddress
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable passkeyName) {
    if (@available(iOS 16.0, macOS 12.0, tvOS 16.0, *)) {
      [user startPasskeyEnrollmentWithName:passkeyName completion:^(ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest * _Nullable request, NSError * _Nullable error) {
        if (request) {
          ASAuthorizationController *controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests: [NSMutableArray arrayWithObject:request]];
          controller.delegate = self;
          controller.presentationContextProvider = self;
          [controller performRequests];
        } else if (error) {
          [self logFailure:@"Passkey enrollment failed" error:error];
        }
      }];
    } else {
      [self log:@"OS version is not supported for this action."];
    }
  }];

}

- (void)passkeySignIn {
  if (@available(iOS 16.0, macOS 12.0, tvOS 16.0, *)) {
    [[AppManager auth] startPasskeySignInWithCompletion:^(ASAuthorizationPlatformPublicKeyCredentialAssertionRequest * _Nullable request, NSError * _Nullable error) {
      if (request) {
        ASAuthorizationController *controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests: [NSMutableArray arrayWithObject:request]];
        controller.delegate = self;
        controller.presentationContextProvider = self;
        [controller performRequestsWithOptions:ASAuthorizationControllerRequestOptionPreferImmediatelyAvailableCredentials];
      }
    }];
  } else {
    [self log:@"OS version is not supported for this action."];
  }
}

@end

NS_ASSUME_NONNULL_END
