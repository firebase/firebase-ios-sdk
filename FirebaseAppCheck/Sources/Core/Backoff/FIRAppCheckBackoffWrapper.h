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

@class FBLPromise<ValueType>;

NS_ASSUME_NONNULL_BEGIN

/// Backoff type. Indicates
typedef NS_ENUM(NSUInteger, FIRAppCheckBackoffType) {
  FIRAppCheckBackoffTypeNone,
  FIRAppCheckBackoffType1Day,
  FIRAppCheckBackoffTypeExponential
};

/// Creates a promise for an operation to apply the backoff to.
typedef FBLPromise *_Nonnull (^FIRAppCheckBackoffOperationProvider)(void);

/// Converts an error to a backoff type.
typedef FIRAppCheckBackoffType (^FIRAppCheckBackoffErrorHandler)(NSError *error);

/// A block returning a date. Is used instead of `+[NSDate date]` for better testability of logic
/// dependent on the current time.
typedef NSDate *_Nonnull (^FIRAppCheckDateProvider)(void);

@protocol FIRAppCheckBackoffWrapperProtocol <NSObject>

/// @param operationProvider A block that returns a new promise. The block will be called only when
/// the operation is allowed.
///        NOTE: We cannot accept just a promise because the operation will be started once the
///        promise has been instantiated, so we need to have a way to instantiate the promise only
///        when the operation is good to go. The provider block is the way we use.
/// @param errorHandler A block that receives an operation error as an input and returns the
/// appropriate backoff type. `defaultErrorHandler` provides a default implementation for Firebase
/// services.
/// @return A promise that is either:
///   - a promise returned by the promise provider if no backoff is required
///   - rejected if the backoff is needed
- (FBLPromise *)applyBackoffToOperation:(FIRAppCheckBackoffOperationProvider)operationProvider
                           errorHandler:(FIRAppCheckBackoffErrorHandler)errorHandler;

/// After calling this method the next call of `[backoff:errorHandler:]` method will always attempt
/// an operation even if a backoff was needed.
- (void)resetBackoff;

/// The default Firebase services error handler. It keeps track of network errors and
/// `FIRAppCheckHTTPError.HTTPResponse.statusCode.statusCode` value to return the appropriate
/// backoff type for the standard Firebase App Check backend response codes.
- (FIRAppCheckBackoffErrorHandler)defaultAppCheckProviderErrorHandler;

@end

/// Provides a backoff implementation. Keeps track of the operation successes and failures to either
/// create and perform the operation promise or fails with a backoff error when the backoff is
/// needed.
@interface FIRAppCheckBackoffWrapper : NSObject <FIRAppCheckBackoffWrapperProtocol>

/// Initializes the wrapper with `+[FIRAppCheckBackoffWrapper currentDateProvider]`.
- (instancetype)init;

- (instancetype)initWithDateProvider:(FIRAppCheckDateProvider)dateProvider
    NS_DESIGNATED_INITIALIZER;

/// A date provider that returns `+[NSDate date]`.
+ (FIRAppCheckDateProvider)currentDateProvider;

@end

NS_ASSUME_NONNULL_END
