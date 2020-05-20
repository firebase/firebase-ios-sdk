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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseMessaging/Sources/FIRMessagingConnection.h"
#import "FirebaseMessaging/Sources/FIRMessagingSecureSocket.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/Protos/GtalkCore.pbobjc.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingFakeSocket.h"

@interface FIRMessagingConnection ()

+ (GtalkLoginRequest *)loginRequestWithToken:(NSString *)token authID:(NSString *)authID;

@end

@interface FIRMessagingSecureSocket () <NSStreamDelegate>

@property(nonatomic, readwrite, assign) FIRMessagingSecureSocketState state;
@property(nonatomic, readwrite, strong) NSInputStream *inStream;
@property(nonatomic, readwrite, strong) NSOutputStream *outStream;

@property(nonatomic, readwrite, assign) BOOL isVersionSent;
@property(nonatomic, readwrite, assign) BOOL isVersionReceived;
@property(nonatomic, readwrite, assign) BOOL isInStreamOpen;
@property(nonatomic, readwrite, assign) BOOL isOutStreamOpen;

@property(nonatomic, readwrite, strong) NSRunLoop *runLoop;

- (BOOL)performRead;

@end

typedef void (^FIRMessagingTestSocketDisconnectHandler)(void);
typedef void (^FIRMessagingTestSocketConnectHandler)(void);

@interface FIRMessagingSecureSocketTest : XCTestCase <FIRMessagingSecureSocketDelegate>

@property(nonatomic, readwrite, strong) FIRMessagingFakeSocket *socket;
@property(nonatomic, readwrite, strong) id mockSocket;
@property(nonatomic, readwrite, strong) NSError *protoParseError;
@property(nonatomic, readwrite, strong) GPBMessage *protoReceived;
@property(nonatomic, readwrite, assign) int8_t protoTagReceived;

@property(nonatomic, readwrite, copy) FIRMessagingTestSocketDisconnectHandler disconnectHandler;
@property(nonatomic, readwrite, copy) FIRMessagingTestSocketConnectHandler connectHandler;

@end

static BOOL isSafeToDisconnectSocket = NO;

@implementation FIRMessagingSecureSocketTest

- (void)setUp {
  [super setUp];
  isSafeToDisconnectSocket = NO;
  self.protoParseError = nil;
  self.protoReceived = nil;
  self.protoTagReceived = 0;
}

- (void)tearDown {
  self.disconnectHandler = nil;
  self.connectHandler = nil;
  isSafeToDisconnectSocket = YES;
  [self.socket disconnect];
  [super tearDown];
}

#pragma mark - Test Reading

- (void)testSendingVersion {
  // read as soon as 1 byte is written
  [self createAndConnectSocketWithBufferSize:1];
  uint8_t versionByte = 40;
  [self.socket.outStream write:&versionByte maxLength:1];

  [[[self.mockSocket stub] andDo:^(NSInvocation *invocation) {
    XCTAssertTrue(isSafeToDisconnectSocket, @"Should not disconnect socket now");
  }] disconnect];
  XCTestExpectation *shouldAcceptVersionExpectation =
      [self expectationWithDescription:@"Socket should accept version"];
  dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC));
  dispatch_after(delay, dispatch_get_main_queue(), ^{
    XCTAssertTrue(self.socket.isVersionReceived);
    [shouldAcceptVersionExpectation fulfill];
  });

  [self waitForExpectationsWithTimeout:3.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testReceivingDataMessage {
  [self createAndConnectSocketWithBufferSize:61];
  [self writeVersionToOutStream];
  GtalkDataMessageStanza *message = [[GtalkDataMessageStanza alloc] init];
  [message setCategory:@"socket-test-category"];
  [message setFrom:@"socket-test-from"];
  FIRMessagingSetLastStreamId(message, 2);
  FIRMessagingSetRmq2Id(message, @"socket-test-rmq");

  XCTestExpectation *dataExpectation =
      [self expectationWithDescription:@"FIRMessaging socket should receive data message"];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [self.socket sendData:[message data]
                                 withTag:kFIRMessagingProtoTagDataMessageStanza
                                   rmqId:FIRMessagingGetRmq2Id(message)];
                 });

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   XCTAssertEqual(self.protoTagReceived, kFIRMessagingProtoTagDataMessageStanza);
                   [dataExpectation fulfill];
                 });

  [self waitForExpectationsWithTimeout:5.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

#pragma mark - Writing

- (void)testLoginRequest {
  [self createAndConnectSocketWithBufferSize:99];

  XCTestExpectation *loginExpectation =
      [self expectationWithDescription:@"Socket send valid login proto"];
  [self writeVersionToOutStream];
  GtalkLoginRequest *loginRequest = [FIRMessagingConnection loginRequestWithToken:@"gcmtoken"
                                                                           authID:@"gcmauthid"];
  FIRMessagingSetLastStreamId(loginRequest, 1);

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [self.socket sendData:[loginRequest data]
                                 withTag:FIRMessagingGetTagForProto(loginRequest)
                                   rmqId:FIRMessagingGetRmq2Id(loginRequest)];
                 });

  dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC));
  dispatch_after(delay, dispatch_get_main_queue(), ^{
    XCTAssertTrue(self.socket.isVersionReceived);
    XCTAssertEqual(self.protoTagReceived, kFIRMessagingProtoTagLoginRequest);
    [loginExpectation fulfill];
  });

  [self waitForExpectationsWithTimeout:6.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testSendingImproperData {
  [self createAndConnectSocketWithBufferSize:124];
  [self writeVersionToOutStream];

  NSString *randomString = @"some random data string";
  NSData *randomData = [randomString dataUsingEncoding:NSUTF8StringEncoding];

  XCTestExpectation *parseErrorExpectation =
      [self expectationWithDescription:@"Sending improper data results in a parse error"];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [self.socket sendData:randomData withTag:3 rmqId:@"some-random-rmq-id"];
                 });

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   if (self.protoParseError != nil) {
                     [parseErrorExpectation fulfill];
                   }
                 });

  [self waitForExpectationsWithTimeout:3.0 handler:nil];
}

- (void)testSendingDataWithImproperTag {
  [self createAndConnectSocketWithBufferSize:124];
  [self writeVersionToOutStream];
  const char dataString[] = {0x02, 0x02, 0x11, 0x11, 0x11, 0x11};  // tag 10, random data
  NSData *randomData = [NSData dataWithBytes:dataString length:6];

  // Create an expectation for a method which should not be invoked during this test.
  // This is required to allow us to wait for the socket stream to be read and
  // processed by FIRMessagingSecureSocket
  OCMExpect([self.mockSocket disconnect]);

  NSTimeInterval sendDelay = 2.0;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(sendDelay * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [self.socket sendData:randomData withTag:10 rmqId:@"some-random-rmq-id"];
                 });

  @try {
    // While waiting to verify this call, an exception should be thrown
    // trying to parse the random data in our delegate.
    // Wait slightly longer than the sendDelay, to allow for the parsing
    OCMVerifyAllWithDelay(self.mockSocket, sendDelay + 0.25);
    XCTFail(@"Invalid data being read should have thrown an exception.");
  } @catch (NSException *exception) {
    XCTAssertNotNil(exception);
  } @finally {
  }
}

- (void)testDisconnect {
  [self createAndConnectSocketWithBufferSize:1];
  [self writeVersionToOutStream];
  // version read and written let's disconnect
  XCTestExpectation *disconnectExpectation =
      [self expectationWithDescription:@"socket should disconnect properly"];
  self.disconnectHandler = ^{
    [disconnectExpectation fulfill];
  };

  [self.socket disconnect];

  [self waitForExpectationsWithTimeout:5.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];

  XCTAssertNil(self.socket.inStream);
  XCTAssertNil(self.socket.outStream);
  XCTAssertEqual(self.socket.state, kFIRMessagingSecureSocketClosed);
}

- (void)testSocketOpening {
  XCTestExpectation *openSocketExpectation =
      [self expectationWithDescription:@"Socket should open properly"];
  self.connectHandler = ^{
    [openSocketExpectation fulfill];
  };
  [self createAndConnectSocketWithBufferSize:1];
  [self writeVersionToOutStream];

  [self waitForExpectationsWithTimeout:10.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];

  XCTAssertTrue(self.socket.isInStreamOpen);
  XCTAssertTrue(self.socket.isOutStreamOpen);
}

#pragma mark - FIRMessagingSecureSocketDelegate protocol

- (void)secureSocket:(FIRMessagingSecureSocket *)socket
      didReceiveData:(NSData *)data
             withTag:(int8_t)tag {
  NSError *error;
  GPBMessage *proto = [FIRMessagingGetClassForTag((FIRMessagingProtoTag)tag) parseFromData:data
                                                                                     error:&error];
  self.protoParseError = error;
  self.protoReceived = proto;
  self.protoTagReceived = tag;
}

- (void)secureSocket:(FIRMessagingSecureSocket *)socket
    didSendProtoWithTag:(int8_t)tag
                  rmqId:(NSString *)rmqId {
  // do nothing
}

- (void)secureSocketDidConnect:(FIRMessagingSecureSocket *)socket {
  if (self.connectHandler) {
    self.connectHandler();
  }
}

- (void)didDisconnectWithSecureSocket:(FIRMessagingSecureSocket *)socket {
  if (self.disconnectHandler) {
    self.disconnectHandler();
  }
}

#pragma mark - Private Helpers

- (void)createAndConnectSocketWithBufferSize:(uint8_t)bufferSize {
  self.socket = [[FIRMessagingFakeSocket alloc] initWithBufferSize:bufferSize];
  self.mockSocket = OCMPartialMock(self.socket);
  self.socket.delegate = self;

  [self.socket connectToHost:@"localhost" port:6234 onRunLoop:[NSRunLoop mainRunLoop]];
}

- (void)writeVersionToOutStream {
  uint8_t versionByte = 40;
  [self.socket.outStream write:&versionByte maxLength:1];
  // don't resend the version
  self.socket.isVersionSent = YES;
}

@end
