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
#import <GRPCClient/GRPCCall+ChannelCredentials.h>
#import <GRPCClient/GRPCCall+Tests.h>
#import <XCTest/XCTest.h>

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Remote/FSTDatastore.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"
#import "Firestore/Source/Remote/FSTRemoteStore.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::EmptyCredentialsProvider;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;

NS_ASSUME_NONNULL_BEGIN

@interface FSTRemoteStore (Tests)
- (void)commitBatch:(FSTMutationBatch *)batch;
@end

#pragma mark - FSTRemoteStoreEventCapture

@interface FSTRemoteStoreEventCapture : NSObject <FSTRemoteSyncer>

- (instancetype)init __attribute__((unavailable("Use initWithTestCase:")));

- (instancetype)initWithTestCase:(XCTestCase *_Nullable)testCase NS_DESIGNATED_INITIALIZER;

- (void)expectWriteEventWithDescription:(NSString *)description;
- (void)expectListenEventWithDescription:(NSString *)description;

@property(nonatomic, weak, nullable) XCTestCase *testCase;
@property(nonatomic, strong) NSMutableArray<NSObject *> *writeEvents;
@property(nonatomic, strong) NSMutableArray<NSObject *> *listenEvents;
@property(nonatomic, strong) NSMutableArray<XCTestExpectation *> *writeEventExpectations;
@property(nonatomic, strong) NSMutableArray<XCTestExpectation *> *listenEventExpectations;
@end

@implementation FSTRemoteStoreEventCapture

- (instancetype)initWithTestCase:(XCTestCase *_Nullable)testCase {
  if (self = [super init]) {
    _writeEvents = [NSMutableArray array];
    _listenEvents = [NSMutableArray array];
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

- (void)rejectFailedWriteWithBatchID:(FSTBatchID)batchID error:(NSError *)error {
  FSTFail(@"Not implemented");
}

- (void)applyRemoteEvent:(FSTRemoteEvent *)remoteEvent {
  [self.listenEvents addObject:remoteEvent];
  XCTestExpectation *expectation = [self.listenEventExpectations objectAtIndex:0];
  [self.listenEventExpectations removeObjectAtIndex:0];
  [expectation fulfill];
}

- (void)rejectListenWithTargetID:(FSTBoxedTargetID *)targetID error:(NSError *)error {
  FSTFail(@"Not implemented");
}

@end

#pragma mark - FSTDatastoreTests

@interface FSTDatastoreTests : XCTestCase

@end

@implementation FSTDatastoreTests {
  FSTDispatchQueue *_testWorkerQueue;
  FSTLocalStore *_localStore;
  EmptyCredentialsProvider _credentials;

  DatabaseInfo _databaseInfo;
  FSTDatastore *_datastore;
  FSTRemoteStore *_remoteStore;
}

- (void)setUp {
  [super setUp];

  NSString *projectID = [[NSProcessInfo processInfo] environment][@"PROJECT_ID"];
  if (!projectID) {
    projectID = @"test-db";
  }

  FIRFirestoreSettings *settings = [FSTIntegrationTestCase settings];
  if (!settings.sslEnabled) {
    [GRPCCall useInsecureConnectionsForHost:settings.host];
  }

  DatabaseId database_id(util::MakeStringView(projectID), DatabaseId::kDefault);

  _databaseInfo = DatabaseInfo(database_id, "test-key", util::MakeStringView(settings.host),
                               settings.sslEnabled);

  _testWorkerQueue = [FSTDispatchQueue
      queueWith:dispatch_queue_create("com.google.firestore.FSTDatastoreTestsWorkerQueue",
                                      DISPATCH_QUEUE_SERIAL)];

  _datastore = [FSTDatastore datastoreWithDatabase:&_databaseInfo
                               workerDispatchQueue:_testWorkerQueue
                                       credentials:&_credentials];

  _remoteStore = [FSTRemoteStore remoteStoreWithLocalStore:_localStore datastore:_datastore];

  [_testWorkerQueue dispatchAsync:^() {
    [_remoteStore start];
  }];
}

- (void)tearDown {
  XCTestExpectation *completion = [self expectationWithDescription:@"shutdown"];
  [_testWorkerQueue dispatchAsync:^{
    [_remoteStore shutdown];
    [completion fulfill];
  }];
  [self awaitExpectations];

  [super tearDown];
}

- (void)testCommit {
  XCTestExpectation *expectation = [self expectationWithDescription:@"commitWithCompletion"];

  [_datastore commitMutations:@[]
                   completion:^(NSError *_Nullable error) {
                     XCTAssertNil(error, @"Failed to commit");
                     [expectation fulfill];
                   }];

  [self awaitExpectations];
}

- (void)testStreamingWrite {
  FSTRemoteStoreEventCapture *capture = [[FSTRemoteStoreEventCapture alloc] initWithTestCase:self];
  [capture expectWriteEventWithDescription:@"write mutations"];

  _remoteStore.syncEngine = capture;

  FSTSetMutation *mutation = [self setMutation];
  FSTMutationBatch *batch = [[FSTMutationBatch alloc] initWithBatchID:23
                                                       localWriteTime:[FIRTimestamp timestamp]
                                                            mutations:@[ mutation ]];
  [_testWorkerQueue dispatchAsync:^{
    [_remoteStore commitBatch:batch];
  }];

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
  return [[FSTSetMutation alloc]
       initWithKey:[FSTDocumentKey keyWithPathString:@"rooms/eros"]
             value:[[FSTObjectValue alloc]
                       initWithDictionary:@{@"name" : [FSTStringValue stringValue:@"Eros"]}]
      precondition:[FSTPrecondition none]];
}

@end

NS_ASSUME_NONNULL_END
