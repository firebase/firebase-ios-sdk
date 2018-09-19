/*
 * Copyright 2018 Google
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

#import "GINDurableDeepLinkServiceReceiving+Private.h"

#import <SafariServices/SafariServices.h>

NS_ASSUME_NONNULL_BEGIN

// We should only read the deeplink after install once. We use the following key to store the state
// in the user defaults.
NSString *const kDeepLinkReadInstallKey = @"com.google.appinvite.readDeeplinkAfterInstall";

// If we don't get a deep link in this many seconds
// we give up and release any hidden windows.
// This is just to free up resources. Functionally, the
// hidden window should be ok even if it stays around forever.
NSTimeInterval const kAppInviteReadDeepLinkTimeout = 10.0;

NSString *const kDDLBaseURLParameterBundleId = @"fdl_ios_bundle_id";
NSString *const kDDLBaseURLParameterURLScheme = @"fdl_ios_url_scheme";

// Retrieves the main window of the application.
UIWindow *_Nullable GINGetMainWindow(UIApplication *application) {
  UIWindow *mainWindow = [application keyWindow];
  if (!mainWindow && [application.delegate respondsToSelector:@selector(window)]) {
    mainWindow = [application.delegate window];
  }
  return mainWindow;
}

UIViewController *_Nullable GINGetTopViewControllerFromViewController(
    UIViewController *_Nullable viewController) {
  if (!viewController) {
    return nil;
  }

  if ([viewController isKindOfClass:[UINavigationController class]]) {
    UINavigationController *navController = (UINavigationController *)viewController;
    return GINGetTopViewControllerFromViewController(navController.topViewController);
  } else if ([viewController isKindOfClass:[UITabBarController class]]) {
    UITabBarController *tabBarController = (UITabBarController *)viewController;
    return GINGetTopViewControllerFromViewController(tabBarController.selectedViewController);
  } else if (viewController.presentedViewController) {
    return GINGetTopViewControllerFromViewController(viewController.presentedViewController);
  }

  return viewController;
}

UIViewController *_Nullable GINGetTopViewController(UIApplication *application) {
  UIViewController *viewController = GINGetMainWindow(application).rootViewController;
  return GINGetTopViewControllerFromViewController(viewController);
}

void GINRemoveViewControllerFromHierarchy(UIViewController *_Nullable viewController) {
  if (viewController.parentViewController) {
    [viewController removeFromParentViewController];
  }
  if (viewController.view.superview) {
    [viewController.view removeFromSuperview];
  }
}

@interface GINDurableDeepLinkServiceReceiving () <SFSafariViewControllerDelegate>
@end

@implementation GINDurableDeepLinkServiceReceiving {
  NSTimer *_dismissWindowTimer;
  UIWindow *_hiddenWindow;
}

- (void)checkForPendingDeepLinkWithUserDefaults:(NSUserDefaults *)userDefaults
                                   customScheme:(nullable NSString *)customScheme
                               bundleIdentifier:(nullable NSString *)bundleIdentifier {
  // Make sure this method is called only once after the application was installed.
  BOOL appInviteDeepLinkRead = [userDefaults boolForKey:kDeepLinkReadInstallKey];
  if (appInviteDeepLinkRead) {
    return;
  }

  if (@available(iOS 9.0, *)) {
    if ([SFSafariViewController class]) {
      // Present a hidden SFSafariViewController.
      if (!bundleIdentifier) {
        bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
      }

      if (!customScheme) {
        customScheme = bundleIdentifier;
      }

      NSURLComponents *components = [NSURLComponents new];
      [components setScheme:@"https"];
      [components setHost:@"goo.gl"];
      [components setPath:@"/app/_/deeplink"];
      NSMutableArray *queryItems = [NSMutableArray array];

      // NSURLQueryItem and -setQueryItems: are called only if the system version is greater than
      // iOS 8, so these are safe here.
      [queryItems addObject:[NSURLQueryItem queryItemWithName:kDDLBaseURLParameterBundleId
                                                        value:bundleIdentifier]];
      [queryItems addObject:[NSURLQueryItem queryItemWithName:kDDLBaseURLParameterURLScheme
                                                        value:customScheme]];
      [components setQueryItems:queryItems];
      NSURL *ddlURL = [components URL];

      SFSafariViewController *safariViewController =
          [[SFSafariViewController alloc] initWithURL:ddlURL entersReaderIfAvailable:NO];

      if ([[UIDevice currentDevice].systemVersion integerValue] >= 10) {
        // Since iOS 10, the SFSafariViewController must be in the view controller hierarchy to
        // load.
        safariViewController.view.alpha = 0.05f;
        safariViewController.view.userInteractionEnabled = NO;
        safariViewController.view.frame = CGRectMake(0, 0, 1, 1);
        safariViewController.delegate = self;

        UIViewController *topViewController =
            GINGetTopViewController([UIApplication sharedApplication]);
        if (topViewController) {
          [topViewController addChildViewController:safariViewController];
          [topViewController.view addSubview:safariViewController.view];

          dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                       (int64_t)(kAppInviteReadDeepLinkTimeout * NSEC_PER_SEC)),
                         dispatch_get_main_queue(), ^{
                           GINRemoveViewControllerFromHierarchy(safariViewController);
                         });
        }
      } else {
        // There is no need to set the frame of UIWindow to zero using initWithFrame:CGRectZero
        // since it's hidden behind the main view and has an alpha of 0.
        _hiddenWindow = [[UIWindow alloc] init];
        // Set window level to be well below UIWindowLevelNormal so that app/status views
        // won't be hidden.
        _hiddenWindow.windowLevel = UIWindowLevelNormal - 1000;
        _hiddenWindow.hidden = NO;
        _hiddenWindow.alpha = 0.0;
        _hiddenWindow.rootViewController = [[UIViewController alloc] init];
        [_hiddenWindow.rootViewController addChildViewController:safariViewController];
        [_hiddenWindow.rootViewController.view addSubview:safariViewController.view];

        if (_dismissWindowTimer) {
          [_dismissWindowTimer invalidate];
          _dismissWindowTimer = nil;
        }
        _dismissWindowTimer =
            [NSTimer scheduledTimerWithTimeInterval:kAppInviteReadDeepLinkTimeout
                                             target:self
                                           selector:@selector(dismissHiddenUIWindow)
                                           userInfo:nil
                                            repeats:NO];

        _dismissWindowTimer.tolerance = kAppInviteReadDeepLinkTimeout / 10.0;
      }

      // Make sure we don't call |checkForPendingDeepLink| again.
      [userDefaults setBool:YES forKey:kDeepLinkReadInstallKey];
    }
  }
}

// Set hidden window to nil once any deep link is received.
// If there is no network access at first launch and no deep link is ever received then
// the hidden window will stay around and takes up resources.
- (void)dismissHiddenUIWindow {
  if (_dismissWindowTimer) {
    [_dismissWindowTimer invalidate];
    _dismissWindowTimer = nil;
  }
  _hiddenWindow = nil;
}

- (void)safariViewController:(SFSafariViewController *)controller
      didCompleteInitialLoad:(BOOL)didLoadSuccessfully API_AVAILABLE(ios(9.0)) {
  GINRemoveViewControllerFromHierarchy(controller);
}

- (void)dealloc {
  [self dismissHiddenUIWindow];
}

@end

NS_ASSUME_NONNULL_END
