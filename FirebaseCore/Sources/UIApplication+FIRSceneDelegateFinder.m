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

#import "FirebaseCore/Extension/UIApplication+FIRSceneDelegateFinder.h"

@implementation UIApplication (FIRSceneDelegateFinder)

+ (nullable UIScene *)fir_findForegroundSceneWithDelegateRespondingToSelector:(SEL)selector {
  return [self fir_findForegroundSceneWithDelegateRespondingToSelector:selector onApplication:nil];
}

+ (nullable UIScene *)
    fir_findForegroundSceneWithDelegateRespondingToSelector:(SEL)selector
                                              onApplication:(UIApplication *)application {
  UIApplication *app = application;

  if (!app) {
    return nil;
  }

  UIScene *targetScene = nil;

  for (UIScene *scene in app.connectedScenes) {
    id<UISceneDelegate> sceneDelegate = scene.delegate;
    if ([sceneDelegate respondsToSelector:selector]) {
      if (scene.activationState == UISceneActivationStateForegroundActive) {
        targetScene = scene;
        break;
      } else if (scene.activationState == UISceneActivationStateForegroundInactive) {
        targetScene = scene;
      }
    }
  }

  return targetScene;
}

@end

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
