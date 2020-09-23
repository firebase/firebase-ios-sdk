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

#import "FirebaseMessaging/Tests/UnitTests/XCTestCase+FIRMessagingRmqManagerTests.h"

#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingPersistentSyncMessage.h"
#import "FirebaseMessaging/Sources/FIRMessagingRmqManager.h"
#import "FirebaseMessaging/Sources/FIRMessagingSyncMessageManager.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"

static NSString *const kRmqSqliteFilename = @"rmq-sync-manager-test";

@interface FIRMessagingRmqManager (ExposedForTest)

- (void)removeDatabase;

@end

@interface FIRMessagingSyncMessageManagerTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRMessagingRmqManager *rmqManager;
@property(nonatomic, readwrite, strong) FIRMessagingSyncMessageManager *syncMessageManager;

@end

@implementation FIRMessagingSyncMessageManagerTest

- (void)setUp {
  [super setUp];
  // Make sure the db state is clean before we begin.
  _rmqManager = [[FIRMessagingRmqManager alloc] initWithDatabaseName:kRmqSqliteFilename];
  self.syncMessageManager =
      [[FIRMessagingSyncMessageManager alloc] initWithRmqManager:self.rmqManager];
}

- (void)tearDown {
  [_rmqManager removeDatabase];
  [self waitForDrainDatabaseQueueForRmqManager:_rmqManager];
  [super tearDown];
}

/**
 *  Test receiving a new sync message via APNS should be added to SYNC_RMQ.
 */
- (void)testNewAPNSMessage {
  NSDictionary *oldMessage = @{
    kFIRMessagingMessageIDKey : @"fake-rmq-1",
    @"hello" : @"world",
  };
  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:oldMessage]);

  NSDictionary *newMessage = @{
    kFIRMessagingMessageIDKey : @"fake-rmq-2",
    @"hello" : @"world",
  };

  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:newMessage]);
}

#if !(SWIFT_PACKAGE && TARGET_OS_TV)  // Not enough space.
/**
 *  Test receiving a duplicate message via APNS.
 */
- (void)testDuplicateAPNSMessage {
  NSString *messageID = @"fake-rmq-1";
  NSDictionary *newMessage = @{
    kFIRMessagingMessageIDKey : messageID,
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

  NSString *noTTLMessageID = @"no-ttl-rmqID";  // no TTL specified should be 4 weeks
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

  NSString *noTTLMessageID = @"no-ttl-rmqID";  // no TTL specified should be 4 weeks
  NSDictionary *noTTLMessage = @{
    kFIRMessagingMessageIDKey : noTTLMessageID,
    @"hello" : @"world",
  };
  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:noTTLMessage]);

  [self.syncMessageManager removeExpiredSyncMessages];

  XCTAssertNotNil([self.rmqManager querySyncMessageWithRmqID:unexpiredMessageID]);
  XCTAssertNotNil([self.rmqManager querySyncMessageWithRmqID:noTTLMessageID]);
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

  NSString *noTTLMessageID = @"no-ttl-rmqID";  // no TTL specified should be 4 weeks
  NSDictionary *noTTLMessage = @{
    kFIRMessagingMessageIDKey : noTTLMessageID,
    @"hello" : @"world",
  };
  XCTAssertFalse([self.syncMessageManager didReceiveAPNSSyncMessage:noTTLMessage]);

  // Remove expired or finished sync messages.
  [self.syncMessageManager removeExpiredSyncMessages];

  XCTAssertNotNil([self.rmqManager querySyncMessageWithRmqID:unexpiredMessageID]);
  XCTAssertNil([self.rmqManager querySyncMessageWithRmqID:expiredMessageID]);
  XCTAssertNotNil([self.rmqManager querySyncMessageWithRmqID:noTTLMessageID]);
}
#endif  // #if !(SWIFT_PACKAGE && TARGET_OS_TV)

@end
