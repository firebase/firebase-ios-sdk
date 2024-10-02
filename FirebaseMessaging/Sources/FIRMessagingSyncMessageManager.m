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

#import "FirebaseMessaging/Sources/FIRMessagingSyncMessageManager.h"

#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingPersistentSyncMessage.h"
#import "FirebaseMessaging/Sources/FIRMessagingRmqManager.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"

static const int64_t kDefaultSyncMessageTTL = 4 * 7 * 24 * 60 * 60;  // 4 weeks

@interface FIRMessagingSyncMessageManager ()

@property(nonatomic, readwrite, strong) FIRMessagingRmqManager *rmqManager;

@end

@implementation FIRMessagingSyncMessageManager

- (instancetype)init {
  FIRMessagingInvalidateInitializer();
}

- (instancetype)initWithRmqManager:(FIRMessagingRmqManager *)rmqManager {
  self = [super init];
  if (self) {
    _rmqManager = rmqManager;
  }
  return self;
}

- (void)removeExpiredSyncMessages {
  [self.rmqManager deleteExpiredOrFinishedSyncMessages];
}

- (BOOL)didReceiveAPNSSyncMessage:(NSDictionary *)message {
  NSString *rmqID = message[kFIRMessagingMessageIDKey];
  if (![rmqID length]) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeSyncMessageManager002,
                            @"Invalid nil rmqID for sync message.");
    return NO;
  }

  FIRMessagingPersistentSyncMessage *persistentMessage =
      [self.rmqManager querySyncMessageWithRmqID:rmqID];

  if (!persistentMessage) {
    int64_t expirationTime = [[self class] expirationTimeForSyncMessage:message];
    [self.rmqManager saveSyncMessageWithRmqID:rmqID expirationTime:expirationTime];
    return NO;
  }

  if (!persistentMessage.apnsReceived) {
    persistentMessage.apnsReceived = YES;
    [self.rmqManager updateSyncMessageViaAPNSWithRmqID:rmqID];
  }

  // Already received this message either via MCS or APNS.
  return YES;
}

+ (int64_t)expirationTimeForSyncMessage:(NSDictionary *)message {
  int64_t ttl = kDefaultSyncMessageTTL;
  if (message[kFIRMessagingMessageSyncMessageTTLKey]) {
    ttl = [message[kFIRMessagingMessageSyncMessageTTLKey] longLongValue];
  }
  int64_t currentTime = FIRMessagingCurrentTimestampInSeconds();
  return currentTime + ttl;
}

@end
