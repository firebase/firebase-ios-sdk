/*
 * Copyright 2017 Google
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

#import <TargetConditionals.h>
#if __has_include(<UIKit/UIKit.h>) && !TARGET_OS_WATCH
#import "SharedTestUtilities/FIRSampleAppUtilities.h"

#if __has_include(<SafariServices/SafariServices.h>)
#import <SafariServices/SafariServices.h>
#endif

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

NSString *const kGoogleAppIDPlistKey = @"GOOGLE_APP_ID";
// Dummy plist GOOGLE_APP_ID
NSString *const kDummyGoogleAppID = @"1:123:ios:123abc";
// GitHub Repo URL String
NSString *const kGitHubRepoURLString = @"https://github.com/firebase/firebase-ios-sdk/";
// Alert contents
NSString *const kInvalidPlistAlertTitle = @"GoogleService-Info.plist";
NSString *const kInvalidPlistAlertMessage = @"This sample app needs to be updated with a valid "
                                            @"GoogleService-Info.plist file in order to configure "
                                            @"Firebase.\n\n"
                                            @"Please update the app with a valid plist file, "
                                            @"following the instructions in the Firebase GitHub "
                                            @"repository at: %@";

@implementation FIRSampleAppUtilities

+ (BOOL)appContainsRealServiceInfoPlist {
  static BOOL containsRealServiceInfoPlist = NO;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSBundle *bundle = [NSBundle mainBundle];
    containsRealServiceInfoPlist = [self containsRealServiceInfoPlistInBundle:bundle];
  });
  return containsRealServiceInfoPlist;
}

+ (BOOL)containsRealServiceInfoPlistInBundle:(NSBundle *)bundle {
  NSString *bundlePath = bundle.bundlePath;
  if (!bundlePath.length) {
    return NO;
  }

  NSString *plistFilePath = [bundle pathForResource:kServiceInfoFileName
                                             ofType:kServiceInfoFileType];
  if (!plistFilePath.length) {
    return NO;
  }

  NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistFilePath];
  if (!plist) {
    return NO;
  }

  // Perform a very naive validation by checking to see if the plist has the dummy google app id
  NSString *googleAppID = plist[kGoogleAppIDPlistKey];
  if (!googleAppID.length) {
    return NO;
  }
  if ([googleAppID isEqualToString:kDummyGoogleAppID]) {
    return NO;
  }

  return YES;
}

+ (void)presentAlertForInvalidServiceInfoPlistFromViewController:
    (UIViewController *)viewController {
  NSString *message = [NSString stringWithFormat:kInvalidPlistAlertMessage, kGitHubRepoURLString];
  UIAlertController *alertController =
      [UIAlertController alertControllerWithTitle:kInvalidPlistAlertTitle
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *viewReadmeAction = [UIAlertAction
      actionWithTitle:@"View GitHub"
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *_Nonnull action) {
                NSURL *githubURL = [NSURL URLWithString:kGitHubRepoURLString];
                [FIRSampleAppUtilities navigateToURL:githubURL fromViewController:viewController];
              }];
  [alertController addAction:viewReadmeAction];

  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Close"
                                                         style:UIAlertActionStyleCancel
                                                       handler:nil];
  [alertController addAction:cancelAction];

  [viewController presentViewController:alertController animated:YES completion:nil];
}

+ (void)navigateToURL:(NSURL *)url fromViewController:(UIViewController *)viewController {
#if __has_include(<SafariServices/SafariServices.h>)
  if ([SFSafariViewController class]) {
    SFSafariViewController *safariController = [[SFSafariViewController alloc] initWithURL:url];
    [viewController showDetailViewController:safariController sender:nil];
  } else {
#endif
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
#if __has_include(<SafariServices/SafariServices.h>)
  }
#endif
}

@end
#endif  // __has_include(<UIKit/UIKit.h>) && !TARGET_OS_WATCH
