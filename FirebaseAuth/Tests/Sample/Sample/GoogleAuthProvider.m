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

#import "GoogleAuthProvider.h"

#import <GoogleSignIn/GoogleSignIn.h>

#import "AppManager.h"
#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIROptions.h>
#import <FirebaseAuth/FIRGoogleAuthProvider.h>

@implementation GoogleAuthProvider

- (void)getAuthCredentialWithPresentingViewController:(UIViewController *)viewController
                                             callback:(AuthCredentialCallback)callback {
  [self signOut];

  GIDSignIn *signIn = GIDSignIn.sharedInstance;
  GIDConfiguration *config = [[GIDConfiguration alloc] initWithClientID:[self googleClientID]];
  [signIn signInWithConfiguration:config
         presentingViewController:viewController
                         callback:^(GIDGoogleUser * _Nullable user, NSError * _Nullable error) {
    if (error) {
      callback(nil, error);
      return;
    }
    GIDAuthentication *auth = user.authentication;
    FIRAuthCredential *credential = [FIRGoogleAuthProvider credentialWithIDToken:auth.idToken
                                                                     accessToken:auth.accessToken];
    callback(credential, error);
  }];
}

- (void)signOut {
  [GIDSignIn.sharedInstance signOut];
}

- (NSString *)googleClientID {
  return [AppManager app].options.clientID;
}

@end
