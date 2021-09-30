// Copyright 2020 Google LLC
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

// Non-google3 relative import to support building with Xcode.
#import "AppDelegate.h"
#import "ViewControllers/NetworkRequestsViewController.h"
#import "ViewControllers/ScreenTracesViewController.h"
#import "ViewControllers/TracesViewController.h"

#import "FirebaseCore/FirebaseCore.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"

@interface AppDelegate ()

@property(nonatomic, readwrite, strong) UITabBarController *tabBarController;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FPRDelegateSwizzling"];
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FPRNSURLConnection"];
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FPRDiagnosticsLocal"];
  [FIRApp configure];
  [self setupRootViewController];
  return YES;
}

- (void)setupRootViewController {
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.backgroundColor = [UIColor whiteColor];

  UITabBarController *tabBarController = [[UITabBarController alloc] init];
  NSMutableArray *viewControllers = [[NSMutableArray alloc] init];

  TracesViewController *tracesViewController = [[TracesViewController alloc] initWithNibName:nil
                                                                                      bundle:nil];
  tracesViewController.tabBarItem.title = @"Traces";
  tracesViewController.tabBarItem.accessibilityIdentifier = @"TracesTab";

  NetworkRequestsViewController *networkRequestsController =
      [[NetworkRequestsViewController alloc] initWithNibName:nil bundle:nil];
  networkRequestsController.tabBarItem.title = @"Requests";
  networkRequestsController.tabBarItem.accessibilityIdentifier = @"RequestsTab";

  ScreenTracesViewController *screenTracesTestViewController =
      [[ScreenTracesViewController alloc] initAndSetup];
  screenTracesTestViewController.tabBarItem.title = @"Screen Traces";
  screenTracesTestViewController.tabBarItem.accessibilityIdentifier = @"ScreenTracesTab";

  [viewControllers addObject:tracesViewController];
  [viewControllers addObject:networkRequestsController];
  [viewControllers addObject:screenTracesTestViewController];

  tabBarController.viewControllers = viewControllers;

  self.tabBarController = tabBarController;
  self.window.rootViewController = tabBarController;
  [self.window makeKeyAndVisible];
}

@end
