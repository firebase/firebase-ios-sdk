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

#import "Crashlytics/UnitTests/FABOperation/FABTestExpectations.h"

#import <XCTest/XCTest.h>

#import "Crashlytics/Shared/FIRCLSOperation/FIRCLSOperation.h"

#import "Crashlytics/UnitTests/FABOperation/FABTestAsyncOperation.h"

void *FABOperationPreFlightCancellationTestKVOContext =
    &FABOperationPreFlightCancellationTestKVOContext;

@interface FABTestExpectationObserver ()

@property(strong, nonatomic) FIRCLSFABAsyncOperation *observedOperation;

@end

@implementation FABTestExpectationObserver

- (void)dealloc {
  [self.observedOperation removeObserver:self
                              forKeyPath:NSStringFromSelector(@selector(isExecuting))];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *, id> *)change
                       context:(void *)context {
  if (context != FABOperationPreFlightCancellationTestKVOContext) {
    return;
  }
  if (![object isKindOfClass:[FABTestAsyncOperation class]]) {
    return;
  }
  if (![keyPath isEqualToString:NSStringFromSelector(@selector(isExecuting))]) {
    return;
  }
  if (![change[@"new"] boolValue]) {
    return;
  }

  if (self.assertionBlock) {
    self.assertionBlock();
  }
}

@end

@implementation FABTestExpectations

+ (void)
    addInFlightCancellationCompletionExpectationsToOperation:(FIRCLSFABAsyncOperation *)operation
                                                    testCase:(XCTestCase *)testCase
                                              assertionBlock:
                                                  (FABAsyncCompletionAssertionBlock)assertionBlock {
  XCTestExpectation *syncCompletionExpectation = [testCase
      expectationWithDescription:[NSString stringWithFormat:@"%@ syncCompletionExpectation",
                                                            operation.name]];
  operation.completionBlock = ^{
    [syncCompletionExpectation fulfill];
  };

  XCTestExpectation *asyncCompletionExpectation = [testCase
      expectationWithDescription:[NSString stringWithFormat:@"%@ asyncCompletionExpectation",
                                                            operation.name]];
  NSString *operationName = [operation.name copy];
  operation.asyncCompletion = ^(NSError *error) {
    [asyncCompletionExpectation fulfill];
    assertionBlock(operationName, error);
  };
}

+ (void)addInFlightCancellationKVOExpectationsToOperation:(FIRCLSFABAsyncOperation *)operation
                                                 testCase:(XCTestCase *)testCase {
  for (NSString *selector in @[
         NSStringFromSelector(@selector(isCancelled)), NSStringFromSelector(@selector(isFinished)),
         NSStringFromSelector(@selector(isExecuting))
       ]) {
    BOOL (^handler)(NSOperation *observedOperation, NSDictionary *change) =
        ^(NSOperation *observedOperation, NSDictionary *change) {
          if ([selector isEqualToString:NSStringFromSelector(@selector(isExecuting))]) {
            if (!observedOperation.isCancelled && !observedOperation.isFinished &&
                ![change[@"old"] boolValue] && [change[@"new"] boolValue]) {
              return YES;
            }
          } else if ([selector isEqualToString:NSStringFromSelector(@selector(isCancelled))]) {
            if (observedOperation.isExecuting && !observedOperation.isFinished &&
                ![change[@"old"] boolValue] && [change[@"new"] boolValue]) {
              return YES;
            }
          } else if ([selector isEqualToString:NSStringFromSelector(@selector(isFinished))]) {
            if (observedOperation.isCancelled && !observedOperation.isExecuting &&
                ![change[@"old"] boolValue] && [change[@"new"] boolValue]) {
              return YES;
            }
          }

          return NO;
        };
    [testCase keyValueObservingExpectationForObject:operation keyPath:selector handler:handler];
  }
}

+ (void)addPreFlightCancellationCompletionExpectationsToOperation:
            (FIRCLSFABAsyncOperation *)operation
                                                         testCase:(XCTestCase *)testCase
                                              asyncAssertionBlock:(FABAsyncCompletionAssertionBlock)
                                                                      asyncAssertionBlock {
  // we expect the synchronous, standard completionBlock to execute. Per Apple's documentation, it
  // always executes when isFinished is set to true, regardless of whether by cancellation or
  // finishing execution
  XCTestExpectation *syncCompletionExpectation =
      [testCase expectationWithDescription:@"syncCompletionExpectation"];
  operation.completionBlock = ^{
    [syncCompletionExpectation fulfill];
  };

  // call block containing XCTest assertions in asyncCompletion which will fail the test, it's just
  // more convenient to pass the block in containing them because of the way the macros work: they
  // use 'self' which must resolve to the XCTestCase instance
  NSString *operationName = [operation.name copy];
  operation.asyncCompletion = ^(NSError *error) {
    asyncAssertionBlock(operationName, error);
  };
}

+ (FABTestExpectationObserver *)
    addPreFlightCancellationKVOExpectationsToOperation:(FIRCLSFABAsyncOperation *)operation
                                              testCase:(XCTestCase *)testCase {
  // add an expectation that isFinished is set to true, isCancelled is true and isExecuting is false
  BOOL (^handler)(NSOperation *observedOperation, NSDictionary *change) =
      ^(NSOperation *observedOperation, NSDictionary *change) {
        if (observedOperation.isCancelled && !observedOperation.isExecuting &&
            ![change[@"old"] boolValue] && [change[@"new"] boolValue]) {
          return YES;
        }

        return NO;
      };
  [testCase keyValueObservingExpectationForObject:operation
                                          keyPath:NSStringFromSelector(@selector(isFinished))
                                          handler:handler];

  // add key-value observing for isExecuting. if isExecuting ever changes to true for this
  // operation, we want to *fail* the test. We can't do this with expectations, so we use plain KVO.
  FABTestExpectationObserver *observer = [[FABTestExpectationObserver alloc] init];
  [operation addObserver:observer
              forKeyPath:NSStringFromSelector(@selector(isExecuting))
                 options:NSKeyValueObservingOptionNew
                 context:FABOperationPreFlightCancellationTestKVOContext];
  observer.observedOperation = operation;
  return observer;
}

@end
