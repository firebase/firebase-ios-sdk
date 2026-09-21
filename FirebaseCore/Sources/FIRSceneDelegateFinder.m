// Copyright 2026 Google LLC
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION

#import "FirebaseCore/Extension/FIRSceneDelegateFinder.h"

static BOOL FIRSceneHasKeyWindow(UIScene *scene) {
  if ([scene isKindOfClass:[UIWindowScene class]]) {
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    for (UIWindow *window in windowScene.windows) {
      if (window.isKeyWindow) {
        return YES;
      }
    }
  }
  return NO;
}

@implementation FIRSceneDelegateFinder

+ (nullable UIScene *)findForegroundSceneForApplication:(nullable UIApplication *)application
                                      matchingPredicate:(BOOL(NS_NOESCAPE ^)(UIScene *scene))
                                                            predicate {
  NSAssert([NSThread isMainThread],
           @"FIRSceneDelegateFinder findForegroundSceneForApplication:matchingPredicate: must be "
           @"called on the main thread.");

  if (!application || !predicate) {
    return nil;
  }

  UIScene *activeWithoutKeyWindow = nil;
  UIScene *inactiveWithKeyWindow = nil;
  UIScene *inactiveWithoutKeyWindow = nil;

  for (UIScene *scene in application.connectedScenes) {
    if (!predicate(scene)) {
      continue;
    }

    if (scene.activationState != UISceneActivationStateForegroundActive &&
        scene.activationState != UISceneActivationStateForegroundInactive) {
      continue;
    }

    BOOL isKey = FIRSceneHasKeyWindow(scene);

    if (scene.activationState == UISceneActivationStateForegroundActive) {
      if (isKey) {
        // active foreground scene with the key window; best case, so just return early
        return scene;
      } else if (!activeWithoutKeyWindow) {
        activeWithoutKeyWindow = scene;
      }
    } else if (scene.activationState == UISceneActivationStateForegroundInactive) {
      if (isKey && !inactiveWithKeyWindow) {
        inactiveWithKeyWindow = scene;
      } else if (!inactiveWithoutKeyWindow) {
        inactiveWithoutKeyWindow = scene;
      }
    }
  }

  if (activeWithoutKeyWindow) {
    return activeWithoutKeyWindow;
  }
  if (inactiveWithKeyWindow) {
    return inactiveWithKeyWindow;
  }
  return inactiveWithoutKeyWindow;
}

+ (nullable UIScene *)findForegroundSceneForApplication:(nullable UIApplication *)application
                                       matchingSelector:(SEL)selector {
  if (!selector) {
    return nil;
  }

  return [self findForegroundSceneForApplication:application
                               matchingPredicate:^BOOL(UIScene *scene) {
                                 id<UISceneDelegate> sceneDelegate = scene.delegate;
                                 return [sceneDelegate respondsToSelector:selector];
                               }];
}

+ (nullable UIWindowScene *)findForegroundWindowSceneForApplication:
    (nullable UIApplication *)application {
  return (UIWindowScene *)[self findForegroundSceneForApplication:application
                                                matchingPredicate:^BOOL(UIScene *scene) {
                                                  return
                                                      [scene isKindOfClass:[UIWindowScene class]];
                                                }];
}

@end

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
