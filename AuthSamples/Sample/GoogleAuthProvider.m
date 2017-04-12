/** @file GoogleAuthProvider.m
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2016 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import "googlemac/iPhone/Identity/Firebear/Sample/GoogleAuthProvider.h"

#import "googlemac/iPhone/Firebase/Source/FIRApp.h"
#import "googlemac/iPhone/Firebase/Source/FIROptions.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/AuthProviders/Google/FIRGoogleAuthProvider.h"
#import "googlemac/iPhone/Identity/Firebear/Sample/ApplicationDelegate.h"
#import "googlemac/iPhone/Identity/SDK/SignIn/GoogleSignIn.h"

/** @typedef GoogleSignInCallback
    @brief The type of block invoked when a @c GIDGoogleUser object is ready or an error has
        occurred.
    @param user The Google user if any.
    @param error The error which occurred, if any.
 */
typedef void (^GoogleSignInCallback)(GIDGoogleUser *user, NSError *error);

/** @class GoogleAuthDelegate
    @brief The designated delegate class for Google Sign-In.
    @param callback A block which is invoked when the sign-in flow finishes. Invoked asynchronously
        on an unspecified thread in the future.
 */
@interface GoogleAuthDelegate : NSObject <GIDSignInDelegate, GIDSignInUIDelegate, OpenURLDelegate>

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

- (void)signIn:(GIDSignIn *)signIn presentViewController:(UIViewController *)viewController {
  [_presentingViewController presentViewController:viewController animated:YES completion:nil];
}

- (void)signIn:(GIDSignIn *)signIn dismissViewController:(UIViewController *)viewController {
  [_presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
  return [[GIDSignIn sharedInstance] handleURL:url
                             sourceApplication:sourceApplication
                                    annotation:nil];
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
  signIn.uiDelegate = delegate;
  [ApplicationDelegate setOpenURLDelegate:delegate];
  [signIn signIn];
}

- (void)signOut {
  [[GIDSignIn sharedInstance] signOut];
}

- (NSString *)googleClientID {
  return [FIRApp defaultApp].options.clientID;
}

@end
