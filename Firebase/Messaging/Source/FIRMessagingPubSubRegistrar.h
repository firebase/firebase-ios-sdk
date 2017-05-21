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

#import "FIRMessagingTopicOperation.h"

@class FIRMessagingCheckinService;

@interface FIRMessagingPubSubRegistrar : NSObject

/**
 *  Designated Initializer.
 *
 *  @param checkinService The checkin service used to register with Checkin
 *                        server.
 *
 *  @return A new FIRMessagingPubSubRegistrar instance used to subscribe/unsubscribe.
 */
- (instancetype)initWithCheckinService:(FIRMessagingCheckinService *)checkinService;

/**
 *  Stops all the subscription requests going on in parallel. This would
 *  invalidate all the handlers associated with the subscription requests.
 */
- (void)stopAllSubscriptionRequests;

/**
 *  Update subscription status for a given topic with FIRMessaging's backend.
 *
 *  @param topic        The topic to subscribe to.
 *  @param token        The registration token to be used.
 *  @param options      The options to be passed in during subscription request.
 *  @param shouldDelete NO if the subscription is being added else YES if being
 *                      removed.
 *  @param handler      The handler invoked once the update subscription request
 *                      finishes.
 */
- (void)updateSubscriptionToTopic:(NSString *)topic
                        withToken:(NSString *)token
                          options:(NSDictionary *)options
                     shouldDelete:(BOOL)shouldDelete
                          handler:(FIRMessagingTopicOperationCompletion)handler;

@end
