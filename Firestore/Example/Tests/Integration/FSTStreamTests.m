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

#import <Firestore/FIRFirestoreSettings.h>

#import "Auth/FSTEmptyCredentialsProvider.h"
#import "Core/FSTDatabaseInfo.h"
#import "FSTTestDispatchQueue.h"
#import "FSTHelpers.h"
#import "FSTIntegrationTestCase.h"
#import "Model/FSTDatabaseID.h"
#import "Remote/FSTDatastore.h"
#import "Util/FSTAssert.h"

/** Exposes otherwise private methods for testing. */
@interface FSTStream (Testing)
- (void)writesFinishedWithError:(NSError *_Nullable)error;
@end

/**
 * Implements FSTWatchStreamDelegate and FSTWriteStreamDelegate and supports waiting on callbacks
 * via `fulfillOnCallback`.
 */
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

- (void)watchStreamDidOpen {
  [_states addObject:@"watchStreamDidOpen"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)writeStreamDidOpen {
  [_states addObject:@"writeStreamDidOpen"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)writeStreamDidCompleteHandshake {
  [_states addObject:@"writeStreamDidCompleteHandshake"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)writeStreamWasInterrupted:(NSError *_Nullable)error {
  [_states addObject:@"writeStreamWasInterrupted"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)watchStreamWasInterrupted:(NSError *_Nullable)error {
  [_states addObject:@"watchStreamWasInterrupted"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)watchStreamDidChange:(FSTWatchChange *)change
             snapshotVersion:(FSTSnapshotVersion *)snapshotVersion {
  [_states addObject:@"watchStreamDidChange"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)writeStreamDidReceiveResponseWithVersion:(FSTSnapshotVersion *)commitVersion
                                 mutationResults:(NSArray<FSTMutationResult *> *)results {
  [_states addObject:@"writeStreamDidReceiveResponseWithVersion"];
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
  FSTEmptyCredentialsProvider *_credentials;
  FSTStreamStatusDelegate *_delegate;
  FSTTestDispatchQueue *_workerDispatchQueue;

  /** Single mutation to send to the write stream. */
  NSArray<FSTMutation *> *_mutations;
}

- (void)setUp {
  [super setUp];

  _mutations = @[ FSTTestSetMutation(@"foo/bar", @{}) ];

  FIRFirestoreSettings *settings = [FSTIntegrationTestCase settings];
  FSTDatabaseID *databaseID =
      [FSTDatabaseID databaseIDWithProject:[FSTIntegrationTestCase projectID]
                                  database:kDefaultDatabaseID];

  _databaseInfo = [FSTDatabaseInfo databaseInfoWithDatabaseID:databaseID
                                               persistenceKey:@"test-key"
                                                         host:settings.host
                                                   sslEnabled:settings.sslEnabled];
  _testQueue = dispatch_queue_create("FSTStreamTestWorkerQueue", DISPATCH_QUEUE_SERIAL);
  _workerDispatchQueue = [[FSTTestDispatchQueue alloc] initWithQueue:_testQueue];
  _credentials = [[FSTEmptyCredentialsProvider alloc] init];
}

- (void)tearDown {
  [super tearDown];
}

- (FSTWriteStream *)setUpWriteStream {
  FSTDatastore *datastore = [[FSTDatastore alloc] initWithDatabaseInfo:_databaseInfo
                                                   workerDispatchQueue:_workerDispatchQueue
                                                           credentials:_credentials];

  _delegate = [FSTStreamStatusDelegate new];
  return [datastore createWriteStream];
}

- (FSTWatchStream *)setUpWatchStream {
  FSTDatastore *datastore = [[FSTDatastore alloc] initWithDatabaseInfo:_databaseInfo
                                                   workerDispatchQueue:_workerDispatchQueue
                                                           credentials:_credentials];
  _delegate = [FSTStreamStatusDelegate new];
  return [datastore createWatchStream];
}

- (void)verifyDelegate:(NSArray<NSString *> *)expectedStates {
  // Drain queue
  dispatch_sync(_testQueue, ^{
                });

  XCTAssertEqualObjects(_delegate.states, expectedStates);
}

/** Verifies that the watch stream does not issue an onClose callback after a call to stop(). */
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

  [self verifyDelegate:@[ @"watchStreamDidOpen" ]];
}

/** Verifies that the write stream does not issue an onClose callback after a call to stop(). */
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

  [self verifyDelegate:@[ @"writeStreamDidOpen" ]];
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

  [self verifyDelegate:@[
    @"writeStreamDidOpen", @"writeStreamDidCompleteHandshake",
    @"writeStreamDidReceiveResponseWithVersion"
  ]];
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

  [self verifyDelegate:@[
    @"writeStreamDidOpen", @"writeStreamDidCompleteHandshake", @"writeStreamWasInterrupted"
  ]];
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

  // Mark the stream idle, but immediately cancel the idle timer by issuing another write.
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

  [self verifyDelegate:@[
    @"writeStreamDidOpen", @"writeStreamDidCompleteHandshake",
    @"writeStreamDidReceiveResponseWithVersion"
  ]];
}

@end
