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

#import <GRPCClient/GRPCCall.h>

#import <FirebaseFirestore/FIRFirestoreSettings.h>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/Auth/FSTEmptyCredentialsProvider.h"
#import "Firestore/Source/Remote/FSTDatastore.h"
#import "Firestore/Source/Remote/FSTStream.h"
#import "Firestore/Source/Util/FSTAssert.h"

#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;

/** Exposes otherwise private methods for testing. */
@interface FSTStream (Testing)
@property(nonatomic, strong, readwrite) id<GRXWriteable> callbackFilter;
@end

/**
 * Implements FSTWatchStreamDelegate and FSTWriteStreamDelegate and supports waiting on callbacks
 * via `fulfillOnCallback`.
 */
@interface FSTStreamStatusDelegate : NSObject <FSTWatchStreamDelegate, FSTWriteStreamDelegate>

- (instancetype)initWithTestCase:(XCTestCase *)testCase
                           queue:(FSTDispatchQueue *)dispatchQueue NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, weak, readonly) XCTestCase *testCase;
@property(nonatomic, strong, readonly) FSTDispatchQueue *dispatchQueue;
@property(nonatomic, readonly) NSMutableArray<NSString *> *states;
@property(nonatomic, strong) XCTestExpectation *expectation;

@end

@implementation FSTStreamStatusDelegate

- (instancetype)initWithTestCase:(XCTestCase *)testCase queue:(FSTDispatchQueue *)dispatchQueue {
  if (self = [super init]) {
    _testCase = testCase;
    _dispatchQueue = dispatchQueue;
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

- (void)writeStreamWasInterruptedWithError:(nullable NSError *)error {
  [_states addObject:@"writeStreamWasInterrupted"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)watchStreamWasInterruptedWithError:(nullable NSError *)error {
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

/**
 * Executes 'block' using the provided FSTDispatchQueue and waits for any callback on this delegate
 * to be called.
 */
- (void)awaitNotificationFromBlock:(void (^)(void))block {
  FSTAssert(_expectation == nil, @"Previous expectation still active");
  XCTestExpectation *expectation =
      [self.testCase expectationWithDescription:@"awaitCallbackInBlock"];
  _expectation = expectation;
  [self.dispatchQueue dispatchAsync:block];
  [self.testCase awaitExpectations];
}

@end

@interface FSTStreamTests : XCTestCase

@end

@implementation FSTStreamTests {
  dispatch_queue_t _testQueue;
  FSTDispatchQueue *_workerDispatchQueue;
  DatabaseInfo _databaseInfo;
  FSTEmptyCredentialsProvider *_credentials;
  FSTStreamStatusDelegate *_delegate;

  /** Single mutation to send to the write stream. */
  NSArray<FSTMutation *> *_mutations;
}

- (void)setUp {
  [super setUp];

  FIRFirestoreSettings *settings = [FSTIntegrationTestCase settings];
  DatabaseId database_id(util::MakeStringView([FSTIntegrationTestCase projectID]),
                         DatabaseId::kDefaultDatabaseId);

  _testQueue = dispatch_queue_create("FSTStreamTestWorkerQueue", DISPATCH_QUEUE_SERIAL);
  _workerDispatchQueue = [[FSTDispatchQueue alloc] initWithQueue:_testQueue];

  _databaseInfo = DatabaseInfo(database_id, "test-key", util::MakeStringView(settings.host),
                               settings.sslEnabled);
  _credentials = [[FSTEmptyCredentialsProvider alloc] init];

  _delegate = [[FSTStreamStatusDelegate alloc] initWithTestCase:self queue:_workerDispatchQueue];

  _mutations = @[ FSTTestSetMutation(@"foo/bar", @{}) ];
}

- (FSTWriteStream *)setUpWriteStream {
  FSTDatastore *datastore = [[FSTDatastore alloc] initWithDatabaseInfo:&_databaseInfo
                                                   workerDispatchQueue:_workerDispatchQueue
                                                           credentials:_credentials];
  return [datastore createWriteStream];
}

- (FSTWatchStream *)setUpWatchStream {
  FSTDatastore *datastore = [[FSTDatastore alloc] initWithDatabaseInfo:&_databaseInfo
                                                   workerDispatchQueue:_workerDispatchQueue
                                                           credentials:_credentials];
  return [datastore createWatchStream];
}

/**
 * Drains the test queue and asserts that all the observed callbacks (up to this point) match
 * 'expectedStates'. Clears the list of observed callbacks on completion.
 */
- (void)verifyDelegateObservedStates:(NSArray<NSString *> *)expectedStates {
  // Drain queue
  dispatch_sync(_testQueue, ^{
                });

  XCTAssertEqualObjects(_delegate.states, expectedStates);
  [_delegate.states removeAllObjects];
}

/** Verifies that the watch stream does not issue an onClose callback after a call to stop(). */
- (void)testWatchStreamStopBeforeHandshake {
  FSTWatchStream *watchStream = [self setUpWatchStream];

  [_delegate awaitNotificationFromBlock:^{
    [watchStream startWithDelegate:_delegate];
  }];

  // Stop must not call watchStreamDidClose because the full implementation of the delegate could
  // attempt to restart the stream in the event it had pending watches.
  [_workerDispatchQueue dispatchAsync:^{
    [watchStream stop];
  }];

  // Simulate a final callback from GRPC
  [_workerDispatchQueue dispatchAsync:^{
    [watchStream.callbackFilter writesFinishedWithError:nil];
  }];

  [self verifyDelegateObservedStates:@[ @"watchStreamDidOpen" ]];
}

/** Verifies that the write stream does not issue an onClose callback after a call to stop(). */
- (void)testWriteStreamStopBeforeHandshake {
  FSTWriteStream *writeStream = [self setUpWriteStream];

  [_delegate awaitNotificationFromBlock:^{
    [writeStream startWithDelegate:_delegate];
  }];

  // Don't start the handshake.

  // Stop must not call watchStreamDidClose because the full implementation of the delegate could
  // attempt to restart the stream in the event it had pending watches.
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream stop];
  }];

  // Simulate a final callback from GRPC
  [_workerDispatchQueue dispatchAsync:^{
    [writeStream.callbackFilter writesFinishedWithError:nil];
  }];

  [self verifyDelegateObservedStates:@[ @"writeStreamDidOpen" ]];
}

- (void)testWriteStreamStopAfterHandshake {
  FSTWriteStream *writeStream = [self setUpWriteStream];

  [_delegate awaitNotificationFromBlock:^{
    [writeStream startWithDelegate:_delegate];
  }];

  // Writing before the handshake should throw
  dispatch_sync(_testQueue, ^{
    XCTAssertThrows([writeStream writeMutations:_mutations]);
  });

  [_delegate awaitNotificationFromBlock:^{
    [writeStream writeHandshake];
  }];

  // Now writes should succeed
  [_delegate awaitNotificationFromBlock:^{
    [writeStream writeMutations:_mutations];
  }];

  [_workerDispatchQueue dispatchAsync:^{
    [writeStream stop];
  }];

  [self verifyDelegateObservedStates:@[
    @"writeStreamDidOpen", @"writeStreamDidCompleteHandshake",
    @"writeStreamDidReceiveResponseWithVersion"
  ]];
}

- (void)testStreamClosesWhenIdle {
  FSTWriteStream *writeStream = [self setUpWriteStream];

  [_delegate awaitNotificationFromBlock:^{
    [writeStream startWithDelegate:_delegate];
  }];

  [_delegate awaitNotificationFromBlock:^{
    [writeStream writeHandshake];
  }];

  [_workerDispatchQueue dispatchAsync:^{
    [writeStream markIdle];
    XCTAssertTrue(
        [_workerDispatchQueue containsDelayedCallbackWithTimerID:FSTTimerIDWriteStreamIdle]);
  }];

  [_workerDispatchQueue runDelayedCallbacksUntil:FSTTimerIDWriteStreamIdle];

  dispatch_sync(_testQueue, ^{
    XCTAssertFalse([writeStream isOpen]);
  });

  [self verifyDelegateObservedStates:@[
    @"writeStreamDidOpen", @"writeStreamDidCompleteHandshake", @"writeStreamWasInterrupted"
  ]];
}

- (void)testStreamCancelsIdleOnWrite {
  FSTWriteStream *writeStream = [self setUpWriteStream];

  [_delegate awaitNotificationFromBlock:^{
    [writeStream startWithDelegate:_delegate];
  }];

  [_delegate awaitNotificationFromBlock:^{
    [writeStream writeHandshake];
  }];

  // Mark the stream idle, but immediately cancel the idle timer by issuing another write.
  [_delegate awaitNotificationFromBlock:^{
    [writeStream markIdle];
    XCTAssertTrue(
        [_workerDispatchQueue containsDelayedCallbackWithTimerID:FSTTimerIDWriteStreamIdle]);
    [writeStream writeMutations:_mutations];
    XCTAssertFalse(
        [_workerDispatchQueue containsDelayedCallbackWithTimerID:FSTTimerIDWriteStreamIdle]);
  }];

  dispatch_sync(_testQueue, ^{
    XCTAssertTrue([writeStream isOpen]);
  });

  [self verifyDelegateObservedStates:@[
    @"writeStreamDidOpen", @"writeStreamDidCompleteHandshake",
    @"writeStreamDidReceiveResponseWithVersion"
  ]];
}

@end
