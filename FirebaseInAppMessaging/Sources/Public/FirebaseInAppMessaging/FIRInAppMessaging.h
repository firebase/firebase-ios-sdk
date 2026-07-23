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

@class FIRApp;

#import "FIRInAppMessagingRendering.h"

NS_ASSUME_NONNULL_BEGIN
/**
 * The root object for in-app messaging iOS SDK.
 *
 * Note: Firebase In-App Messaging depends on using a Firebase Installation ID and token pair to be
 * able to retrieve messages defined for the current app instance. By default, the Firebase In-App
 * Messaging SDK will obtain the ID and token pair on app/SDK startup. In its default configuration
 * the in-app messaging SDK will send some device and client data (linked to the installation ID)
 * to the Firebase backend periodically.
 *
 * The app can tune the default data collection behavior via certain controls. They are listed in
 * descending order below. If a higher-priority setting exists, lower level settings are ignored.
 *
 *   1. Dynamically turning on or off data collection behavior by setting the
 *     `automaticDataCollectionEnabled` property on the `InAppMessaging` instance to true or false.
 *   2. Setting `FirebaseInAppMessagingAutomaticDataCollectionEnabled` to false in the app's plist
 *      file.
 *   3. Disabling data collection via the global Firebase data collection setting.
 *
 * This class is unavailable on macOS, macOS Catalyst, and watchOS.
 **/

NS_EXTENSION_UNAVAILABLE("Firebase In App Messaging is not supported for iOS extensions.")
API_UNAVAILABLE(macos, watchos)
NS_SWIFT_NAME(InAppMessaging)
@interface FIRInAppMessaging : NSObject
/** @fn inAppMessaging
    @brief Gets the singleton InAppMessaging object constructed from the default Firebase app
    settings.
*/
+ (FIRInAppMessaging *)inAppMessaging NS_SWIFT_NAME(inAppMessaging());

/**
 *  Unavailable. Use +inAppMessaging instead.
 */
- (instancetype)init __attribute__((unavailable("Use +inAppMessaging instead.")));

/**
 * A boolean flag that can be used to suppress messaging display at runtime,
 * initialized to false at app startup. Once set to true, the in-app messaging SDK will stop
 * rendering any new messages until this flag is set back to false.
 */
@property(nonatomic) BOOL messageDisplaySuppressed;

/**
 * A boolean flag that can be set at runtime to allow or disallow
 * collecting user data on app startup. This property is persisted across app
 * restarts and has higher priority over the `FirebaseInAppMessagingAutomaticDataCollectionEnabled`
 * flag (if present) in your app's `Info.plist` file.
 */
@property(nonatomic) BOOL automaticDataCollectionEnabled;

/**
 * This is the display component that will be used by InAppMessaging to render messages.
 * If it's `nil`, InAppMessaging will only perform other non-rendering flows (fetching messages for
 * example). Any custom implementations of `InAppMessagingDisplay` require setting this property in
 * order to take effect.
 */
@property(nonatomic) id<FIRInAppMessagingDisplay> messageDisplayComponent;

/**
 * Directly requests an in-app message with the given trigger to be shown.
 */
- (void)triggerEvent:(NSString *)eventName;

/**
 * This delegate should be set on the app side to receive message lifecycle events.
 */
@property(nonatomic, weak) id<FIRInAppMessagingDisplayDelegate> delegate;

@end
NS_ASSUME_NONNULL_END
