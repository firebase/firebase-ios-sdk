// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//  This test class checks behavior of an async operation that is cancelled after
//  its execution has begun. It makes use of KVO expectations to ensure it goes
//  through the expected state changes, and also makes use of the asyncCompletion
//  to pass an error proving the cancellation.

#import <XCTest/XCTest.h>

#import "Crashlytics/Shared/FIRCLSOperation/FIRCLSOperation.h"

#import "Crashlytics/UnitTests/FABOperation/FABTestAsyncOperation.h"
#import "Crashlytics/UnitTests/FABOperation/FABTestExpectations.h"

@interface FABInFlightCancellationTests : XCTestCase

@end

@implementation FABInFlightCancellationTests

- (void)testAsyncCancellationInFlight {
  FABTestAsyncOperation *cancelledOperation = [[FABTestAsyncOperation alloc] init];
  cancelledOperation.name = @"cancelledOperation";

  [FABTestExpectations
      addInFlightCancellationCompletionExpectationsToOperation:cancelledOperation
                                                      testCase:self
                                                assertionBlock:^(NSString *operationName,
                                                                 NSError *error) {
                                                  XCTAssertNotNil(error,
                                                                  @"Should have received error for "
                                                                  @"cancellation of %@.",
                                                                  operationName);
                                                  XCTAssertEqual(
                                                      error.code,
                                                      FABTestAsyncOperationErrorCodeCancelled,
                                                      @"Unexpected error code from %@.",
                                                      operationName);
                                                }];
  [FABTestExpectations addInFlightCancellationKVOExpectationsToOperation:cancelledOperation
                                                                testCase:self];

  NSOperationQueue *queue = [[NSOperationQueue alloc] init];
  [queue addOperation:cancelledOperation];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [cancelledOperation cancel];
                 });

  [self waitForExpectationsWithTimeout:5
                               handler:^(NSError *error) {
                                 XCTAssertNil(error, @"expectations failed: %@", error);
                               }];
}

// This test case adds several async operations to a compound operation and cancels the compound
// operation while the first of its suboperations is executing. When it cancels the operations on
// its compoundQueue, the first should be checked using the in-flight cancellation checks, and the
// ones awaiting execution should be checked using the pre-flight checks. The compound operation is
// checked using the in-flight checks.
- (void)testCompoundCancellationInFlight {
  FIRCLSCompoundOperation *cancelledCompoundOperation = [[FIRCLSCompoundOperation alloc] init];
  cancelledCompoundOperation.name = @"cancelled compound operation";
  cancelledCompoundOperation.compoundQueue.maxConcurrentOperationCount = 1;

  NSMutableArray<NSOperation *> *cancelledSuboperations = [NSMutableArray array];
  for (int i = 0; i < 5; i++) {
    FABTestAsyncOperation *subOperation = [[FABTestAsyncOperation alloc] init];
    subOperation.name = [NSString stringWithFormat:@"cancelledOperation%i", i];
    [cancelledSuboperations addObject:subOperation];
    if (i == 0) {
      [FABTestExpectations
          addInFlightCancellationCompletionExpectationsToOperation:subOperation
                                                          testCase:self
                                                    assertionBlock:^(NSString *operationName,
                                                                     NSError *error) {
                                                      XCTAssertNotNil(error,
                                                                      @"Should have received error "
                                                                      @"for cancellation of %@.",
                                                                      operationName);
                                                      XCTAssertEqual(
                                                          error.code,
                                                          FABTestAsyncOperationErrorCodeCancelled,
                                                          @"Unexpected error code from %@.",
                                                          operationName);
                                                    }];
      [FABTestExpectations addInFlightCancellationKVOExpectationsToOperation:subOperation
                                                                    testCase:self];
    } else {
      [FABTestExpectations
          addPreFlightCancellationCompletionExpectationsToOperation:subOperation
                                                           testCase:self
                                                asyncAssertionBlock:^(NSString *operationName,
                                                                      NSError *error) {
                                                  XCTFail(@"asyncCompletion should not have "
                                                          @"executed for %@",
                                                          operationName);
                                                }];
      FABTestExpectationObserver *observer =
          [FABTestExpectations addPreFlightCancellationKVOExpectationsToOperation:subOperation
                                                                         testCase:self];
      observer.assertionBlock = ^{
        XCTFail(@"%@ should not have begun executing", subOperation.name);
      };
    }
  }
  cancelledCompoundOperation.operations = cancelledSuboperations;

  [FABTestExpectations
      addInFlightCancellationCompletionExpectationsToOperation:cancelledCompoundOperation
                                                      testCase:self
                                                assertionBlock:^(NSString *operationName,
                                                                 NSError *error) {
                                                  XCTAssertNotNil(error,
                                                                  @"Should have received error for "
                                                                  @"cancellation of %@.",
                                                                  operationName);
                                                  XCTAssertEqual(
                                                      error.code,
                                                      FIRCLSCompoundOperationErrorCodeCancelled,
                                                      @"Unexpected error code from %@.",
                                                      operationName);
                                                }];
  [FABTestExpectations addInFlightCancellationKVOExpectationsToOperation:cancelledCompoundOperation
                                                                testCase:self];

  NSOperationQueue *queue = [[NSOperationQueue alloc] init];
  [queue addOperation:cancelledCompoundOperation];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [cancelledCompoundOperation cancel];
                 });

  [self waitForExpectationsWithTimeout:5
                               handler:^(NSError *error) {
                                 XCTAssertNil(error, @"expectations failed: %@", error);
                               }];
}

@end
