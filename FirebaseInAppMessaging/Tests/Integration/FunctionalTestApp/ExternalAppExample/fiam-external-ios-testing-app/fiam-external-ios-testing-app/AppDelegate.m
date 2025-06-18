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

@end
