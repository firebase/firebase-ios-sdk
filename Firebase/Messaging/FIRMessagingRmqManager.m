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

#import "Firebase/Messaging/FIRMessagingRmqManager.h"

#import <sqlite3.h>

#import "Firebase/Messaging/FIRMessagingDefines.h"
#import "Firebase/Messaging/FIRMessagingLogger.h"
#import "Firebase/Messaging/FIRMessagingRmq2PersistentStore.h"
#import "Firebase/Messaging/FIRMessagingUtilities.h"
#import "Firebase/Messaging/Protos/GtalkCore.pbobjc.h"

#ifndef _FIRMessagingRmqLogAndExit
#define _FIRMessagingRmqLogAndExit(stmt, return_value)   \
do {                              \
  [self logErrorAndFinalizeStatement:stmt];  \
  return return_value; \
} while(0)
#endif

static NSString *const kFCMRmqTag = @"FIRMessagingRmq:";

@interface FIRMessagingRmqManager ()

@property(nonatomic, readwrite, strong) FIRMessagingRmq2PersistentStore *rmq2Store;
// map the category of an outgoing message with the number of messages for that category
// should always have two keys -- the app, gcm
@property(nonatomic, readwrite, strong) NSMutableDictionary *outstandingMessages;

// Outgoing RMQ persistent id
@property(nonatomic, readwrite, assign) int64_t rmqId;

@end

@implementation FIRMessagingRmqManager

- (instancetype)initWithDatabaseName:(NSString *)databaseName {
  self = [super init];
  if (self) {
    _rmq2Store = [[FIRMessagingRmq2PersistentStore alloc] initWithDatabaseName:databaseName];
    _outstandingMessages = [NSMutableDictionary dictionaryWithCapacity:2];
    _rmqId = -1;
  }
  return self;
}

- (void)loadRmqId {
  if (self.rmqId >= 0) {
    return; // already done
  }

  [self loadInitialOutgoingPersistentId];
  if (self.outstandingMessages.count) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeRmqManager000,
                            @"%@: outstanding categories %ld", kFCMRmqTag,
                            _FIRMessaging_UL(self.outstandingMessages.count));
  }
}

/**
 * Initialize the 'initial RMQ':
 * - max ID of any message in the queue
 * - if the queue is empty, stored value in separate DB.
 *
 * Stream acks will remove from RMQ, when we remove the highest message we keep track
 * of its ID.
 */
- (void)loadInitialOutgoingPersistentId {

  // we shouldn't always trust the lastRmqId stored in the LastRmqId table, because
  // we only save to the LastRmqId table once in a while (after getting the lastRmqId sent
  // by the server after reconnect, and after getting a rmq ack from the server). The
  // rmq message with the highest rmq id tells the real story, so check against that first.

  int64_t rmqId = [self queryHighestRmqId];
  if (rmqId == 0) {
    rmqId = [self querylastRmqId];
  }
  self.rmqId = rmqId + 1;
}

#pragma mark - Save

/**
 * Save a message to RMQ2. Will populate the rmq2 persistent ID.
 */
- (BOOL)saveRmqMessage:(GPBMessage *)message
                 error:(NSError **)error {
  // send using rmq2manager
  // the wire format of rmq2 id is a string. However, we keep it as a long internally
  // in the database. So only convert the id to string when preparing for sending over
  // the wire.
  NSString *rmq2Id = FIRMessagingGetRmq2Id(message);
  if (![rmq2Id length]) {
    int64_t rmqId = [self nextRmqId];
    rmq2Id = [NSString stringWithFormat:@"%lld", rmqId];
    FIRMessagingSetRmq2Id(message, rmq2Id);
  }
  FIRMessagingProtoTag tag = FIRMessagingGetTagForProto(message);
  return [self saveMessage:message withRmqId:[rmq2Id integerValue] tag:tag error:error];
}

- (BOOL)saveMessage:(GPBMessage *)message
          withRmqId:(int64_t)rmqId
                tag:(int8_t)tag
              error:(NSError **)error {
  NSData *data = [message data];
  return [self.rmq2Store saveMessageWithRmqId:rmqId tag:tag data:data error:error];
}

/**
 * This is called when we delete the largest outgoing message from queue.
 */
- (void)saveLastOutgoingRmqId:(int64_t)rmqID {
  [self.rmq2Store updateLastOutgoingRmqId:rmqID];
}

- (BOOL)saveS2dMessageWithRmqId:(NSString *)rmqID {
  return [self.rmq2Store saveUnackedS2dMessageWithRmqId:rmqID];
}

#pragma mark - Query

- (int64_t)queryHighestRmqId {
  return [self.rmq2Store queryHighestRmqId];
}

- (int64_t)querylastRmqId {
  return [self.rmq2Store queryLastRmqId];
}

- (NSArray *)unackedS2dRmqIds {
  return [self.rmq2Store unackedS2dRmqIds];
}

#pragma mark - FIRMessagingRMQScanner protocol

/**
 * We don't have a 'getMessages' method - it would require loading in memory
 * the entire content body of all messages.
 *
 * Instead we iterate and call 'resend' for each message.
 *
 * This is called:
 *  - on connect MCS, to resend any outstanding messages
 *  - init
 */
- (void)scanWithRmqMessageHandler:(FIRMessagingRmqMessageHandler)rmqMessageHandler
               dataMessageHandler:(FIRMessagingDataMessageHandler)dataMessageHandler {
  // no need to scan database with no callbacks
  if (rmqMessageHandler || dataMessageHandler) {
    [self.rmq2Store scanOutgoingRmqMessagesWithHandler:^(int64_t rmqId, int8_t tag, NSData *data) {
      if (rmqMessageHandler != nil) {
        rmqMessageHandler(rmqId, tag, data);
      }
      if (dataMessageHandler != nil && kFIRMessagingProtoTagDataMessageStanza == tag) {
        GPBMessage *proto =
            [FIRMessagingGetClassForTag((FIRMessagingProtoTag)tag) parseFromData:data error:NULL];
        GtalkDataMessageStanza *stanza = (GtalkDataMessageStanza *)proto;
        dataMessageHandler(rmqId, stanza);
      }
    }];
  }
}

#pragma mark - Remove

- (void)ackReceivedForRmqId:(NSString *)rmqId {
  // TODO: Optional book-keeping
}

- (int)removeRmqMessagesWithRmqId:(NSString *)rmqId {
  return [self removeRmqMessagesWithRmqIds:@[rmqId]];
}

- (int)removeRmqMessagesWithRmqIds:(NSArray *)rmqIds {
  if (![rmqIds count]) {
    return 0;
  }
  for (NSString *rmqId in rmqIds) {
    [self ackReceivedForRmqId:rmqId];
  }
  int64_t maxRmqId = -1;
  for (NSString *rmqId in rmqIds) {
    int64_t rmqIdValue = [rmqId longLongValue];
    if (rmqIdValue > maxRmqId) {
      maxRmqId = rmqIdValue;
    }
  }
  maxRmqId++;
  if (maxRmqId >= self.rmqId) {
    [self saveLastOutgoingRmqId:maxRmqId];
  }
  return [self.rmq2Store deleteMessagesFromTable:kTableOutgoingRmqMessages withRmqIds:rmqIds];
}

- (void)removeS2dIds:(NSArray *)s2dIds {
  [self.rmq2Store deleteMessagesFromTable:kTableS2DRmqIds withRmqIds:s2dIds];
}

#pragma mark - Sync Messages

// TODO: RMQManager should also have a cache for all the sync messages
// so we don't hit the DB each time.
- (FIRMessagingPersistentSyncMessage *)querySyncMessageWithRmqID:(NSString *)rmqID {
  return [self.rmq2Store querySyncMessageWithRmqID:rmqID];
}

- (BOOL)deleteSyncMessageWithRmqID:(NSString *)rmqID {
  return [self.rmq2Store deleteSyncMessageWithRmqID:rmqID];
}

- (int)deleteExpiredOrFinishedSyncMessages:(NSError **)error {
  return [self.rmq2Store deleteExpiredOrFinishedSyncMessages:error];
}

- (BOOL)saveSyncMessageWithRmqID:(NSString *)rmqID
                  expirationTime:(int64_t)expirationTime
                    apnsReceived:(BOOL)apnsReceived
                     mcsReceived:(BOOL)mcsReceived
                           error:(NSError *__autoreleasing *)error {
  return [self.rmq2Store saveSyncMessageWithRmqID:rmqID
                                   expirationTime:expirationTime
                                     apnsReceived:apnsReceived
                                      mcsReceived:mcsReceived
                                            error:error];
}

- (BOOL)updateSyncMessageViaAPNSWithRmqID:(NSString *)rmqID error:(NSError **)error {
  return [self.rmq2Store updateSyncMessageViaAPNSWithRmqID:rmqID error:error];
}

- (BOOL)updateSyncMessageViaMCSWithRmqID:(NSString *)rmqID error:(NSError **)error {
  return [self.rmq2Store updateSyncMessageViaMCSWithRmqID:rmqID error:error];
}

#pragma mark - Testing

+ (void)removeDatabaseWithName:(NSString *)dbName {
  [FIRMessagingRmq2PersistentStore removeDatabase:dbName];
}

#pragma mark - Private

- (int64_t)nextRmqId {
  return ++self.rmqId;
}

@end
