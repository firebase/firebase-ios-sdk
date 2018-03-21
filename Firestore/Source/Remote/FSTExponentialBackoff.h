/*
 * Copyright 2017 Google
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

#import "Firestore/Source/Util/FSTDispatchQueue.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Helper to implement exponential backoff.
 *
 * In general, call -reset after each successful round-trip. Call -backoffAndRunBlock before
 * retrying after an error. Each backoffAndRunBlock will increase the delay between retries.
 */
@interface FSTExponentialBackoff : NSObject

/**
 * Initializes a helper for running delayed tasks following an exponential backoff curve
 * between attempts.
 *
 * Each delay is made up of a "base" delay which follows the exponential backoff curve, and a
 * +/- 50% "jitter" that is calculated and added to the base delay. This prevents clients from
 * accidentally synchronizing their delays causing spikes of load to the backend.
 *
 * @param dispatchQueue The dispatch queue to run tasks on.
 * @param timerID The ID to use when scheduling backoff operations on the FSTDispatchQueue.
 * @param initialDelay The initial delay (used as the base delay on the first retry attempt).
 *     Note that jitter will still be applied, so the actual delay could be as little as
 *     0.5*initialDelay.
 * @param backoffFactor The multiplier to use to determine the extended base delay after each
 *     attempt.
 * @param maxDelay The maximum base delay after which no further backoff is performed. Note that
 *     jitter will still be applied, so the actual delay could be as much as 1.5*maxDelay.
 */
- (instancetype)initWithDispatchQueue:(FSTDispatchQueue *)dispatchQueue
                              timerID:(FSTTimerID)timerID
                         initialDelay:(NSTimeInterval)initialDelay
                        backoffFactor:(double)backoffFactor
                             maxDelay:(NSTimeInterval)maxDelay NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Resets the backoff delay.
 *
 * The very next backoffAndRunBlock: will have no delay. If it is called again (i.e. due to an
 * error), initialDelay (plus jitter) will be used, and subsequent ones will increase according
 * to the backoffFactor.
 */
- (void)reset;

/**
 * Resets the backoff to the maximum delay (e.g. for use after a RESOURCE_EXHAUSTED error).
 */
- (void)resetToMax;

/**
 * Waits for currentDelay seconds, increases the delay and runs the specified block. If there was
 * a pending block waiting to be run already, it will be canceled.
 *
 * @param block The block to run.
 */
- (void)backoffAndRunBlock:(void (^)(void))block;

/** Cancels any pending backoff block scheduled via backoffAndRunBlock:. */
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
