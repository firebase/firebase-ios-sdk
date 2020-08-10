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

#import <FirebaseMessaging/FIRMessaging.h>

@class GULReachabilityChecker;
@class GPBMessage;

@class FIRMessagingConnection;
@class FIRMessagingDataMessageManager;
@class FIRMessagingRmqManager;

/**
 *  Callback to handle MCS connection requests.
 *
 *  @param error The error object if any while trying to connect with MCS else nil.
 */
typedef void (^FIRMessagingConnectCompletionHandler)(NSError *error);

@protocol FIRMessagingClientDelegate <NSObject>

@end

/**
 * The client handles the subscribe/unsubscribe for an unregistered senderID
 * and device. It also manages the FIRMessaging data connection, the exponential backoff
 * algorithm in case of registration failures, sign in failures and unregister
 * failures. It also handles the reconnect logic if the FIRMessaging connection is
 * broken off by some error during an active session.
 */
@interface FIRMessagingClient : NSObject

@property(nonatomic, readonly, strong) FIRMessagingConnection *connection;
@property(nonatomic, readwrite, weak) FIRMessagingDataMessageManager *dataMessageManager;

// Designated initializer
- (instancetype)initWithDelegate:(id<FIRMessagingClientDelegate>)delegate
                    reachability:(GULReachabilityChecker *)reachability
                     rmq2Manager:(FIRMessagingRmqManager *)rmq2Manager;

- (void)teardown;

#pragma mark - MCS Connection

/**
 *  Create a MCS connection.
 *
 *  @param handler  The handler to be invokend once the connection is setup. If
 *                  setting up the connection fails we invoke the handler with
 *                  an appropriate error object.
 */
- (void)connectWithHandler:(FIRMessagingConnectCompletionHandler)handler;

/**
 *  Disconnect the current MCS connection. If there is no valid connection this
 *  should be a NO-OP.
 */
- (void)disconnect;

#pragma mark - MCS Connection State

/**
 *  If we are connected to MCS or not. This doesn't take into account the fact if
 *  the client has been signed in(verified) by MCS.
 *
 *  @return YES if we are signed in or connecting and trying to sign-in else NO.
 */
@property(nonatomic, readonly) BOOL isConnected;

/**
 *  If we have an active MCS connection
 *
 *  @return YES if we have an active MCS connection else NO.
 */
@property(nonatomic, readonly) BOOL isConnectionActive;

/**
 *  If we should be connected to MCS
 *
 *  @return YES if we have attempted a connection and not requested to disconect.
 */
@property(nonatomic, readonly) BOOL shouldStayConnected;

/**
 *  Schedule a retry to connect to MCS. If `immediately` is `YES` try to
 *  schedule a retry now else retry with some delay.
 *
 *  @param immediately Should retry right now.
 */
- (void)retryConnectionImmediately:(BOOL)immediately;

#pragma mark - Messages

/**
 *  Send a message over the MCS connection.
 *
 *  @param message Message to be sent.
 */
- (void)sendMessage:(GPBMessage *)message;

/**
 *  Send message if we have an active MCS connection. If not cache the  message
 *  for this session and in case we are able to re-establish the connection try
 *  again else drop it. This should only be used for TTL=0 messages for now.
 *
 *  @param message Message to be sent.
 */
- (void)sendOnConnectOrDrop:(GPBMessage *)message;

@end
