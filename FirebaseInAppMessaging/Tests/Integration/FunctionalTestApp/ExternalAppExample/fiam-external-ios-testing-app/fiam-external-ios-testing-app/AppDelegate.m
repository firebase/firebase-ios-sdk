// Copyright 2017 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "AppDelegate.h"

#import <FirebaseCore/FirebaseCore.h>

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Override point for customization after application launch.
  // uncomment the following line for disabling the auto startup
  // of the sdk
  // [FIRInAppMessaging inAppMessaging].automaticDataCollectionEnabled = @NO;

  [FIROptions defaultOptions].deepLinkURLScheme = @"com.google.InAppMessagingExampleiOS";
  [FIRApp configure];
  return YES;
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<NSString *, id> *)options {
  NSLog(@"called here 1");
  return [self application:app
                   openURL:url
         sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
}

- (BOOL)application:(UIApplication *)application
              openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication
           annotation:(id)annotation {
  FIRDynamicLink *dynamicLink = [[FIRDynamicLinks dynamicLinks] dynamicLinkFromCustomSchemeURL:url];

  NSLog(@"called here with %@", dynamicLink);
  if (dynamicLink) {
    if (dynamicLink.url) {
      // Handle the deep link. For example, show the deep-linked content,
      // apply a promotional offer to the user's account or show customized onboarding view.
      // ...

    } else {
      // Dynamic link has empty deep link. This situation will happens if
      // Firebase Dynamic Links iOS SDK tried to retrieve pending dynamic link,
      // but pending link is not available for this device/App combination.
      // At this point you may display default onboarding view.
    }
    return YES;
  }
  return NO;
}
@end
