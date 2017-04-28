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

#import "ApplicationDelegate.h"

#import "FIRApp.h"
#import "FirebaseAuth.h"
#import "AuthProviders.h"
#import "MainViewController.h"

#if INTERNAL_GOOGLE3_BUILD
#import "googlemac/iPhone/Identity/Firebear/InternalUtils/FIRSessionFetcherLogging.h"
#import "third_party/firebase/ios/Source/FirebaseCore/Library/Private/FIRLogger.h"
#endif

/** @var gOpenURLDelegate
    @brief The delegate to for application:openURL:... method.
 */
static __weak id<OpenURLDelegate> gOpenURLDelegate;

@implementation ApplicationDelegate

+ (void)setOpenURLDelegate:(nullable id<OpenURLDelegate>)openURLDelegate {
  gOpenURLDelegate = openURLDelegate;
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#if INTERNAL_GOOGLE3_BUILD
  [FIRSessionFetcherLogging setEnabled:YES];
  FIRSetLoggerLevel(FIRLoggerLevelInfo);
#endif

  // Configure the default Firebase application:
  [FIRApp configure];

  // Load and present the UI:
  UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  window.rootViewController =
      [[MainViewController alloc] initWithNibName:NSStringFromClass([MainViewController class])
                                           bundle:nil];
  self.window = window;
  [self.window makeKeyAndVisible];

  return YES;
}

- (BOOL)application:(nonnull UIApplication *)application
            openURL:(nonnull NSURL *)url
            options:(nonnull NSDictionary<NSString *, id> *)options {
  return [self application:application
                   openURL:url
         sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
}

- (BOOL)application:(UIApplication *)application
              openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication
           annotation:(id)annotation {
  if ([gOpenURLDelegate handleOpenURL:url sourceApplication:sourceApplication]) {
    return YES;
  }
  return NO;
}

@end
