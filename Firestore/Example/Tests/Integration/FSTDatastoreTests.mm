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

#import <FirebaseFirestore/FirebaseFirestore.h>

#import <FirebaseFirestore/FIRTimestamp.h>
#import <XCTest/XCTest.h>

#include <memory>
#include <vector>

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/remote/datastore.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_store.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/memory/memory.h"

namespace util = firebase::firestore::util;
using firebase::Timestamp;
using firebase::firestore::auth::EmptyCredentialsProvider;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::OnlineState;
using firebase::firestore::model::TargetId;
using firebase::firestore::remote::Datastore;
using firebase::firestore::remote::GrpcConnection;
using firebase::firestore::remote::RemoteEvent;
using firebase::firestore::remote::RemoteStore;
using firebase::firestore::testutil::WrapObject;
using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::ExecutorLibdispatch;
using firebase::firestore::util::Status;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTRemoteStoreEventCapture

@interface FSTRemoteStoreEventCapture : NSObject <FSTRemoteSyncer>

- (instancetype)init __attribute__((unavailable("Use initWithTestCase:")));

- (instancetype)initWithTestCase:(XCTestCase *_Nullable)testCase NS_DESIGNATED_INITIALIZER;

- (void)expectWriteEventWithDescription:(NSString *)description;
- (void)expectListenEventWithDescription:(NSString *)description;

@property(nonatomic, weak, nullable) XCTestCase *testCase;
@property(nonatomic, strong) NSMutableArray<NSObject *> *writeEvents;
@property(nonatomic, strong) NSMutableArray<XCTestExpectation *> *writeEventExpectations;
@property(nonatomic, strong) NSMutableArray<XCTestExpectation *> *listenEventExpectations;
@end

@implementation FSTRemoteStoreEventCapture {
  std::vector<RemoteEvent> _listenEvents;
}

- (instancetype)initWithTestCase:(XCTestCase *_Nullable)testCase {
  if (self = [super init]) {
    _writeEvents = [NSMutableArray array];
    _testCase = testCase;
    _writeEventExpectations = [NSMutableArray array];
    _listenEventExpectations = [NSMutableArray array];
  }
  return self;
}

- (void)expectWriteEventWithDescription:(NSString *)description {
  [self.writeEventExpectations
      addObject:[self.testCase
                    expectationWithDescription:[NSString
                                                   stringWithFormat:@"write event %lu: %@",
                                                                    (unsigned long)
                                                                        self.writeEventExpectations
                                                                            .count,
                                                                    description]]];
}

- (void)expectListenEventWithDescription:(NSString *)description {
  [self.listenEventExpectations
      addObject:[self.testCase
                    expectationWithDescription:[NSString
                                                   stringWithFormat:@"listen event %lu: %@",
                                                                    (unsigned long)
                                                                        self.listenEventExpectations
                                                                            .count,
                                                                    description]]];
}

- (void)applySuccessfulWriteWithResult:(FSTMutationBatchResult *)batchResult {
  [self.writeEvents addObject:batchResult];
  XCTestExpectation *expectation = [self.writeEventExpectations objectAtIndex:0];
  [self.writeEventExpectations removeObjectAtIndex:0];
  [expectation fulfill];
}

- (void)rejectFailedWriteWithBatchID:(BatchId)batchID error:(NSError *)error {
  HARD_FAIL("Not implemented");
}

- (DocumentKeySet)remoteKeysForTarget:(TargetId)targetId {
  return DocumentKeySet{};
}

- (void)applyRemoteEvent:(const RemoteEvent &)remoteEvent {
  _listenEvents.push_back(remoteEvent);
  XCTestExpectation *expectation = [self.listenEventExpectations objectAtIndex:0];
  [self.listenEventExpectations removeObjectAtIndex:0];
  [expectation fulfill];
}

- (void)rejectListenWithTargetID:(const TargetId)targetID error:(NSError *)error {
  HARD_FAIL("Not implemented");
}

@end

#pragma mark - FSTDatastoreTests

@interface FSTDatastoreTests : XCTestCase

@end

@implementation FSTDatastoreTests {
  std::shared_ptr<AsyncQueue> _testWorkerQueue;
  FSTLocalStore *_localStore;
  EmptyCredentialsProvider _credentials;

  DatabaseInfo _databaseInfo;
  std::shared_ptr<Datastore> _datastore;
  std::unique_ptr<RemoteStore> _remoteStore;
}

- (void)setUp {
  [super setUp];

  NSString *projectID = [FSTIntegrationTestCase projectID];
  FIRFirestoreSettings *settings = [FSTIntegrationTestCase settings];
  if (!settings.sslEnabled) {
    GrpcConnection::UseInsecureChannel(util::MakeString(settings.host));
  }

  DatabaseId database_id(util::MakeString(projectID));

  _databaseInfo =
      DatabaseInfo(database_id, "test-key", util::MakeString(settings.host), settings.sslEnabled);

  dispatch_queue_t queue = dispatch_queue_create(
      "com.google.firestore.FSTDatastoreTestsWorkerQueue", DISPATCH_QUEUE_SERIAL);
  _testWorkerQueue = std::make_shared<AsyncQueue>(absl::make_unique<ExecutorLibdispatch>(queue));
  _datastore = std::make_shared<Datastore>(_databaseInfo, _testWorkerQueue, &_credentials);

  _remoteStore =
      absl::make_unique<RemoteStore>(_localStore, _datastore, _testWorkerQueue, [](OnlineState) {});

  _testWorkerQueue->Enqueue([=] { _remoteStore->Start(); });
}

- (void)tearDown {
  XCTestExpectation *completion = [self expectationWithDescription:@"shutdown"];
  _testWorkerQueue->Enqueue([=] {
    _remoteStore->Shutdown();
    [completion fulfill];
  });
  [self awaitExpectations];

  [super tearDown];
}

- (void)testCommit {
  XCTestExpectation *expectation = [self expectationWithDescription:@"commitWithCompletion"];

  _datastore->CommitMutations({}, [self, expectation](const Status &status) {
    XCTAssertTrue(status.ok(), @"Failed to commit");
    [expectation fulfill];
  });

  [self awaitExpectations];
}

- (void)testStreamingWrite {
  FSTRemoteStoreEventCapture *capture = [[FSTRemoteStoreEventCapture alloc] initWithTestCase:self];
  [capture expectWriteEventWithDescription:@"write mutations"];

  _remoteStore->set_sync_engine(capture);

  FSTSetMutation *mutation = [self setMutation];
  FSTMutationBatch *batch = [[FSTMutationBatch alloc] initWithBatchID:23
                                                       localWriteTime:Timestamp::Now()
                                                        baseMutations:{}
                                                            mutations:{mutation}];
  _testWorkerQueue->Enqueue([=] {
    _remoteStore->AddToWritePipeline(batch);
    // The added batch won't be written immediately because write stream wasn't yet open --
    // trigger its opening.
    _remoteStore->FillWritePipeline();
  });

  [self awaitExpectations];
}

- (void)awaitExpectations {
  [self waitForExpectationsWithTimeout:4.0
                               handler:^(NSError *_Nullable expectationError) {
                                 if (expectationError) {
                                   XCTFail(@"Error waiting for timeout: %@", expectationError);
                                 }
                               }];
}

- (FSTSetMutation *)setMutation {
  return [[FSTSetMutation alloc] initWithKey:DocumentKey::FromPathString("rooms/eros")
                                       value:WrapObject("name", "Eros")
                                precondition:Precondition::None()];
}

@end

NS_ASSUME_NONNULL_END
