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
#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Core/FRepoManager.h"
#import "FirebaseDatabase/Sources/Core/FRepo_Private.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

/** A connection that records puts instead of sending them, so that tests can answer them. */
@interface FRecordingPutConnection : FPersistentConnection

@property(nonatomic, strong) NSMutableArray<fbt_void_nsstring_nsstring> *putCallbacks;

@end

@implementation FRecordingPutConnection

- (void)putData:(id)data
         forPath:(NSString *)pathString
        withHash:(NSString *)hash
    withCallback:(fbt_void_nsstring_nsstring)onComplete {
  [self.putCallbacks addObject:[onComplete copy]];
}

@end

@interface FRepoTransactionTests : XCTestCase

@property(nonatomic, strong) FIRDatabaseConfig *config;
@property(nonatomic, strong) FRepo *repo;
@property(nonatomic, strong) FRecordingPutConnection *connection;

@end

@implementation FRepoTransactionTests

- (void)setUp {
  [super setUp];
  self.config = [FTestHelpers configForName:@"FRepoTransactionTests"];
  FRepoInfo *repoInfo = [[FRepoInfo alloc] initWithHost:@"example.com"
                                               isSecure:NO
                                          withNamespace:@"default"];
  self.repo = [FRepoManager getRepo:repoInfo config:self.config];
  self.connection = [[FRecordingPutConnection alloc] initWithRepoInfo:repoInfo
                                                        dispatchQueue:[FIRDatabaseQuery sharedQueue]
                                                               config:self.config];
  self.connection.putCallbacks = [NSMutableArray array];
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

// When the server rejects the first of two queued transactions as stale, both are rerun and the
// observer should see the result of each rerun, not just the first.
- (void)testRerunRaisesEventsForEveryTransaction {
  FIRDatabaseReference *ref = [[FIRDatabaseReference alloc] initWithRepo:self.repo
                                                                    path:PATH(@"foo")];
  NSMutableArray *values = [self observeValuesAtRef:ref];
  [self runTwoTransactionsAtRef:ref];
  XCTAssertEqualObjects(values, (@[ @"first-1", @"second-1" ]));

  [self answerPut:0 withStatus:kFWPResponseForActionStatusDataStale];
  XCTAssertEqualObjects(values, (@[ @"first-1", @"second-1", @"first-2", @"second-2" ]));
}

// When the server rejects two transactions that were sent together, both are reverted and the
// observer should see the server value again, not the value of a rejected transaction.
- (void)testAbortRaisesRevertEventsForEveryTransaction {
  FIRDatabaseReference *ref = [[FIRDatabaseReference alloc] initWithRepo:self.repo
                                                                    path:PATH(@"foo")];
  NSMutableArray *values = [self observeValuesAtRef:ref];
  dispatch_sync([FIRDatabaseQuery sharedQueue], ^{
    [self.repo onDataUpdate:self.connection forPath:@"foo" message:@"server" isMerge:NO tagId:nil];
  });
  [self runTwoTransactionsAtRef:ref];
  // Answering the first put as stale reruns both transactions, which are then sent together.
  [self answerPut:0 withStatus:kFWPResponseForActionStatusDataStale];
  XCTAssertEqual(self.connection.putCallbacks.count, 2);
  XCTAssertEqualObjects(values.lastObject, @"second-2");

  [self answerPut:1 withStatus:@"permission_denied"];
  XCTAssertEqualObjects(values.lastObject, @"server");
}

/** Records the values that a value observer at `ref` receives. */
- (NSMutableArray *)observeValuesAtRef:(FIRDatabaseReference *)ref {
  NSMutableArray *values = [NSMutableArray array];
  [ref observeEventType:FIRDataEventTypeValue
              withBlock:^(FIRDataSnapshot *snapshot) {
                [values addObject:snapshot.value];
              }];
  return values;
}

/**
 * Starts two transactions at `ref` that set "first-<run>" and "second-<run>". Only the first one is
 * sent; the second one waits until the first one completes.
 */
- (void)runTwoTransactionsAtRef:(FIRDatabaseReference *)ref {
  __block int firstRuns = 0;
  [ref runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
    currentData.value = [NSString stringWithFormat:@"first-%d", ++firstRuns];
    return [FIRTransactionResult successWithValue:currentData];
  }];
  __block int secondRuns = 0;
  [ref runTransactionBlock:^FIRTransactionResult *(FIRMutableData *currentData) {
    currentData.value = [NSString stringWithFormat:@"second-%d", ++secondRuns];
    return [FIRTransactionResult successWithValue:currentData];
  }];
  [self waitForEvents];
  XCTAssertEqual(self.connection.putCallbacks.count, 1);
}

/** Answers the put at `index` with `status` and waits for the resulting events. */
- (void)answerPut:(NSUInteger)index withStatus:(NSString *)status {
  dispatch_sync([FIRDatabaseQuery sharedQueue], ^{
    self.connection.putCallbacks[index](status, nil);
  });
  [self waitForEvents];
}

/** Waits until the work queued on the shared queue has run and raised its events. */
- (void)waitForEvents {
  XCTestExpectation *raised = [self expectationWithDescription:@"events raised"];
  dispatch_async([FIRDatabaseQuery sharedQueue], ^{
    dispatch_async(self.config.callbackQueue, ^{
      [raised fulfill];
    });
  });
  [self waitForExpectations:@[ raised ] timeout:5];
}

@end
