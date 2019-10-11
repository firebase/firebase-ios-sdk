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

@class FIRMessagingConnection;
@class FIRMessagingDataMessageManager;
@class FIRMessagingRmqManager;

@class GtalkDataMessageStanza;
@class GPBMessage;

typedef void (^FIRMessagingMessageHandler)(NSDictionary *);

typedef NS_ENUM(NSUInteger, FIRMessagingConnectionState) {
  kFIRMessagingConnectionNotConnected = 0,
  kFIRMessagingConnectionConnecting,
  kFIRMessagingConnectionConnected,
  kFIRMessagingConnectionSignedIn,
};

typedef NS_ENUM(NSUInteger, FIRMessagingConnectionCloseReason) {
  kFIRMessagingConnectionCloseReasonSocketDisconnected = 0,
  kFIRMessagingConnectionCloseReasonTimeout,
  kFIRMessagingConnectionCloseReasonUserDisconnect,
};

@protocol FIRMessagingConnectionDelegate<NSObject>

- (void)connection:(FIRMessagingConnection *)fcmConnection
    didCloseForReason:(FIRMessagingConnectionCloseReason)reason;
- (void)didLoginWithConnection:(FIRMessagingConnection *)fcmConnection;
- (void)connectionDidRecieveMessage:(GtalkDataMessageStanza *)message;
/**
 * Called when a stream ACK or a selective ACK are received - this indicates the
 * message has been received by MCS.
 */
- (void)connectionDidReceiveAckForRmqIds:(NSArray *)rmqIds;

@end


/**
 * This class maintains the actual FIRMessaging connection that we use to receive and send messages
 * while the app is in foreground. Once we have a registrationID from the FIRMessaging backend we
 * are able to set up this connection which is used for any further communication with FIRMessaging
 * backend. In case the connection breaks off while the app is still being used we try to rebuild
 * the connection with an exponential backoff.
 *
 * This class also notifies the delegate about the main events happening in the lifcycle of the
 * FIRMessaging connection (read FIRMessagingConnectionDelegate). All of the `on-the-wire`
 * interactions with FIRMessaging are channelled through here.
 */
@interface FIRMessagingConnection : NSObject

@property(nonatomic, readonly, assign) FIRMessagingConnectionState state;
@property(nonatomic, readonly, copy) NSString *host;
@property(nonatomic, readonly, assign) NSUInteger port;
@property(nonatomic, readwrite, weak) id<FIRMessagingConnectionDelegate> delegate;

- (instancetype)initWithAuthID:(NSString *)authId
                         token:(NSString *)token
                          host:(NSString *)host
                          port:(NSUInteger)port
                       runLoop:(NSRunLoop *)runLoop
                   rmq2Manager:(FIRMessagingRmqManager *)rmq2Manager
                    fcmManager:(FIRMessagingDataMessageManager *)dataMessageManager;

- (void)signIn; // connect
- (void)signOut; // disconnect

/**
 * Teardown the FIRMessaging connection and deallocate the resources being held up by the
 * connection.
 */
- (void)teardown;

/**
 * Send proto to the wire. The message will be cached before we try to send so that in case of
 * failure we can send it again later on when we have connection.
 */
- (void)sendProto:(GPBMessage *)proto;

/**
 * Send a message after the currently in progress connection succeeds, otherwise drop it.
 *
 * This should be used for TTL=0 messages that force a reconnect. They shouldn't be persisted
 * in the RMQ, but they should be sent if the reconnect is successful.
 */
- (void)sendOnConnectOrDrop:(GPBMessage *)message;

@end
