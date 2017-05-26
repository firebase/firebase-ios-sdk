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

@import XCTest;

#import <OCMock/OCMock.h>

#import "Protos/GtalkCore.pbobjc.h"

#import "FIRMessaging.h"
#import "FIRMessagingClient.h"
#import "FIRMessagingConnection.h"
#import "FIRMessagingDataMessageManager.h"
#import "FIRMessagingReceiver.h"
#import "FIRMessagingRmqManager.h"
#import "FIRMessagingSyncMessageManager.h"
#import "FIRMessagingUtilities.h"
#import "FIRMessaging_Private.h"
#import "FIRMessagingConstants.h"
#import "FIRMessagingDefines.h"
#import "NSError+FIRMessaging.h"

static NSString *const kFIRMessagingUserDefaultsSuite = @"FIRMessagingClientTestUserDefaultsSuite";

static NSString *const kFIRMessagingAppIDToken = @"1234abcdef789";

static NSString *const kMessagePersistentID = @"abcdef123";
static NSString *const kMessageFrom = @"com.example.gcm";
static NSString *const kMessageTo = @"123456789";
static NSString *const kCollapseKey = @"collapse-1";
static NSString *const kAppDataItemKey = @"hello";
static NSString *const kAppDataItemValue = @"world";
static NSString *const kAppDataItemInvalidKey = @"google.hello";

static NSString *const kRmqDatabaseName = @"gcm-dmm-test";

@interface FIRMessagingDataMessageManager()

@property(nonatomic, readwrite, weak) FIRMessagingRmqManager *rmq2Manager;

- (NSString *)categoryForUpstreamMessages;

@end

@interface FIRMessagingDataMessageManagerTest : XCTestCase

@property(nonatomic, readwrite, strong) id mockClient;
@property(nonatomic, readwrite, strong) id mockRmqManager;
@property(nonatomic, readwrite, strong) id mockReceiver;
@property(nonatomic, readwrite, strong) id mockSyncMessageManager;
@property(nonatomic, readwrite, strong) FIRMessagingDataMessageManager *dataMessageManager;
@property(nonatomic, readwrite, strong) id mockDataMessageManager;

@end

@implementation FIRMessagingDataMessageManagerTest

- (void)setUp {
  [super setUp];
  _mockClient = OCMClassMock([FIRMessagingClient class]);
  _mockReceiver = OCMClassMock([FIRMessagingReceiver class]);
  _mockRmqManager = OCMClassMock([FIRMessagingRmqManager class]);
  _mockSyncMessageManager = OCMClassMock([FIRMessagingSyncMessageManager class]);
  _dataMessageManager = [[FIRMessagingDataMessageManager alloc]
        initWithDelegate:_mockReceiver
                  client:_mockClient
             rmq2Manager:_mockRmqManager
      syncMessageManager:_mockSyncMessageManager];
  [_dataMessageManager refreshDelayedMessages];
  _mockDataMessageManager = OCMPartialMock(_dataMessageManager);
}


- (void)testSendValidMessage_withNoConnection {
  // mock no connection initially
  NSString *messageID = @"1";
  BOOL mockConnectionActive = NO;
  [[[self.mockClient stub] andDo:^(NSInvocation *invocation) {
    NSValue *returnValue = [NSValue valueWithBytes:&mockConnectionActive
                                          objCType:@encode(BOOL)];
    [invocation setReturnValue:&returnValue];
  }] isConnectionActive];

  BOOL(^isValidStanza)(id obj) = ^BOOL(id obj) {
    if ([obj isKindOfClass:[GtalkDataMessageStanza class]]) {
      GtalkDataMessageStanza *message = (GtalkDataMessageStanza *)obj;
      return ([message.id_p isEqualToString:messageID] && [message.to isEqualToString:kMessageTo]);
    }
    return NO;
  };
  OCMExpect([self.mockReceiver willSendDataMessageWithID:[OCMArg isEqual:messageID]
                                                   error:[OCMArg isNil]]);
  [[[self.mockRmqManager stub] andReturnValue:@YES]
      saveRmqMessage:[OCMArg checkWithBlock:isValidStanza]
               error:[OCMArg anyObjectRef]];

  // should be logged into the service
  [self addFakeFIRMessagingRegistrationToken];
  [self.dataMessageManager setDeviceAuthID:@"auth-id" secretToken:@"secret-token"];
  // try to send messages with no connection should be queued into RMQ
  NSMutableDictionary *message = [self upstreamMessageWithID:messageID ttl:-1 delay:0];
  [self.dataMessageManager sendDataMessageStanza:message];

  OCMVerifyAll(self.mockReceiver);
  OCMVerifyAll(self.mockRmqManager);
}

- (void)testSendValidMessage_withoutCheckinAuthentication {
  NSString *messageID = @"1";
  NSMutableDictionary *message = [self standardFIRMessagingMessageWithMessageID:messageID];

  OCMExpect([self.mockReceiver
      willSendDataMessageWithID:[OCMArg isEqual:messageID]
                          error:[OCMArg checkWithBlock:^BOOL(id obj) {
                            if ([obj isKindOfClass:[NSError class]]) {
                              NSError *error = (NSError *)obj;
                              return error.code == kFIRMessagingErrorCodeMissingDeviceID;
                            }
                            return NO;
                          }]]);

  // do not log into checkin service
  [self.dataMessageManager sendDataMessageStanza:message];

  OCMVerifyAll(self.mockReceiver);
}

- (void)testSendInvalidMessage_withNoTo {
  NSString *messageID = @"1";
  NSMutableDictionary *message =
      [FIRMessaging createFIRMessagingMessageWithMessage:@{ kAppDataItemKey : kAppDataItemValue}
                                                      to:@""
                                                  withID:messageID
                                              timeToLive:-1
                                                   delay:0];

  OCMExpect([self.mockReceiver
      willSendDataMessageWithID:[OCMArg isEqual:messageID]
                          error:[OCMArg checkWithBlock:^BOOL(id obj) {
                            if ([obj isKindOfClass:[NSError class]]) {
                              NSError *error = (NSError *)obj;
                              return error.code == kFIRMessagingErrorMissingTo;
                            }
                            return NO;
                          }]]);

  // should be logged into the service
  [self addFakeFIRMessagingRegistrationToken];
  [self.dataMessageManager setDeviceAuthID:@"auth-id" secretToken:@"secret-token"];
  [self.dataMessageManager sendDataMessageStanza:message];

  OCMVerifyAll(self.mockReceiver);
}

- (void)testSendInvalidMessage_withSizeExceeded {
  NSString *messageID = @"1";
  NSString *veryLargeString = [@"a" stringByPaddingToLength:4 * 1024 // 4kB
                                                 withString:@"b"
                                            startingAtIndex:0];
  NSMutableDictionary *message =
      [FIRMessaging createFIRMessagingMessageWithMessage:@{ kAppDataItemKey : veryLargeString }
                                                      to:kMessageTo
                                                  withID:messageID
                                              timeToLive:-1
                                                   delay:0];

  OCMExpect([self.mockReceiver
      willSendDataMessageWithID:[OCMArg isEqual:messageID]
                          error:[OCMArg checkWithBlock:^BOOL(id obj) {
                            if ([obj isKindOfClass:[NSError class]]) {
                              NSError *error = (NSError *)obj;
                              return error.code == kFIRMessagingErrorSizeExceeded;
                            }
                            return NO;
                          }]]);

  [self addFakeFIRMessagingRegistrationToken];
  // should be logged into the service
  [self.dataMessageManager setDeviceAuthID:@"auth-id" secretToken:@"secret-token"];
  [self.dataMessageManager sendDataMessageStanza:message];

  OCMVerifyAll(self.mockReceiver);
}

// TODO: Add test with rawData exceeding 4KB in size

- (void)testSendValidMessage_withRmqSaveError {
  NSString *messageID = @"1";
  NSMutableDictionary *message = [self standardFIRMessagingMessageWithMessageID:messageID];
  [[[self.mockRmqManager stub] andReturnValue:@NO]
      saveRmqMessage:[OCMArg any] error:[OCMArg anyObjectRef]];

  OCMExpect([self.mockReceiver
      willSendDataMessageWithID:[OCMArg isEqual:messageID]
                          error:[OCMArg checkWithBlock:^BOOL(id obj) {
                            if ([obj isKindOfClass:[NSError class]]) {
                              NSError *error = (NSError *)obj;
                              return error.code == kFIRMessagingErrorSave;
                            }
                            return NO;
                          }]]);

  // should be logged into the service
  [self.dataMessageManager setDeviceAuthID:@"auth-id" secretToken:@"secret-token"];
  [self addFakeFIRMessagingRegistrationToken];
  [self.dataMessageManager sendDataMessageStanza:message];

  OCMVerifyAll(self.mockReceiver);
}

- (void)testSendValidMessage_withTTL0 {
  // simulate a valid connection
  [[[self.mockClient stub] andReturnValue:@YES] isConnectionActive];
  NSString *messageID = @"1";
  NSMutableDictionary *message = [self upstreamMessageWithID:messageID ttl:0 delay:0];

  BOOL(^isValidStanza)(id obj) = ^BOOL(id obj) {
    if ([obj isKindOfClass:[GtalkDataMessageStanza class]]) {
      GtalkDataMessageStanza *stanza = (GtalkDataMessageStanza *)obj;
      return ([stanza.id_p isEqualToString:messageID] &&
              [stanza.to isEqualToString:kMessageTo] &&
              stanza.ttl == 0);
    }
    return NO;
  };

  OCMExpect([self.mockClient sendMessage:[OCMArg checkWithBlock:isValidStanza]]);

  [self.dataMessageManager setDeviceAuthID:@"auth-id" secretToken:@"secret-token"];
  [self addFakeFIRMessagingRegistrationToken];
  [self.dataMessageManager sendDataMessageStanza:message];

  OCMVerifyAll(self.mockClient);
}

// TODO: This is failing on simulator 7.1 & 8.2, take this out temporarily
- (void)XXX_testSendValidMessage_withTTL0AndNoFIRMessagingConnection {
  // simulate a invalid connection
  [[[self.mockClient stub] andReturnValue:@NO] isConnectionActive];

  // simulate network reachability
  FIRMessaging *service = [FIRMessaging messaging];
  id mockService = OCMPartialMock(service);
  [[[mockService stub] andReturnValue:@YES] isNetworkAvailable];

  NSString *messageID = @"1";
  NSMutableDictionary *message = [self upstreamMessageWithID:messageID ttl:0 delay:0];


  BOOL(^isValidStanza)(id obj) = ^BOOL(id obj) {
    if ([obj isKindOfClass:[GtalkDataMessageStanza class]]) {
      GtalkDataMessageStanza *stanza = (GtalkDataMessageStanza *)obj;
      return ([stanza.id_p isEqualToString:messageID] &&
              [stanza.to isEqualToString:kMessageTo] &&
              stanza.ttl == 0);
    }
    return NO;
  };

  // should save the message to be sent when we reconnect the next time
  OCMExpect([self.mockClient sendOnConnectOrDrop:[OCMArg checkWithBlock:isValidStanza]]);
  // should also try to reconnect immediately
  OCMExpect([self.mockClient retryConnectionImmediately:[OCMArg isEqual:@YES]]);

  [self.dataMessageManager setDeviceAuthID:@"auth-id" secretToken:@"secret-token"];
  [self addFakeFIRMessagingRegistrationToken];
  [self.dataMessageManager sendDataMessageStanza:message];

  OCMVerifyAll(self.mockClient);
}

// TODO: Investigate why this test is flaky
- (void)xxx_testSendValidMessage_withTTL0AndNoNetwork {
  // simulate a invalid connection
  [[[self.mockClient stub] andReturnValue:@NO] isConnectionActive];

  NSString *messageID = @"1";
  NSMutableDictionary *message = [self upstreamMessageWithID:messageID ttl:0 delay:0];


  // should drop the message since there is no network
  OCMExpect([self.mockReceiver willSendDataMessageWithID:[OCMArg isEqual:messageID]
                                                   error:[OCMArg checkWithBlock:^BOOL(id obj) {
    if ([obj isKindOfClass:[NSError class]]) {
      NSError *error = (NSError *)obj;
      return error.code == kFIRMessagingErrorCodeNetwork;
    }
    return NO;
  }]]);

  [self.dataMessageManager setDeviceAuthID:@"auth-id" secretToken:@"secret-token"];
  [self addFakeFIRMessagingRegistrationToken];
  [self.dataMessageManager sendDataMessageStanza:message];

  OCMVerifyAll(self.mockReceiver);
}

// TODO: This failed on simulator 7.1 & 8.2, take this out temporarily
- (void)XXX_testDelayedMessagesBeingResentOnReconnect {
  static BOOL isConnectionActive = NO;
  OCMStub([self.mockClient isConnectionActive]).andDo(^(NSInvocation *invocation) {
    [invocation setReturnValue:&isConnectionActive];
  });

  // message that lives for 2 seconds
  NSString *messageID = @"1";
  int ttl = 2;
  NSMutableDictionary *message = [self upstreamMessageWithID:messageID ttl:ttl delay:1];

  __block GtalkDataMessageStanza *firstMessageStanza;

  OCMStub([self.mockRmqManager saveRmqMessage:[OCMArg any]
                                        error:[OCMArg anyObjectRef]]).andReturn(YES);

  OCMExpect([self.mockReceiver willSendDataMessageWithID:[OCMArg isEqual:messageID]
                                                   error:[OCMArg isNil]]);

  [self.dataMessageManager setDeviceAuthID:@"auth-id" secretToken:@"secret-token"];
  [self addFakeFIRMessagingRegistrationToken];
  [self.dataMessageManager sendDataMessageStanza:message];

  __block FIRMessagingDataMessageHandler dataMessageHandler;

  [[[self.mockRmqManager stub] andDo:^(NSInvocation *invocation) {
    dataMessageHandler([FIRMessagingGetRmq2Id(firstMessageStanza) longLongValue],
                       firstMessageStanza);
  }]
      scanWithRmqMessageHandler:[OCMArg isNil]
             dataMessageHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
               dataMessageHandler = obj;
               return YES;
             }]];

  // expect both 1 and 2 messages to be sent once we regain connection
  __block BOOL firstMessageSent = NO;
  __block BOOL secondMessageSent = NO;
  XCTestExpectation *didSendAllMessages =
      [self expectationWithDescription:@"Did send all messages"];
  OCMExpect([self.mockClient sendMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
    // [didSendAllMessages fulfill];
    if ([obj isKindOfClass:[GtalkDataMessageStanza class]]) {
      GtalkDataMessageStanza *message = (GtalkDataMessageStanza *)obj;
      if ([@"1" isEqualToString:message.id_p]) {
        firstMessageSent = YES;
      } else if ([@"2" isEqualToString:message.id_p]) {
        secondMessageSent = YES;
      }
      if (firstMessageSent && secondMessageSent) {
        [didSendAllMessages fulfill];
      }
      return firstMessageSent || secondMessageSent;
    }
    return NO;
  }]]);

  // send the second message after some delay
  [NSThread sleepForTimeInterval:2.0];

  isConnectionActive = YES;
  // simulate active connection
  NSString *newMessageID = @"2";
  NSMutableDictionary *newMessage = [self upstreamMessageWithID:newMessageID
                                                            ttl:0
                                                          delay:0];
  // send another message to resend not sent messages
  [self.dataMessageManager sendDataMessageStanza:newMessage];

  [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
    XCTAssertNil(error);
    OCMVerifyAll(self.mockClient);
    OCMVerifyAll(self.mockReceiver);
  }];
}

- (void)testSendDelayedMessage_shouldNotSend {
  // should not send a delayed message even with an active connection
  // simulate active connection
  [[[self.mockClient stub] andReturnValue:OCMOCK_VALUE(YES)] isConnectionActive];
  [[self.mockClient reject] sendMessage:[OCMArg any]];

  [[self.mockReceiver reject] didSendDataMessageWithID:[OCMArg any]];

  // delayed message
  NSString *messageID = @"1";
  [self.dataMessageManager setDeviceAuthID:@"auth-id" secretToken:@"secret-token"];
  NSMutableDictionary *message = [self upstreamMessageWithID:messageID ttl:0 delay:1];
  [self.dataMessageManager sendDataMessageStanza:message];

  OCMVerifyAll(self.mockClient);
  OCMVerifyAll(self.mockReceiver);
}

- (void)testProcessPacket_withValidPacket {
  GtalkDataMessageStanza *message = [self validDataMessagePacket];
  NSDictionary *parsedMessage = [self.dataMessageManager processPacket:message];
  XCTAssertEqualObjects(parsedMessage[kFIRMessagingFromKey], message.from);
  XCTAssertEqualObjects(parsedMessage[kFIRMessagingCollapseKey], message.token);
  XCTAssertEqualObjects(parsedMessage[kFIRMessagingMessageIDKey], kMessagePersistentID);
  XCTAssertEqualObjects(parsedMessage[kAppDataItemKey], kAppDataItemValue);
  XCTAssertEqual(4, parsedMessage.count);
}

- (void)testProcessPacket_withOnlyFrom {
  GtalkDataMessageStanza *message = [self validDataMessageWithOnlyFrom];
  NSDictionary *parsedMessage = [self.dataMessageManager processPacket:message];
  XCTAssertEqualObjects(parsedMessage[kFIRMessagingFromKey], message.from);
  XCTAssertEqualObjects(parsedMessage[kFIRMessagingMessageIDKey], kMessagePersistentID);
  XCTAssertEqual(2, parsedMessage.count);
}

- (void)testProcessPacket_withInvalidPacket {
  GtalkDataMessageStanza *message = [self invalidDataMessageUsingReservedKeyword];
  NSDictionary *parsedMessage = [self.dataMessageManager processPacket:message];
  XCTAssertEqualObjects(parsedMessage[kFIRMessagingFromKey], message.from);
  XCTAssertEqualObjects(parsedMessage[kFIRMessagingMessageIDKey], kMessagePersistentID);
  XCTAssertEqual(2, parsedMessage.count);
}

/**
 *  Test parsing a duplex message.
 */
- (void)testProcessPacket_withDuplexMessage {
  GtalkDataMessageStanza *stanza = [self validDuplexmessage];
  NSDictionary *parsedMessage = [self.dataMessageManager processPacket:stanza];
  XCTAssertEqual(5, parsedMessage.count);
  XCTAssertEqualObjects(parsedMessage[kFIRMessagingFromKey], stanza.from);
  XCTAssertEqualObjects(parsedMessage[kFIRMessagingCollapseKey], stanza.token);
  XCTAssertEqualObjects(parsedMessage[kFIRMessagingMessageIDKey], kMessagePersistentID);
  XCTAssertEqualObjects(parsedMessage[kAppDataItemKey], kAppDataItemValue);
  XCTAssertTrue([parsedMessage[kFIRMessagingMessageSyncViaMCSKey] boolValue]);
}

- (void)testReceivingParsedMessage {
  NSDictionary *message = @{ @"hello" : @"world" };
  OCMStub([self.mockReceiver didReceiveMessage:[OCMArg isEqual:message] withIdentifier:[OCMArg any]]);
  [self.dataMessageManager didReceiveParsedMessage:message];
  OCMVerify([self.mockReceiver didReceiveMessage:message withIdentifier:[OCMArg any]]);
}

/**
 *  Test receiving a new duplex message notifies the receiver callback.
 */
- (void)testReceivingNewDuplexMessage {
  GtalkDataMessageStanza *message = [self validDuplexmessage];
  NSDictionary *parsedMessage = [self.dataMessageManager processPacket:message];
  [[[self.mockSyncMessageManager stub] andReturnValue:@(NO)]
      didReceiveMCSSyncMessage:parsedMessage];
  OCMStub([self.mockReceiver didReceiveMessage:[OCMArg isEqual:message] withIdentifier:[OCMArg any]]);
  [self.dataMessageManager didReceiveParsedMessage:parsedMessage];
  OCMVerify([self.mockReceiver didReceiveMessage:[OCMArg any] withIdentifier:[OCMArg any]]);
}

/**
 *  Test receiving a duplicated duplex message does not notify the receiver callback.
 */
- (void)testReceivingDuplicateDuplexMessage {
  GtalkDataMessageStanza *message = [self validDuplexmessage];
  NSDictionary *parsedMessage = [self.dataMessageManager processPacket:message];
  [[[self.mockSyncMessageManager stub] andReturnValue:@(YES)]
      didReceiveMCSSyncMessage:parsedMessage];
  [[self.mockReceiver reject] didReceiveMessage:[OCMArg any] withIdentifier:[OCMArg any]];
  [self.dataMessageManager didReceiveParsedMessage:parsedMessage];
}

/**
 *  In this test we simulate a real RMQ manager and send messages simulating no
 *  active connection. Then we simulate a new connection being established and
 *  the client receives a Streaming ACK which should result in resending RMQ messages.
 */
- (void)testResendSavedMessages {
  static BOOL isClientConnected = NO;
  [[[self.mockClient stub] andDo:^(NSInvocation *invocation) {
    [invocation setReturnValue:&isClientConnected];
  }] isConnectionActive];

  // Set a fake, valid bundle identifier
  [[[self.mockDataMessageManager stub] andReturn:@"gcm-dmm-test"] categoryForUpstreamMessages];

  [FIRMessagingRmqManager removeDatabaseWithName:kRmqDatabaseName];
  FIRMessagingRmqManager *newRmqManager =
      [[FIRMessagingRmqManager alloc] initWithDatabaseName:kRmqDatabaseName];
  [newRmqManager loadRmqId];
  // have a real RMQ store
  [self.dataMessageManager setRmq2Manager:newRmqManager];

  [self addFakeFIRMessagingRegistrationToken];
  [self.dataMessageManager setDeviceAuthID:@"auth-id" secretToken:@"secret-token"];

  // send a couple of message with no connection should be saved to RMQ
  [self.dataMessageManager sendDataMessageStanza:
      [self upstreamMessageWithID:@"1" ttl:20000 delay:0]];
  [self.dataMessageManager sendDataMessageStanza:
      [self upstreamMessageWithID:@"2" ttl:20000 delay:0]];

  [NSThread sleepForTimeInterval:1.0];
  isClientConnected = YES;
  // after the usual version, login assertion we would receive a SelectiveAck
  // assuming we we weren't able to send any messages we won't delete anything
  // from the RMQ but try to resend whatever is there
  __block int didRecieveMessages = 0;
  id mockConnection = OCMClassMock([FIRMessagingConnection class]);

  BOOL (^resendMessageBlock)(id obj) = ^BOOL(id obj) {
    if ([obj isKindOfClass:[GtalkDataMessageStanza class]]) {
      GtalkDataMessageStanza *message = (GtalkDataMessageStanza *)obj;
      NSLog(@"hello resending %@, %d", message.id_p, didRecieveMessages);
      if ([@"1" isEqualToString:message.id_p]) {
        didRecieveMessages |= 1; // right most bit for 1st message
        return YES;
      } else if ([@"2" isEqualToString:message.id_p]) {
        didRecieveMessages |= (1<<1); // second from RMB for 2nd message
        return YES;
      }
    }
    return NO;
  };
  [[[mockConnection stub] andDo:^(NSInvocation *invocation) {
    // pass
  }] sendProto:[OCMArg checkWithBlock:resendMessageBlock]];

  [self.dataMessageManager resendMessagesWithConnection:mockConnection];

  // should send both messages
  XCTAssert(didRecieveMessages == 3);
  OCMVerifyAll(mockConnection);
}

- (void)testResendingExpiredMessagesFails {
  // TODO: Test that expired messages should not be sent on resend
  static BOOL isClientConnected = NO;
  [[[self.mockClient stub] andDo:^(NSInvocation *invocation) {
    [invocation setReturnValue:&isClientConnected];
  }] isConnectionActive];

  // Set a fake, valid bundle identifier
  [[[self.mockDataMessageManager stub] andReturn:@"gcm-dmm-test"] categoryForUpstreamMessages];

  [FIRMessagingRmqManager removeDatabaseWithName:kRmqDatabaseName];
  FIRMessagingRmqManager *newRmqManager =
      [[FIRMessagingRmqManager alloc] initWithDatabaseName:kRmqDatabaseName];
  [newRmqManager loadRmqId];
  // have a real RMQ store
  [self.dataMessageManager setRmq2Manager:newRmqManager];

  [self.dataMessageManager setDeviceAuthID:@"auth-id" secretToken:@"secret-token"];
  // send a message that expires in 1 sec
  [self.dataMessageManager sendDataMessageStanza:
      [self upstreamMessageWithID:@"1" ttl:1 delay:0]];

  // wait for 2 seconds (let the above message expire)
  [NSThread sleepForTimeInterval:2.0];
  isClientConnected = YES;

  id mockConnection = OCMClassMock([FIRMessagingConnection class]);

  [[mockConnection reject] sendProto:[OCMArg any]];
  [self.dataMessageManager resendMessagesWithConnection:mockConnection];

  // rmq should not have any pending messages
  [newRmqManager scanWithRmqMessageHandler:^(int64_t rmqId, int8_t tag, NSData *data) {
    XCTFail(@"RMQ should not have any message");
  }
                        dataMessageHandler:nil];
}

#pragma mark - Private

- (void)addFakeFIRMessagingRegistrationToken {
  // [[FIRMessagingDefaultsManager sharedInstance] saveAppIDToken:kFIRMessagingAppIDToken];
}

#pragma mark - Create Packet

- (GtalkDataMessageStanza *)validDataMessagePacket {
  GtalkDataMessageStanza *message = [[GtalkDataMessageStanza alloc] init];
  message.from = kMessageFrom;
  message.token = kCollapseKey;
  message.persistentId = kMessagePersistentID;
  GtalkAppData *item = [[GtalkAppData alloc] init];
  item.key = kAppDataItemKey;
  item.value = kAppDataItemValue;
  message.appDataArray = [NSMutableArray arrayWithObject:item];
  return message;
}

- (GtalkDataMessageStanza *)validDataMessageWithOnlyFrom {
  GtalkDataMessageStanza *message = [[GtalkDataMessageStanza alloc] init];
  message.from = kMessageFrom;
  message.persistentId = kMessagePersistentID;
  return message;
}

- (GtalkDataMessageStanza *)invalidDataMessageUsingReservedKeyword {
  GtalkDataMessageStanza *message = [[GtalkDataMessageStanza alloc] init];
  message.from = kMessageFrom;
  message.persistentId = kMessagePersistentID;
  GtalkAppData *item = [[GtalkAppData alloc] init];
  item.key = kAppDataItemInvalidKey;
  item.value = kAppDataItemValue;
  message.appDataArray = [NSMutableArray arrayWithObject:item];
  return message;
}

- (GtalkDataMessageStanza *)validDataMessageForFIRMessaging {
  GtalkDataMessageStanza *message = [[GtalkDataMessageStanza alloc] init];
  message.from = kMessageFrom;
  message.token = @"com.google.gcm";
  return message;
}

- (GtalkDataMessageStanza *)validDuplexmessage {
  GtalkDataMessageStanza *message = [[GtalkDataMessageStanza alloc] init];
  message.from = kMessageFrom;
  message.token = kCollapseKey;
  message.persistentId = kMessagePersistentID;
  GtalkAppData *item = [[GtalkAppData alloc] init];
  item.key = kAppDataItemKey;
  item.value = kAppDataItemValue;
  GtalkAppData *duplexItem = [[GtalkAppData alloc] init];
  duplexItem.key = @"gcm.duplex";
  duplexItem.value = @"1";
  message.appDataArray = [NSMutableArray arrayWithObjects:item, duplexItem, nil];
  return message;
}

#pragma mark - Create Message

- (NSMutableDictionary *)standardFIRMessagingMessageWithMessageID:(NSString *)messageID {
  NSDictionary *message = @{ kAppDataItemKey : kAppDataItemValue };
  return [FIRMessaging createFIRMessagingMessageWithMessage:message
                                                         to:kMessageTo
                                                     withID:messageID
                                                 timeToLive:-1
                                                      delay:0];
}

- (NSMutableDictionary *)upstreamMessageWithID:(NSString *)messageID
                                           ttl:(int64_t)ttl
                                         delay:(int)delay {
  NSDictionary *message = @{ kAppDataItemInvalidKey : kAppDataItemValue };
  return [FIRMessaging createFIRMessagingMessageWithMessage:message
                                                         to:kMessageTo
                                                     withID:messageID
                                                 timeToLive:ttl
                                                      delay:delay];
}

@end
