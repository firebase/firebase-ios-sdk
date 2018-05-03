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

@class FIRMessagingClient;
@class FIRMessagingPubSub;

typedef NS_ENUM(int8_t, FIRMessagingNetworkStatus) {
  kFIRMessagingReachabilityNotReachable = 0,
  kFIRMessagingReachabilityReachableViaWiFi,
  kFIRMessagingReachabilityReachableViaWWAN,
};

FOUNDATION_EXPORT NSString *const kFIRMessagingPlistAutoInitEnabled;
FOUNDATION_EXPORT NSString *const kFIRMessagingUserDefaultsKeyAutoInitEnabled;

@interface FIRMessagingRemoteMessage ()

@property(nonatomic, strong) NSDictionary *appData;

@end

@interface FIRMessaging ()

#pragma mark - Private API

// The data collection flag from Core.
@property(nonatomic, readwrite, getter=isGlobalAutomaticDataCollectionEnabled) BOOL globalAutomaticDataCollectionEnabled;

- (NSString *)defaultFcmToken;
- (FIRMessagingClient *)client;
- (FIRMessagingPubSub *)pubsub;

// Create a sample message to be sent over the wire using FIRMessaging. Look at
// FIRMessagingService.h to see what each param signifies.
+ (NSMutableDictionary *)createFIRMessagingMessageWithMessage:(NSDictionary *)message
                                                  to:(NSString *)to
                                              withID:(NSString *)msgID
                                          timeToLive:(int64_t)ttl
                                               delay:(int)delay;

- (BOOL)isNetworkAvailable;
- (FIRMessagingNetworkStatus)networkType;

@end
