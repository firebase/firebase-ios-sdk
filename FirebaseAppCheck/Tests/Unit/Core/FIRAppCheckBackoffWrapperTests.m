/*
 * Copyright 2021 Google LLC
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

#import "FBLPromise+Testing.h"
#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FirebaseAppCheck/Sources/Core/Backoff/FIRAppCheckBackoffWrapper.h"

@interface FIRAppCheckBackoffWrapperTests : XCTestCase

@property(nonatomic, nullable) FIRAppCheckBackoffWrapper *backoffWrapper;

@property(nonatomic) NSDate *currentDate;

/// `NSObject` subclass for resolve the `self.operation` with in the case of success or `NSError`
/// for a failure.
@property(nonatomic) id operationResult;
/// Operation to apply backoff to. It configure with the helper methods during tests.
@property(nonatomic) FIRAppCheckBackoffOperationProvider operationProvider;
/// Expectation to fulfill when operation is completed. It is configured with the `self.operation`
/// in setup helpers.
@property(nonatomic) XCTestExpectation *operationFinishExpectation;

/// Test error handler that returns `self.errorHandlerResult` and fulfills
/// `self.errorHandlerExpectation`.
@property(nonatomic, copy) FIRAppCheckBackoffErrorHandler errorHandler;
/// Expectation to fulfill when error handlers is executed.
@property(nonatomic) XCTestExpectation *errorHandlerExpectation;

@end

@implementation FIRAppCheckBackoffWrapperTests

- (void)setUp {
  [super setUp];

  __auto_type __weak weakSelf = self;
  self.backoffWrapper = [[FIRAppCheckBackoffWrapper alloc] initWithDateProvider:^NSDate *_Nonnull {
    return weakSelf.currentDate ?: [NSDate date];
  }];
}

- (void)tearDown {
  self.backoffWrapper = nil;
  self.operationProvider = nil;

  [super tearDown];
}

- (void)testBackoffFirstOperationAlwaysExecuted {
  // 1. Set up operation success.
  [self setUpOperationSuccess];
  [self setUpErrorHandlerWithBackoffType:FIRAppCheckBackoffTypeNone];
  self.errorHandlerExpectation.inverted = YES;

  // 3. Compose operation with backoff.
  __auto_type operationWithBackoff =
      [self.backoffWrapper applyBackoffToOperation:self.operationProvider
                                      errorHandler:self.errorHandler];

  // 4. Wait for operation to complete and check.
  [self waitForExpectationsWithTimeout:0.5 handler:NULL];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertEqualObjects(operationWithBackoff.value, self.operationResult);
}

- (void)testBackoff1DayBackoffAfterFailure {
  // 0. Set current date.
  self.currentDate = [NSDate date];

  // 1. Check initial failure.
  // 1.1. Set up operation failure.
  [self setUpOperationError];
  [self setUpErrorHandlerWithBackoffType:FIRAppCheckBackoffType1Day];

  // 1.3. Compose operation with backoff.
  __auto_type operationWithBackoff =
      [self.backoffWrapper applyBackoffToOperation:self.operationProvider
                                      errorHandler:self.errorHandler];

  // 1.4. Wait for operation to complete.
  [self waitForExpectationsWithTimeout:0.5 handler:NULL];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  // 1.5. Expect the promise to be rejected with the operation error.
  XCTAssertEqualObjects(operationWithBackoff.error, self.operationResult);

  // 2. Check backoff in 12 hours.
  // 2.1. Set up another operation.
  [self setUpOperationError];
  [self setUpErrorHandlerWithBackoffType:FIRAppCheckBackoffType1Day];

  // Don't expect operation to be called.
  self.operationFinishExpectation.inverted = YES;
  // Don't expect error handler to be called.
  self.errorHandlerExpectation.inverted = YES;

  // 2.2. Move current date.
  self.currentDate = [self.currentDate dateByAddingTimeInterval:12 * 60 * 60];

  // 2.3. Compose operation with backoff.
  operationWithBackoff = [self.backoffWrapper applyBackoffToOperation:self.operationProvider
                                                         errorHandler:self.errorHandler];

  // 2.4. Wait for operation to complete.
  [self waitForExpectationsWithTimeout:0.5 handler:NULL];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  // 2.5. Expect the promise to be rejected with a backoff error.
  XCTAssertTrue(operationWithBackoff.isRejected);
  XCTAssertTrue([self isBackoffError:operationWithBackoff.error]);

  // 3. Check backoff one minute before allowing retry.
  // 3.1. Set up another operation.
  [self setUpOperationError];
  [self setUpErrorHandlerWithBackoffType:FIRAppCheckBackoffType1Day];

  // Don't expect operation to be called.
  self.operationFinishExpectation.inverted = YES;
  // Don't expect error handler to be called.
  self.errorHandlerExpectation.inverted = YES;

  // 3.2. Move current date.
  self.currentDate = [self.currentDate dateByAddingTimeInterval:11 * 60 * 60 + 59 * 60];

  // 3.3. Compose operation with backoff.
  operationWithBackoff = [self.backoffWrapper applyBackoffToOperation:self.operationProvider
                                                         errorHandler:self.errorHandler];

  // 3.4. Wait for operation to complete.
  [self waitForExpectationsWithTimeout:0.5 handler:NULL];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  // 3.5. Expect the promise to be rejected with a backoff error.
  XCTAssertTrue(operationWithBackoff.isRejected);
  XCTAssertTrue([self isBackoffError:operationWithBackoff.error]);

  // 4. Check backoff one minute after allowing retry.
  // 4.1. Set up another operation.
  [self setUpOperationError];
  [self setUpErrorHandlerWithBackoffType:FIRAppCheckBackoffType1Day];

  // 4.2. Move current date.
  self.currentDate = [self.currentDate dateByAddingTimeInterval:12 * 60 * 60 + 1 * 60];

  // 4.3. Compose operation with backoff.
  operationWithBackoff = [self.backoffWrapper applyBackoffToOperation:self.operationProvider
                                                         errorHandler:self.errorHandler];

  // 4.4. Wait for operation to complete and check failure.
  [self waitForExpectationsWithTimeout:0.5 handler:NULL];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  // 4.5. Expect the promise to be rejected with the operation error.
  XCTAssertEqualObjects(operationWithBackoff.error, self.operationResult);
}

#pragma mark - Helpers

- (void)setUpErrorHandlerWithBackoffType:(FIRAppCheckBackoffType)backoffType {
  __auto_type __weak weakSelf = self;
  self.errorHandlerExpectation = [self expectationWithDescription:@"Error handler"];
  self.errorHandler = ^FIRAppCheckBackoffType(NSError *_Nonnull error) {
    [weakSelf.errorHandlerExpectation fulfill];
    return backoffType;
  };
}

- (void)setUpOperationSuccess {
  self.operationFinishExpectation = [self expectationWithDescription:@"Operation performed"];
  self.operationResult = [[NSObject alloc] init];
  __auto_type __weak weakSelf = self;
  self.operationProvider = ^FBLPromise *() {
    return [FBLPromise do:^id(void) {
      [weakSelf.operationFinishExpectation fulfill];
      return weakSelf.operationResult;
    }];
  };
}

- (void)setUpOperationError {
  self.operationFinishExpectation = [self expectationWithDescription:@"Operation performed"];
  self.operationResult = [NSError errorWithDomain:self.name code:-1 userInfo:nil];
  __auto_type __weak weakSelf = self;
  self.operationProvider = ^FBLPromise *() {
    return [FBLPromise do:^id(void) {
      [weakSelf.operationFinishExpectation fulfill];
      return weakSelf.operationResult;
    }];
  };
}

- (BOOL)isBackoffError:(NSError *)error {
  return [error.localizedDescription containsString:@"Too many attempts. Underlying error:"];
}

@end
