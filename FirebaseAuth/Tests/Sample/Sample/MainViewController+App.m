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

#import "MainViewController+App.h"

#import "AppManager.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAPNSToken.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAPNSTokenManager.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredential.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredentialManager.h"
#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "MainViewController+Internal.h"
//#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyClientRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyClientResponse.h"
//#import "FirebaseAuth/Sources/Backend/RPC/FIRSendVerificationCodeRequest.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import <FirebaseCore/FIRApp.h>

static NSString *const kTokenRefreshErrorAlertTitle = @"Get Token Error";

static NSString *const kTokenRefreshedAlertTitle = @"Token";

@implementation MainViewController (App)

- (StaticContentTableViewSection *)appSection {
  __weak typeof(self) weakSelf = self;
  return [StaticContentTableViewSection sectionWithTitle:@"APP" cells:@[
    [StaticContentTableViewCell cellWithTitle:@"Get Token"
                                       action:^{ [weakSelf getUserTokenResultWithForce:NO]; }],
    [StaticContentTableViewCell cellWithTitle:@"Get Token Force Refresh"
                                       action:^{ [weakSelf getUserTokenResultWithForce:YES]; }],
    [StaticContentTableViewCell cellWithTitle:@"Add Auth State Change Listener"
                                       action:^{ [weakSelf addAuthStateListener]; }],
    [StaticContentTableViewCell cellWithTitle:@"Remove Last Auth State Change Listener"
                                       action:^{ [weakSelf removeAuthStateListener]; }],
    [StaticContentTableViewCell cellWithTitle:@"Add ID Token Change Listener"
                                       action:^{ [weakSelf addIDTokenListener]; }],
    [StaticContentTableViewCell cellWithTitle:@"Remove Last ID Token Change Listener"
                                       action:^{ [weakSelf removeIDTokenListener]; }],
    [StaticContentTableViewCell cellWithTitle:@"Verify Client"
                                       action:^{ [weakSelf verifyClient]; }],
    [StaticContentTableViewCell cellWithTitle:@"Delete App"
                                       action:^{ [weakSelf deleteApp]; }],
    ]];
}

- (void)getUserTokenResultWithForce:(BOOL)force {
  [[self user] getIDTokenResultForcingRefresh:force
                                   completion:^(FIRAuthTokenResult *_Nullable tokenResult,
                                                NSError *_Nullable error) {
    if (error) {
     [self showMessagePromptWithTitle:kTokenRefreshErrorAlertTitle
                              message:error.localizedDescription
                     showCancelButton:NO
                           completion:nil];
     [self logFailure:@"refresh token failed" error:error];
     return;
    }
    [self logSuccess:@"refresh token succeeded."];
    NSString *message = [tokenResult.claims description];
    [self showMessagePromptWithTitle:kTokenRefreshedAlertTitle
                            message:message
                   showCancelButton:NO
                         completion:nil];
    }];
}

- (void)addAuthStateListener {
  __weak typeof(self) weakSelf = self;
  NSUInteger index = self.authStateDidChangeListeners.count;
  [self log:[NSString stringWithFormat:@"Auth State Did Change Listener #%lu was added.",
             (unsigned long)index]];
  FIRAuthStateDidChangeListenerHandle handle =
  [[AppManager auth] addAuthStateDidChangeListener:^(FIRAuth *_Nonnull auth,
                                                     FIRUser *_Nullable user) {
    [weakSelf log:[NSString stringWithFormat:
                   @"Auth State Did Change Listener #%lu was invoked on user '%@'.",
                   (unsigned long)index, user.uid]];
  }];
  [self.authStateDidChangeListeners addObject:handle];
}

- (void)removeAuthStateListener {
  if (!self.authStateDidChangeListeners.count) {
    [self log:@"No remaining Auth State Did Change Listeners."];
    return;
  }
  NSUInteger index = self.authStateDidChangeListeners.count - 1;
  FIRAuthStateDidChangeListenerHandle handle = self.authStateDidChangeListeners.lastObject;
  [[AppManager auth] removeAuthStateDidChangeListener:handle];
  [self.authStateDidChangeListeners removeObject:handle];
  NSString *logString =
  [NSString stringWithFormat:@"Auth State Did Change Listener #%lu was removed.",
   (unsigned long)index];
  [self log:logString];
}

- (void)addIDTokenListener {
  __weak typeof(self) weakSelf = self;
  NSUInteger index = self.IDTokenDidChangeListeners.count;
  [self log:[NSString stringWithFormat:@"ID Token Did Change Listener #%lu was added.",
             (unsigned long)index]];
  FIRIDTokenDidChangeListenerHandle handle =
  [[AppManager auth] addIDTokenDidChangeListener:^(FIRAuth *_Nonnull auth,
                                                   FIRUser *_Nullable user) {
    [weakSelf log:[NSString stringWithFormat:
                   @"ID Token Did Change Listener #%lu was invoked on user '%@'.",
                   (unsigned long)index, user.uid]];
  }];
  [self.IDTokenDidChangeListeners addObject:handle];
}

- (void)removeIDTokenListener {
  if (!self.IDTokenDidChangeListeners.count) {
    [self log:@"No remaining ID Token Did Change Listeners."];
    return;
  }
  NSUInteger index = self.IDTokenDidChangeListeners.count - 1;
  FIRIDTokenDidChangeListenerHandle handle = self.IDTokenDidChangeListeners.lastObject;
  [[AppManager auth] removeIDTokenDidChangeListener:handle];
  [self.IDTokenDidChangeListeners removeObject:handle];
  NSString *logString =
  [NSString stringWithFormat:@"ID Token Did Change Listener #%lu was removed.",
   (unsigned long)index];
  [self log:logString];
}

- (void)verifyClient {
  [[AppManager auth].tokenManager getTokenWithCallback:^(FIRAuthAPNSToken *_Nullable token,
                                                         NSError *_Nullable error) {
    if (!token) {
      [self logFailure:@"Verify iOS client failed." error:error];
      return;
    }
    FIRVerifyClientRequest *request =
    [[FIRVerifyClientRequest alloc] initWithAppToken:token.string
                                           isSandbox:token.type == FIRAuthAPNSTokenTypeSandbox
                                requestConfiguration:[AppManager auth].requestConfiguration];
    [FIRAuthBackend verifyClient:request callback:^(FIRVerifyClientResponse *_Nullable response,
                                                    NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"Verify iOS client failed." error:error];
        return;
      }
      NSTimeInterval timeout = [response.suggestedTimeOutDate timeIntervalSinceNow];
      [[AppManager auth].appCredentialManager
       didStartVerificationWithReceipt:response.receipt
       timeout:timeout
       callback:^(FIRAuthAppCredential *credential) {
         if (!credential.secret) {
           [self logFailure:@"Failed to receive remote notification to verify app identity."
                      error:error];
           return;
         }
         NSString *testPhoneNumber = @"+16509964692";
         FIRSendVerificationCodeRequest *request =
         [[FIRSendVerificationCodeRequest alloc] initWithPhoneNumber:testPhoneNumber
                                                       appCredential:credential
                                                      reCAPTCHAToken:nil
                                                requestConfiguration:
         [AppManager auth].requestConfiguration];
         [FIRAuthBackend sendVerificationCode:request
                                     callback:^(FIRSendVerificationCodeResponse *_Nullable response,
                                                NSError *_Nullable error) {
           if (error) {
             [self logFailure:@"Verify iOS client failed." error:error];
             return;
           } else {
             [self logSuccess:@"Verify iOS client succeeded."];
             [self showMessagePrompt:@"Verify iOS client succeed."];
           }
         }];
       }];
    }];
  }];
}

- (void)deleteApp {
  [[FIRApp defaultApp] deleteApp:^(BOOL success) {
    [self log:success ? @"App deleted successfully." : @"Failed to delete app."];
  }];
}

@end
