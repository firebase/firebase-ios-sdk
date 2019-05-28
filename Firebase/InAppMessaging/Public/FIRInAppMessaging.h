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
 * Note: Firebase InApp Messaging depends on using a Firebase Instance ID & token pair to be able
 * to retrieve FIAM messages defined for the current app instance. By default, Firebase in-app
 * messaging SDK would obtain the ID & token pair on app/SDK startup. As a result of using
 * ID & token pair, some device client data (linked to the instance ID) would be collected and sent
 * over to Firebase backend periodically.
 *
 * The app can tune the default data collection behavior via certain controls. They are listed in
 * descending order below. If a higher-priority setting exists, lower level settings are ignored.
 *
 *   1. Dynamically turn on/off data collection behavior by setting the
 *     `automaticDataCollectionEnabled` property on the `FIRInAppMessaging` instance to true/false
 *      Swift or YES/NO (objective-c).
 *   2. Set `FirebaseInAppMessagingAutomaticDataCollectionEnabled` to false in the app's plist file.
 *   3. Global Firebase data collection setting.
 **/
NS_SWIFT_NAME(InAppMessaging)
@interface FIRInAppMessaging : NSObject
/** @fn inAppMessaging
    @brief Gets the singleton FIRInAppMessaging object constructed from default Firebase App
    settings.
*/
+ (FIRInAppMessaging *)inAppMessaging NS_SWIFT_NAME(inAppMessaging());

/**
 *  Unavailable. Use +inAppMessaging instead.
 */
- (instancetype)init __attribute__((unavailable("Use +inAppMessaging instead.")));

/**
 * A boolean flag that can be used to suppress messaging display at runtime. It's
 * initialized to false at app startup. Once set to true, fiam SDK would stop rendering any
 * new messages until it's set back to false.
 */
@property(nonatomic) BOOL messageDisplaySuppressed;

/**
 * A boolean flag that can be set at runtime to allow/disallow fiam SDK automatically
 * collect user data on app startup. Settings made via this property is persisted across app
 * restarts and has higher priority over FirebaseInAppMessagingAutomaticDataCollectionEnabled
 * flag (if present) in plist file.
 */
@property(nonatomic) BOOL automaticDataCollectionEnabled;

/**
 * This is the display component that will be used by FirebaseInAppMessaging to render messages.
 * If it's nil (the default case when FirebaseIAppMessaging SDK starts), FirebaseInAppMessaging
 * would only perform other non-rendering flows (fetching messages for example). SDK
 * FirebaseInAppMessagingDisplay would set itself as the display component if it's included by
 * the app. Any other custom implementation of FIRInAppMessagingDisplay would need to set this
 * property so that it can be used for rendering fiam message UIs.
 */
@property(nonatomic) id<FIRInAppMessagingDisplay> messageDisplayComponent;

/**
 * Directly requests an in-app message with the given trigger to be shown.
 */
- (void)triggerEvent:(NSString *)eventName;

/**
 * This delegate should be set on the app side to receive message lifecycle events in app runtime.
 */
@property(nonatomic, weak) id<FIRInAppMessagingDisplayDelegate> delegate;

@end
NS_ASSUME_NONNULL_END
