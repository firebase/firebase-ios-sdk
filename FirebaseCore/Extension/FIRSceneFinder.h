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

/**
 * A utility class to help find active UIScene instances on UIApplication.
 */
NS_SWIFT_NAME(SceneFinder)
@interface FIRSceneFinder : NSObject

- (instancetype)init NS_UNAVAILABLE;

/**
 Iterates through the connectedScenes of the specified application instance to find a
 foreground scene whose delegate responds to the specified selector.

 Prioritizes `UISceneActivationStateForegroundActive` scenes over
 `UISceneActivationStateForegroundInactive` scenes. If multiple matching scenes share the same
 activation state, scenes containing a key window (`UIWindow.isKeyWindow`) are prioritized over
 non-key window scenes.

 Note that a scene in the `ForegroundInactive` state is visible and loaded
 in the foreground, but is temporarily not receiving touch events for whatever
 reason (eg; because a system dialog, permission prompt, or notification center
 overlay is covering it). It's totally valid to send events through these scenes,
 so we fall back to checking if these scenes exist if we don't find a better
 alternative (ie; a scene that's in the foreground _and_ active).

 ### Usage Example
 ```objc
 SEL selector = @selector(scene:continueUserActivity:);
 UIScene *targetScene = [FIRSceneFinder
     findForegroundSceneForApplication:self.mainApplication
                      matchingSelector:selector];

 if (targetScene) {
   [targetScene.delegate scene:targetScene continueUserActivity:userActivity];
 }
 ```

 @param application UIApplication instance to search for scenes from.
 @param selector The selector to find a scene delegate for (e.g.
 `@selector(scene:continueUserActivity:)`).
 @return The matching UIScene instance, or nil if no matching scene delegate is found.
 @note This method must be called on the main thread.
 */
+ (nullable UIScene *)findForegroundSceneForApplication:(nullable UIApplication *)application
                                      matchingPredicate:(BOOL(NS_NOESCAPE ^)(UIScene *scene))
                                                            predicate;

/**
 Iterates through the connectedScenes of the specified application instance to find a
 foreground scene matching the specified predicate.

 Prioritizes `UISceneActivationStateForegroundActive` scenes over
 `UISceneActivationStateForegroundInactive` scenes. If multiple matching scenes share the same
 activation state, scenes containing a key window (`UIWindow.isKeyWindow`) are prioritized over
 non-key window scenes.

 Note that a scene in the `ForegroundInactive` state is visible and loaded
 in the foreground, but is temporarily not receiving touch events for whatever
 reason (eg; because a system dialog, permission prompt, or notification center
 overlay is covering it). It's totally valid to interact with these scenes,
 so we fall back to checking if these scenes exist if we don't find a better
 alternative (ie; a scene that's in the foreground _and_ active).

 ### Usage Example
 ```objc
 UIScene *targetScene = [FIRSceneFinder
     findForegroundSceneForApplication:self.mainApplication
                     matchingPredicate:^BOOL(UIScene *scene) {
                       return [scene.session.role
 isEqualToString:UIWindowSceneSessionRoleApplication];
                     }];
 ```

 @param application UIApplication instance to search for scenes from.
 @param predicate The block to evaluate against each scene in connectedScenes.
 @return The matching UIScene instance, or nil if no matching scene is found.
 @note This method must be called on the main thread.
 */
+ (nullable UIScene *)findForegroundSceneForApplication:(nullable UIApplication *)application
                                       matchingSelector:(SEL)selector;

/**
 Iterates through the connectedScenes of the specified application instance to find a
 foreground UIWindowScene.

 Prioritizes `UISceneActivationStateForegroundActive` window scenes over
 `UISceneActivationStateForegroundInactive` window scenes. If multiple matching window scenes share
 the same activation state, window scenes containing a key window (`UIWindow.isKeyWindow`) are
 prioritized over non-key window scenes.

 Note that scenes that are not instances of `UIWindowScene` are ignored.

 ### Usage Example
 ```objc
 UIWindowScene *targetScene = [FIRSceneFinder
     findForegroundWindowSceneForApplication:self.mainApplication];

 if (targetScene) {
   UIInterfaceOrientation orientation = targetScene.interfaceOrientation;
 }
 ```

 @param application UIApplication instance to search for window scenes from.
 @return The matching UIWindowScene instance, or nil if no matching window scene is found.
 @note This method must be called on the main thread.
 */
+ (nullable UIWindowScene *)findForegroundWindowSceneForApplication:
    (nullable UIApplication *)application;

@end

NS_ASSUME_NONNULL_END

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
