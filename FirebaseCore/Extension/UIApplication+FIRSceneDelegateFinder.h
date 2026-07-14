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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIApplication (FIRSceneDelegateFinder)

/**
 Iterates through the connectedScenes of the specified application instance to find a
 foreground scene whose delegate responds to the specified selector. Prioritizes
 `UISceneActivationStateForegroundActive` scenes over `UISceneActivationStateForegroundInactive`
 scenes.

 Note that a scene in the `ForegroundInactive` state is visible and loaded
 in the foreground, but is temporarily not receiving touch events for whatever
 reason (eg; because a system dialog, permission prompt, or notification center
 overlay is covering it). It's totally valid to send events through these scenes,
 so we fall back to checking if these scenes exist if we don't find a better
 alternative (ie; a scene that's in the foregound _and_ active).

 ### Usage Example
 ```objc
 SEL selector = @selector(scene:continueUserActivity:);
 UIScene *targetScene = [UIApplication
    fir_findForegroundSceneWithDelegateRespondingToSelector:selector
                                            onApplication:self.mainApplication];

 if (targetScene) {
  [targetScene.delegate scene:targetScene continueUserActivity:userActivity];
 }                               
 ```

 @param selector The selector to find a scene delegate for (e.g.
 `@selector(scene:continueUserActivity:)`).
 @param application UIApplication instance to search for scenes from.
 @return The matching UIScene instance, or nil if no matching scene delegate is found.
 */
+ (nullable UIScene *)
    fir_findForegroundSceneWithDelegateRespondingToSelector:(SEL)selector
                                              onApplication:(nullable UIApplication *)application;

@end

NS_ASSUME_NONNULL_END

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
