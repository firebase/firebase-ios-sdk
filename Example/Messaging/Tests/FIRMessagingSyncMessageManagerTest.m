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

#import <XCTest/XCTest.h>

#import "FIRMessagingPersistentSyncMessage.h"
#import "FIRMessagingRmqManager.h"
#import "FIRMessagingSyncMessageManager.h"
#import "FIRMessagingUtilities.h"
#import "FIRMessagingConstants.h"

static NSString *const kRmqSqliteFilename = @"rmq-sync-manager-test";

@interface FIRMessagingSyncMessageManagerTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRMessagingRmqManager *rmqManager;
@property(nonatomic, readwrite, strong) FIRMessagingSyncMessageManager *syncMessageManager;

@end

@implementation FIRMessagingSyncMessageManagerTest

- (void)setUp {
  [super setUp];
  // Make sure the db state is clean before we begin.
  [FIRMessagingRmqManager removeDatabaseWithName:kRmqSqliteFilename];
  self.rmqManager = [[FIRMessagingRmqManager alloc] initWithDatabaseName:kRmqSqliteFilename];
  self.syncMessageManager = [[FIRMessagingSyncMessageManager alloc] initWithRmqManager:self.rmqManager];
}

- (void)tearDown {
  [[self.rmqManager class] removeDatabaseWithName:kRmqSqliteFilename];
  [super tearDown];
}

/**
 *  Test receiving a new sync message via APNS should be added to SYNC_RMQ.
 */
- (void)testNewAPNSMessage {
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 86400;  // 1 day in future

  NSDictionary *oldMessage = @{
    kFIRMessagingMessageIDKey : @"fake-rmq-1",
    kFIRMessagingMessageSyncViaMCSKey : @(expirationTime),
    @"hello" : @"world",
  };
  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:oldMessage]);

  NSDictionary *newMessage = @{
    kFIRMessagingMessageIDKey : @"fake-rmq-2",
    kFIRMessagingMessageSyncViaMCSKey : @(expirationTime),
    @"hello" : @"world",
  };

  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:newMessage]);
}

/**
 *  Test receiving a new sync message via MCS should be added to SYNC_RMQ.
 */
- (void)testNewMCSMessage {
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 86400;  // 1 day in future
  NSDictionary *oldMessage = @{
    kFIRMessagingMessageIDKey : @"fake-rmq-1",
    kFIRMessagingMessageSyncViaMCSKey : @(expirationTime),
    @"hello" : @"world",
  };
  XCTAssertFalse([self.syncMessageManager didReceiveMCSSyncMessage:oldMessage]);

  NSDictionary *newMessage = @{
    kFIRMessagingMessageIDKey : @"fake-rmq-2",
    kFIRMessagingMessageSyncViaMCSKey : @(expirationTime),
    @"hello" : @"world",
  };

  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:newMessage]);
}

/**
 *  Test receiving a duplicate message via APNS.
 */
- (void)testDuplicateAPNSMessage {
  NSString *messageID = @"fake-rmq-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 86400;  // 1 day in future
  NSDictionary *newMessage = @{
    kFIRMessagingMessageIDKey : messageID,
    kFIRMessagingMessageSyncViaMCSKey : @(expirationTime),
    @"hello" : @"world",
  };

  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:newMessage]);

  // The message is a duplicate
  XCTAssertTrue([self.syncMessageManager didReceiveAPNSSyncMessage:newMessage]);

  FIRMessagingPersistentSyncMessage *persistentMessage =
      [self.rmqManager querySyncMessageWithRmqID:messageID];
  XCTAssertTrue(persistentMessage.apnsReceived);
  XCTAssertFalse(persistentMessage.mcsReceived);
}

/**
 *  Test receiving a duplicate message via MCS.
 */
- (void)testDuplicateMCSMessage {
  NSString *messageID = @"fake-rmq-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 86400;  // 1 day in future
  NSDictionary *newMessage = @{
    kFIRMessagingMessageIDKey : messageID,
    kFIRMessagingMessageSyncViaMCSKey : @(expirationTime),
    @"hello" : @"world",
  };

  XCTAssertFalse([self.syncMessageManager didReceiveMCSSyncMessage:newMessage]);

  // The message is a duplicate
  XCTAssertTrue([self.syncMessageManager didReceiveMCSSyncMessage:newMessage]);

  FIRMessagingPersistentSyncMessage *persistentMessage =
      [self.rmqManager querySyncMessageWithRmqID:messageID];
  XCTAssertFalse(persistentMessage.apnsReceived);
  XCTAssertTrue(persistentMessage.mcsReceived);
}

/**
 *  Test receiving a sync message both via APNS and MCS.
 */
- (void)testMessageReceivedBothViaAPNSAndMCS {
  NSString *messageID = @"fake-rmq-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 86400;  // 1 day in future
  NSDictionary *newMessage = @{
    kFIRMessagingMessageIDKey : messageID,
    kFIRMessagingMessageSyncViaMCSKey : @(expirationTime),
    @"hello" : @"world",
  };

  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:newMessage]);
  // Duplicate of the above received APNS message
  XCTAssertTrue([self.syncMessageManager didReceiveMCSSyncMessage:newMessage]);

  // Since we've received both APNS and MCS messages we should have deleted them from SYNC_RMQ
  FIRMessagingPersistentSyncMessage *persistentMessage =
      [self.rmqManager querySyncMessageWithRmqID:messageID];
  XCTAssertNil(persistentMessage);
}

- (void)testDeletingExpiredMessages {
  NSString *unexpiredMessageID = @"fake-not-expired-rmqID";
  int64_t futureExpirationTime = 86400;  // 1 day in future
  NSDictionary *unexpiredMessage = @{
    kFIRMessagingMessageIDKey : unexpiredMessageID,
    kFIRMessagingMessageSyncMessageTTLKey : @(futureExpirationTime),
    @"hello" : @"world",
  };
  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:unexpiredMessage]);

  NSString *expiredMessageID = @"fake-expired-rmqID";
  int64_t past = -86400;  // 1 day in past
  NSDictionary *expiredMessage = @{
    kFIRMessagingMessageIDKey : expiredMessageID,
    kFIRMessagingMessageSyncMessageTTLKey : @(past),
    @"hello" : @"world",
  };
  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:expiredMessage]);

  NSString *noTTLMessageID = @"no-ttl-rmqID"; // no TTL specified should be 4 weeks
  NSDictionary *noTTLMessage = @{
    kFIRMessagingMessageIDKey : noTTLMessageID,
    @"hello" : @"world",
  };
  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:noTTLMessage]);

  [self.syncMessageManager removeExpiredSyncMessages];

  XCTAssertNotNil([self.rmqManager querySyncMessageWithRmqID:unexpiredMessageID]);
  XCTAssertNil([self.rmqManager querySyncMessageWithRmqID:expiredMessageID]);
  XCTAssertNotNil([self.rmqManager querySyncMessageWithRmqID:noTTLMessageID]);
}

- (void)testDeleteFinishedMessages {
  NSString *unexpiredMessageID = @"fake-not-expired-rmqID";
  int64_t futureExpirationTime = 86400;  // 1 day in future
  NSDictionary *unexpiredMessage = @{
    kFIRMessagingMessageIDKey : unexpiredMessageID,
    kFIRMessagingMessageSyncMessageTTLKey : @(futureExpirationTime),
    @"hello" : @"world",
  };
  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:unexpiredMessage]);

  NSString *noTTLMessageID = @"no-ttl-rmqID"; // no TTL specified should be 4 weeks
  NSDictionary *noTTLMessage = @{
                                 kFIRMessagingMessageIDKey : noTTLMessageID,
                                 @"hello" : @"world",
                                 };
  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:noTTLMessage]);

  // Mark the no-TTL message as received via MCS too
  XCTAssertTrue([self.rmqManager updateSyncMessageViaMCSWithRmqID:noTTLMessageID error:nil]);

  [self.syncMessageManager removeExpiredSyncMessages];

  XCTAssertNotNil([self.rmqManager querySyncMessageWithRmqID:unexpiredMessageID]);
  XCTAssertNil([self.rmqManager querySyncMessageWithRmqID:noTTLMessageID]);
}

- (void)testDeleteFinishedAndExpiredMessages {
  NSString *unexpiredMessageID = @"fake-not-expired-rmqID";
  int64_t futureExpirationTime = 86400;  // 1 day in future
  NSDictionary *unexpiredMessage = @{
    kFIRMessagingMessageIDKey : unexpiredMessageID,
    kFIRMessagingMessageSyncMessageTTLKey : @(futureExpirationTime),
    @"hello" : @"world",
  };
  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:unexpiredMessage]);

  NSString *expiredMessageID = @"fake-expired-rmqID";
  int64_t past = -86400;  // 1 day in past
  NSDictionary *expiredMessage = @{
    kFIRMessagingMessageIDKey : expiredMessageID,
    kFIRMessagingMessageSyncMessageTTLKey : @(past),
    @"hello" : @"world",
  };
  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:expiredMessage]);

  NSString *noTTLMessageID = @"no-ttl-rmqID"; // no TTL specified should be 4 weeks
  NSDictionary *noTTLMessage = @{
    kFIRMessagingMessageIDKey : noTTLMessageID,
    @"hello" : @"world",
  };
  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:noTTLMessage]);

  // Mark the no-TTL message as received via MCS too
  XCTAssertTrue([self.rmqManager updateSyncMessageViaMCSWithRmqID:noTTLMessageID error:nil]);

  // Remove expired or finished sync messages.
  [self.syncMessageManager removeExpiredSyncMessages];

  XCTAssertNotNil([self.rmqManager querySyncMessageWithRmqID:unexpiredMessageID]);
  XCTAssertNil([self.rmqManager querySyncMessageWithRmqID:expiredMessageID]);
  XCTAssertNil([self.rmqManager querySyncMessageWithRmqID:noTTLMessageID]);
}

@end
