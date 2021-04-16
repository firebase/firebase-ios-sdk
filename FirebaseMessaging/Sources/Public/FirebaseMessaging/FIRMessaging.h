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

NS_ASSUME_NONNULL_BEGIN

/**
 *  @related FIRMessaging
 *
 *  The completion handler invoked when the registration token returns.
 *  If the call fails we return the appropriate `error code`, described by
 *  `FIRMessagingError`.
 *
 *  @param FCMToken  The valid registration token returned by FCM.
 *  @param error     The error describing why a token request failed. The error code
 *                   will match a value from the FIRMessagingError enumeration.
 */
typedef void (^FIRMessagingFCMTokenFetchCompletion)(NSString *_Nullable FCMToken,
                                                    NSError *_Nullable error)
    NS_SWIFT_NAME(MessagingFCMTokenFetchCompletion);

/**
 *  @related FIRMessaging
 *
 *  The completion handler invoked when the registration token deletion request is
 *  completed. If the call fails we return the appropriate `error code`, described
 *  by `FIRMessagingError`.
 *
 *  @param error The error describing why a token deletion failed. The error code
 *               will match a value from the FIRMessagingError enumeration.
 */
typedef void (^FIRMessagingDeleteFCMTokenCompletion)(NSError *_Nullable error)
    NS_SWIFT_NAME(MessagingDeleteFCMTokenCompletion);

/**
 *  Callback to invoke once the HTTP call to FIRMessaging backend for updating
 *  subscription finishes.
 *
 *  @param error  The error which occurred while updating the subscription topic
 *                on the FIRMessaging server. This will be nil in case the operation
 *                was successful, or if the operation was cancelled.
 */
typedef void (^FIRMessagingTopicOperationCompletion)(NSError *_Nullable error);

/**
 *  Notification sent when the FCM registration token has been refreshed. Please use the
 *  FIRMessaging delegate method `messaging:didReceiveRegistrationToken:` to receive current and
 *  updated tokens.
 */
// clang-format off
// clang-format12 merges the next two lines.
FOUNDATION_EXPORT const NSNotificationName FIRMessagingRegistrationTokenRefreshedNotification
    NS_SWIFT_NAME(MessagingRegistrationTokenRefreshed);
// clang-format on

/**
 *  @enum FIRMessagingError
 */
typedef NS_ENUM(NSUInteger, FIRMessagingError) {
  /// Unknown error.
  FIRMessagingErrorUnknown = 0,

  /// FIRMessaging couldn't validate request from this client.
  FIRMessagingErrorAuthentication = 1,

  /// InstanceID service cannot be accessed.
  FIRMessagingErrorNoAccess = 2,

  /// Request to InstanceID backend timed out.
  FIRMessagingErrorTimeout = 3,

  /// No network available to reach the servers.
  FIRMessagingErrorNetwork = 4,

  /// Another similar operation in progress, bailing this one.
  FIRMessagingErrorOperationInProgress = 5,

  /// Some parameters of the request were invalid.
  FIRMessagingErrorInvalidRequest = 7,

  /// Topic name is invalid for subscription/unsubscription.
  FIRMessagingErrorInvalidTopicName = 8,

} NS_SWIFT_NAME(MessagingError);

/// Status for the downstream message received by the app.
typedef NS_ENUM(NSInteger, FIRMessagingMessageStatus) {
  /// Unknown status.
  FIRMessagingMessageStatusUnknown,
  /// New downstream message received by the app.
  FIRMessagingMessageStatusNew,
} NS_SWIFT_NAME(MessagingMessageStatus);

/**
 *  The APNs token type for the app. If the token type is set to `UNKNOWN`
 *  Firebase Messaging will implicitly try to figure out what the actual token type
 *  is from the provisioning profile.
 *  Unless you really need to specify the type, you should use the `APNSToken`
 *  property instead.
 */
typedef NS_ENUM(NSInteger, FIRMessagingAPNSTokenType) {
  /// Unknown token type.
  FIRMessagingAPNSTokenTypeUnknown,
  /// Sandbox token type.
  FIRMessagingAPNSTokenTypeSandbox,
  /// Production token type.
  FIRMessagingAPNSTokenTypeProd,
} NS_SWIFT_NAME(MessagingAPNSTokenType);

/// Information about a downstream message received by the app.
NS_SWIFT_NAME(MessagingMessageInfo)
@interface FIRMessagingMessageInfo : NSObject

/// The status of the downstream message
@property(nonatomic, readonly, assign) FIRMessagingMessageStatus status;

@end

@class FIRMessaging;
@class FIRMessagingExtensionHelper;

/**
 * A protocol to handle token update or data message delivery from FCM.
 *
 */
NS_SWIFT_NAME(MessagingDelegate)
@protocol FIRMessagingDelegate <NSObject>

@optional
/// This method will be called once a token is available, or has been refreshed. Typically it
/// will be called once per app start, but may be called more often, if token is invalidated or
/// updated. In this method, you should perform operations such as:
///
/// * Uploading the FCM token to your application server, so targeted notifications can be sent.
///
/// * Subscribing to any topics.
- (void)messaging:(FIRMessaging *)messaging
    didReceiveRegistrationToken:(nullable NSString *)fcmToken
    NS_SWIFT_NAME(messaging(_:didReceiveRegistrationToken:));
@end

/**
 *  Firebase Messaging lets you reliably deliver messages at no cost.
 *
 *  To send or receive messages, the app must get a
 *  registration token from FIRInstanceID. This token authorizes an
 *  app server to send messages to an app instance.
 *
 *  In order to receive FIRMessaging messages, declare
 *  `application:didReceiveRemoteNotification::fetchCompletionHandler:`.
 */
NS_SWIFT_NAME(Messaging)
@interface FIRMessaging : NSObject

/**
 * Delegate to handle FCM token refreshes, and remote data messages received via FCM direct channel.
 */
@property(nonatomic, weak, nullable) id<FIRMessagingDelegate> delegate;

/**
 *  FIRMessaging
 *
 *  @return An instance of FIRMessaging.
 */
+ (instancetype)messaging NS_SWIFT_NAME(messaging());

/**
 * FIRMessagingExtensionHelper
 *
 * Use FIRMessagingExtensionHelper to populate rich UI contents for your notifications.
 * e.g. If an image URL is set in your notification payload or on the console, call
 * FIRMessagingExtensionHelper API to render it on your notification.
 *
 * @return An instance of FIRMessagingExtensionHelper that handles the extensions API.
 */
+ (FIRMessagingExtensionHelper *)extensionHelper NS_SWIFT_NAME(serviceExtension())
    NS_AVAILABLE(10.14, 10.0);

/**
 *  Unavailable. Use +messaging instead.
 */
- (instancetype)init __attribute__((unavailable("Use +messaging instead.")));

#pragma mark - APNs

/**
 *  This property is used to set the APNs Token received by the application delegate.
 *
 *  FIRMessaging uses method swizzling to ensure that the APNs token is set
 *  automatically. However, if you have disabled swizzling by setting
 *  `FirebaseAppDelegateProxyEnabled` to `NO` in your app's
 *  Info.plist, you should manually set the APNs token in your application
 *  delegate's `-application:didRegisterForRemoteNotificationsWithDeviceToken:`
 *  method.
 *
 *  If you would like to set the type of the APNs token, rather than relying on
 *  automatic detection, see: `-setAPNSToken:type:`.
 */
@property(nonatomic, copy, nullable) NSData *APNSToken NS_SWIFT_NAME(apnsToken);

/**
 *  Set APNs token for the application. This APNs token will be used to register
 *  with Firebase Messaging using `FCMToken` or
 *  `tokenWithAuthorizedEntity:scope:options:handler`.
 *
 *  @param apnsToken The APNs token for the application.
 *  @param type  The type of APNs token. Debug builds should use
 *  FIRMessagingAPNSTokenTypeSandbox. Alternatively, you can supply
 *  FIRMessagingAPNSTokenTypeUnknown to have the type automatically
 *  detected based on your provisioning profile.
 */
- (void)setAPNSToken:(NSData *)apnsToken type:(FIRMessagingAPNSTokenType)type;

#pragma mark - FCM Tokens

/**
 * Is Firebase Messaging token auto generation enabled?  If this flag is disabled, Firebase
 * Messaging will not generate token automatically for message delivery.
 *
 * If this flag is disabled, Firebase Messaging does not generate new tokens automatically for
 * message delivery. If this flag is enabled, FCM generates a registration token on application
 * start when there is no existing valid token and periodically refreshes the token and sends
 * data to Firebase backend.
 *
 * This setting is persisted, and is applied on future invocations of your application.  Once
 * explicitly set, it overrides any settings in your Info.plist.
 *
 * By default, FCM automatic initialization is enabled.  If you need to change the
 * default (for example, because you want to prompt the user before getting token)
 * set FirebaseMessagingAutoInitEnabled to false in your application's Info.plist.
 */
@property(nonatomic, assign, getter=isAutoInitEnabled) BOOL autoInitEnabled;

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
 * This creates a Firebase Installations ID, if one does not exist, and sends information about the
 * application and the device to the Firebase backend. A network connection is required for the
 * method to succeed. To stop this, see `Messaging.isAutoInitEnabled`,
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
 * been created when generating the token. See `Installations.delete(completion:)`.
 *
 * @param senderID The senderID for a particular Firebase project.
 * @param completion The completion handler to handle the token deletion.
 */
- (void)deleteFCMTokenForSenderID:(NSString *)senderID
                       completion:(void (^)(NSError *_Nullable error))completion
    NS_SWIFT_NAME(deleteFCMToken(forSenderID:completion:));

#pragma mark - Topics

/**
 * Asynchronously subscribes to a topic. This uses the default FCM registration token to identify
 * the app instance and periodically sends data to the Firebase backend. To stop this, see
 * `Messaging.delete(completion:)` and `Installations.delete(completion:)`.
 *
 * @param topic The name of the topic, for example, @"sports".
 */
- (void)subscribeToTopic:(NSString *)topic NS_SWIFT_NAME(subscribe(toTopic:));

/**
 * Asynchronously subscribe to the provided topic, retrying on failure. This uses the default FCM
 * registration token to identify the app instance and periodically sends data to the Firebase
 * backend. To stop this, see `Messaging.delete(completion:)` and
 * `Installations.delete(completion:)`.
 *
 * @param topic       The topic name to subscribe to, for example, @"sports".
 * @param completion  The completion that is invoked once the subscribe call ends.
 *                     In case of success, nil error is returned. Otherwise, an
 *                     appropriate error object is returned.
 */
- (void)subscribeToTopic:(nonnull NSString *)topic
              completion:(void (^_Nullable)(NSError *_Nullable error))completion;

/**
 * Asynchronously unsubscribe from a topic.  This uses a FCM Token
 * to identify the app instance and periodically sends data to the Firebase backend. To stop this,
 * see `Messaging.delete(completion:)` and `Installations.delete(completion:)`.
 *
 * @param topic The name of the topic, for example @"sports".
 */
- (void)unsubscribeFromTopic:(NSString *)topic NS_SWIFT_NAME(unsubscribe(fromTopic:));

/**
 * Asynchronously unsubscribe from the provided topic, retrying on failure. This uses a FCM Token
 * to identify the app instance and periodically sends data to the Firebase backend. To stop this,
 * see `Messaging.delete(completion:)` and `Installations.delete(completion:)`.
 *
 *  @param topic       The topic name to unsubscribe from, for example @"sports".
 *  @param completion  The completion that is invoked once the unsubscribe call ends.
 *                     In case of success, nil error is returned. Otherwise, an
 *                     appropriate error object is returned.
 */
- (void)unsubscribeFromTopic:(nonnull NSString *)topic
                  completion:(void (^_Nullable)(NSError *_Nullable error))completion;

#pragma mark - Analytics

/**
 *  Use this to track message delivery and analytics for messages, typically
 *  when you receive a notification in `application:didReceiveRemoteNotification:`.
 *  However, you only need to call this if you set the `FirebaseAppDelegateProxyEnabled`
 *  flag to `NO` in your Info.plist. If `FirebaseAppDelegateProxyEnabled` is either missing
 *  or set to `YES` in your Info.plist, the library will call this automatically.
 *
 *  @param message The downstream message received by the application.
 *
 *  @return Information about the downstream message.
 */
- (FIRMessagingMessageInfo *)appDidReceiveMessage:(NSDictionary *)message;

#pragma mark - GDPR
/**
 * Deletes all the tokens and checkin data of the Firebase project and related data on the server
 * side. A network connection is required for the method to succeed.
 *
 * This does not delete the Firebase Installations ID. See `Installations.delete(completion:)`.
 * To prevent token auto generation, see `Messaging.isAutoInitEnabled`.
 *
 * @param completion A completion handler which is invoked when the operation completes. `error ==
 * nil` indicates success.
 */
- (void)deleteDataWithCompletion:(void (^)(NSError *__nullable error))completion;

@end

NS_ASSUME_NONNULL_END
