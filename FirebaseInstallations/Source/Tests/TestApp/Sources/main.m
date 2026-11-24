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

// A minimal app that hosts the Installations integration tests. A host app gives the tests keychain
// access, which Swift Package Manager test bundles don't have. The tests link FirebaseInstallations
// themselves, so the app doesn't.

#import <UIKit/UIKit.h>

@interface FIRInstallationsTestAppSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, nullable) UIWindow *window;
@end

@implementation FIRInstallationsTestAppSceneDelegate

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

@interface FIRInstallationsTestAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation FIRInstallationsTestAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
  return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                                   options:(UISceneConnectionOptions *)options {
  UISceneConfiguration *configuration =
      [[UISceneConfiguration alloc] initWithName:@"Default"
                                     sessionRole:connectingSceneSession.role];
  configuration.delegateClass = [FIRInstallationsTestAppSceneDelegate class];
  return configuration;
}

@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil,
                             NSStringFromClass([FIRInstallationsTestAppDelegate class]));
  }
}
