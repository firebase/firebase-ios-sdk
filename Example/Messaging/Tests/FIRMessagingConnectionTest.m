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

#import <OCMock/OCMock.h>

#import "Protos/GtalkCore.pbobjc.h"

#import "FIRMessagingClient.h"
#import "FIRMessagingConnection.h"
#import "FIRMessagingDataMessageManager.h"
#import "FIRMessagingFakeConnection.h"
#import "FIRMessagingRmqManager.h"
#import "FIRMessagingSecureSocket.h"
#import "FIRMessagingUtilities.h"

static NSString *const kDeviceAuthId = @"123456";
static NSString *const kSecretToken = @"56789";

// used to verify if we are sending in the right proto or not.
// set it to negative value to disable this check
static FIRMessagingProtoTag currentProtoSendTag;

@interface FIRMessagingSecureSocket ()

@property(nonatomic, readwrite, assign) FIRMessagingSecureSocketState state;

@end

@interface FIRMessagingSecureSocket (test_FIRMessagingConnection)

- (void)_successconnectToHost:(NSString *)host
                         port:(NSUInteger)port
                    onRunLoop:(NSRunLoop *)runLoop;
- (void)_fakeSuccessfulSocketConnect;

@end

@implementation FIRMessagingSecureSocket (test_FIRMessagingConnection)

- (void)_successconnectToHost:(NSString *)host
                         port:(NSUInteger)port
                    onRunLoop:(NSRunLoop *)runLoop {
  // created ports, opened streams
  // invoke callback async
  [self _fakeSuccessfulSocketConnect];
}

- (void)_fakeSuccessfulSocketConnect {
  self.state = kFIRMessagingSecureSocketOpen;
  [self.delegate secureSocketDidConnect:self];
}

@end

// make sure these are defined in FIRMessagingConnection
@interface FIRMessagingConnection () <FIRMessagingSecureSocketDelegate>

@property(nonatomic, readwrite, assign) int64_t lastLoginServerTimestamp;
@property(nonatomic, readwrite, assign) int lastStreamIdAcked;
@property(nonatomic, readwrite, assign) int inStreamId;
@property(nonatomic, readwrite, assign) int outStreamId;

@property(nonatomic, readwrite, strong) FIRMessagingSecureSocket *socket;

@property(nonatomic, readwrite, strong) NSMutableArray *unackedS2dIds;
@property(nonatomic, readwrite, strong) NSMutableDictionary *ackedS2dMap;
@property(nonatomic, readwrite, strong) NSMutableArray *d2sInfos;

- (void)setupConnectionSocket;
- (void)connectToSocket:(FIRMessagingSecureSocket *)socket;
- (NSTimeInterval)connectionTimeoutInterval;
- (void)sendHeartbeatPing;

@end


@interface FIRMessagingConnectionTest : XCTestCase

@property(nonatomic, readwrite, assign) BOOL didSuccessfullySendData;

@property(nonatomic, readwrite, strong) NSUserDefaults *userDefaults;
@property(nonatomic, readwrite, strong) FIRMessagingConnection *fakeConnection;
@property(nonatomic, readwrite, strong) id mockClient;
@property(nonatomic, readwrite, strong) id mockConnection;
@property(nonatomic, readwrite, strong) id mockRmq;
@property(nonatomic, readwrite, strong) id mockDataMessageManager;

@end

@implementation FIRMessagingConnectionTest

- (void)setUp {
  [super setUp];
  _userDefaults = [[NSUserDefaults alloc] init];
  _mockRmq = OCMClassMock([FIRMessagingRmqManager class]);
  _mockDataMessageManager = OCMClassMock([FIRMessagingDataMessageManager class]);
  // fake connection is only used to simulate the socket behavior
  _fakeConnection = [[FIRMessagingFakeConnection alloc] initWithAuthID:kDeviceAuthId
                                                        token:kSecretToken
                                                         host:[FIRMessagingFakeConnection fakeHost]
                                                         port:[FIRMessagingFakeConnection fakePort]
                                                      runLoop:[NSRunLoop currentRunLoop]
                                                  rmq2Manager:_mockRmq
                                                   fcmManager:_mockDataMessageManager];

  _mockClient = OCMClassMock([FIRMessagingClient class]);
  _fakeConnection.delegate = _mockClient;
  _mockConnection = OCMPartialMock(_fakeConnection);
  _didSuccessfullySendData = NO;
}

- (void)tearDown {
  [self.fakeConnection teardown];
  [super tearDown];
}

- (void)testInitialConnectionNotConnected {
  XCTAssertEqual(kFIRMessagingConnectionNotConnected, [self.fakeConnection state]);
}

- (void)testSuccessfulSocketConnection {
  [self.fakeConnection signIn];

  // should be connected now
  XCTAssertEqual(kFIRMessagingConnectionConnected, self.fakeConnection.state);
  XCTAssertEqual(0, self.fakeConnection.lastStreamIdAcked);
  XCTAssertEqual(0, self.fakeConnection.inStreamId);
  XCTAssertEqual(0, self.fakeConnection.ackedS2dMap.count);
  XCTAssertEqual(0, self.fakeConnection.unackedS2dIds.count);

  [self stubSocketDisconnect:self.fakeConnection.socket];
}

- (void)testSignInAndThenSignOut {
  [self.fakeConnection signIn];
  [self stubSocketDisconnect:self.fakeConnection.socket];
  [self.fakeConnection signOut];
  XCTAssertEqual(kFIRMessagingSecureSocketClosed, self.fakeConnection.socket.state);
}

- (void)testSuccessfulSignIn {
  [self setupSuccessfulLoginRequestWithConnection:self.fakeConnection];
  XCTAssertEqual(self.fakeConnection.state, kFIRMessagingConnectionSignedIn);
  XCTAssertEqual(self.fakeConnection.outStreamId, 2);
  XCTAssertTrue(self.didSuccessfullySendData);
}

- (void)testSignOut_whenSignedIn {
  [self setupSuccessfulLoginRequestWithConnection:self.fakeConnection];

  // should be signed in now
  id mockSocket = self.fakeConnection.socket;
  [self.fakeConnection signOut];
  XCTAssertEqual(self.fakeConnection.state, kFIRMessagingConnectionNotConnected);
  XCTAssertEqual(self.fakeConnection.outStreamId, 3);
  XCTAssertNil([(FIRMessagingSecureSocket *)mockSocket delegate]);
  XCTAssertTrue(self.didSuccessfullySendData);
  OCMVerify([mockSocket sendData:[OCMArg any]
                         withTag:kFIRMessagingProtoTagClose
                           rmqId:[OCMArg isNil]]);
}

- (void)testReceiveCloseProto {
  [self setupSuccessfulLoginRequestWithConnection:self.fakeConnection];

  id mockSocket = self.fakeConnection.socket;
  GtalkClose *close = [[GtalkClose alloc] init];
  [self.fakeConnection secureSocket:mockSocket
                     didReceiveData:[close data]
                            withTag:kFIRMessagingProtoTagClose];
  XCTAssertEqual(self.fakeConnection.state, kFIRMessagingConnectionNotConnected);
  XCTAssertTrue(self.didSuccessfullySendData);
}

- (void)testLoginRequest {
  XCTAssertEqual(kFIRMessagingConnectionNotConnected, [self.fakeConnection state]);
  [self.fakeConnection setupConnectionSocket];

  id socketMock = OCMPartialMock(self.fakeConnection.socket);
  self.fakeConnection.socket = socketMock;

  [[[socketMock stub]
      andDo:^(NSInvocation *invocation) {
        [socketMock _fakeSuccessfulSocketConnect];
      }]
      connectToHost:[FIRMessagingFakeConnection fakeHost]
               port:[FIRMessagingFakeConnection fakePort]
          onRunLoop:[OCMArg any]];

  [[[socketMock stub] andCall:@selector(_sendData:withTag:rmqId:) onObject:self]
      // do nothing
      sendData:[OCMArg any]
       withTag:kFIRMessagingProtoTagLoginRequest
         rmqId:[OCMArg isNil]];

  // swizzle disconnect socket
  OCMVerify([[[socketMock stub] andCall:@selector(_disconnectSocket)
                               onObject:self] disconnect]);

  currentProtoSendTag = kFIRMessagingProtoTagLoginRequest;
  // send login request
  [self.fakeConnection connectToSocket:socketMock];

  // verify login request sent
  XCTAssertEqual(1, self.fakeConnection.outStreamId);
  XCTAssertTrue(self.didSuccessfullySendData);
}

- (void)testLoginRequest_withPendingMessagesInRmq {
  // TODO: add fake messages to rmq and test login request with them
}

- (void)testLoginRequest_withSuccessfulResponse {
  [self setupSuccessfulLoginRequestWithConnection:self.fakeConnection];

  OCMVerify([self.mockClient didLoginWithConnection:[OCMArg isEqual:self.fakeConnection]]);

  // should send a heartbeat ping too
  XCTAssertEqual(self.fakeConnection.outStreamId, 2);
  // update for the received login response proto
  XCTAssertEqual(self.fakeConnection.inStreamId, 1);
  // did send data during login
  XCTAssertTrue(self.didSuccessfullySendData);
}

- (void)testConnectionTimeout {
  XCTAssertEqual(kFIRMessagingConnectionNotConnected, [self.fakeConnection state]);

  [self.fakeConnection setupConnectionSocket];

  id socketMock = OCMPartialMock(self.fakeConnection.socket);
  self.fakeConnection.socket = socketMock;

  [[[socketMock stub]
      andDo:^(NSInvocation *invocation) {
        [socketMock _fakeSuccessfulSocketConnect];
      }]
      connectToHost:[FIRMessagingFakeConnection fakeHost]
               port:[FIRMessagingFakeConnection fakePort]
          onRunLoop:[OCMArg any]];

  [self.fakeConnection connectToSocket:socketMock];
  XCTAssertEqual(self.fakeConnection.state, kFIRMessagingConnectionConnected);

  GtalkLoginResponse *response = [[GtalkLoginResponse alloc] init];
  [response setId_p:@""];

  // connection timeout has been scheduled
  // should disconnect since we wait for more time
  XCTestExpectation *disconnectExpectation =
      [self expectationWithDescription:
          @"FCM connection should timeout without receiving "
          @"any data for a timeout interval"];
  [[[socketMock stub]
      andDo:^(NSInvocation *invocation) {
        [self _disconnectSocket];
        [disconnectExpectation fulfill];
      }] disconnect];

  // simulate connection receiving login response
  [self.fakeConnection secureSocket:socketMock
                     didReceiveData:[response data]
                            withTag:kFIRMessagingProtoTagLoginResponse];

  [self waitForExpectationsWithTimeout:2.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];

  [socketMock verify];
  XCTAssertEqual(self.fakeConnection.state, kFIRMessagingConnectionNotConnected);
}

- (void)testDataMessageReceive {
  [self setupSuccessfulLoginRequestWithConnection:self.fakeConnection];
  GtalkDataMessageStanza *stanza = [[GtalkDataMessageStanza alloc] init];
  [stanza setCategory:@"special"];
  [stanza setFrom:@"xyz"];
  [self.fakeConnection secureSocket:self.fakeConnection.socket
                     didReceiveData:[stanza data]
                            withTag:kFIRMessagingProtoTagDataMessageStanza];

  OCMVerify([self.mockClient connectionDidRecieveMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
      GtalkDataMessageStanza *message = (GtalkDataMessageStanza *)obj;
      return [[message category] isEqual:@"special"] && [[message from] isEqual:@"xyz"];
  }]]);
  // did send data while login
  XCTAssertTrue(self.didSuccessfullySendData);
}

- (void)testDataMessageReceiveWithInvalidTag {
  [self setupSuccessfulLoginRequestWithConnection:self.fakeConnection];
  GtalkDataMessageStanza *stanza = [[GtalkDataMessageStanza alloc] init];
  BOOL didCauseException = NO;
  @try {
    [self.fakeConnection secureSocket:self.fakeConnection.socket
                       didReceiveData:[stanza data]
                              withTag:kFIRMessagingProtoTagInvalid];
  } @catch (NSException *exception) {
    didCauseException = YES;
  } @finally {
  }
  XCTAssertFalse(didCauseException);
}

- (void)testDataMessageReceiveWithTagThatDoesntEquateToClass {
  [self setupSuccessfulLoginRequestWithConnection:self.fakeConnection];
  GtalkDataMessageStanza *stanza = [[GtalkDataMessageStanza alloc] init];
  BOOL didCauseException = NO;
  int8_t tagWhichDoesntEquateToClass = INT8_MAX;
  @try {
    [self.fakeConnection secureSocket:self.fakeConnection.socket
                       didReceiveData:[stanza data]
                              withTag:tagWhichDoesntEquateToClass];
  } @catch (NSException *exception) {
    didCauseException = YES;
  } @finally {
  }
  XCTAssertFalse(didCauseException);
}

- (void)testHeartbeatSend {
  [self setupSuccessfulLoginRequestWithConnection:self.fakeConnection]; // outstreamId should be 2
  XCTAssertEqual(self.fakeConnection.outStreamId, 2);
  [self.fakeConnection sendHeartbeatPing];
  id mockSocket = self.fakeConnection.socket;
  OCMVerify([mockSocket sendData:[OCMArg any]
                         withTag:kFIRMessagingProtoTagHeartbeatPing
                           rmqId:[OCMArg isNil]]);
  XCTAssertEqual(self.fakeConnection.outStreamId, 3);
  // did send data
  XCTAssertTrue(self.didSuccessfullySendData);
}

- (void)testHeartbeatReceived {
  [self setupSuccessfulLoginRequestWithConnection:self.fakeConnection];
  XCTAssertEqual(self.fakeConnection.outStreamId, 2);
  GtalkHeartbeatPing *ping = [[GtalkHeartbeatPing alloc] init];
  [self.fakeConnection secureSocket:self.fakeConnection.socket
                     didReceiveData:[ping data]
                            withTag:kFIRMessagingProtoTagHeartbeatPing];
  XCTAssertEqual(self.fakeConnection.inStreamId, 2);
  id mockSocket = self.fakeConnection.socket;
  OCMVerify([mockSocket sendData:[OCMArg any]
                         withTag:kFIRMessagingProtoTagHeartbeatAck
                           rmqId:[OCMArg isNil]]);
  XCTAssertEqual(self.fakeConnection.outStreamId, 3);
  // did send data
  XCTAssertTrue(self.didSuccessfullySendData);
}

// TODO: Add tests for Selective/Stream ACK's

#pragma mark - Stubs

- (void)_disconnectSocket {
  self.fakeConnection.socket.state = kFIRMessagingSecureSocketClosed;
}

- (void)_sendData:(NSData *)data withTag:(int8_t)tag rmqId:(NSString *)rmqId {
  NSLog(@"FIRMessaging Socket: Send data with Tag: %d rmq: %@", tag, rmqId);
  if (currentProtoSendTag > 0) {
    XCTAssertEqual(tag, currentProtoSendTag);
  }
  self.didSuccessfullySendData = YES;
}

#pragma mark - Private Helpers

/**
 * Stub socket disconnect to prevent spurious assert. Since we mock the socket object being
 * used by the connection, while we teardown the client we also disconnect the socket to tear
 * it down. Since we are using mock sockets we need to stub the `disconnect` to prevent some
 * assertions from taking place.
 * The `_disconectSocket` has the gist of the actual socket disconnect without any assertions.
 */
- (void)stubSocketDisconnect:(id)mockSocket {
  [[[mockSocket stub] andCall:@selector(_disconnectSocket)
                     onObject:self] disconnect];

  [mockSocket verify];
}

- (void)mockSuccessfulSignIn {
  XCTAssertEqual(kFIRMessagingConnectionNotConnected, [self.fakeConnection state]);
  [self.fakeConnection setupConnectionSocket];

  id socketMock = OCMPartialMock(self.fakeConnection.socket);
  self.fakeConnection.socket = socketMock;

  [[[socketMock stub]
      andDo:^(NSInvocation *invocation) {
        [socketMock _fakeSuccessfulSocketConnect];
      }]
      connectToHost:[FIRMessagingFakeConnection fakeHost]
               port:[FIRMessagingFakeConnection fakePort]
          onRunLoop:[OCMArg any]];

  [[[socketMock stub] andCall:@selector(_sendData:withTag:rmqId:) onObject:self]
      // do nothing
      sendData:[OCMArg any]
       withTag:kFIRMessagingProtoTagLoginRequest
         rmqId:[OCMArg isNil]];

  // send login request
  currentProtoSendTag = kFIRMessagingProtoTagLoginRequest;
  [self.fakeConnection connectToSocket:socketMock];

  GtalkLoginResponse *response = [[GtalkLoginResponse alloc] init];
  [response setId_p:@""];

  // simulate connection receiving login response
  [self.fakeConnection secureSocket:socketMock
                     didReceiveData:[response data]
                            withTag:kFIRMessagingProtoTagLoginResponse];

  OCMVerify([self.mockClient didLoginWithConnection:[OCMArg isEqual:self.fakeConnection]]);

  // should receive data
  XCTAssertTrue(self.didSuccessfullySendData);
  // should send a heartbeat ping too
  XCTAssertEqual(self.fakeConnection.outStreamId, 2);
  // update for the received login response proto
  XCTAssertEqual(self.fakeConnection.inStreamId, 1);
}

- (void)setupSuccessfulLoginRequestWithConnection:(FIRMessagingConnection *)fakeConnection {
  [fakeConnection setupConnectionSocket];

  id socketMock = OCMPartialMock(fakeConnection.socket);
  fakeConnection.socket = socketMock;

  [[[socketMock stub]
      andDo:^(NSInvocation *invocation) {
        [socketMock _fakeSuccessfulSocketConnect];
      }]
      connectToHost:[FIRMessagingFakeConnection fakeHost]
               port:[FIRMessagingFakeConnection fakePort]
          onRunLoop:[OCMArg any]];

  [[[socketMock stub] andCall:@selector(_sendData:withTag:rmqId:) onObject:self]
       // do nothing
       sendData:[OCMArg any]
        withTag:kFIRMessagingProtoTagLoginRequest
          rmqId:[OCMArg isNil]];

  // swizzle disconnect socket
  [[[socketMock stub] andCall:@selector(_disconnectSocket)
                     onObject:self] disconnect];

  // send login request
  currentProtoSendTag = kFIRMessagingProtoTagLoginRequest;
  [fakeConnection connectToSocket:socketMock];

  GtalkLoginResponse *response = [[GtalkLoginResponse alloc] init];
  [response setId_p:@""];

  // simulate connection receiving login response
  [fakeConnection secureSocket:socketMock
                didReceiveData:[response data]
                       withTag:kFIRMessagingProtoTagLoginResponse];
}

@end
