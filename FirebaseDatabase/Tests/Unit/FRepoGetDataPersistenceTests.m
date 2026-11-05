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

#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Core/FPersistentConnection.h"
#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"
#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Core/FRepoManager.h"
#import "FirebaseDatabase/Sources/Core/FRepo_Private.h"
#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Sources/Persistence/FTrackedQuery.h"
#import "FirebaseDatabase/Tests/Helpers/FMockStorageEngine.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

/** A connection whose get responses are configured by the test and whose listens stay pending. */
@interface FStubGetConnection : FPersistentConnection

@property(nonatomic, copy) NSString *getStatus;
@property(nonatomic, strong, nullable) id getData;
@property(nonatomic, copy, nullable) NSString *getErrorReason;

@end

@implementation FStubGetConnection

- (void)listen:(FQuerySpec *)query
         tagId:(NSNumber *)tagId
          hash:(id<FSyncTreeHash>)hash
    onComplete:(fbt_void_nsstring)onComplete {
  // Keep listens pending so `getData` is not satisfied from the in-memory cache before reaching the
  // connection.
}

- (void)unlisten:(FQuerySpec *)query tagId:(NSNumber *)tagId {
}

- (void)putData:(id)data
         forPath:(NSString *)pathString
        withHash:(NSString *)hash
    withCallback:(fbt_void_nsstring_nsstring)onComplete {
}

- (void)getDataAtPath:(NSString *)pathString
           withParams:(NSDictionary *)queryWireProtocolParams
         withCallback:(fbt_void_nsstring_id_nsstring)onComplete {
  onComplete(self.getStatus, self.getData, self.getErrorReason);
}

@end

@interface FRepoGetDataPersistenceTests : XCTestCase

@property(nonatomic, strong) FIRDatabaseConfig *config;
@property(nonatomic, strong) FMockStorageEngine *storageEngine;
@property(nonatomic, strong) FRepo *repo;
@property(nonatomic, strong) FStubGetConnection *connection;

@end

@implementation FRepoGetDataPersistenceTests

- (void)setUp {
  [super setUp];
  self.storageEngine = [[FMockStorageEngine alloc] init];
  self.config = [FTestHelpers configForName:@"FRepoGetDataPersistenceTests"];
  self.config.persistenceEnabled = YES;
  self.config.forceStorageEngine = self.storageEngine;
  FRepoInfo *repoInfo = [[FRepoInfo alloc] initWithHost:@"example.com"
                                               isSecure:NO
                                          withNamespace:@"default"];
  self.repo = [FRepoManager getRepo:repoInfo config:self.config];
  self.connection = [[FStubGetConnection alloc] initWithRepoInfo:repoInfo
                                                   dispatchQueue:[FIRDatabaseQuery sharedQueue]
                                                          config:self.config];
  self.connection.getStatus = kFWPResponseForActionStatusFailed;
  self.connection.getErrorReason = kPersistentConnectionOffline;
  // Replace the repo's connection once the repo has finished initializing on the shared queue, so
  // that the repo never reaches the network.
  dispatch_sync([FIRDatabaseQuery sharedQueue], ^{
    [self.repo.connection interruptForReason:kFInterruptReasonRepoInterrupt];
    self.repo.connection = self.connection;
  });
}

- (void)tearDown {
  [FRepoManager disposeRepos:self.config];
  [super tearDown];
}

// A one-shot get that fails without a cached value should mark its query inactive again, so that
// the query doesn't keep its location from being pruned from the cache.
- (void)testFailedGetDataWithoutCacheMarksQueryInactive {
  FIRDatabaseReference *ref = [[FIRDatabaseReference alloc] initWithRepo:self.repo
                                                                    path:PATH(@"foo")];
  XCTestExpectation *completed = [self expectationWithDescription:@"getData completed"];
  [ref getDataWithCompletionBlock:^(NSError *error, FIRDataSnapshot *snapshot) {
    XCTAssertNotNil(error);
    XCTAssertNil(snapshot);
    [completed fulfill];
  }];
  [self waitForExpectations:@[ completed ] timeout:5];

  FTrackedQuery *trackedQuery =
      [self trackedQueryForSpec:[FQuerySpec defaultQueryAtPath:PATH(@"foo")]];
  XCTAssertNotNil(trackedQuery);
  XCTAssertFalse(trackedQuery.isActive);
}

- (void)testSucceededGetDataOnObservedFilteredQueryKeepsQueryActive {
  self.connection.getStatus = kFWPResponseForActionStatusOk;
  self.connection.getData = @{@"c" : @3, @"d" : @4};
  self.connection.getErrorReason = nil;

  FIRDatabaseReference *ref = [[FIRDatabaseReference alloc] initWithRepo:self.repo
                                                                    path:PATH(@"foo")];
  FIRDatabaseQuery *query = [[ref queryOrderedByKey] queryLimitedToLast:2];
  FIRDatabaseHandle handle = [query observeEventType:FIRDataEventTypeValue
                                           withBlock:^(FIRDataSnapshot *snapshot){
                                           }];

  XCTestExpectation *completed = [self expectationWithDescription:@"getData completed"];
  [query getDataWithCompletionBlock:^(NSError *error, FIRDataSnapshot *snapshot) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(snapshot.value, (@{@"c" : @3, @"d" : @4}));
    [completed fulfill];
  }];
  [self waitForExpectations:@[ completed ] timeout:5];

  FTrackedQuery *trackedQuery = [self trackedQueryForSpec:query.querySpec];
  XCTAssertNotNil(trackedQuery);
  XCTAssertTrue(trackedQuery.isActive);

  // Updating keys in the active filtered view asserts that the tracked query is still active.
  [[ref child:@"e"] setValue:@5];

  [query removeObserverWithHandle:handle];
  trackedQuery = [self trackedQueryForSpec:query.querySpec];
  XCTAssertNotNil(trackedQuery);
  XCTAssertFalse(trackedQuery.isActive);
}

- (void)testFailedGetDataOnKeptSyncedFilteredQueryKeepsQueryActive {
  FIRDatabaseReference *ref = [[FIRDatabaseReference alloc] initWithRepo:self.repo
                                                                    path:PATH(@"foo")];
  FIRDatabaseQuery *query = [[ref queryOrderedByKey] queryLimitedToLast:2];
  [query keepSynced:YES];

  XCTestExpectation *completed = [self expectationWithDescription:@"getData completed"];
  [query getDataWithCompletionBlock:^(NSError *error, FIRDataSnapshot *snapshot) {
    XCTAssertNotNil(error);
    [completed fulfill];
  }];
  [self waitForExpectations:@[ completed ] timeout:5];

  FTrackedQuery *trackedQuery = [self trackedQueryForSpec:query.querySpec];
  XCTAssertNotNil(trackedQuery);
  XCTAssertTrue(trackedQuery.isActive);

  // Updating keys in the active filtered view asserts that the tracked query is still active.
  [[ref child:@"a"] setValue:@1];

  [query keepSynced:NO];
  trackedQuery = [self trackedQueryForSpec:query.querySpec];
  XCTAssertNotNil(trackedQuery);
  XCTAssertFalse(trackedQuery.isActive);
}

- (void)testSucceededGetDataOnObservedDefaultQueryKeepsQueryActive {
  self.connection.getStatus = kFWPResponseForActionStatusOk;
  self.connection.getData = @{@"a" : @1};
  self.connection.getErrorReason = nil;

  FIRDatabaseReference *ref = [[FIRDatabaseReference alloc] initWithRepo:self.repo
                                                                    path:PATH(@"foo")];
  FIRDatabaseHandle handle = [ref observeEventType:FIRDataEventTypeValue
                                         withBlock:^(FIRDataSnapshot *snapshot){
                                         }];

  XCTestExpectation *completed = [self expectationWithDescription:@"getData completed"];
  [[ref queryOrderedByKey] getDataWithCompletionBlock:^(NSError *error, FIRDataSnapshot *snapshot) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(snapshot.value, @{@"a" : @1});
    [completed fulfill];
  }];
  [self waitForExpectations:@[ completed ] timeout:5];

  FQuerySpec *defaultSpec = [FQuerySpec defaultQueryAtPath:PATH(@"foo")];
  FTrackedQuery *trackedQuery = [self trackedQueryForSpec:defaultSpec];
  XCTAssertNotNil(trackedQuery);
  XCTAssertTrue(trackedQuery.isActive);

  [ref removeObserverWithHandle:handle];
  trackedQuery = [self trackedQueryForSpec:defaultSpec];
  XCTAssertNotNil(trackedQuery);
  XCTAssertFalse(trackedQuery.isActive);
}

- (nullable FTrackedQuery *)trackedQueryForSpec:(FQuerySpec *)querySpec {
  __block NSArray<FTrackedQuery *> *trackedQueries;
  dispatch_sync([FIRDatabaseQuery sharedQueue], ^{
    trackedQueries = [self.storageEngine loadTrackedQueries];
  });
  for (FTrackedQuery *trackedQuery in trackedQueries) {
    if ([trackedQuery.query isEqual:querySpec]) {
      return trackedQuery;
    }
  }
  return nil;
}

@end
