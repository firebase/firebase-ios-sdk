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

#import "MainViewController+Apple.h"

#import <AuthenticationServices/AuthenticationServices.h>

#import "AppManager.h"
#import "FirebaseAuth.h"
#import "MainViewController+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController () <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding> {

}

@end

@implementation MainViewController (Apple)

- (StaticContentTableViewSection *)appleAuthSection API_AVAILABLE(ios(13.0)) {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"Apple Auth" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Apple"
                                       action:^{ [weakSelf signInWithApple]; }],
    [StaticContentTableViewCell cellWithTitle:@"Link with Apple"
                                       action:^{ [weakSelf linkWithApple]; }],
    [StaticContentTableViewCell cellWithTitle:@"Unlink with Apple"
                                       action:^{ [weakSelf unlinkFromProvider:@"apple.com" completion:nil]; }],
    [StaticContentTableViewCell cellWithTitle:@"Reauthenticate with Apple"
                                       action:^{ [weakSelf reauthenticateWithApple]; }],
  ]];
}

- (void)signInWithApple API_AVAILABLE(ios(13.0)) {
  ASAuthorizationAppleIDProvider* provider = [[ASAuthorizationAppleIDProvider alloc] init];
  ASAuthorizationAppleIDRequest* request = [provider createRequest];
  request.requestedScopes = @[ASAuthorizationScopeEmail, ASAuthorizationScopeFullName];
  request.nonce = @"c3ab8ff13720e8ad9047dd39466b3c8974e592c2fa383d4a3960714caef0c4f2";
  request.state = @"signIn";

  ASAuthorizationController* controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
  controller.delegate = self;
  controller.presentationContextProvider = self;
  [controller performRequests];
}

- (void)linkWithApple API_AVAILABLE(ios(13.0)) {
  ASAuthorizationAppleIDProvider* provider = [[ASAuthorizationAppleIDProvider alloc] init];
  ASAuthorizationAppleIDRequest* request = [provider createRequest];
  request.requestedScopes = @[ASAuthorizationScopeEmail, ASAuthorizationScopeFullName];
  request.nonce = @"c3ab8ff13720e8ad9047dd39466b3c8974e592c2fa383d4a3960714caef0c4f2";
  request.state = @"link";

  ASAuthorizationController* controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
  controller.delegate = self;
  controller.presentationContextProvider = self;
  [controller performRequests];
}

- (void)reauthenticateWithApple API_AVAILABLE(ios(13.0)) {
  ASAuthorizationAppleIDProvider* provider = [[ASAuthorizationAppleIDProvider alloc] init];
  ASAuthorizationAppleIDRequest* request = [provider createRequest];
  request.requestedScopes = @[ASAuthorizationScopeEmail, ASAuthorizationScopeFullName];
  request.nonce = @"c3ab8ff13720e8ad9047dd39466b3c8974e592c2fa383d4a3960714caef0c4f2";
  request.state = @"reauth";

  ASAuthorizationController* controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
  controller.delegate = self;
  controller.presentationContextProvider = self;
  [controller performRequests];
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization API_AVAILABLE(ios(13.0)) {
  ASAuthorizationAppleIDCredential* appleIDCredential = authorization.credential;
  NSString *idToken = [NSString stringWithUTF8String:[appleIDCredential.identityToken bytes]];
  FIROAuthCredential *credential = [FIROAuthProvider credentialWithProviderID:@"apple.com"
                                                                      IDToken:idToken
                                                                     rawNonce:@"foobar"
                                                                  accessToken:nil];

  if ([appleIDCredential.state isEqualToString:@"signIn"]) {
    [FIRAuth.auth signInWithCredential:credential completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
      if (!error) {
        NSLog(@"%@", authResult.description);
      } else {
        NSLog(@"%@", error.description);
      }
    }];
  } else if ([appleIDCredential.state isEqualToString:@"link"]) {
    [FIRAuth.auth.currentUser linkWithCredential:credential completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
      if (!error) {
        NSLog(@"%@", authResult.description);
      } else {
        NSLog(@"%@", error.description);
      }
    }];
  } else if ([appleIDCredential.state isEqualToString:@"reauth"]) {
    [FIRAuth.auth.currentUser reauthenticateWithCredential:credential completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
      if (!error) {
        NSLog(@"%@", authResult.description);
      } else {
        NSLog(@"%@", error.description);
      }
    }];
  }
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error API_AVAILABLE(ios(13.0)) {
  NSLog(@"%@", error.description);
}

@end

NS_ASSUME_NONNULL_END
