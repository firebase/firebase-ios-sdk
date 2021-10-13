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
#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckHTTPError.h"

NS_ASSUME_NONNULL_BEGIN

static NSTimeInterval const k24Hours = 24 * 60 * 60;

/// Jitter coefficient 0.5 means that the backoff interval can be up to 50% longer.
static double const kMaxJitterCoefficient = 0.5;

/// Maximum exponential backoff interval.
static double const kMaxExponentialBackoffInterval = 4 * 60 * 60;  // 4 hours.

/// A class representing an operation result with data required for the backoff calculation.
@interface FIRAppCheckBackoffOperationFailure : NSObject

/// The operation finish date.
@property(nonatomic, readonly) NSDate *finishDate;

/// The operation error.
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

- (FBLPromise *)applyBackoffToOperation:(FIRAppCheckBackoffOperationProvider)operationProvider
                           errorHandler:(FIRAppCheckBackoffErrorHandler)errorHandler {
  if (![self isNextOperationAllowed]) {
    // Backing off - skip the operation and return an error straight away.
    return [self promiseWithRetryDisallowedError:self.lastFailure.error];
  }

  __auto_type operationPromise = operationProvider();
  return operationPromise
      .thenOn([self queue],
              ^id(id result) {
                @synchronized(self) {
                  // Reset failure on success.
                  self.lastFailure = nil;
                }

                // Return the result.
                return result;
              })
      .recoverOn([self queue], ^NSError *(NSError *error) {
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

#pragma mark - Private

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

      case FIRAppCheckBackoffTypeExponential:
        return [self hasTimeIntervalPassedSinceLastFailure:
                         [self exponentialBackoffIntervalForFailure:self.lastFailure]];
        break;
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
      [NSString stringWithFormat:@"Too many attempts. Underlying error: %@",
                                 error.localizedDescription ?: error.localizedFailureReason];
  NSError *retryDisallowedError = [FIRAppCheckErrorUtil errorWithFailureReason:reason];
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:retryDisallowedError];
  return rejectedPromise;
}

- (dispatch_queue_t)queue {
  return dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
}

#pragma mark - Exponential backoff

/// @return Exponential backoff interval with jitter. Jitter is needed to avoid all clients to retry
/// at the same time after e.g. a backend outage.
- (NSTimeInterval)exponentialBackoffIntervalForFailure:
    (FIRAppCheckBackoffOperationFailure *)failure {
  // Base exponential backoff interval.
  NSTimeInterval baseBackoff = pow(2, failure.retryCount);

  // Get a random number from 0 to 1.
  double maxRandom = 1000;
  double randomNumber = (double)arc4random_uniform((int32_t)maxRandom) / maxRandom;

  // A number from 1 to 1 + kMaxJitterCoefficient, e.g. from 1 to 1.5. Indicates how much the
  // backoff can be extended.
  double jitterCoefficient = 1 + randomNumber * kMaxJitterCoefficient;

  // Exponential backoff interval with jitter.
  NSTimeInterval backoffIntervalWithJitter = baseBackoff * jitterCoefficient;

  // Apply limit to the backoff interval.
  return MIN(backoffIntervalWithJitter, kMaxExponentialBackoffInterval);
}

#pragma mark - Error handling

- (FIRAppCheckBackoffErrorHandler)defaultAppCheckProviderErrorHandler {
  return ^FIRAppCheckBackoffType(NSError *error) {
    FIRAppCheckHTTPError *HTTPError =
        [error isKindOfClass:[FIRAppCheckHTTPError class]] ? (FIRAppCheckHTTPError *)error : nil;

    if (HTTPError == nil) {
      // No backoff for attestation providers for non-backend (e.g. network) errors.
      return FIRAppCheckBackoffTypeNone;
    }

    NSInteger statusCode = HTTPError.HTTPResponse.statusCode;

    if (statusCode < 400) {
      // No backoff for codes before 400.
      return FIRAppCheckBackoffTypeNone;
    }

    if (statusCode == 400 || statusCode == 404) {
      // Firebase project misconfiguration. It will unlikely be fixed soon and often requires
      // another version of the app. Try again in 1 day.
      return FIRAppCheckBackoffType1Day;
    }

    if (statusCode == 403) {
      // Project may have been soft-deleted accidentally. There is a chance of timely recovery, so
      // try again later.
      return FIRAppCheckBackoffTypeExponential;
    }

    if (statusCode == 429) {
      // Too many requests. Try again in a while.
      return FIRAppCheckBackoffTypeExponential;
    }

    if (statusCode == 503) {
      // Server is overloaded. Try again in a while.
      return FIRAppCheckBackoffTypeExponential;
    }

    // For all other server error cases default to the exponential backoff.
    return FIRAppCheckBackoffTypeExponential;
  };
}

@end

NS_ASSUME_NONNULL_END
