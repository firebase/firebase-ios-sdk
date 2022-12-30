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

#import "FacebookAuthProvider.h"

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>

#import <FirebaseAuth/FIRFacebookAuthProvider.h>
#import "ApplicationDelegate.h"
#import "AuthCredentials.h"

/** @var kFacebookAppId
    @brief The App ID for the Facebook SDK.
 */
static NSString *const kFacebookAppID = KFACEBOOK_APP_ID;

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
  //[FBSDKSettings setAppID:kFacebookAppID];
  [_loginManager logInWithPermissions:@[ @"email" ]
                   fromViewController:viewController
                              handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
    [ApplicationDelegate setOpenURLDelegate:nil];
    if (!error && result.isCancelled) {
      error = [NSError errorWithDomain:@"com.google.FirebaseAuthSample" code:-1 userInfo:nil];
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
