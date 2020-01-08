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

#import <Foundation/Foundation.h>

@class FIRCLSFABAsyncOperation;
@class XCTestCase;

/// These blocks provide mechanisms to indirectly call XCTestCase assertion macros, since they
/// require 'self' to be an XCTestCase. So, the test case adding expectations can pass along calls
/// to XCTAssert... and XCTFail into the methods of this class.
typedef void (^FABAsyncCompletionAssertionBlock)(NSString *operationName, NSError *error);
typedef void (^FABPreFlightCancellationFailureAssertionBlock)(void);

@interface FABTestExpectationObserver : NSObject

@property(copy, nonatomic) FABPreFlightCancellationFailureAssertionBlock assertionBlock;

@end

@interface FABTestExpectations : NSObject

/*
 The two following methods add XCTestExpectations for async operations that will be cancelled after
 they begin executing.
 */
+ (void)
    addInFlightCancellationCompletionExpectationsToOperation:(FIRCLSFABAsyncOperation *)operation
                                                    testCase:(XCTestCase *)testCase
                                              assertionBlock:
                                                  (FABAsyncCompletionAssertionBlock)assertionBlock;
+ (void)addInFlightCancellationKVOExpectationsToOperation:(FIRCLSFABAsyncOperation *)operation
                                                 testCase:(XCTestCase *)testCase;

/*
 The two following methods add XCTestExpectations for async operations that will be cancelled before
 they begin executing.
 */
+ (void)
    addPreFlightCancellationCompletionExpectationsToOperation:(FIRCLSFABAsyncOperation *)operation
                                                     testCase:(XCTestCase *)testCase
                                          asyncAssertionBlock:
                                              (FABAsyncCompletionAssertionBlock)asyncAssertionBlock;
+ (FABTestExpectationObserver *)
    addPreFlightCancellationKVOExpectationsToOperation:(FIRCLSFABAsyncOperation *)operation
                                              testCase:(XCTestCase *)testCase;

@end
