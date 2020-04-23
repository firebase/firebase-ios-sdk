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

#import <FirebaseInstallations/FIRInstallations.h>
#import <FirebaseInstanceID/FIRInstanceID_Private.h>
#import <GoogleUtilities/GULReachabilityChecker.h>

#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingFakeConnection.h"
#import "FirebaseMessaging/Sources/FIRMessagingClient.h"
#import "FirebaseMessaging/Sources/FIRMessagingConnection.h"
#import "FirebaseMessaging/Sources/FIRMessagingDataMessageManager.h"
#import "FirebaseMessaging/Sources/FIRMessagingRmqManager.h"
#import "FirebaseMessaging/Sources/FIRMessagingSecureSocket.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"
#import "FirebaseMessaging/Sources/Protos/GtalkCore.pbobjc.h"

static NSString *const kDeviceAuthId = @"123456";
static NSString *const kSecretToken = @"56789";

@interface FIRInstanceID (exposedForTests)

+ (FIRInstanceID *)instanceIDForTests;

@end

@interface FIRMessagingClient () <FIRMessagingConnectionDelegate>

@property(nonatomic, readwrite, strong) FIRMessagingConnection *connection;
@property(nonatomic, readwrite, assign) int64_t lastConnectedTimestamp;
@property(nonatomic, readwrite, assign) int64_t lastDisconnectedTimestamp;
@property(nonatomic, readwrite, assign) NSUInteger subscribeRetryCount;
@property(nonatomic, readwrite, assign) NSUInteger connectRetryCount;

- (NSTimeInterval)connectionTimeoutInterval;
- (void)setupConnection;

@end

@interface FIRMessagingConnection () <FIRMessagingSecureSocketDelegate>

@property(nonatomic, readwrite, strong) FIRMessagingSecureSocket *socket;

- (void)setupConnectionSocket;
- (void)connectToSocket:(FIRMessagingSecureSocket *)socket;
- (NSTimeInterval)connectionTimeoutInterval;
- (void)sendHeartbeatPing;

@end

@interface FIRMessagingSecureSocket ()

@property(nonatomic, readwrite, assign) FIRMessagingSecureSocketState state;

@end

@interface FIRMessagingClientTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRMessagingClient *client;
@property(nonatomic, readwrite, strong) id mockClient;
@property(nonatomic, readwrite, strong) id mockReachability;
@property(nonatomic, readwrite, strong) id mockRmqManager;
@property(nonatomic, readwrite, strong) id mockClientDelegate;
@property(nonatomic, readwrite, strong) id mockDataMessageManager;
@property(nonatomic, readwrite, strong) id mockInstanceID;
@property(nonatomic, readwrite, strong) id mockInstallations;

// argument callback blocks
@property(nonatomic, readwrite, copy) FIRMessagingConnectCompletionHandler connectCompletion;
@property(nonatomic, readwrite, copy) FIRMessagingTopicOperationCompletion subscribeCompletion;

@end

@implementation FIRMessagingClientTest

- (void)setUp {
  [super setUp];
  _mockClientDelegate = OCMStrictProtocolMock(@protocol(FIRMessagingClientDelegate));
  _mockReachability = OCMClassMock([GULReachabilityChecker class]);
  _mockRmqManager = OCMClassMock([FIRMessagingRmqManager class]);
  _client = [[FIRMessagingClient alloc] initWithDelegate:_mockClientDelegate
                                            reachability:_mockReachability
                                             rmq2Manager:_mockRmqManager];
  _mockClient = OCMPartialMock(_client);
  _mockDataMessageManager = OCMClassMock([FIRMessagingDataMessageManager class]);
  [_mockClient setDataMessageManager:_mockDataMessageManager];
}

- (void)tearDown {
  // remove all handlers
  [self tearDownMocksAndHandlers];
  // Mock all sockets to disconnect in a nice way
  [[[(id)self.client.connection.socket stub] andDo:^(NSInvocation *invocation) {
    self.client.connection.socket.state = kFIRMessagingSecureSocketClosed;
  }] disconnect];

  [self.client teardown];
  [super tearDown];
}

- (void)tearDownMocksAndHandlers {
  self.connectCompletion = nil;
  self.subscribeCompletion = nil;
  self.mockInstanceID = nil;
  self.mockInstallations = nil;
}

- (void)setupConnectionWithFakeLoginResult:(BOOL)loginResult
                          heartbeatTimeout:(NSTimeInterval)heartbeatTimeout {
  [self setupFakeConnectionWithClass:[FIRMessagingFakeConnection class]
          withSetupCompletionHandler:^(FIRMessagingConnection *connection) {
            FIRMessagingFakeConnection *fakeConnection = (FIRMessagingFakeConnection *)connection;
            fakeConnection.shouldFakeSuccessLogin = loginResult;
            fakeConnection.fakeConnectionTimeout = heartbeatTimeout;
          }];
}

- (void)testSetupConnection {
  XCTAssertNil(self.client.connection);
  [self.client setupConnection];
  XCTAssertNotNil(self.client.connection);
  XCTAssertNotNil(self.client.connection.delegate);
}

- (void)testConnectSuccess_withCachedFcmDefaults {
  [self addFIRMessagingPreferenceKeysToUserDefaults];

  // login request should be successful
  [self setupConnectionWithFakeLoginResult:YES heartbeatTimeout:1.0];

  XCTestExpectation *setupConnection =
      [self expectationWithDescription:@"Fcm should successfully setup a connection"];

  [self.client connectWithHandler:^(NSError *error) {
    XCTAssertNil(error);
    [setupConnection fulfill];
  }];

  [self waitForExpectationsWithTimeout:1.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testsConnectWithNoNetworkError_withCachedFcmDefaults {
  // connection timeout interval is 1s
  [[[self.mockClient stub] andReturnValue:@(1)] connectionTimeoutInterval];
  [self addFIRMessagingPreferenceKeysToUserDefaults];

  [self setupFakeConnectionWithClass:[FIRMessagingFakeFailConnection class]
          withSetupCompletionHandler:^(FIRMessagingConnection *connection) {
            FIRMessagingFakeFailConnection *fakeConnection =
                (FIRMessagingFakeFailConnection *)connection;
            fakeConnection.shouldFakeSuccessLogin = NO;
            // should fail only once
            fakeConnection.failCount = 1;
          }];

  XCTestExpectation *connectExpectation =
      [self expectationWithDescription:@"Should retry connection if once failed"];
  [self.client connectWithHandler:^(NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqual(kFIRMessagingErrorCodeNetwork, error.code);
    [connectExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:10.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testConnectSuccessOnSecondTry_withCachedFcmDefaults {
  // connection timeout interval is 1s
  [[[self.mockClient stub] andReturnValue:@(1)] connectionTimeoutInterval];
  [self addFIRMessagingPreferenceKeysToUserDefaults];

  // the network is available
  [[[self.mockReachability stub] andReturnValue:@(kGULReachabilityViaWifi)] reachabilityStatus];

  [self setupFakeConnectionWithClass:[FIRMessagingFakeFailConnection class]
          withSetupCompletionHandler:^(FIRMessagingConnection *connection) {
            FIRMessagingFakeFailConnection *fakeConnection =
                (FIRMessagingFakeFailConnection *)connection;
            fakeConnection.shouldFakeSuccessLogin = NO;
            // should fail only once
            fakeConnection.failCount = 1;
          }];

  XCTestExpectation *connectExpectation =
      [self expectationWithDescription:@"Should retry connection if once failed"];
  [self.client connectWithHandler:^(NSError *error) {
    XCTAssertNil(error);
    [connectExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:10.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                                 XCTAssertTrue([self.client isConnectionActive]);
                               }];
}

- (void)testDisconnectAfterConnect {
  // setup the connection
  [self addFIRMessagingPreferenceKeysToUserDefaults];

  // login request should be successful
  // Connection should not timeout because of heartbeat failure. Therefore set heartbeatTimeout
  // to a large value.
  [self setupConnectionWithFakeLoginResult:YES heartbeatTimeout:100.0];

  [[[self.mockClient stub] andReturnValue:@(1)] connectionTimeoutInterval];

  // the network is available
  [[[self.mockReachability stub] andReturnValue:@(kGULReachabilityViaWifi)] reachabilityStatus];

  XCTestExpectation *setupConnection =
      [self expectationWithDescription:@"Fcm should successfully setup a connection"];

  __block int timesConnected = 0;
  FIRMessagingConnectCompletionHandler handler = ^(NSError *error) {
    XCTAssertNil(error);
    timesConnected++;
    if (timesConnected == 1) {
      [setupConnection fulfill];
      // disconnect the connection after some time
      FIRMessagingFakeConnection *fakeConnection =
          (FIRMessagingFakeConnection *)[self.mockClient connection];
      dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (0.2 * NSEC_PER_SEC));
      dispatch_after(time, dispatch_get_main_queue(), ^{
        // disconnect now
        [(FIRMessagingFakeConnection *)fakeConnection mockSocketDisconnect];
        [(FIRMessagingFakeConnection *)fakeConnection disconnectNow];
      });
    } else {
      XCTFail(@"Fcm should only connect at max 2 times");
    }
  };
  [self.mockClient connectWithHandler:handler];

  // reconnect after disconnect
  XCTAssertTrue(self.client.isConnectionActive);

  [self waitForExpectationsWithTimeout:10.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                                 XCTAssertNotEqual(self.client.lastDisconnectedTimestamp, 0);
                                 XCTAssertTrue(self.client.isConnectionActive);
                               }];
}

#pragma mark - Private Helpers

- (void)setupFakeConnectionWithClass:(Class)connectionClass
          withSetupCompletionHandler:(void (^)(FIRMessagingConnection *))handler {
  [[[self.mockClient stub] andDo:^(NSInvocation *invocation) {
    self.client.connection =
        [[connectionClass alloc] initWithAuthID:kDeviceAuthId
                                          token:kSecretToken
                                           host:[FIRMessagingFakeConnection fakeHost]
                                           port:[FIRMessagingFakeConnection fakePort]
                                        runLoop:[NSRunLoop mainRunLoop]
                                    rmq2Manager:self.mockRmqManager
                                     fcmManager:self.mockDataMessageManager];
    self.client.connection.delegate = self.client;
    handler(self.client.connection);
  }] setupConnection];
}

- (void)addFIRMessagingPreferenceKeysToUserDefaults {
  // `+[FIRInstallations installations]` supposed to be used on `-[FIRInstanceID start]` to get
  // `FIRInstallations` default instance. Need to stub it before.
  self.mockInstallations = OCMClassMock([FIRInstallations class]);
  OCMStub([self.mockInstallations installations]).andReturn(self.mockInstallations);

  self.mockInstanceID = OCMPartialMock([FIRInstanceID instanceIDForTests]);
  OCMStub([self.mockInstanceID tryToLoadValidCheckinInfo]).andReturn(YES);
  OCMStub([self.mockInstanceID deviceAuthID]).andReturn(kDeviceAuthId);
  OCMStub([self.mockInstanceID secretToken]).andReturn(kSecretToken);
}

@end
