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

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0 || \
    __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_10_14
#import <UserNotifications/UserNotifications.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/// This class is used to automatically populate a notification with an image if it is
/// specified in the notification body via the `image` parameter. Images and other
/// rich content can be populated manually without the use of this class. See the
/// `UNNotificationServiceExtension` type for more details.
__IOS_AVAILABLE(10.0) __OSX_AVAILABLE(10.14) @interface FIRMessagingExtensionHelper : NSObject

/// Call this API to complete your notification content modification. If you like to
/// overwrite some properties of the content instead of using the default payload,
/// make sure to make your customized motification to the content before passing it to
/// this call.
- (void)populateNotificationContent:(UNMutableNotificationContent *)content
                 withContentHandler:(void (^)(UNNotificationContent *_Nonnull))contentHandler;

@end

NS_ASSUME_NONNULL_END
