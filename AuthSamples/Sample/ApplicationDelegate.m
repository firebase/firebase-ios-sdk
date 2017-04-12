/** @file ApplicationDelegate.m
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import "googlemac/iPhone/Identity/Firebear/Sample/ApplicationDelegate.h"

#import "googlemac/iPhone/Firebase/Source/FIRApp.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/FirebaseAuth.h"
#import "googlemac/iPhone/Identity/Firebear/Sample/AuthProviders.h"
#import "googlemac/iPhone/Identity/Firebear/Sample/MainViewController.h"

#if INTERNAL_GOOGLE3_BUILD
#import "googlemac/iPhone/Firebase/Source/FIRLogger.h"
#import "googlemac/iPhone/Identity/Firebear/InternalUtils/FIRSessionFetcherLogging.h"
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
