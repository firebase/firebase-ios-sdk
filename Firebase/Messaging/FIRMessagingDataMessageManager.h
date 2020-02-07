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

@class GtalkDataMessageStanza;

@class FIRMessagingClient;
@class FIRMessagingConnection;
@class FIRMessagingReceiver;
@class FIRMessagingRmqManager;
@class FIRMessagingSyncMessageManager;

@protocol FIRMessagingDataMessageManagerDelegate <NSObject>

#pragma mark - Downstream Callbacks

/**
 *  Invoked when FIRMessaging receives a downstream message via the MCS connection.
 *  Let's the user know that they have received a new message by invoking the
 *  App's remoteNotification callback.
 *
 *  @param message The downstream message received by the MCS connection.
 */
- (void)didReceiveMessage:(nonnull NSDictionary *)message
           withIdentifier:(nullable NSString *)messageID;

#pragma mark - Upstream Callbacks

/**
 *  Notify the app that FIRMessaging will soon be sending the upstream message requested by the app.
 *
 *  @param messageID The messageId passed in by the app to track this particular message.
 *  @param error     The error in case FIRMessaging cannot send the message upstream.
 */
- (void)willSendDataMessageWithID:(nullable NSString *)messageID error:(nullable NSError *)error;

/**
 *  Notify the app that FIRMessaging did successfully send it's message via the MCS
 *  connection and the message was successfully delivered.
 *
 *  @param messageId The messageId passed in by the app to track this particular
 *                   message.
 */
- (void)didSendDataMessageWithID:(nonnull NSString *)messageId;

#pragma mark - Server Callbacks

/**
 *  Notify the app that FIRMessaging server deleted some messages which exceeded storage limits.
 * This indicates the "deleted_messages" message type we received from the server.
 */
- (void)didDeleteMessagesOnServer;

@end

/**
 * This manages all of the data messages being sent by the client and also the messages that
 * were received from the server.
 */
@interface FIRMessagingDataMessageManager : NSObject

NS_ASSUME_NONNULL_BEGIN

- (instancetype)initWithDelegate:(id<FIRMessagingDataMessageManagerDelegate>)delegate
                          client:(FIRMessagingClient *)client
                     rmq2Manager:(FIRMessagingRmqManager *)rmq2Manager
              syncMessageManager:(FIRMessagingSyncMessageManager *)syncMessageManager;

- (void)setDeviceAuthID:(NSString *)deviceAuthID secretToken:(NSString *)secretToken;

- (void)refreshDelayedMessages;

#pragma mark - Receive

- (nullable NSDictionary *)processPacket:(GtalkDataMessageStanza *)packet;
- (void)didReceiveParsedMessage:(NSDictionary *)message;

#pragma mark - Send

- (void)sendDataMessageStanza:(NSMutableDictionary *)dataMessage;
- (void)didSendDataMessageStanza:(GtalkDataMessageStanza *)message;

- (void)resendMessagesWithConnection:(FIRMessagingConnection *)connection;

NS_ASSUME_NONNULL_END

@end
