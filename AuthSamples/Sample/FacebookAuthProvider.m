/** @file FacebookAuthProvider.m
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2016 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import "googlemac/iPhone/Identity/Firebear/Sample/FacebookAuthProvider.h"

#import "googlemac/iPhone/Identity/Firebear/Auth/Source/AuthProviders/Facebook/FIRFacebookAuthProvider.h"
#import "googlemac/iPhone/Identity/Firebear/Sample/ApplicationDelegate.h"
#import "third_party/objective_c/FacebookSDK/FBSDKCoreKit.framework/Headers/FBSDKCoreKit.h"
#import "third_party/objective_c/FacebookSDK/FBSDKLoginKit.framework/Headers/FBSDKLoginKit.h"

/** @var kFacebookAppId
    @brief The App ID for the Facebook SDK.
 */
static NSString *const kFacebookAppID = @"452491954956225";

@interface FacebookAuthProvider () <OpenURLDelegate>
@end

@implementation FacebookAuthProvider {
  FBSDKLoginManager *_loginManager;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _loginManager = [[FBSDKLoginManager alloc] init];
  }
  return self;
}

- (void)getAuthCredentialWithPresentingViewController:(UIViewController *)viewController
                                             callback:(AuthCredentialCallback)callback {
  [self signOut];

  [ApplicationDelegate setOpenURLDelegate:self];
  [FBSDKSettings setAppID:kFacebookAppID];
  [_loginManager logInWithReadPermissions:@[ @"email" ]
                       fromViewController:viewController
                                  handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
    [ApplicationDelegate setOpenURLDelegate:nil];
    if (!error && result.isCancelled) {
      error = [NSError errorWithDomain:@"com.google.FirebearSample" code:-1 userInfo:nil];
    }
    if (error) {
      callback(nil, error);
      return;
    }
    NSString *accessToken = [FBSDKAccessToken currentAccessToken].tokenString;
    callback([FIRFacebookAuthProvider credentialWithAccessToken:accessToken], nil);
  }];
}

- (void)signOut {
  [_loginManager logOut];
}

- (BOOL)handleOpenURL:(NSURL *)URL sourceApplication:(NSString *)sourceApplication {
  return [[FBSDKApplicationDelegate sharedInstance] application:[UIApplication sharedApplication]
                                                        openURL:URL
                                              sourceApplication:sourceApplication
                                                     annotation:nil];
}

@end
