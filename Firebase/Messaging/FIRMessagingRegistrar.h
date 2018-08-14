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

#import "FIRMessaging.h"
#import "FIRMessagingCheckinService.h"

@class FIRMessagingCheckinStore;
@class FIRMessagingPubSubRegistrar;

/**
 *  Handle the registration process for the client. Fetch checkin information from the Checkin
 *  service if not cached on the device and then try to register the client with FIRMessaging backend.
 */
@interface FIRMessagingRegistrar : NSObject

@property(nonatomic, readonly, strong) FIRMessagingPubSubRegistrar *pubsubRegistrar;
@property(nonatomic, readonly, strong) NSString *deviceAuthID;
@property(nonatomic, readonly, strong) NSString *secretToken;

/**
 *  Initialize a FIRMessaging Registrar.
 *
 *  @return A FIRMessaging Registrar object.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

#pragma mark - Checkin

/**
 *  Try to load checkin info from the disk if not currently loaded into memory.
 *
 *  @return YES if successfully loaded valid checkin info to memory else NO.
 */
- (BOOL)tryToLoadValidCheckinInfo;

#pragma mark - Subscribe/Unsubscribe

/**
 *  Update the subscription for a given topic for the client.
 *
 *  @param topic        The topic for which the subscription should be updated.
 *  @param token        The registration token to be used by the client.
 *  @param options      The extra options if any being passed as part of
 *                      subscription request.
 *  @param shouldDelete YES if we want to delete an existing subscription else NO
 *                      if we want to create a new subscription.
 *  @param handler      The handler to invoke once the subscription request is
 *                      complete.
 */
- (void)updateSubscriptionToTopic:(NSString *)topic
                        withToken:(NSString *)token
                          options:(NSDictionary *)options
                     shouldDelete:(BOOL)shouldDelete
                          handler:(FIRMessagingTopicOperationCompletion)handler;

/**
 *  Cancel all subscription requests as well as any requests to checkin. Note if
 *  there are subscription requests waiting on checkin to complete those requests
 *  would be marked as stale and be NO-OP's if they happen in the future.
 *
 *  Also note this is a one time operation, you should only call this if you want
 *  to immediately stop all requests and deallocate the registrar. After calling
 *  this once you would no longer be able to use this registrar object.
 */
- (void)cancelAllRequests;

@end
