/*
 * Copyright 2019 Google
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

@protocol OpenURLDelegate <NSObject>

/** @fn handleOpenURL:sourceApplication:
    @brief Handles application:openURL:... methods for @c UIApplicationDelegate .
 */
- (BOOL)handleOpenURL:(NSURL *)url sourceApplication:(nullable NSString *)sourceApplication;

@end

/** @class ApplicationDelegate
    @brief The sample application's delegate.
 */
@interface ApplicationDelegate : UIResponder <UIApplicationDelegate>

/** @property window
    @brief The sample application's @c UIWindow.
 */
@property(strong, nonatomic) UIWindow *window;

/** @fn setOpenURLDelegate:
    @brief Sets the delegate to handle application:openURL:... methods.
    @param openURLDelegate The delegate which is not retained by this method.
 */
+ (void)setOpenURLDelegate:(nullable id<OpenURLDelegate>)openURLDelegate;

@end

NS_ASSUME_NONNULL_END
