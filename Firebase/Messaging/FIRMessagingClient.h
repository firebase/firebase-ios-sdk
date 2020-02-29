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

// Designated initializer
- (instancetype)initWithDelegate:(id<FIRMessagingClientDelegate>)delegate;

- (void)teardown;

- (void)cancelAllRequests;

#pragma mark - FIRMessaging subscribe

/**
 *  Update the subscription associated with the given token and topic.
 *
 *  For a to-be-created subscription we check if the client is already
 *  subscribed to the topic or not. If subscribed we should have the
 *  subscriptionID in the cache and we return from there itself, else we call
 *  the FIRMessaging backend to create a new subscription for the topic for this client.
 *
 *  For delete subscription requests we delete the stored subscription in the
 *  client and then invoke the FIRMessaging backend to delete the existing subscription
 *  completely.
 *
 *  @param token        The token associated with the device.
 *  @param topic        The topic for which the subscription should be updated.
 *  @param options      The options to be passed in to the subscription request.
 *  @param shouldDelete If YES this would delete the subscription from the cache
 *                      and also let the FIRMessaging backend know that we need to delete
 *                      the subscriptionID associated with this topic.
 *                      If NO we try to create a new subscription for the given
 *                      token and topic.
 *  @param handler      The handler to invoke once the subscription request
 *                      finishes.
 */
- (void)updateSubscriptionWithToken:(NSString *)token
                              topic:(NSString *)topic
                            options:(NSDictionary *)options
                       shouldDelete:(BOOL)shouldDelete
                            handler:(FIRMessagingTopicOperationCompletion)handler;



@end
