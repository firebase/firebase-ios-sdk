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
