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

/**
 *  The completion handler invoked once the data connection with FIRMessaging is
 *  established.  The data connection is used to send a continous stream of
 *  data and all the FIRMessaging data notifications arrive through this connection.
 *  Once the connection is established we invoke the callback with `nil` error.
 *  Correspondingly if we get an error while trying to establish a connection
 *  we invoke the handler with an appropriate error object and do an
 *  exponential backoff to try and connect again unless successful.
 *
 *  @param error The error object if any describing why the data connection
 *               to FIRMessaging failed.
 */
typedef void(^FIRMessagingConnectCompletion)(NSError * __nullable error);

/**
 *  Notification sent when the upstream message has been delivered
 *  successfully to the server. The notification object will be the messageID
 *  of the successfully delivered message.
 */
FOUNDATION_EXPORT NSString * __nonnull const FIRMessagingSendSuccessNotification;

/**
 *  Notification sent when the upstream message was failed to be sent to the
 *  server.  The notification object will be the messageID of the failed
 *  message. The userInfo dictionary will contain the relevant error
 *  information for the failure.
 */
FOUNDATION_EXPORT NSString * __nonnull const FIRMessagingSendErrorNotification;

/**
 *  Notification sent when the Firebase messaging server deletes pending
 *  messages due to exceeded storage limits. This may occur, for example, when
 *  the device cannot be reached for an extended period of time.
 *
 *  It is recommended to retrieve any missing messages directly from the
 *  server.
 */
FOUNDATION_EXPORT NSString * __nonnull const FIRMessagingMessagesDeletedNotification;

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
};

/// Status for the downstream message received by the app.
typedef NS_ENUM(NSInteger, FIRMessagingMessageStatus) {
  /// Unknown status.
  FIRMessagingMessageStatusUnknown,
  /// New downstream message received by the app.
  FIRMessagingMessageStatusNew,
};

/// Information about a downstream message received by the app.
@interface FIRMessagingMessageInfo : NSObject

/// The status of the downstream message
@property(nonatomic, readonly, assign) FIRMessagingMessageStatus status;

@end

/**
 * A remote data message received by the app via FCM (not just the APNs interface).
 *
 * This is only for devices running iOS 10 or above. To support devices running iOS 9 or below, use
 * the local and remote notifications handlers defined in UIApplicationDelegate protocol.
 */
@interface FIRMessagingRemoteMessage : NSObject

/// The downstream message received by the application.
@property(nonatomic, readonly, strong, nonnull) NSDictionary *appData;

@end

/**
 * A protocol to receive data message via FCM for devices running iOS 10 or above.
 *
 * To support devices running iOS 9 or below, use the local and remote notifications handlers
 * defined in UIApplicationDelegate protocol.
 */
__IOS_AVAILABLE(10.0)
@protocol FIRMessagingDelegate <NSObject>

/// The callback to handle data message received via FCM for devices running iOS 10 or above.
- (void)applicationReceivedRemoteMessage:(nonnull FIRMessagingRemoteMessage *)remoteMessage;

@end

/**
 *  Firebase Messaging lets you reliably deliver messages at no cost.
 *
 *  To send or receive messages, the app must get a
 *  registration token from FIRInstanceID. This token authorizes an
 *  app server to send messages to an app instance.
 *
 *  In order to receive FIRMessaging messages, declare `application:didReceiveRemoteNotification:`.
 *
 *
 */
@interface FIRMessaging : NSObject

/**
 * Delegate to handle remote data messages received via FCM for devices running iOS 10 or above.
 */
@property(nonatomic, weak, nullable) id<FIRMessagingDelegate> remoteMessageDelegate;

/**
 *  FIRMessaging
 *
 *  @return An instance of FIRMessaging.
 */
+ (nonnull instancetype)messaging NS_SWIFT_NAME(messaging());

/**
 *  Unavailable. Use +messaging instead.
 */
- (nonnull instancetype)init __attribute__((unavailable("Use +messaging instead.")));

#pragma mark - Connect

/**
 *  Create a FIRMessaging data connection which will be used to send the data notifications
 *  sent by your server. It will also be used to send ACKS and other messages based
 *  on the FIRMessaging ACKS and other messages based  on the FIRMessaging protocol.
 *
 *
 *  @param handler  The handler to be invoked once the connection is established.
 *                  If the connection fails we invoke the handler with an
 *                  appropriate error code letting you know why it failed. At
 *                  the same time, FIRMessaging performs exponential backoff to retry
 *                  establishing a connection and invoke the handler when successful.
 */
- (void)connectWithCompletion:(nonnull FIRMessagingConnectCompletion)handler;

/**
 *  Disconnect the current FIRMessaging data connection. This stops any attempts to
 *  connect to FIRMessaging. Calling this on an already disconnected client is a no-op.
 *
 *  Call this before `teardown` when your app is going to the background.
 *  Since the FIRMessaging connection won't be allowed to live when in background it is
 *  prudent to close the connection.
 */
- (void)disconnect;

#pragma mark - Topics

/**
 *  Asynchronously subscribes to a topic.
 *
 *  @param topic The name of the topic, for example, @"sports".
 */
- (void)subscribeToTopic:(nonnull NSString *)topic;

/**
 *  Asynchronously unsubscribe from a topic.
 *
 *  @param topic The name of the topic, for example @"sports".
 */
- (void)unsubscribeFromTopic:(nonnull NSString *)topic;

#pragma mark - Upstream

/**
 *  Sends an upstream ("device to cloud") message.
 *
 *  The message is queued if we don't have an active connection.
 *  You can only use the upstream feature if your FCM implementation
 *  uses the XMPP server protocol.
 *
 *  @param message      Key/Value pairs to be sent. Values must be String, any
 *                      other type will be ignored.
 *  @param receiver     A string identifying the receiver of the message. For FCM
 *                      project IDs the value is `SENDER_ID@gcm.googleapis.com`.
 *  @param messageID    The ID of the message. This is generated by the application. It
 *                      must be unique for each message generated by this application.
 *                      It allows error callbacks and debugging, to uniquely identify
 *                      each message.
 *  @param ttl          The time to live for the message. In case we aren't able to
 *                      send the message before the TTL expires we will send you a
 *                      callback. If 0, we'll attempt to send immediately and return
 *                      an error if we're not connected.  Otherwise, the message will
 *                      be queued.  As for server-side messages, we don't return an error
 *                      if the message has been dropped because of TTL; this can happen
 *                      on the server side, and it would require extra communication.
 */
- (void)sendMessage:(nonnull NSDictionary *)message
                 to:(nonnull NSString *)receiver
      withMessageID:(nonnull NSString *)messageID
         timeToLive:(int64_t)ttl;

#pragma mark - Analytics

/**
 *  Use this to track message delivery and analytics for messages, typically
 *  when you receive a notification in `application:didReceiveRemoteNotification:`.
 *  However, you only need to call this if you set the `FirebaseAppDelegateProxyEnabled`
 *  flag to NO in your Info.plist. If `FirebaseAppDelegateProxyEnabled` is either missing
 *  or set to YES in your Info.plist, the library will call this automatically.
 *
 *  @param message The downstream message received by the application.
 *
 *  @return Information about the downstream message.
 */
- (nonnull FIRMessagingMessageInfo *)appDidReceiveMessage:(nonnull NSDictionary *)message;

@end
