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

#import <UIKit/UIKit.h>

#import "GINDurableDeepLinkServiceReceiving.h"

NS_ASSUME_NONNULL_BEGIN

/** These methods are exposed for testing purposes. */
@interface GINDurableDeepLinkServiceReceiving (Private)

/** Retrieves the main window of the application. */
UIWindow *_Nullable GINGetMainWindow(UIApplication *application);

/** Retrieves the topmost view controller presented from the given view controller. */
UIViewController *_Nullable GINGetTopViewControllerFromViewController(
    UIViewController *_Nullable viewController);

/** Retrieves the topmost view controller in the view controller hierarchy. */
UIViewController *_Nullable GINGetTopViewController(UIApplication *application);

/** Removes the view controller from the view controller hierarchy. */
void GINRemoveViewControllerFromHierarchy(UIViewController *_Nullable viewController);

@end

NS_ASSUME_NONNULL_END
