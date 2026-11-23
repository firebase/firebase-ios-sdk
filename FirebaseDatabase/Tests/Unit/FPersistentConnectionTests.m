/*
 * Copyright 2026 Google LLC
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

#import "FirebaseDatabase/Sources/Api/FIRDatabaseConfig.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Core/FPersistentConnection.h"
#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Realtime/FConnection.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

// The value of `ConnectionStateConnecting` in FPersistentConnection.m.
static const int kConnectionStateConnecting = 2;

/** A realtime connection that records the requests sent through it instead of using a socket. */
@interface FRecordingConnection : FConnection

@property(nonatomic, strong) NSMutableArray<NSDictionary *> *sentRequests;
/** The sent requests whose action is a get. */
@property(nonatomic, readonly) NSArray<NSDictionary *> *sentGets;

@end

@implementation FRecordingConnection

- (instancetype)init {
  self = [super init];
  if (self) {
    _sentRequests = [NSMutableArray array];
  }
  return self;
}

- (void)open {
}

- (void)close {
}

- (void)sendRequest:(NSDictionary *)dataMsg sensitive:(BOOL)sensitive {
  [self.sentRequests addObject:dataMsg];
}

- (NSArray<NSDictionary *> *)sentGets {
  NSMutableArray<NSDictionary *> *gets = [NSMutableArray array];
  for (NSDictionary *request in self.sentRequests) {
    if ([request[kFWPRequestAction] isEqualToString:kFWPRequestActionGet]) {
      [gets addObject:request];
    }
  }
  return gets;
}

@end

@interface FPersistentConnectionTestDouble : FPersistentConnection

@property(nonatomic, strong) NSMutableArray<NSString *> *interruptedReasons;
@property(nonatomic, strong) NSMutableArray<NSString *> *resumedReasons;

@end

@implementation FPersistentConnectionTestDouble

- (void)interruptForReason:(NSString *)reason {
  [self.interruptedReasons addObject:reason];
}

- (void)resumeForReason:(NSString *)reason {
  [self.resumedReasons addObject:reason];
}

@end

@interface FPersistentConnection (Testing)

- (void)systemClockDidChange:(NSNotification *)notification;
- (void)onDataPushWithAction:(NSString *)action andBody:(NSDictionary *)body;
- (void)sendOnDisconnectAction:(NSString *)action
                       forPath:(NSString *)pathString
                      withData:(id)data
                   andCallback:(fbt_void_nsstring_nsstring)callback;

@end

// Records whether the connection forwarded a server push to its delegate so a
// malformed message can be asserted to have been dropped rather than applied.
@interface FPersistentConnectionRecordingDelegate : NSObject <FPersistentConnectionDelegate>

@property(nonatomic) BOOL didReceiveDataUpdate;
@property(nonatomic) BOOL didReceiveRangeMerge;

@end

@implementation FPersistentConnectionRecordingDelegate

- (void)onDataUpdate:(FPersistentConnection *)fpconnection
             forPath:(NSString *)pathString
             message:(id)message
             isMerge:(BOOL)isMerge
               tagId:(NSNumber *)tagId {
  self.didReceiveDataUpdate = YES;
}

- (void)onRangeMerge:(NSArray *)ranges forPath:(NSString *)path tagId:(NSNumber *)tag {
  self.didReceiveRangeMerge = YES;
}

- (void)onConnect:(FPersistentConnection *)fpconnection {
}
- (void)onDisconnect:(FPersistentConnection *)fpconnection {
}
- (void)onServerInfoUpdate:(FPersistentConnection *)fpconnection updates:(NSDictionary *)updates {
}

@end

@interface FPersistentConnectionTests : XCTestCase

@property(nonatomic, strong) FPersistentConnectionTestDouble *connection;
@property(nonatomic, strong) dispatch_queue_t connectionQueue;

@end

@implementation FPersistentConnectionTests

- (void)setUp {
  [super setUp];
  self.connectionQueue = dispatch_queue_create(
      "com.google.firebase.database.PersistentConnectionTests", DISPATCH_QUEUE_SERIAL);
  FRepoInfo *repoInfo = [[FRepoInfo alloc] initWithHost:@"example.firebaseio.com"
                                               isSecure:YES
                                          withNamespace:@"example"];
  self.connection =
      [[FPersistentConnectionTestDouble alloc] initWithRepoInfo:repoInfo
                                                  dispatchQueue:self.connectionQueue
                                                         config:[FTestHelpers defaultConfig]];
  self.connection.interruptedReasons = [NSMutableArray array];
  self.connection.resumedReasons = [NSMutableArray array];
}

// A data message with an error that isn't a response to a request used to
// throw an exception that nothing caught, which crashed the app.
- (void)testServerErrorMessageDoesNotThrow {
  NSDictionary *message = @{kFWPRequestError : @"boom"};
  XCTAssertNoThrow([self.connection onDataMessage:nil withMessage:message]);
}

- (void)testSystemClockChangeRestartsConnection {
  [self.connection systemClockDidChange:nil];
  [self waitForConnectionQueue];

  [self assertConnectionRestartedForSystemClockChange];
}

- (void)testSystemClockDidChangeNotificationRestartsConnection {
  [[NSNotificationCenter defaultCenter] postNotificationName:NSSystemClockDidChangeNotification
                                                      object:nil];
  [self waitForConnectionQueue];

  [self assertConnectionRestartedForSystemClockChange];
}

- (void)testGetInFlightWhenConnectionDropsIsResentOnReconnect {
  self.continueAfterFailure = NO;
  FPersistentConnection *connection = [self unopenedConnection];
  FRecordingConnection *firstSocket = [[FRecordingConnection alloc] init];
  [self connect:connection toSocket:firstSocket];

  __block NSUInteger completionCount = 0;
  __block NSString *completedStatus = nil;
  __block id completedData = nil;
  [connection getDataAtPath:@"/foo"
                 withParams:@{}
               withCallback:^(NSString *status, id data, NSString *errorReason) {
                 completionCount++;
                 completedStatus = status;
                 completedData = data;
               }];
  NSArray<NSDictionary *> *firstSentGets = firstSocket.sentGets;
  XCTAssertEqual(firstSentGets.count, 1);

  // The connection drops before the server replies to the get.
  [connection onDisconnect:firstSocket withReason:DISCONNECT_REASON_OTHER];
  FRecordingConnection *secondSocket = [[FRecordingConnection alloc] init];
  [self connect:connection toSocket:secondSocket];

  NSArray<NSDictionary *> *secondSentGets = secondSocket.sentGets;
  XCTAssertEqual(secondSentGets.count, 1, @"The get should be resent after reconnecting");
  NSDictionary *resentGet = secondSentGets[0];
  XCTAssertEqualObjects(resentGet[kFWPRequestPayloadBody],
                        firstSentGets[0][kFWPRequestPayloadBody]);
  XCTAssertEqual(completionCount, 0);

  [connection onDataMessage:secondSocket
                withMessage:[self replyTo:resentGet
                                   status:kFWPResponseForActionStatusOk
                                     data:@"bar"]];
  XCTAssertEqual(completionCount, 1);
  XCTAssertEqualObjects(completedStatus, kFWPResponseForActionStatusOk);
  XCTAssertEqualObjects(completedData, @"bar");
}

- (void)testCompletedGetIsNotResentOnReconnect {
  self.continueAfterFailure = NO;
  FPersistentConnection *connection = [self unopenedConnection];
  FRecordingConnection *firstSocket = [[FRecordingConnection alloc] init];
  [self connect:connection toSocket:firstSocket];

  __block NSUInteger completionCount = 0;
  [connection getDataAtPath:@"/foo"
                 withParams:@{}
               withCallback:^(NSString *status, id data, NSString *errorReason) {
                 completionCount++;
               }];
  NSArray<NSDictionary *> *firstSentGets = firstSocket.sentGets;
  XCTAssertEqual(firstSentGets.count, 1);
  [connection onDataMessage:firstSocket
                withMessage:[self replyTo:firstSentGets[0]
                                   status:kFWPResponseForActionStatusOk
                                     data:@"bar"]];
  XCTAssertEqual(completionCount, 1);

  [connection onDisconnect:firstSocket withReason:DISCONNECT_REASON_OTHER];
  FRecordingConnection *secondSocket = [[FRecordingConnection alloc] init];
  [self connect:connection toSocket:secondSocket];

  XCTAssertEqual(secondSocket.sentGets.count, 0);
  XCTAssertEqual(completionCount, 1);
}

// A server frame is parsed straight from JSON, so a malformed message (wrong
// JSON type for the envelope, the push body, or a nested field) must be ignored
// rather than crash the client with an unrecognized selector. The literals are
// bound to locals first because their commas would otherwise be split across
// the XCTAssert macro's arguments.
- (void)testNonDictionaryDataMessageIsIgnored {
  NSArray *arrayMessage = @[ @1, @2 ];
  XCTAssertNoThrow([self.connection onDataMessage:nil withMessage:(id)arrayMessage]);
  XCTAssertNoThrow([self.connection onDataMessage:nil withMessage:(id) @"not a dict"]);
}

// A response whose body is not a JSON object must not be passed to the request
// callback as is, since the callback reads it with -objectForKey:. The request
// should complete as an ordinary failure instead.
- (void)testResponseWithNonDictionaryBodyFailsRequest {
  XCTAssertEqualObjects([self statusOfRequestAnsweredWithBody:@"not a dict"],
                        kFWPResponseForActionStatusFailed);
}

// A status that is not a string is reported as a failure too, rather than as nil.
- (void)testResponseWithNonStringStatusFailsRequest {
  NSDictionary *body = @{kFWPResponseForActionStatus : @5};
  XCTAssertEqualObjects([self statusOfRequestAnsweredWithBody:body],
                        kFWPResponseForActionStatusFailed);
}

- (void)testMalformedServerPushIsIgnored {
  FPersistentConnectionRecordingDelegate *delegate =
      [[FPersistentConnectionRecordingDelegate alloc] init];
  self.connection.delegate = delegate;

  // Body is not a JSON object.
  XCTAssertNoThrow([self.connection onDataPushWithAction:kFWPAsyncServerDataUpdate
                                                 andBody:(id) @"not a dict"]);
  // Action is not a string.
  NSNumber *numericAction = @5;
  XCTAssertNoThrow([self.connection onDataPushWithAction:(id)numericAction andBody:@{}]);
  // Data update with a non-string path.
  NSDictionary *nonStringPathUpdate =
      @{kFWPAsyncServerDataUpdateBodyPath : @42, kFWPAsyncServerDataUpdateBodyData : @"value"};
  XCTAssertNoThrow([self.connection onDataPushWithAction:kFWPAsyncServerDataUpdate
                                                 andBody:nonStringPathUpdate]);
  // Merge whose data is not a JSON object.
  NSDictionary *nonDictMerge = @{
    kFWPAsyncServerDataUpdateBodyPath : @"/",
    kFWPAsyncServerDataUpdateBodyData : @"not a dict"
  };
  XCTAssertNoThrow([self.connection onDataPushWithAction:kFWPAsyncServerDataMerge
                                                 andBody:nonDictMerge]);
  // Data update with a non-numeric tag.
  NSDictionary *nonNumericTagUpdate = @{
    kFWPAsyncServerDataUpdateBodyPath : @"/",
    kFWPAsyncServerDataUpdateBodyData : @"value",
    kFWPAsyncServerDataUpdateBodyTag : @"not a number"
  };
  XCTAssertNoThrow([self.connection onDataPushWithAction:kFWPAsyncServerDataUpdate
                                                 andBody:nonNumericTagUpdate]);
  // Range merge whose ranges are not an array.
  NSDictionary *nonArrayRanges =
      @{kFWPAsyncServerDataUpdateBodyPath : @"/", kFWPAsyncServerDataUpdateBodyData : @"not array"};
  XCTAssertNoThrow([self.connection onDataPushWithAction:kFWPAsyncServerDataRangeMerge
                                                 andBody:nonArrayRanges]);
  // Range merge whose range elements are not dictionaries.
  NSDictionary *nonDictRangeElement = @{
    kFWPAsyncServerDataUpdateBodyPath : @"/",
    kFWPAsyncServerDataUpdateBodyData : @[ @"not a dict" ]
  };
  XCTAssertNoThrow([self.connection onDataPushWithAction:kFWPAsyncServerDataRangeMerge
                                                 andBody:nonDictRangeElement]);
  // Range merge with a non-string start bound; the whole message is rejected so
  // a partial or widened merge is never applied.
  NSDictionary *nonStringBoundRange = @{
    kFWPAsyncServerDataUpdateBodyPath : @"/",
    kFWPAsyncServerDataUpdateBodyData : @[ @{kFWPAsyncServerDataUpdateStartPath : @5} ]
  };
  XCTAssertNoThrow([self.connection onDataPushWithAction:kFWPAsyncServerDataRangeMerge
                                                 andBody:nonStringBoundRange]);
  // Listen cancel with a non-string path.
  NSDictionary *nonStringCancelPath = @{kFWPAsyncServerDataUpdateBodyPath : @99};
  XCTAssertNoThrow([self.connection onDataPushWithAction:kFWPASyncServerListenCancelled
                                                 andBody:nonStringCancelPath]);

  // None of the malformed pushes should have reached the delegate.
  XCTAssertFalse(delegate.didReceiveDataUpdate);
  XCTAssertFalse(delegate.didReceiveRangeMerge);
}

- (void)testResponseWithMalformedRequestNumberIsIgnored {
  NSDictionary *response = @{kFWPRequestNumber : @[ @1 ]};
  XCTAssertNoThrow([self.connection onDataMessage:nil withMessage:response]);
}

- (void)testAuthRevokedWithNonStringStatusIsIgnored {
  NSDictionary *body = @{kFWPResponseForActionStatus : @5};
  XCTAssertNoThrow([self.connection onDataPushWithAction:kFWPAsyncServerAuthRevoked andBody:body]);
}

- (void)testSecurityDebugWithNonStringMessageIsIgnored {
  NSDictionary *body = @{@"msg" : @5};
  XCTAssertNoThrow([self.connection onDataPushWithAction:kFWPAsyncServerSecurityDebug
                                                 andBody:body]);
}

// Sends a request so that a callback is registered for it, answers it with the
// given response body, and returns the status its completion received. Returns
// nil if the completion never ran.
- (NSString *)statusOfRequestAnsweredWithBody:(id)body {
  __block NSString *receivedStatus = nil;
  [self.connection sendOnDisconnectAction:kFWPRequestActionDisconnectCancel
                                  forPath:@"/"
                                 withData:[NSNull null]
                              andCallback:^(NSString *status, NSString *errorReason) {
                                receivedStatus = status;
                              }];

  // Request numbers start at 1 and the connection is fresh, so the request
  // above is number 1.
  NSDictionary *response = @{kFWPRequestNumber : @1, kFWPResponseForRNData : body};
  XCTAssertNoThrow([self.connection onDataMessage:nil withMessage:response]);
  return receivedStatus;
}

- (void)waitForConnectionQueue {
  dispatch_sync(self.connectionQueue, ^{
                });
}

- (void)assertConnectionRestartedForSystemClockChange {
  XCTAssertEqualObjects(self.connection.interruptedReasons,
                        (@[ kFInterruptReasonSystemClockChange ]));
  XCTAssertEqualObjects(self.connection.resumedReasons, (@[ kFInterruptReasonSystemClockChange ]));
}

/**
 * Returns a connection that is never opened, so it never reaches the network. It runs on the main
 * queue, so the tests can drive it synchronously.
 */
- (FPersistentConnection *)unopenedConnection {
  FRepoInfo *repoInfo = [[FRepoInfo alloc] initWithHost:@"example.firebaseio.com"
                                               isSecure:YES
                                          withNamespace:@"example"];
  return [[FPersistentConnection alloc] initWithRepoInfo:repoInfo
                                           dispatchQueue:dispatch_get_main_queue()
                                                  config:[FTestHelpers defaultConfig]];
}

/** Simulates `socket` being opened for `connection` and becoming ready. */
- (void)connect:(FPersistentConnection *)connection toSocket:(FRecordingConnection *)socket {
  [connection setValue:@(kConnectionStateConnecting) forKey:@"connectionState"];
  [connection setValue:socket forKey:@"realtime"];
  [connection onReady:socket atTime:@0 sessionID:@"session"];
}

/** Returns the server's reply to `request`. */
- (NSDictionary *)replyTo:(NSDictionary *)request status:(NSString *)status data:(id)data {
  return @{
    kFWPRequestNumber : request[kFWPRequestNumber],
    kFWPResponseForRNData :
        @{kFWPResponseForActionStatus : status, kFWPResponseForActionData : data}
  };
}

@end
