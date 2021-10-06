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

#import "FirebaseAppCheck/Sources/Core/Backoff/FIRAppCheckBackoffWrapper.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"

NS_ASSUME_NONNULL_BEGIN

static NSTimeInterval const k24Hours = 24 * 60 * 60;

/// A class representing an operation result with data required for the backoff calculation.
@interface FIRAppCheckBackoffOperationFailure : NSObject

/// The operation finish date.
@property(nonatomic, readonly) NSDate *finishDate;

/// The operation error. If `nil` then the operation succeeded.
@property(nonatomic, readonly) NSError *error;

/// A backoff type calculated based on the error.
@property(nonatomic, readonly) FIRAppCheckBackoffType backoffType;

/// Number of retries. Is 0 for the first attempt and incremented with each error. Is reset back to
/// 0 on success.
@property(nonatomic, readonly) NSInteger retryCount;

/// Designated initializer.
- (instancetype)initWithFinishDate:(NSDate *)finishDate
                             error:(NSError *)error
                       backoffType:(FIRAppCheckBackoffType)backoffType
                        retryCount:(NSInteger)retryCount NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Creates a new result with incremented retryCount and specified error and backoff type.
+ (instancetype)nextRetryFailureWithFailure:
                    (nullable FIRAppCheckBackoffOperationFailure *)previousFailure
                                 finishDate:(NSDate *)finishDate
                                      error:(NSError *)error
                                backoffType:(FIRAppCheckBackoffType)backoffType;

@end

@implementation FIRAppCheckBackoffOperationFailure

- (instancetype)initWithFinishDate:(NSDate *)finishDate
                             error:(NSError *)error
                       backoffType:(FIRAppCheckBackoffType)backoffType
                        retryCount:(NSInteger)retryCount {
  self = [super init];
  if (self) {
    _finishDate = finishDate;
    _error = error;
    _retryCount = retryCount;
    _backoffType = backoffType;
  }
  return self;
}

+ (instancetype)nextRetryFailureWithFailure:
                    (nullable FIRAppCheckBackoffOperationFailure *)previousFailure
                                 finishDate:(NSDate *)finishDate
                                      error:(NSError *)error
                                backoffType:(FIRAppCheckBackoffType)backoffType {
  NSInteger newRetryCount = previousFailure ? previousFailure.retryCount + 1 : 0;

  return [[self alloc] initWithFinishDate:finishDate
                                    error:error
                              backoffType:backoffType
                               retryCount:newRetryCount];
}

@end

@interface FIRAppCheckBackoffWrapper ()

/// Current date provider. Is used instead of `+[NSDate date]` for testability.
@property(nonatomic, readonly) FIRAppCheckDateProvider dateProvider;

/// Last operation result.
@property(nonatomic, nullable) FIRAppCheckBackoffOperationFailure *lastFailure;

@end

@implementation FIRAppCheckBackoffWrapper

- (instancetype)init {
  return [self initWithDateProvider:[FIRAppCheckBackoffWrapper currentDateProvider]];
}

- (instancetype)initWithDateProvider:(FIRAppCheckDateProvider)dateProvider {
  self = [super init];
  if (self) {
    _dateProvider = [dateProvider copy];
  }
  return self;
}

+ (FIRAppCheckDateProvider)currentDateProvider {
  return ^NSDate *(void) {
    return [NSDate date];
  };
}

- (FBLPromise *)backoff:(FIRAppCheckBackoffOperationProvider)operationProvider
           errorHandler:(FIRAppCheckBackoffErrorHandler)errorHandler {
  if (![self isNextOperationAllowed]) {
    // Backing off - skip the operation and return an error straight away.
    return [self promiseWithRetryDisallowedError:self.lastFailure.error];
  }

  __auto_type operationPromise = operationProvider();
  return operationPromise
      .thenOn(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0),
              ^id(id result) {
                @synchronized(self) {
                  // Reset failure on success.
                  self.lastFailure = nil;
                }

                // Return the result.
                return result;
              })
      .recoverOn(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^NSError *(NSError *error) {
        @synchronized(self) {
          // Update the last failure to calculate the backoff.
          self.lastFailure =
              [FIRAppCheckBackoffOperationFailure nextRetryFailureWithFailure:self.lastFailure
                                                                   finishDate:self.dateProvider()
                                                                        error:error
                                                                  backoffType:errorHandler(error)];
        }

        // Re-throw the error.
        return error;
      });
}

- (FIRAppCheckBackoffErrorHandler)defaultErrorHandler {
  return ^FIRAppCheckBackoffType(NSError *error) {
    return FIRAppCheckBackoffTypeNone;
  };
}

- (void)resetBackoff {
  @synchronized(self) {
    self.lastFailure = nil;
  }
}

#pragma mark -

- (BOOL)isNextOperationAllowed {
  @synchronized(self) {
    if (self.lastFailure == nil) {
      // It is first attempt. Always allow it.
      return YES;
    }

    switch (self.lastFailure.backoffType) {
      case FIRAppCheckBackoffTypeNone:
        return YES;
        break;

      case FIRAppCheckBackoffType1Day:
        return [self hasTimeIntervalPassedSinceLastFailure:k24Hours];
        break;

        // TODO: Implement other cases.
      default:
        return YES;
    }
  }
}

- (BOOL)hasTimeIntervalPassedSinceLastFailure:(NSTimeInterval)timeInterval {
  NSDate *failureDate = self.lastFailure.finishDate;
  // Return YES if there has not been a failure yet.
  if (failureDate == nil) return YES;

  NSTimeInterval timeSinceFailure = [self.dateProvider() timeIntervalSinceDate:failureDate];
  return timeSinceFailure >= timeInterval;
}

- (FBLPromise *)promiseWithRetryDisallowedError:(NSError *)error {
  NSString *reason =
      [NSString stringWithFormat:@"To many attempts. Underlying error: %@",
                                 error.localizedDescription ?: error.localizedFailureReason];
  NSError *retryDisallowedError = [FIRAppCheckErrorUtil errorWithFailureReason:reason];
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:retryDisallowedError];
  return rejectedPromise;
}

@end

NS_ASSUME_NONNULL_END
