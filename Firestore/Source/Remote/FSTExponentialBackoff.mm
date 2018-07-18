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

#import "Firestore/Source/Remote/FSTExponentialBackoff.h"

#include <random>

#import "Firestore/Source/Util/FSTDispatchQueue.h"

#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/secure_random.h"

using firebase::firestore::util::SecureRandom;

@interface FSTExponentialBackoff ()

@property(nonatomic, strong) FSTDispatchQueue *dispatchQueue;
@property(nonatomic, assign, readonly) FSTTimerID timerID;
@property(nonatomic) double backoffFactor;
@property(nonatomic) NSTimeInterval initialDelay;
@property(nonatomic) NSTimeInterval maxDelay;
@property(nonatomic) NSTimeInterval currentBase;
@property(nonatomic, strong, nullable) FSTDelayedCallback *timerCallback;
@end

@implementation FSTExponentialBackoff {
  SecureRandom _secureRandom;
}

- (instancetype)initWithDispatchQueue:(FSTDispatchQueue *)dispatchQueue
                              timerID:(FSTTimerID)timerID
                         initialDelay:(NSTimeInterval)initialDelay
                        backoffFactor:(double)backoffFactor
                             maxDelay:(NSTimeInterval)maxDelay {
  if (self = [super init]) {
    _dispatchQueue = dispatchQueue;
    _timerID = timerID;
    _initialDelay = initialDelay;
    _backoffFactor = backoffFactor;
    _maxDelay = maxDelay;

    [self reset];
  }
  return self;
}

- (void)reset {
  _currentBase = 0;
}

- (void)resetToMax {
  _currentBase = _maxDelay;
}

- (void)backoffAndRunBlock:(void (^)(void))block {
  [self cancel];

  // First schedule the block using the current base (which may be 0 and should be honored as such).
  NSTimeInterval delayWithJitter = _currentBase + [self jitterDelay];
  if (_currentBase > 0) {
    LOG_DEBUG("Backing off for %s seconds (base delay: %s seconds)", delayWithJitter, _currentBase);
  }

  self.timerCallback =
      [self.dispatchQueue dispatchAfterDelay:delayWithJitter timerID:self.timerID block:block];

  // Apply backoff factor to determine next delay and ensure it is within bounds.
  _currentBase *= _backoffFactor;
  if (_currentBase < _initialDelay) {
    _currentBase = _initialDelay;
  }
  if (_currentBase > _maxDelay) {
    _currentBase = _maxDelay;
  }
}

- (void)cancel {
  if (self.timerCallback) {
    [self.timerCallback cancel];
    self.timerCallback = nil;
  }
}

/** Returns a random value in the range [-currentBase/2, currentBase/2] */
- (NSTimeInterval)jitterDelay {
  std::uniform_real_distribution<double> dist;
  double random_double = dist(_secureRandom);
  return (random_double - 0.5) * _currentBase;
}

@end
