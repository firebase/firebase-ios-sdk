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

#import "Firebase/Messaging/FIRMessagingSyncMessageManager.h"

#import "Firebase/Messaging/FIRMessagingConstants.h"
#import "Firebase/Messaging/FIRMessagingDefines.h"
#import "Firebase/Messaging/FIRMessagingLogger.h"
#import "Firebase/Messaging/FIRMessagingPersistentSyncMessage.h"
#import "Firebase/Messaging/FIRMessagingRmqManager.h"
#import "Firebase/Messaging/FIRMessagingUtilities.h"

static const int64_t kDefaultSyncMessageTTL = 4 * 7 * 24 * 60 * 60;  // 4 weeks
// 4 MB of free space is required to persist Sync messages
static const uint64_t kMinFreeDiskSpaceInMB = 1;

@interface FIRMessagingSyncMessageManager()

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
  NSError *error;
  int deleteCount = [self.rmqManager deleteExpiredOrFinishedSyncMessages:&error];
  if (error) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeSyncMessageManager000,
                            @"Error while deleting expired sync messages %@", error);
  } else if (deleteCount > 0) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSyncMessageManager001,
                            @"Successfully deleted %d sync messages from store", deleteCount);
  }
}

- (BOOL)didReceiveAPNSSyncMessage:(NSDictionary *)message {
  return [self didReceiveSyncMessage:message viaAPNS:YES viaMCS:NO];
}

- (BOOL)didReceiveMCSSyncMessage:(NSDictionary *)message {
  return [self didReceiveSyncMessage:message viaAPNS:NO viaMCS:YES];
}

- (BOOL)didReceiveSyncMessage:(NSDictionary *)message
                      viaAPNS:(BOOL)viaAPNS
                       viaMCS:(BOOL)viaMCS {
  NSString *rmqID = message[kFIRMessagingMessageIDKey];
  if (![rmqID length]) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeSyncMessageManager002,
                            @"Invalid nil rmqID for sync message.");
    return NO;
  }

  FIRMessagingPersistentSyncMessage *persistentMessage =
      [self.rmqManager querySyncMessageWithRmqID:rmqID];

  NSError *error;
  if (!persistentMessage) {

    // Do not persist the new message if we don't have enough disk space
    uint64_t freeDiskSpace = FIRMessagingGetFreeDiskSpaceInMB();
    if (freeDiskSpace < kMinFreeDiskSpaceInMB) {
      return NO;
    }

    int64_t expirationTime = [[self class] expirationTimeForSyncMessage:message];
    if (![self.rmqManager saveSyncMessageWithRmqID:rmqID
                                    expirationTime:expirationTime
                                      apnsReceived:viaAPNS
                                       mcsReceived:viaMCS
                                             error:&error]) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeSyncMessageManager003,
                              @"Failed to save sync message with rmqID %@", rmqID);
    } else {
      FIRMessagingLoggerInfo(kFIRMessagingMessageCodeSyncMessageManager004,
                             @"Added sync message to cache: %@", rmqID);
    }
    return NO;
  }

  if (viaAPNS && !persistentMessage.apnsReceived) {
    persistentMessage.apnsReceived = YES;
    if (![self.rmqManager updateSyncMessageViaAPNSWithRmqID:rmqID error:&error]) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeSyncMessageManager005,
                              @"Failed to update APNS state for sync message %@", rmqID);
    }
  } else if (viaMCS && !persistentMessage.mcsReceived) {
    persistentMessage.mcsReceived = YES;
    if (![self.rmqManager updateSyncMessageViaMCSWithRmqID:rmqID error:&error]) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeSyncMessageManager006,
                              @"Failed to update MCS state for sync message %@", rmqID);
    }
  }

  // Received message via both ways we can safely delete it.
  if (persistentMessage.apnsReceived && persistentMessage.mcsReceived) {
    if (![self.rmqManager deleteSyncMessageWithRmqID:rmqID]) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeSyncMessageManager007,
                              @"Failed to delete sync message %@", rmqID);
    } else {
      FIRMessagingLoggerInfo(kFIRMessagingMessageCodeSyncMessageManager008,
                             @"Successfully deleted sync message from cache %@", rmqID);
    }
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
