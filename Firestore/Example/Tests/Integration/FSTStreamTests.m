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

#import <FirebaseCommunity/FIRLogger.h>
#import <Firestore/FIRFirestoreSettings.h>

#import "Auth/FSTEmptyCredentialsProvider.h"
#import "Core/FSTDatabaseInfo.h"
#import "FIRTestDispatchQueue.h"
#import "FSTHelpers.h"
#import "FSTIntegrationTestCase.h"
#import "Model/FSTDatabaseID.h"
#import "Remote/FSTDatastore.h"
#import "Util/FSTAssert.h"

/** Expose otherwise private methods for testing. */
@interface FSTStream (Testing)
- (void)writesFinishedWithError:(NSError *_Nullable)error;
@end

@interface FSTStreamStatusDelegate : NSObject <FSTWatchStreamDelegate, FSTWriteStreamDelegate>

@property(nonatomic, readonly) NSMutableArray<NSString *> *states;
@property(atomic, readwrite) BOOL invokeCallbacks;
@property(nonatomic, weak) XCTestExpectation *expectation;

@end

@implementation FSTStreamStatusDelegate

- (instancetype)init {
  if (self = [super init]) {
    _states = [NSMutableArray new];
  }

  return self;
}

- (void)streamDidReceiveChange:(FSTWatchChange *)change
               snapshotVersion:(FSTSnapshotVersion *)snapshotVersion {
  [_states addObject:@"didReceiveChange"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)streamDidOpen {
  [_states addObject:@"didOpen"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)streamDidClose:(NSError *_Nullable)error {
  [_states addObject:@"didClose"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)streamDidCompleteHandshake {
  [_states addObject:@"didCompleteHandshake"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)streamDidReceiveResponseWithVersion:(FSTSnapshotVersion *)commitVersion
                            mutationResults:(NSArray<FSTMutationResult *> *)results {
  [_states addObject:@"didReceiveResponse"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)fulfillOnCallback:(XCTestExpectation *)expectation {
  FSTAssert(_expectation == nil, @"Previous expectation still active");
  _expectation = expectation;
}

@end

@interface FSTStreamTests : XCTestCase

@end

@implementation FSTStreamTests {
  dispatch_queue_t _testQueue;
  FSTDatabaseInfo *_databaseInfo;
  FSTTestDispatchQueue *_workerDispatchQueue;
  FSTEmptyCredentialsProvider *_credentials;
  FSTStreamStatusDelegate *_delegate;

  /** Single mutation to send to the write stream. */
  NSArray<FSTMutation *> *_mutations;
}

- (void)setUp {
  [super setUp];

  FIRSetLoggerLevel(FIRLoggerLevelDebug);

  NSString *projectID = [FSTIntegrationTestCase projectID];
  FIRFirestoreSettings *settings = [FSTIntegrationTestCase settings];
  FSTDatabaseID *databaseID =
      [FSTDatabaseID databaseIDWithProject:projectID database:kDefaultDatabaseID];

  _databaseInfo = [FSTDatabaseInfo databaseInfoWithDatabaseID:databaseID
                                               persistenceKey:@"test-key"
                                                         host:settings.host
                                                   sslEnabled:settings.sslEnabled];

  _testQueue =
      dispatch_queue_create("com.google.firestore.FSTStreamTestWorkerQueue", DISPATCH_QUEUE_SERIAL);
  _workerDispatchQueue = [[FSTTestDispatchQueue alloc] initWithQueue:_testQueue];
  _credentials = [[FSTEmptyCredentialsProvider alloc] init];

  _mutations = @[ FSTTestSetMutation(@"foo/bar", @{}) ];

  _delegate = [FSTStreamStatusDelegate new];
}

- (void)tearDown {
  [super tearDown];
}

- (FSTWriteStream *)setUpWriteStream {
  FSTDatastore *datastore = [[FSTDatastore alloc] initWithDatabaseInfo:_databaseInfo
                                                   workerDispatchQueue:_workerDispatchQueue
                                                           credentials:_credentials];

  return [datastore createWriteStream];
}

- (FSTWatchStream *)setUpWatchStream {
  FSTDatastore *datastore = [[FSTDatastore alloc] initWithDatabaseInfo:_databaseInfo
                                                   workerDispatchQueue:_workerDispatchQueue
                                                           credentials:_credentials];
  FSTWatchStream *stream = [datastore createWatchStream];

  return stream;
}

- (void)verifyDelegate:(NSArray<NSString *> *)expectedStates {
  // Drain queue
  dispatch_sync(_testQueue, ^{
                });

  XCTAssertEqualObjects(_delegate.states, expectedStates);
}

/** Verifies that the stream does not issue an onClose callback after a call to stop(). */
- (void)testWatchStreamStopBeforeHandshake {
  FSTWatchStream *watchStream = [self setUpWatchStream];

  XCTestExpectation *openExpectation = [self expectationWithDescription:@"open"];
  [_delegate fulfillOnCallback:openExpectation];
  [_workerDispatchQueue dispatchAsync:^{
    [watchStream start:_delegate];
  }];
  [self awaitExpectations];

  // Stop must not call watchStreamDidClose because the full implementation of the delegate could
  // attempt to restart the stream in the event it had pending watches.
  [_workerDispatchQueue dispatchAsync:^{
    [watchStream stop];
  }];

  // Simulate a final callback from GRPC
  [watchStream writesFinishedWithError:nil];

  [self verifyDelegate:@[ @"didOpen" ]];
}

/** Verifies that the stream does not issue an onClose callback after a call to stop(). */
- (void)testWriteStreamStopBeforeHandshake {
  FSTWriteStream *writeStream = [self setUpWriteStream];

  XCTestExpectation *openExpectation = [self expectationWithDescription:@"open"];
  [_delegate fulfillOnCallback:openExpectation];
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream start:_delegate];
  }];
  [self awaitExpectations];

  // Don't start the handshake.

  // Stop must not call watchStreamDidClose because the full implementation of the delegate could
  // attempt to restart the stream in the event it had pending watches.
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream stop];
  }];

  // Simulate a final callback from GRPC
  [writeStream writesFinishedWithError:nil];

  [self verifyDelegate:@[ @"didOpen" ]];
}

- (void)testWriteStreamStopAfterHandshake {
  FSTWriteStream *writeStream = [self setUpWriteStream];

  XCTestExpectation *openExpectation = [self expectationWithDescription:@"open"];
  [_delegate fulfillOnCallback:openExpectation];
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream start:_delegate];
  }];
  [self awaitExpectations];

  // Writing before the handshake should throw
  dispatch_sync(_testQueue, ^{
    XCTAssertThrows([writeStream writeMutations:_mutations]);
  });

  XCTestExpectation *handshakeExpectation = [self expectationWithDescription:@"handshake"];
  [_delegate fulfillOnCallback:handshakeExpectation];
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream writeHandshake];
  }];
  [self awaitExpectations];

  // Now writes should succeed
  XCTestExpectation *writeExpectation = [self expectationWithDescription:@"write"];
  [_delegate fulfillOnCallback:writeExpectation];
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream writeMutations:_mutations];
  }];
  [self awaitExpectations];

  [_workerDispatchQueue dispatchAsync:^{
    [writeStream stop];
  }];

  [self verifyDelegate:@[ @"didOpen", @"didCompleteHandshake", @"didReceiveResponse" ]];
}

- (void)testStreamClosesWhenIdle {
  FSTWriteStream *writeStream = [self setUpWriteStream];

  XCTestExpectation *openExpectation = [self expectationWithDescription:@"open"];
  [_delegate fulfillOnCallback:openExpectation];
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream start:_delegate];
  }];
  [self awaitExpectations];

  XCTestExpectation *handshakeExpectation = [self expectationWithDescription:@"handshake"];
  [_delegate fulfillOnCallback:handshakeExpectation];
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream writeHandshake];
  }];
  [self awaitExpectations];

  XCTestExpectation *closeExpectation = [self expectationWithDescription:@"close"];
  [_delegate fulfillOnCallback:closeExpectation];
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream markIdle];
  }];
  [self awaitExpectations];

  dispatch_sync(_testQueue, ^{
    XCTAssertFalse([writeStream isOpen]);
  });

  [self verifyDelegate:@[ @"didOpen", @"didCompleteHandshake", @"didClose" ]];
}

- (void)testStreamCancelsIdleOnWrite {
  FSTWriteStream *writeStream = [self setUpWriteStream];

  XCTestExpectation *openExpectation = [self expectationWithDescription:@"open"];
  [_delegate fulfillOnCallback:openExpectation];
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream start:_delegate];
  }];
  [self awaitExpectations];

  XCTestExpectation *handshakeExpectation = [self expectationWithDescription:@"handshake"];
  [_delegate fulfillOnCallback:handshakeExpectation];
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream writeHandshake];
  }];
  [self awaitExpectations];

  // Mark the stream idle, but immediately cancel the idle time by sending another write.
  XCTestExpectation *idleExpectation = [self expectationWithDescription:@"idle"];
  [_workerDispatchQueue fulfillOnExecution:idleExpectation];
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream markIdle];
  }];
  XCTestExpectation *writeExpectation = [self expectationWithDescription:@"write"];
  [_delegate fulfillOnCallback:writeExpectation];
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream writeMutations:_mutations];
  }];

  [self awaitExpectations];

  dispatch_sync(_testQueue, ^{
    XCTAssertTrue([writeStream isOpen]);
  });

  [_workerDispatchQueue dispatchAsync:^{
    [writeStream stop];
  }];

  [self verifyDelegate:@[ @"didOpen", @"didCompleteHandshake", @"didReceiveResponse" ]];
}

@end
