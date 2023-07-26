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
#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "FirebaseAuth/Sources/User/FIRUser_Internal.h"
#import <FirebaseAuth/FIRMultiFactorInfo.h>
#import <FirebaseAuth/FIRPhoneAuthProvider.h>
#import "MainViewController+Internal.h"
#import <AuthenticationServices/AuthenticationServices.h>


NS_ASSUME_NONNULL_BEGIN
@interface MainViewController () <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding>
@end

@implementation MainViewController (Passkey)

- (StaticContentTableViewSection *)passkeySection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"Passkey" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Sign In With Passkey"
                                       action:^{ [weakSelf passkeySignIn]; }],
    [StaticContentTableViewCell cellWithTitle:@"Enroll with Passkey"
                                       action:^{ [weakSelf passkeyEnroll]; }],
    [StaticContentTableViewCell cellWithTitle:@"Unenroll with Passkey"
                                       action:^{ [weakSelf passkeyUnenroll]; }],
  ]];
}

- (void)passkeySignIn {
  FIRUser *user = FIRAuth.auth.currentUser;
  // Sign In
  if (!user) {
    if (@available(iOS 16.0, *)) {
      // Create sign-in request
      [FIRAuth.auth startPasskeySignInWithCompletion:^(ASAuthorizationPlatformPublicKeyCredentialAssertionRequest * _Nullable request, NSError * _Nullable error) {
        ASAuthorizationController *controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests: [NSMutableArray arrayWithObject:request]];
        controller.delegate = self;
        controller.presentationContextProvider = self;
        [controller performAutoFillAssistedRequests];
      }];
    } else {
      // Fallback on earlier versions
    }
  }
}

- (void)passkeyEnroll {
  FIRUser *user = FIRAuth.auth.currentUser;
  if (!user) {
    [self logFailure:@"Please sign in first." error:nil];
    return;
  }
  
  // Create creation request
  if (@available(iOS 15.0, *)) {
    [user startPasskeyEnrollmentWithCompletion:^(ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest * _Nullable request, NSError * _Nullable error) {
      ASAuthorizationController *controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests: [NSMutableArray arrayWithObject:request]];
      controller.delegate = self;
      controller.presentationContextProvider = self;
      [controller performRequests];
    }];
  } else {
    // Fallback on earlier versions
  }
}

- (void)passkeyUnenroll {
  NSMutableString *enrolledPasskeyName = [NSMutableString string];
  
  for (FIRPasskey *enrolledPasskey in FIRAuth.auth.currentUser.enrolledPasskeys) {
    [enrolledPasskeyName appendString:enrolledPasskey.name];
    [enrolledPasskeyName appendString:@" "];
  }
    
  [self showTextInputPromptWithMessage:[NSString stringWithFormat:@"Passkey Unenroll\n%@", enrolledPasskeyName]
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable name) {
    FIRPasskey *passkeyToDelete;
    for (FIRPasskey *enrolledPasskey in FIRAuth.auth.currentUser.enrolledPasskeys) {
      if ([name isEqualToString:enrolledPasskey.name]) {
        passkeyToDelete = enrolledPasskey;
      }
    }

    if (@available(iOS 15.0, *)) {
      [FIRAuth.auth.currentUser unenrollPasskeyWithCredentialID:passkeyToDelete.credentialID
                                                             completion:^(NSError * _Nullable error) {
        if (error) {
          [self logFailure:@"Passkey unenroll failed." error:error];
        } else {
          [self logSuccess:@"Passkey unenroll succeeded."];
        }
      }];
    } else {
      // Fallback on earlier versions
    }
  }];
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization API_AVAILABLE(ios(15.0)) {
  // Enrollment
  if ([authorization.credential isKindOfClass: [ASAuthorizationPlatformPublicKeyCredentialRegistration class]]) {
    ASAuthorizationPlatformPublicKeyCredentialRegistration *platformCredential = (ASAuthorizationPlatformPublicKeyCredentialRegistration*) authorization.credential;
    
    // enroll method is for already existed accounts.
    FIRUser *user = FIRAuth.auth.currentUser;
    if (!user) {
      [self logFailure:@"Please sign in first." error:nil];
      return;
    }
    // enroll is on user level
    [user finalizePasskeyEnrollmentWithPlatformCredential:platformCredential completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
      if (!error) {
        [self log:@"enroll with passkey succeed"];
      }
    }];
    
  // Sign In
  } else if ([authorization.credential isKindOfClass: [ASAuthorizationPlatformPublicKeyCredentialAssertion class]]) {
    ASAuthorizationPlatformPublicKeyCredentialAssertion *platformCredential = (ASAuthorizationPlatformPublicKeyCredentialAssertion*) authorization.credential;
    [FIRAuth.auth finalizePasskeySignInWithPlatformCredential:platformCredential completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
      if (!error) {
        [self log:@"passkey sign in succeed"];
      }
    }];
  } else {
    [self log:@"credential type not found"];
  }
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error API_AVAILABLE(ios(13.0)) {
  NSLog(@"%@", error.description);
  if (@available(iOS 16.0, *)) {
    // Either the user canceled the sheet, or there were no credentials available.
    // This should land into the sign up case
    if (error.code == ASAuthorizationErrorCanceled) {
      // user implementing sign up request
      // create anoynmous user first
      // then enroll user with passkey
    }
  } else {
    // Fallback on earlier versions
  }
}
@end

NS_ASSUME_NONNULL_END
