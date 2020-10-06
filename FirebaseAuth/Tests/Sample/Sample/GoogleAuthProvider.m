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
#import "ApplicationDelegate.h"

/** @typedef GoogleSignInCallback
    @brief The type of block invoked when a @c GIDGoogleUser object is ready or an error has
        occurred.
    @param user The Google user if any.
    @param error The error which occurred, if any.
 */
typedef void (^GoogleSignInCallback)(GIDGoogleUser *user, NSError *error);

/** @class GoogleAuthDelegate
    @brief The designated delegate class for Google Sign-In.
 */
@interface GoogleAuthDelegate : NSObject <GIDSignInDelegate, OpenURLDelegate>

/** @fn initWithPresentingViewController:callback:
    @brief Initializes the new instance with the callback.
    @param presentingViewController The view controller to present the UI.
    @param callback A block which is invoked when the sign-in flow finishes. Invoked asynchronously
        on an unspecified thread in the future.
 */
- (instancetype)initWithPresentingViewController:(UIViewController *)presentingViewController
                                        callback:(nullable GoogleSignInCallback)callback;

@end

@implementation GoogleAuthDelegate {
  UIViewController *_presentingViewController;
  GoogleSignInCallback _callback;
}

- (instancetype)initWithPresentingViewController:(UIViewController *)presentingViewController
                                        callback:(nullable GoogleSignInCallback)callback {
  self = [super init];
  if (self) {
    _presentingViewController = presentingViewController;
    _callback = callback;
  }
  return self;
}

- (void)signIn:(GIDSignIn *)signIn
    didSignInForUser:(GIDGoogleUser *)user
           withError:(NSError *)error {
  GoogleSignInCallback callback = _callback;
  _callback = nil;
  if (callback) {
    callback(user, error);
  }
}

- (BOOL)handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
  return [[GIDSignIn sharedInstance] handleURL:url];
}

@end

@implementation GoogleAuthProvider

- (void)getAuthCredentialWithPresentingViewController:(UIViewController *)viewController
                                             callback:(AuthCredentialCallback)callback {
  [self signOut];

  // The delegate needs to be retained.
  __block GoogleAuthDelegate *delegate = [[GoogleAuthDelegate alloc]
      initWithPresentingViewController:viewController
                              callback:^(GIDGoogleUser *user, NSError *error) {
    [ApplicationDelegate setOpenURLDelegate:nil];
    delegate = nil;
    if (error) {
      callback(nil, error);
      return;
    }
    GIDAuthentication *auth = user.authentication;
    FIRAuthCredential *credential = [FIRGoogleAuthProvider credentialWithIDToken:auth.idToken
                                                                     accessToken:auth.accessToken];
    callback(credential, error);
  }];
  GIDSignIn *signIn = [GIDSignIn sharedInstance];
  signIn.clientID = [self googleClientID];
  signIn.shouldFetchBasicProfile = YES;
  signIn.delegate = delegate;
  signIn.presentingViewController = viewController;
  [ApplicationDelegate setOpenURLDelegate:delegate];
  [signIn signIn];
}

- (void)signOut {
  [[GIDSignIn sharedInstance] signOut];
}

- (NSString *)googleClientID {
  return [AppManager app].options.clientID;
}

@end
