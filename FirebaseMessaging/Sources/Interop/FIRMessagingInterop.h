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
@protocol FIRMessagingInterop <NSObject>

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

/**
 * Asynchronously gets the default FCM registration token.
 *
 * A network connection is required for the method to succeed, and data is sent to the Firebase
 * backend to validate the token. To stop this, see `Messaging.isAutoInitEnabled`,
 * `Messaging.delete(completion:)` and `Installations.delete(completion:)`.
 *
 * @param completion The completion handler to handle the token request.
 */

- (void)tokenWithCompletion:(void (^)(NSString *__nullable token,
                                      NSError *__nullable error))completion;

/**
 * Asynchronously deletes the default FCM registration token.
 *
 * This does not delete all tokens for non-default sender IDs, See `Messaging.delete(completion:)`
 * for deleting all of them. To prevent token auto generation, see `Messaging.isAutoInitEnabled`.
 *
 * @param completion The completion handler to handle the token deletion.
 */

- (void)deleteTokenWithCompletion:(void (^)(NSError *__nullable error))completion;

/**
 *  Retrieves an FCM registration token for a particular Sender ID. This can be used to allow
 *  multiple senders to send notifications to the same device. By providing a different Sender
 *  ID than your default when fetching a token, you can create a new FCM token which you can
 *  give to a different sender. Both tokens will deliver notifications to your device, and you
 *  can revoke a token when you need to.
 *
 *  This registration token is not cached by FIRMessaging. FIRMessaging should have an APNs
 *  token set before calling this to ensure that notifications can be delivered via APNs using
 *  this FCM token. You may re-retrieve the FCM token once you have the APNs token set, to
 *  associate it with the FCM token. The default FCM token is automatically associated with
 *  the APNs token, if the APNs token data is available.
 *
 *  This creates a Firebase Installations ID, if one does not exist, and sends information
 *  about the application and the device to the Firebase backend.
 *
 *  @param senderID The Sender ID for a particular Firebase project.
 *  @param completion The completion handler to handle the token request.
 */
- (void)retrieveFCMTokenForSenderID:(NSString *)senderID
                         completion:(void (^)(NSString *_Nullable FCMToken,
                                              NSError *_Nullable error))completion
    NS_SWIFT_NAME(retrieveFCMToken(forSenderID:completion:));

/**
 * Invalidates an FCM token for a particular Sender ID. That Sender ID cannot no longer send
 * notifications to that FCM token. This does not delete the Firebase Installations ID that may have
 * been created when  generating the token. See `Installations.delete(completion:)`.
 *
 * @param senderID The senderID for a particular Firebase project.
 * @param completion The completion handler to handle the token deletion.
 */
- (void)deleteFCMTokenForSenderID:(NSString *)senderID
                       completion:(void (^)(NSError *_Nullable error))completion
    NS_SWIFT_NAME(deleteFCMToken(forSenderID:completion:));

@end

NS_ASSUME_NONNULL_END
