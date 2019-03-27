/*
 * Copyright 2017 Google
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/** @protocol FIRAuthAppDelegateHandler
    @brief The protocol to handle app delegate methods.
 */
@protocol FIRAuthAppDelegateHandler <NSObject>

/** @fn setAPNSToken:
    @brief Sets the APNs device token.
    @param token The APNs device token.
 */
- (void)setAPNSToken:(NSData *)token;

/** @fn handleAPNSTokenError:
    @brief Handles APNs device token error.
    @param error The APNs device token error.
 */
- (void)handleAPNSTokenError:(NSError *)error;

/** @fn canHandleNotification:
    @brief Checks whether the notification can be handled by the receiver, and handles it if so.
    @param notification The notification in question, which will be consumed if returns @c YES.
    @return Whether the notification can be (and already has been) handled by the receiver.
 */
- (BOOL)canHandleNotification:(nonnull NSDictionary *)notification;

/** @fn canHandleURL:
    @brief Checks whether the URL can be handled by the receiver, and handles it if so.
    @param url The URL in question, which will be consumed if returns @c YES.
    @return Whether the URL can be (and already has been) handled by the receiver.
 */
- (BOOL)canHandleURL:(nonnull NSURL *)url;

@end

/** @class FIRAuthAppDelegateProxy
    @brief A manager for swizzling @c UIApplicationDelegate methods.
 */
@interface FIRAuthAppDelegateProxy : NSObject

/** @fn initWithApplication
    @brief Initialize the instance with the given @c UIApplication.
    @returns An initialized instance, or @c nil if a proxy cannot be established.
    @remarks This method should only be called from tests if called outside of this class.
 */
- (nullable instancetype)initWithApplication:(nullable UIApplication *)application
    NS_DESIGNATED_INITIALIZER;

/** @fn init
    @brief Call @c sharedInstance to get an instance of this class.
 */
- (instancetype)init NS_UNAVAILABLE;

/** @fn addHandler:
    @brief Adds a handler for UIApplicationDelegate methods.
    @param handler The handler to be added.
 */
- (void)addHandler:(__weak id<FIRAuthAppDelegateHandler>)handler;

/** @fn sharedInstance
    @brief Gets the shared instance of this class.
    @returns The shared instance of this class.
 */
+ (nullable instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
