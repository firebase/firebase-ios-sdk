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

#import "Firestore/Example/Tests/Util/FSTTestDispatchQueue.h"

#import <XCTest/XCTestExpectation.h>

#import "Firestore/Source/Util/FSTAssert.h"

@interface FSTTestDispatchQueue ()

@property(nonatomic, weak) XCTestExpectation* expectation;

@end

@implementation FSTTestDispatchQueue

/** The delay used by the idle timeout */
static const NSTimeInterval kIdleDispatchDelay = 60.0;

/** The maximum delay we use in a test run. */
static const NSTimeInterval kTestDispatchDelay = 1.0;

+ (instancetype)queueWith:(dispatch_queue_t)dispatchQueue {
  return [[FSTTestDispatchQueue alloc] initWithQueue:dispatchQueue];
}

- (instancetype)initWithQueue:(dispatch_queue_t)dispatchQueue {
  return (self = [super initWithQueue:dispatchQueue]);
}

- (void)dispatchAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block {
  [super dispatchAfterDelay:MIN(delay, kTestDispatchDelay)
                      block:^() {
                        block();
                        if (delay == kIdleDispatchDelay) {
                          [_expectation fulfill];
                          _expectation = nil;
                        }
                      }];
}

- (void)fulfillOnExecution:(XCTestExpectation*)expectation {
  FSTAssert(_expectation == nil, @"Previous expectation still active");
  _expectation = expectation;
}

@end
