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

#import "Protos/GtalkCore.pbobjc.h"

#import "FIRMessagingPersistentSyncMessage.h"
#import "FIRMessagingRmqManager.h"
#import "FIRMessagingUtilities.h"

static NSString *const kRmqDatabaseName = @"rmq-test-db";
static NSString *const kRmqDataMessageCategory = @"com.google.gcm-rmq-test";

@interface FIRMessagingRmqManagerTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRMessagingRmqManager *rmqManager;

@end

@implementation FIRMessagingRmqManagerTest

- (void)setUp {
  [super setUp];
  // Make sure we start off with a clean state each time
  [FIRMessagingRmqManager removeDatabaseWithName:kRmqDatabaseName];
  _rmqManager = [[FIRMessagingRmqManager alloc] initWithDatabaseName:kRmqDatabaseName];
}

- (void)tearDown {
  [super tearDown];
  [FIRMessagingRmqManager removeDatabaseWithName:kRmqDatabaseName];
}

/**
 *  Add s2d messages with different RMQ-ID's to the RMQ. Fetch the messages
 *  and verify that all messages were successfully saved.
 */
- (void)testSavingS2dMessages {
  NSArray *messageIDs = @[ @"message1", @"message2", @"123456" ];
  for (NSString *messageID in messageIDs) {
    [self.rmqManager saveS2dMessageWithRmqId:messageID];
  }
  NSArray *rmqMessages = [self.rmqManager unackedS2dRmqIds];
  XCTAssertEqual(messageIDs.count, rmqMessages.count);
  for (NSString *messageID in rmqMessages) {
    XCTAssertTrue([messageIDs containsObject:messageID]);
  }
}

/**
 *  Add s2d messages with different RMQ-ID's to the RMQ. Delete some of the
 *  messages stored, assuming we received a server ACK for them. The remaining
 *  messages should be fetched successfully.
 */
- (void)testDeletingS2dMessages {
  NSArray *addMessages = @[ @"message1", @"message2", @"message3", @"message4"];
  for (NSString *messageID in addMessages) {
    [self.rmqManager saveS2dMessageWithRmqId:messageID];
  }
  NSArray *removeMessages = @[ addMessages[1], addMessages[3] ];
  [self.rmqManager removeS2dIds:removeMessages];
  NSArray *remainingMessages = [self.rmqManager unackedS2dRmqIds];
  XCTAssertEqual(2, remainingMessages.count);
  XCTAssertTrue([remainingMessages containsObject:addMessages[0]]);
  XCTAssertTrue([remainingMessages containsObject:addMessages[2]]);
}

/**
 *  Test deleting a s2d message that is not in the persistent store. This shouldn't
 *  crash or alter the valid contents of the RMQ store.
 */
- (void)testDeletingInvalidS2dMessage {
  NSString *validMessageID = @"validMessage123";
  [self.rmqManager saveS2dMessageWithRmqId:validMessageID];
  NSString *invalidMessageID = @"invalidMessage123";
  [self.rmqManager removeS2dIds:@[invalidMessageID]];
  NSArray *remainingMessages = [self.rmqManager unackedS2dRmqIds];
  XCTAssertEqual(1, remainingMessages.count);
  XCTAssertEqualObjects(validMessageID, remainingMessages[0]);
}

/**
 *  Test loading the RMQ-ID for d2s messages when there are no outgoing messages in the RMQ.
 */
- (void)testLoadRmqIDWithNoD2sMessages {
  [self.rmqManager loadRmqId];
  XCTAssertEqual(-1, [self maxRmqIDInRmqStoreForD2SMessages]);
}

/**
 *  Test that outgoing RMQ messages are correctly saved
 */
- (void)testOutgoingRmqWithValidMessages {
  NSString *from = @"rmq-test";
  [self.rmqManager loadRmqId];
  GtalkDataMessageStanza *message1 = [self dataMessageWithMessageID:@"message1"
                                                               from:from
                                                               data:nil];
  NSError *error = nil;

  // should successfully save the message to RMQ
  XCTAssertTrue([self.rmqManager saveRmqMessage:message1 error:&error]);
  XCTAssertNil(error);

  GtalkDataMessageStanza *message2 = [self dataMessageWithMessageID:@"message2"
                                                               from:from
                                                               data:nil];

  // should successfully save the second message to RMQ
  XCTAssertTrue([self.rmqManager saveRmqMessage:message2 error:&error]);
  XCTAssertNil(error);

  // message1 should have RMQ-ID = 2, message2 = 3
  XCTAssertEqual(3, [self maxRmqIDInRmqStoreForD2SMessages]);
  [self.rmqManager scanWithRmqMessageHandler:nil
                          dataMessageHandler:^(int64_t rmqId, GtalkDataMessageStanza *stanza) {
                            if (rmqId == 2) {
                              XCTAssertEqualObjects(@"message1", stanza.id_p);
                            } else if (rmqId == 3) {
                              XCTAssertEqualObjects(@"message2", stanza.id_p);
                            } else {
                              XCTFail(@"Invalid RmqID %lld for s2d message", rmqId);
                            }
                          }];
}

/**
 *  Test that an outgoing message with different properties is correctly saved to the RMQ.
 */
- (void)testOutgoingDataMessageIsCorrectlySaved {
  NSString *from = @"rmq-test";
  NSString *messageID = @"message123";
  NSString *to = @"to-senderID-123";
  int32_t ttl = 2400;
  NSString *registrationToken = @"registration-token";
  NSDictionary *data = @{
    @"hello" : @"world",
    @"count" : @"2",
  };

  [self.rmqManager loadRmqId];
  GtalkDataMessageStanza *message = [self dataMessageWithMessageID:messageID
                                                               from:from
                                                               data:data];
  [message setTo:to];
  [message setTtl:ttl];
  [message setRegId:registrationToken];
  NSError *error = nil;

  // should successfully save the message to RMQ
  XCTAssertTrue([self.rmqManager saveRmqMessage:message error:&error]);
  XCTAssertNil(error);

  [self.rmqManager scanWithRmqMessageHandler:nil
                          dataMessageHandler:^(int64_t rmqId, GtalkDataMessageStanza *stanza) {
                            XCTAssertEqualObjects(from, stanza.from);
                            XCTAssertEqualObjects(messageID, stanza.id_p);
                            XCTAssertEqualObjects(to, stanza.to);
                            XCTAssertEqualObjects(registrationToken, stanza.regId);
                            XCTAssertEqual(ttl, stanza.ttl);
                            NSMutableDictionary *d = [NSMutableDictionary dictionary];
                            for (GtalkAppData *appData in stanza.appDataArray) {
                              d[appData.key] = appData.value;
                            }
                            XCTAssertTrue([data isEqualToDictionary:d]);
                          }];
}

/**
 *  Test D2S messages being deleted from RMQ.
 */
- (void)testDeletingD2SMessagesFromRMQ {
  NSString *message1 = @"message123";
  NSString *ackedMessage = @"message234";
  NSString *from = @"from-rmq-test";
  GtalkDataMessageStanza *stanza1 = [self dataMessageWithMessageID:message1 from:from data:nil];
  GtalkDataMessageStanza *stanza2 = [self dataMessageWithMessageID:ackedMessage
                                                              from:from
                                                              data:nil];
  NSError *error = nil;
  XCTAssertTrue([self.rmqManager saveRmqMessage:stanza1 error:&error]);
  XCTAssertNil(error);
  XCTAssertTrue([self.rmqManager saveRmqMessage:stanza2 error:&error]);
  XCTAssertNil(error);

  __block int64_t ackedMessageRmqID = -1;
  [self.rmqManager scanWithRmqMessageHandler:nil
                          dataMessageHandler:^(int64_t rmqId, GtalkDataMessageStanza *stanza) {
                            if ([stanza.id_p isEqualToString:ackedMessage]) {
                              ackedMessageRmqID = rmqId;
                            }
                          }];
  // should be a valid RMQ ID
  XCTAssertTrue(ackedMessageRmqID > 0);

  // delete the acked message
  NSString *rmqIDString = [NSString stringWithFormat:@"%lld", ackedMessageRmqID];
  XCTAssertEqual(1, [self.rmqManager removeRmqMessagesWithRmqId:rmqIDString]);

  // should only have one message in the d2s RMQ
  [self.rmqManager scanWithRmqMessageHandler:nil
                          dataMessageHandler:^(int64_t rmqId, GtalkDataMessageStanza *stanza) {
                            // the acked message was queued later so should have
                            // rmqID = ackedMessageRMQID - 1
                            XCTAssertEqual(ackedMessageRmqID - 1, rmqId);
                            XCTAssertEqual(message1, stanza2.id_p);
                          }];
}

/**
 *  Test saving a sync message to SYNC_RMQ.
 */
- (void)testSavingSyncMessage {
  NSString *rmqID = @"fake-rmq-id-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 1;
  XCTAssertTrue([self.rmqManager saveSyncMessageWithRmqID:rmqID
                                           expirationTime:expirationTime
                                             apnsReceived:YES
                                              mcsReceived:NO
                                                    error:nil]);

  FIRMessagingPersistentSyncMessage *persistentMessage = [self.rmqManager querySyncMessageWithRmqID:rmqID];
  XCTAssertEqual(persistentMessage.expirationTime, expirationTime);
  XCTAssertTrue(persistentMessage.apnsReceived);
  XCTAssertFalse(persistentMessage.mcsReceived);
}

/**
 *  Test updating a sync message initially received via MCS, now being received via APNS.
 */
- (void)testUpdateMessageReceivedViaAPNS {
  NSString *rmqID = @"fake-rmq-id-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 1;
  XCTAssertTrue([self.rmqManager saveSyncMessageWithRmqID:rmqID
                                           expirationTime:expirationTime
                                             apnsReceived:NO
                                              mcsReceived:YES
                                                    error:nil]);

  // Message was now received via APNS
  XCTAssertTrue([self.rmqManager updateSyncMessageViaAPNSWithRmqID:rmqID error:nil]);

  FIRMessagingPersistentSyncMessage *persistentMessage = [self.rmqManager querySyncMessageWithRmqID:rmqID];
  XCTAssertTrue(persistentMessage.apnsReceived);
  XCTAssertTrue(persistentMessage.mcsReceived);
}

/**
 *  Test updating a sync message initially received via APNS, now being received via MCS.
 */
- (void)testUpdateMessageReceivedViaMCS {
  NSString *rmqID = @"fake-rmq-id-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 1;
  XCTAssertTrue([self.rmqManager saveSyncMessageWithRmqID:rmqID
                                           expirationTime:expirationTime
                                             apnsReceived:YES
                                              mcsReceived:NO
                                                    error:nil]);

  // Message was now received via APNS
  XCTAssertTrue([self.rmqManager updateSyncMessageViaMCSWithRmqID:rmqID error:nil]);

  FIRMessagingPersistentSyncMessage *persistentMessage = [self.rmqManager querySyncMessageWithRmqID:rmqID];
  XCTAssertTrue(persistentMessage.apnsReceived);
  XCTAssertTrue(persistentMessage.mcsReceived);
}

/**
 *  Test deleting sync messages from SYNC_RMQ.
 */
- (void)testDeleteSyncMessage {
  NSString *rmqID = @"fake-rmq-id-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 1;
  XCTAssertTrue([self.rmqManager saveSyncMessageWithRmqID:rmqID
                                           expirationTime:expirationTime
                                             apnsReceived:YES
                                              mcsReceived:NO
                                                    error:nil]);
  XCTAssertNotNil([self.rmqManager querySyncMessageWithRmqID:rmqID]);

  // should successfully delete the message
  XCTAssertTrue([self.rmqManager deleteSyncMessageWithRmqID:rmqID]);
  XCTAssertNil([self.rmqManager querySyncMessageWithRmqID:rmqID]);
}

#pragma mark - Private Helpers

- (GtalkDataMessageStanza *)dataMessageWithMessageID:(NSString *)messageID
                                                from:(NSString *)from
                                                data:(NSDictionary *)data {
  GtalkDataMessageStanza *stanza = [[GtalkDataMessageStanza alloc] init];
  [stanza setId_p:messageID];
  [stanza setFrom:from];
  [stanza setCategory:kRmqDataMessageCategory];

  for (NSString *key in data) {
    NSString *val = data[key];
    GtalkAppData *appData = [[GtalkAppData alloc] init];
    [appData setKey:key];
    [appData setValue:val];
    [[stanza appDataArray] addObject:appData];
  }

  return stanza;
}

- (int64_t)maxRmqIDInRmqStoreForD2SMessages {
  __block int64_t maxRmqID = -1;
  [self.rmqManager scanWithRmqMessageHandler:^(int64_t rmqId, int8_t tag, NSData *data) {
    if (rmqId > maxRmqID) {
      maxRmqID = rmqId;
    }
  }
                          dataMessageHandler:nil];
  return maxRmqID;
}

@end
