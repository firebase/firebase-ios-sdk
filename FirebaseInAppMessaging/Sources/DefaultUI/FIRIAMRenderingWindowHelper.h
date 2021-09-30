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

NS_ASSUME_NONNULL_BEGIN
/**
 * To avoid the risk of hijacking the app's existing view transition flow, we render in-app message
 * views in a new top-level UIWindow instead of presenting them from app's existing UIWindow.
 * The caller is supposed to set the rootViewController to be the appropriate view controller
 * for the in-app message and call setHidden:NO to make it really visible.
 */
NS_EXTENSION_UNAVAILABLE("Firebase In App Messaging is not supported for iOS extensions.")
@interface FIRIAMRenderingWindowHelper : NSObject

/// Returns the singleton `UIWindow` object used for rendering IAM views that block
/// user interactions with underlying content.
+ (UIWindow *)windowForBlockingView;

/// Returns the singleton `UIWindow` object used for rendering IAM views that don't block
/// user interactions with underlying content.
+ (UIWindow *)windowForNonBlockingView;

@end
NS_ASSUME_NONNULL_END
