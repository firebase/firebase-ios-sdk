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

#import <Foundation/Foundation.h>

@class UNMutableNotificationContent, UNNotificationContent;

#if __has_include(<UserNotifications/UserNotifications.h>)
#import <UserNotifications/UserNotifications.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/// This class is used to automatically populate a notification with an image if it is
/// specified in the notification body via the `image` parameter. Images and other
/// rich content can be populated manually without the use of this class. See the
/// `UNNotificationServiceExtension` type for more details.
__OSX_AVAILABLE(10.14) @interface FIRMessagingExtensionHelper : NSObject

/// Call this API to complete your notification content modification. If you like to
/// overwrite some properties of the content instead of using the default payload,
/// make sure to make your customized motification to the content before passing it to
/// this call.
- (void)populateNotificationContent:(UNMutableNotificationContent *)content
                 withContentHandler:(void (^)(UNNotificationContent *_Nonnull))contentHandler;

/// Exports delivery metrics to BigQuery. Call this API to enable logging delivery of alert
/// notification or background notification and export to BigQuery.
/// If you log alert notifications, enable Notification Service Extension and calls this API
/// under `UNNotificationServiceExtension didReceiveNotificationRequest: withContentHandler:`.
/// If you log background notifications, call the API under `UIApplicationDelegate
/// application:didReceiveRemoteNotification:fetchCompletionHandler:`.
- (void)exportDeliveryMetricsToBigQueryWithMessageInfo:(NSDictionary *)info;

@end

NS_ASSUME_NONNULL_END
