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

#import "FSTExponentialBackoff.h"

#import "FSTDispatchQueue.h"
#import "FSTLogger.h"
#import "FSTUtil.h"

@interface FSTExponentialBackoff ()
- (instancetype)initWithDispatchQueue:(FSTDispatchQueue *)dispatchQueue
                         initialDelay:(NSTimeInterval)initialDelay
                        backoffFactor:(double)backoffFactor
                             maxDelay:(NSTimeInterval)maxDelay NS_DESIGNATED_INITIALIZER;

@property(nonatomic, strong) FSTDispatchQueue *dispatchQueue;
@property(nonatomic) double backoffFactor;
@property(nonatomic) NSTimeInterval initialDelay;
@property(nonatomic) NSTimeInterval maxDelay;
@property(nonatomic) NSTimeInterval currentBase;
@end

@implementation FSTExponentialBackoff

- (instancetype)initWithDispatchQueue:(FSTDispatchQueue *)dispatchQueue
                         initialDelay:(NSTimeInterval)initialDelay
                        backoffFactor:(double)backoffFactor
                             maxDelay:(NSTimeInterval)maxDelay {
  if (self = [super init]) {
    _dispatchQueue = dispatchQueue;
    _initialDelay = initialDelay;
    _backoffFactor = backoffFactor;
    _maxDelay = maxDelay;

    [self reset];
  }
  return self;
}

+ (instancetype)exponentialBackoffWithDispatchQueue:(FSTDispatchQueue *)dispatchQueue
                                       initialDelay:(NSTimeInterval)initialDelay
                                      backoffFactor:(double)backoffFactor
                                           maxDelay:(NSTimeInterval)maxDelay {
  return [[FSTExponentialBackoff alloc] initWithDispatchQueue:dispatchQueue
                                                 initialDelay:initialDelay
                                                backoffFactor:backoffFactor
                                                     maxDelay:maxDelay];
}

- (void)reset {
  _currentBase = 0;
}

- (void)resetToMax {
  _currentBase = _maxDelay;
}

- (void)backoffAndRunBlock:(void (^)())block {
  // First schedule the block using the current base (which may be 0 and should be honored as such).
  NSTimeInterval delayWithJitter = _currentBase + [self jitterDelay];
  if (_currentBase > 0) {
    FSTLog(@"Backing off for %.2f seconds (base delay: %.2f seconds)", delayWithJitter,
           _currentBase);
  }
  dispatch_time_t delay =
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayWithJitter * NSEC_PER_SEC));
  dispatch_after(delay, self.dispatchQueue.queue, block);

  // Apply backoff factor to determine next delay and ensure it is within bounds.
  _currentBase *= _backoffFactor;
  if (_currentBase < _initialDelay) {
    _currentBase = _initialDelay;
  }
  if (_currentBase > _maxDelay) {
    _currentBase = _maxDelay;
  }
}

/** Returns a random value in the range [-currentBase/2, currentBase/2] */
- (NSTimeInterval)jitterDelay {
  return ([FSTUtil randomDouble] - 0.5) * _currentBase;
}

@end
