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

@interface MainViewController () <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding>

@end

@implementation MainViewController (Apple)

- (StaticContentTableViewSection *)appleAuthSection {
//  if (@available(iOS 13, *)) {
//    __weak typeof(self) weakSelf = self;
//    return [StaticContentTableViewSection sectionWithTitle:@"Apple Auth" cells:@[
//      [StaticContentTableViewCell cellWithTitle:@"Sign in with Apple"
//                                         action:^{ [weakSelf signInWithApple]; }],
//      [StaticContentTableViewCell cellWithTitle:@"Link with Apple"
//                                         action:^{ [weakSelf linkWithApple]; }],
//      [StaticContentTableViewCell cellWithTitle:@"Unlink with Apple"
//                                         action:^{ [weakSelf unlinkFromProvider:@"apple.com" completion:nil]; }],
//      [StaticContentTableViewCell cellWithTitle:@"Reauthenticate with Apple"
//                                         action:^{ [weakSelf reauthenticateWithApple]; }],
//    ]];
//  } else {
//    return [StaticContentTableViewSection sectionWithTitle:@"Apple Auth" cells:@[]];
//  }
  return [StaticContentTableViewSection sectionWithTitle:@"Apple Auth" cells:@[]];
}

- (ASAuthorizationAppleIDRequest *)appleIDRequestWithState:(NSString *)state API_AVAILABLE(ios(13.0)) {
  ASAuthorizationAppleIDRequest *request = [[[ASAuthorizationAppleIDProvider alloc] init] createRequest];
  request.requestedScopes = @[ASAuthorizationScopeEmail, ASAuthorizationScopeFullName];
//  request.nonce = @"REPLACE_ME_WITH_YOUR_NONCE"; //
  request.state = state;
  return request;
}

- (void)signInWithApple API_AVAILABLE(ios(13.0)) {
  ASAuthorizationAppleIDRequest* request = [self appleIDRequestWithState:@"signIn"];

  ASAuthorizationController* controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
  controller.delegate = self;
  controller.presentationContextProvider = self;
  [controller performRequests];
}

- (void)linkWithApple API_AVAILABLE(ios(13.0)) {
  ASAuthorizationAppleIDRequest* request = [self appleIDRequestWithState:@"link"];

  ASAuthorizationController* controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
  controller.delegate = self;
  controller.presentationContextProvider = self;
  [controller performRequests];
}

- (void)reauthenticateWithApple API_AVAILABLE(ios(13.0)) {
  ASAuthorizationAppleIDRequest* request = [self appleIDRequestWithState:@"reauth"];

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
                                                                     rawNonce:@"REPLACE_ME_WITH_YOUR_RAW_NONCE"
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
