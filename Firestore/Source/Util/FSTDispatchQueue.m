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

#import "FSTAssert.h"
#import "FSTDispatchQueue.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTDispatchQueue ()
- (instancetype)initWithQueue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;
@end

@implementation FSTDispatchQueue

+ (instancetype)queueWith:(dispatch_queue_t)dispatchQueue {
  return [[FSTDispatchQueue alloc] initWithQueue:dispatchQueue];
}

- (instancetype)initWithQueue:(dispatch_queue_t)queue {
  if (self = [super init]) {
    _queue = queue;
  }
  return self;
}

- (void)verifyIsCurrentQueue {
  FSTAssert([self onTargetQueue],
            @"We are running on the wrong dispatch queue. Expected '%@' Actual: '%@'",
            [self targetQueueLabel], [self currentQueueLabel]);
}

- (void)dispatchAsync:(void (^)(void))block {
  FSTAssert(![self onTargetQueue],
            @"dispatchAsync called when we are already running on target dispatch queue '%@'",
            [self targetQueueLabel]);

  dispatch_async(self.queue, block);
}

- (void)dispatchAsyncAllowingSameQueue:(void (^)(void))block {
  dispatch_async(self.queue, block);
}

#pragma mark - Private Methods

- (NSString *)currentQueueLabel {
  return [NSString stringWithUTF8String:dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL)];
}

- (NSString *)targetQueueLabel {
  return [NSString stringWithUTF8String:dispatch_queue_get_label(self.queue)];
}

- (BOOL)onTargetQueue {
  return [[self currentQueueLabel] isEqualToString:[self targetQueueLabel]];
}

@end

NS_ASSUME_NONNULL_END
