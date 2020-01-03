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

#import "MainViewController+OAuth.h"

#import <AuthenticationServices/AuthenticationServices.h>

#import "AppManager.h"
#import "FIROAuthProvider.h"
#import "MainViewController+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController () <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding>

@end

@implementation MainViewController (OAuth)

- (StaticContentTableViewSection *)oAuthSection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"OAuth" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Google"
                                       action:^{ [weakSelf signInGoogleHeadfulLite]; }],
    [StaticContentTableViewCell cellWithTitle:@"Link with Google"
                                       action:^{ [weakSelf linkWithGoogleHeadfulLite]; }],
    [StaticContentTableViewCell cellWithTitle:@"Reauthenticate with Google"
                                       action:^{ [weakSelf reauthenticateWithGoogleHeadfulLite]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Apple"
                                       action:^{ [weakSelf signInWithApple]; }],
    [StaticContentTableViewCell cellWithTitle:@"Link with Apple"
                                       action:^{ [weakSelf linkWithApple]; }],
    [StaticContentTableViewCell cellWithTitle:@"Unlink with Apple"
                                       action:^{ [weakSelf unlinkFromProvider:@"apple.com" completion:nil]; }],
    [StaticContentTableViewCell cellWithTitle:@"Reauthenticate with Apple"
                                       action:^{ [weakSelf reauthenticateWithApple]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Twitter"
                                       action:^{ [weakSelf signInTwitterHeadfulLite]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with GitHub"
                                       action:^{ [weakSelf signInGitHubHeadfulLite]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with GitHub (Access token)"
                                       action:^{ [weakSelf signInWithGitHub]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Microsoft"
                                       action:^{ [weakSelf signInMicrosoftHeadfulLite]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Yahoo"
                                       action:^{ [weakSelf signInYahooHeadfulLite]; }],
    [StaticContentTableViewCell cellWithTitle:@"Sign in with Linkedin"
                                       action:^{ [weakSelf signInLinkedinHeadfulLite]; }],
    ]];
}

- (void)signInGoogleHeadfulLite {
  FIROAuthProvider *provider = self.googleOAuthProvider;
  provider.customParameters = @{
                                @"prompt" : @"consent",
                                };
  provider.scopes = @[ @"profile", @"email", @"https://www.googleapis.com/auth/plus.me" ];
  [self showSpinner:^{
    [[AppManager auth] signInWithProvider:provider
                               UIDelegate:nil
                               completion:^(FIRAuthDataResult *_Nullable authResult,
                                            NSError *_Nullable error) {
       [self hideSpinner:^{
         if (error) {
           [self logFailure:@"sign-in with provider (Google) failed" error:error];
         } else if (authResult.additionalUserInfo) {
           [self logSuccess:[self stringWithAdditionalUserInfo:authResult.additionalUserInfo]];
           if (self.isNewUserToggleOn) {
             NSString *newUserString = authResult.additionalUserInfo.newUser ?
             @"New user" : @"Existing user";
             [self showMessagePromptWithTitle:@"New or Existing"
                                      message:newUserString
                             showCancelButton:NO
                                   completion:nil];
           }
         }
         [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In Error" error:error];
       }];
     }];
  }];
}

- (void)linkWithGoogleHeadfulLite {
  FIROAuthProvider *provider = self.googleOAuthProvider;
  provider.customParameters = @{
                                @"prompt" : @"consent",
                                };
  provider.scopes = @[ @"profile", @"email", @"https://www.googleapis.com/auth/plus.me" ];
  [self showSpinner:^{
    [[AppManager auth].currentUser linkWithProvider:provider
                                         UIDelegate:nil
                                         completion:^(FIRAuthDataResult *_Nullable authResult,
                                                      NSError *_Nullable error) {
     [self hideSpinner:^{
       if (error) {
         [self logFailure:@"Reauthenticate with provider (Google) failed" error:error];
       } else if (authResult.additionalUserInfo) {
         [self logSuccess:[self stringWithAdditionalUserInfo:authResult.additionalUserInfo]];
         if (self.isNewUserToggleOn) {
           NSString *newUserString = authResult.additionalUserInfo.newUser ?
           @"New user" : @"Existing user";
           [self showMessagePromptWithTitle:@"New or Existing"
                                    message:newUserString
                           showCancelButton:NO
                                 completion:nil];
         }
       }
       [self showTypicalUIForUserUpdateResultsWithTitle:@"Link Error" error:error];
     }];
   }];
  }];
}

- (void)reauthenticateWithGoogleHeadfulLite {
  FIROAuthProvider *provider = self.googleOAuthProvider;
  provider.customParameters = @{
                                @"prompt" : @"consent",
                                };
  provider.scopes = @[ @"profile", @"email", @"https://www.googleapis.com/auth/plus.me" ];
  [self showSpinner:^{
    [[AppManager auth].currentUser reauthenticateWithProvider:provider
                                                   UIDelegate:nil
                                                   completion:^(FIRAuthDataResult *_Nullable authResult,
                                                                NSError *_Nullable error) {
     [self hideSpinner:^{
       if (error) {
         [self logFailure:@"Link with provider (Google) failed" error:error];
       } else if (authResult.additionalUserInfo) {
         [self logSuccess:[self stringWithAdditionalUserInfo:authResult.additionalUserInfo]];
         if (self.isNewUserToggleOn) {
           NSString *newUserString = authResult.additionalUserInfo.newUser ?
           @"New user" : @"Existing user";
           [self showMessagePromptWithTitle:@"New or Existing"
                                    message:newUserString
                           showCancelButton:NO
                                 completion:nil];
         }
       }
       [self showTypicalUIForUserUpdateResultsWithTitle:@"Reauthenticate Error" error:error];
     }];
   }];
  }];
}

- (void)signInTwitterHeadfulLite {
  FIROAuthProvider *provider = self.twitterOAuthProvider;
  [self showSpinner:^{
    [provider getCredentialWithUIDelegate:nil completion:^(FIRAuthCredential *_Nullable credential,
                                                           NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with Twitter failed" error:error];
        return;
      }
      [[AppManager auth] signInWithCredential:credential
                                   completion:^(FIRAuthDataResult *_Nullable
                                                authResult,
                                                NSError *_Nullable error) {
         [self hideSpinner:^{
           if (error) {
             [self logFailure:@"sign-in with Twitter (headful-lite) failed" error:error];
             return;
           } else {
             [self logSuccess:@"sign-in with Twitter (headful-lite) succeeded."];
           }
           [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In Error" error:error];
         }];
       }];
    }];
  }];
}

- (void)signInWithGitHub {
  [self showTextInputPromptWithMessage:@"GitHub Access Token:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable accessToken) {
   if (!userPressedOK || !accessToken.length) {
     return;
   }
   FIROAuthCredential *credential =
   [FIROAuthProvider credentialWithProviderID:FIRGitHubAuthProviderID accessToken:accessToken];
   if (credential) {
     [[AppManager auth] signInWithCredential:credential
                                  completion:^(FIRAuthDataResult *_Nullable result,
                                               NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with provider failed" error:error];
      } else {
        [self logSuccess:@"sign-in with provider succeeded."];
      }
      [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In" error:error];
    }];
   }
 }];
}

- (void)signInGitHubHeadfulLite {
  FIROAuthProvider *provider = self.gitHubOAuthProvider;
  [self showSpinner:^{
    [provider getCredentialWithUIDelegate:nil completion:^(FIRAuthCredential *_Nullable credential,
                                                           NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with GitHub failed" error:error];
        return;
      }
      [[AppManager auth] signInWithCredential:credential
                                   completion:^(FIRAuthDataResult *_Nullable
                                                authResult,
                                                NSError *_Nullable error) {
         [self hideSpinner:^{
           if (error) {
             [self logFailure:@"sign-in with GitHub (headful-lite) failed" error:error];
             return;
           } else {
             [self logSuccess:@"sign-in with GitHub (headful-lite) succeeded."];
           }
           [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In Error" error:error];
         }];
       }];
    }];
  }];
}

- (void)signInLinkedinHeadfulLite {
  FIROAuthProvider *provider = self.linkedinOAuthProvider;
  [self showSpinner:^{
    [provider getCredentialWithUIDelegate:nil completion:^(FIRAuthCredential *_Nullable credential,
                                                           NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with Linkedin failed" error:error];
        return;
      }
      [[AppManager auth] signInWithCredential:credential
                                   completion:^(FIRAuthDataResult *_Nullable
                                                authResult,
                                                NSError *_Nullable error) {
         [self hideSpinner:^{
           if (error) {
             [self logFailure:@"sign-in with Linkedin (headful-lite) failed" error:error];
             return;
           } else {
             [self logSuccess:@"sign-in with Linkedin (headful-lite) succeeded."];
           }
           [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In Error" error:error];
         }];
       }];
    }];
  }];
}

- (void)signInMicrosoftHeadfulLite {
  FIROAuthProvider *provider = self.microsoftOAuthProvider;
  provider.customParameters = @{
                                @"prompt" : @"consent",
                                @"login_hint" : @"tu8731@gmail.com",
                                };
  provider.scopes = @[ @"user.readwrite,calendars.read" ];
  [self showSpinner:^{
    [provider getCredentialWithUIDelegate:nil completion:^(FIRAuthCredential *_Nullable credential,
                                                           NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with Microsoft failed" error:error];
        return;
      }
      [[AppManager auth] signInWithCredential:credential
                                   completion:^(FIRAuthDataResult *_Nullable
                                                authResult,
                                                NSError *_Nullable error) {
         [self hideSpinner:^{
           if (error) {
             [self logFailure:@"sign-in with Microsoft failed" error:error];
             return;
           } else {
             [self logSuccess:@"sign-in with Microsoft (headful-lite) succeeded."];
           }
           [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In Error" error:error];
         }];
       }];
    }];
  }];
}

- (void)signInYahooHeadfulLite {
  FIROAuthProvider *provider = self.yahooOAuthProvider;
  [self showSpinner:^{
    [provider getCredentialWithUIDelegate:nil completion:^(FIRAuthCredential *_Nullable credential,
                                                           NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with Yahoo failed" error:error];
        return;
      }
      [[AppManager auth] signInWithCredential:credential
                                   completion:^(FIRAuthDataResult *_Nullable
                                                authResult,
                                                NSError *_Nullable error) {
         [self hideSpinner:^{
           if (error) {
             [self logFailure:@"sign-in with Yahoo (headful-lite) failed" error:error];
             return;
           } else {
             [self logSuccess:@"sign-in with Yahoo (headful-lite) succeeded."];
           }
           [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In Error" error:error];
         }];
       }];
    }];
  }];
}

- (ASAuthorizationAppleIDRequest *)appleIDRequestWithState:(NSString *)state API_AVAILABLE(ios(13.0)) {
  ASAuthorizationAppleIDRequest *request = [[[ASAuthorizationAppleIDProvider alloc] init] createRequest];
  request.requestedScopes = @[ASAuthorizationScopeEmail, ASAuthorizationScopeFullName];
  request.state = state;
  return request;
}

- (void)signInWithApple {
  if (@available(iOS 13, *)) {
    ASAuthorizationAppleIDRequest* request = [self appleIDRequestWithState:@"signIn"];

    ASAuthorizationController* controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
    controller.delegate = self;
    controller.presentationContextProvider = self;
    [controller performRequests];
  }
}

- (void)linkWithApple {
  if (@available(iOS 13, *)) {
    ASAuthorizationAppleIDRequest* request = [self appleIDRequestWithState:@"link"];

    ASAuthorizationController* controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
    controller.delegate = self;
    controller.presentationContextProvider = self;
    [controller performRequests];
  }
}

- (void)reauthenticateWithApple {
  if (@available(iOS 13, *)) {
    ASAuthorizationAppleIDRequest* request = [self appleIDRequestWithState:@"reauth"];

    ASAuthorizationController* controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
    controller.delegate = self;
    controller.presentationContextProvider = self;
    [controller performRequests];
  }
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization API_AVAILABLE(ios(13.0)) {
  ASAuthorizationAppleIDCredential* appleIDCredential = authorization.credential;
  NSString *idToken = [NSString stringWithUTF8String:[appleIDCredential.identityToken bytes]];
  FIROAuthCredential *credential = [FIROAuthProvider credentialWithProviderID:@"apple.com"
                                                                      IDToken:idToken
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
