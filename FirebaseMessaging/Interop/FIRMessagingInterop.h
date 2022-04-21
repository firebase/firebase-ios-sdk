/*
 * Copyright 2020 Google LLC
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

NS_ASSUME_NONNULL_BEGIN

/** Connector for bridging communication between Firebase SDKs and FIRMessaging API. */
NS_SWIFT_NAME(MessagingInterop) @protocol FIRMessagingInterop

/**
 * The FCM registration token is used to identify this device so that FCM can send notifications to
 * it. It is associated with your APNs token when the APNs token is supplied, so messages sent to
 * the FCM token will be delivered over APNs.
 *
 * The FCM registration token is sometimes refreshed automatically. In your FIRMessaging delegate,
 * the delegate method `messaging:didReceiveRegistrationToken:` will be called once a token is
 * available, or has been refreshed. Typically it should be called once per app start, but
 * may be called more often if the token is invalidated or updated.
 *
 * Once you have an FCM registration token, you should send it to your application server, so it can
 * use the FCM token to send notifications to your device.
 */
@property(nonatomic, readonly, nullable) NSString *FCMToken NS_SWIFT_NAME(fcmToken);

@end

NS_ASSUME_NONNULL_END
