/*
 * Copyright 2019 Google
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

#import "FBLPromise+Await.h"
#import "FBLPromise+Delay.h"
#import "FBLPromise+Testing.h"

#import "FIRInstallationsSingleOperationPromiseCache.h"

@interface FIRInstallationsSingleOperationPromiseCacheTests : XCTestCase

@end

@implementation FIRInstallationsSingleOperationPromiseCacheTests

// This test is flaky by definition.
// If this test fails at least once it means there must be a concurrency issue.
- (void)testRaceCondition {
  for (NSInteger i = 0; i < 100; i++) {
    [self assertRaceConditionWithParallelOperationCount:10000];
  }
}

- (void)assertRaceConditionWithParallelOperationCount:(NSInteger)count {
  FIRInstallationsSingleOperationPromiseCache *promiseCache =
      [[FIRInstallationsSingleOperationPromiseCache alloc]
          initWithNewOperationHandler:^FBLPromise *_Nonnull {
            [NSThread sleepForTimeInterval:0.001];
            return [[FBLPromise resolvedWith:[[NSObject alloc] init]] delay:0.001];
          }];

  XCTestExpectation *expectation = [self expectationWithDescription:@""];
  expectation.expectedFulfillmentCount = count;

  for (NSInteger i = 0; i < count; i++) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      XCTAssertNoThrow([promiseCache getExistingPendingPromise]);
    });

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      FBLPromise *promise = [promiseCache getExistingPendingOrCreateNewPromise];
      XCTAssertNotNil(promise);
      [expectation fulfill];
    });
  }

  XCTAssert(FBLWaitForPromisesWithTimeout(10));
  XCTAssertNil([promiseCache getExistingPendingPromise]);

  [self waitForExpectations:@[ expectation ] timeout:10];
}

@end
