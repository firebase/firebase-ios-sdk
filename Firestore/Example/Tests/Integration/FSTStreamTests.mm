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

#import <FirebaseFirestore/FIRFirestoreErrors.h>
#import <FirebaseFirestore/FIRFirestoreSettings.h>

#include <utility>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/Remote/FSTDatastore.h"
#import "Firestore/Source/Remote/FSTStream.h"

#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::FirestoreErrorCode;
using firebase::firestore::auth::EmptyCredentialsProvider;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::SnapshotVersion;

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
             snapshotVersion:(const SnapshotVersion &)snapshotVersion {
  [_states addObject:@"watchStreamDidChange"];
  [_expectation fulfill];
  _expectation = nil;
}

- (void)writeStreamDidReceiveResponseWithVersion:(const SnapshotVersion &)commitVersion
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
  HARD_ASSERT(_expectation == nil, "Previous expectation still active");
  XCTestExpectation *expectation =
      [self.testCase expectationWithDescription:@"awaitCallbackInBlock"];
  _expectation = expectation;
  [self.dispatchQueue dispatchAsync:block];
  [self.testCase awaitExpectations];
}

@end

@interface FSTStreamTests : XCTestCase

@end

class MockCredentialsProvider : public firebase::firestore::auth::EmptyCredentialsProvider {
 public:
  MockCredentialsProvider() {
    observed_states_ = [NSMutableArray new];
  }

  void GetToken(firebase::firestore::auth::TokenListener completion) override {
    [observed_states_ addObject:@"GetToken"];
    EmptyCredentialsProvider::GetToken(std::move(completion));
  }

  void InvalidateToken() override {
    [observed_states_ addObject:@"InvalidateToken"];
    EmptyCredentialsProvider::InvalidateToken();
  }

  NSMutableArray<NSString *> *observed_states() const {
    return observed_states_;
  }

 private:
  NSMutableArray<NSString *> *observed_states_;
};

@implementation FSTStreamTests {
  dispatch_queue_t _testQueue;
  FSTDispatchQueue *_workerDispatchQueue;
  DatabaseInfo _databaseInfo;
  MockCredentialsProvider _credentials;
  FSTStreamStatusDelegate *_delegate;
  FSTDatastore *_datastore;

  /** Single mutation to send to the write stream. */
  NSArray<FSTMutation *> *_mutations;
}

- (void)setUp {
  [super setUp];

  FIRFirestoreSettings *settings = [FSTIntegrationTestCase settings];
  DatabaseId database_id(util::MakeStringView([FSTIntegrationTestCase projectID]),
                         DatabaseId::kDefault);

  _testQueue = dispatch_queue_create("FSTStreamTestWorkerQueue", DISPATCH_QUEUE_SERIAL);
  _workerDispatchQueue = [[FSTDispatchQueue alloc] initWithQueue:_testQueue];

  _databaseInfo = DatabaseInfo(database_id, "test-key", util::MakeStringView(settings.host),
                               settings.sslEnabled);

  _delegate = [[FSTStreamStatusDelegate alloc] initWithTestCase:self queue:_workerDispatchQueue];

  _datastore = [[FSTDatastore alloc] initWithDatabaseInfo:&_databaseInfo
                                      workerDispatchQueue:_workerDispatchQueue
                                              credentials:&_credentials];

  _mutations = @[ FSTTestSetMutation(@"foo/bar", @{}) ];
}

- (std::shared_ptr<firebase::firestore::remote::WatchStream>)setUpWatchStream {
  return [_datastore createWatchStreamWithDelegate:_delegate];
}

- (std::shared_ptr<firebase::firestore::remote::WriteStream>)setUpWriteStream {
  return [_datastore createWriteStreamWithDelegate:_delegate];
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
  auto watchStream = [self setUpWatchStream];

  [_delegate awaitNotificationFromBlock:^{
    watchStream->Start();
  }];

  // Stop must not call watchStreamDidClose because the full implementation of the delegate could
  // attempt to restart the stream in the event it had pending watches.
  [_workerDispatchQueue dispatchAsync:^{
    watchStream->Stop();
  }];

  // Simulate a final callback from GRPC
  [_workerDispatchQueue dispatchAsync:^{
    watchStream->OnStreamFinish(util::Status::OK());
  }];

  [self verifyDelegateObservedStates:@[ @"watchStreamDidOpen", @"watchStreamWasInterrupted" ]];
}

/** Verifies that the write stream does not issue an onClose callback after a call to stop(). */
- (void)testWriteStreamStopBeforeHandshake {
  auto writeStream = [self setUpWriteStream];

  [_delegate awaitNotificationFromBlock:^{
    writeStream->Start();
  }];

  // Don't start the handshake.

  // Stop must not call watchStreamDidClose because the full implementation of the delegate could
  // attempt to restart the stream in the event it had pending watches.
  [_workerDispatchQueue dispatchAsync:^{
    writeStream->Stop();
  }];

  // Simulate a final callback from GRPC
  [_workerDispatchQueue dispatchAsync:^{
    writeStream->OnStreamFinish(util::Status::OK());
  }];

  [self verifyDelegateObservedStates:@[ @"writeStreamDidOpen", @"writeStreamWasInterrupted" ]];
}

- (void)testWriteStreamStopAfterHandshake {
  auto writeStream = [self setUpWriteStream];

  [_delegate awaitNotificationFromBlock:^{
    writeStream->Start();
  }];

  // Writing before the handshake should throw
  [_workerDispatchQueue dispatchSync:^{
    XCTAssertThrows(writeStream->WriteMutations(_mutations));
  }];

  [_delegate awaitNotificationFromBlock:^{
    writeStream->WriteHandshake();
  }];

  // Now writes should succeed
  [_delegate awaitNotificationFromBlock:^{
    writeStream->WriteMutations(_mutations);
  }];

  [_workerDispatchQueue dispatchAsync:^{
    writeStream->Stop();
  }];

  [self verifyDelegateObservedStates:@[
    @"writeStreamDidOpen", @"writeStreamDidCompleteHandshake",
    @"writeStreamDidReceiveResponseWithVersion"
  ]];
}

- (void)testStreamClosesWhenIdle {
  auto writeStream = [self setUpWriteStream];

  [_delegate awaitNotificationFromBlock:^{
    writeStream->Start();
  }];

  [_delegate awaitNotificationFromBlock:^{
    writeStream->WriteHandshake();
  }];

  [_workerDispatchQueue dispatchAsync:^{
    writeStream->MarkIdle();
    XCTAssertTrue(
        [_workerDispatchQueue containsDelayedCallbackWithTimerID:FSTTimerIDWriteStreamIdle]);
  }];

  [_workerDispatchQueue runDelayedCallbacksUntil:FSTTimerIDWriteStreamIdle];

  [_workerDispatchQueue dispatchSync:^{
    XCTAssertFalse(writeStream->IsOpen());
  }];

  [self verifyDelegateObservedStates:@[
    @"writeStreamDidOpen", @"writeStreamDidCompleteHandshake", @"writeStreamWasInterrupted"
  ]];
}

- (void)testStreamCancelsIdleOnWrite {
  auto writeStream = [self setUpWriteStream];

  [_delegate awaitNotificationFromBlock:^{
    writeStream->Start();
  }];

  [_delegate awaitNotificationFromBlock:^{
    writeStream->WriteHandshake();
  }];

  // Mark the stream idle, but immediately cancel the idle timer by issuing another write.
  [_delegate awaitNotificationFromBlock:^{
    writeStream->MarkIdle();
    XCTAssertTrue(
        [_workerDispatchQueue containsDelayedCallbackWithTimerID:FSTTimerIDWriteStreamIdle]);
    writeStream->WriteMutations(_mutations);
    XCTAssertFalse(
        [_workerDispatchQueue containsDelayedCallbackWithTimerID:FSTTimerIDWriteStreamIdle]);
  }];

  [_workerDispatchQueue dispatchSync:^{
    XCTAssertTrue(writeStream->IsOpen());
  }];

  [self verifyDelegateObservedStates:@[
    @"writeStreamDidOpen", @"writeStreamDidCompleteHandshake",
    @"writeStreamDidReceiveResponseWithVersion"
  ]];
}

- (void)testStreamRefreshesTokenUponExpiration {
  auto watchStream = [self setUpWatchStream];

  [_delegate awaitNotificationFromBlock:^{
    watchStream->Start();
  }];

  // Simulate callback from GRPC with an unauthenticated error -- this should invalidate the token.
   [_workerDispatchQueue dispatchAsync:^{
    watchStream->OnStreamFinish(util::Status{FirestoreErrorCode::Unauthenticated, ""});
  }];
  // Drain the queue.
  [_workerDispatchQueue dispatchSync:^{}];

  // Try reconnecting.
  // Calling `OnStreamFinish` manually breaks the state machine (it's normally called by GRPC after either graceful stop or disconnect).
  // Restarting will fail, it's easiest to juts recreate the stream.
  watchStream = [self setUpWatchStream];
  [_delegate awaitNotificationFromBlock:^{
    watchStream->Start();
  }];
  // Simulate a different error -- token should not be invalidated this time.
  [_workerDispatchQueue dispatchAsync:^{
    watchStream->OnStreamFinish(util::Status{FirestoreErrorCode::Unavailable, ""});
  }];
   [_workerDispatchQueue dispatchSync:^{}];

  watchStream = [self setUpWatchStream];
  [_delegate awaitNotificationFromBlock:^{
    watchStream->Start();
  }];
   [_workerDispatchQueue dispatchSync:^{
                }];

  NSArray<NSString *> *expected = @[ @"GetToken", @"InvalidateToken", @"GetToken", @"GetToken" ];
  XCTAssertEqualObjects(_credentials.observed_states(), expected);
}

@end
