/*
 * Copyright 2026 Google LLC
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

// A blank app that hosts the XCTest bundles in HostedTests.xcodeproj. A host app gives tests an
// app process: keychain access, `UIApplication.sharedApplication` with a delegate, and a main
// bundle. Swift Package Manager test bundles don't have these. Each test bundle links the Firebase
// products it tests, so this app links no Firebase code. Don't add any here: a second copy of an
// SDK in the host would conflict with the copy in the test bundle.

#import <UIKit/UIKit.h>

@interface FIRTestHostSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, nullable) UIWindow *window;
@end

@implementation FIRTestHostSceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions {
  if (![scene isKindOfClass:[UIWindowScene class]]) {
    return;
  }
  self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
  self.window.rootViewController = [[UIViewController alloc] init];
  [self.window makeKeyAndVisible];
}

@end

@interface FIRTestHostAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation FIRTestHostAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
  return YES;
}

// The iOS 27 SDK requires apps to use scenes.
- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                                   options:(UISceneConnectionOptions *)options {
  UISceneConfiguration *configuration =
      [[UISceneConfiguration alloc] initWithName:@"Default"
                                     sessionRole:connectingSceneSession.role];
  configuration.delegateClass = [FIRTestHostSceneDelegate class];
  return configuration;
}

@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([FIRTestHostAppDelegate class]));
  }
}
