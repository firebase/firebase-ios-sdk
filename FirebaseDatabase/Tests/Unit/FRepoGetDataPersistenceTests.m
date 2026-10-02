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

/** A connection that fails every get as if the client were offline. */
@interface FOfflineGetConnection : FPersistentConnection

@end

@implementation FOfflineGetConnection

- (void)getDataAtPath:(NSString *)pathString
           withParams:(NSDictionary *)queryWireProtocolParams
         withCallback:(fbt_void_nsstring_id_nsstring)onComplete {
  onComplete(kFWPResponseForActionStatusFailed, nil, kPersistentConnectionOffline);
}

@end

@interface FRepoGetDataPersistenceTests : XCTestCase

@property(nonatomic, strong) FIRDatabaseConfig *config;
@property(nonatomic, strong) FMockStorageEngine *storageEngine;
@property(nonatomic, strong) FRepo *repo;

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
  FOfflineGetConnection *connection =
      [[FOfflineGetConnection alloc] initWithRepoInfo:repoInfo
                                        dispatchQueue:[FIRDatabaseQuery sharedQueue]
                                               config:self.config];
  // Replace the repo's connection once the repo has finished initializing on the shared queue, so
  // that the repo never reaches the network.
  dispatch_sync([FIRDatabaseQuery sharedQueue], ^{
    [self.repo.connection interruptForReason:kFInterruptReasonRepoInterrupt];
    self.repo.connection = connection;
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

  __block NSArray<FTrackedQuery *> *trackedQueries;
  dispatch_sync([FIRDatabaseQuery sharedQueue], ^{
    trackedQueries = [self.storageEngine loadTrackedQueries];
  });
  XCTAssertEqual(trackedQueries.count, 1);
  XCTAssertEqualObjects(trackedQueries.firstObject.query,
                        [FQuerySpec defaultQueryAtPath:PATH(@"foo")]);
  XCTAssertFalse(trackedQueries.firstObject.isActive);
}

@end
