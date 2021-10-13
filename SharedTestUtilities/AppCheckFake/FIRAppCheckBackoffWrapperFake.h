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

#import <Foundation/Foundation.h>

#import <XCTest/XCTest.h>

#import "FirebaseAppCheck/Sources/Core/Backoff/FIRAppCheckBackoffWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRAppCheckBackoffWrapperFake : NSObject <FIRAppCheckBackoffWrapperProtocol>

/// If `YES` then the next operation passed to `[backoff:errorHandler:]` method will be performed.
/// If `NO` then it will fail with a backoff error.
@property(nonatomic) BOOL isNextOperationAllowed;

/// Result of the last performed operation if it succeeded.
@property(nonatomic, nullable, readonly) id operationResult;

/// Error of the last performed operation if it failed.
@property(nonatomic, nullable, readonly) NSError *operationError;

/// Default error handler.
@property(nonatomic, copy) FIRAppCheckBackoffErrorHandler defaultErrorHandler;

/// Assign expectation to fulfill on  `[backoff:errorHandler:]` method call to this property.
@property(nonatomic, nullable) XCTestExpectation *backoffExpectation;

/// Error returned when retry is not allowed.
@property(nonatomic, readonly) NSError *backoffError;

@end

NS_ASSUME_NONNULL_END
