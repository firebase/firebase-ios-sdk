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

#import "AppCheckCore/Sources/Core/TokenRefresh/GACAppCheckTimer.h"

NS_ASSUME_NONNULL_BEGIN

@interface GACAppCheckTimer ()
@property(nonatomic, readonly) dispatch_queue_t dispatchQueue;
@property(atomic, readonly) dispatch_source_t timer;
@end

@implementation GACAppCheckTimer

+ (GACTimerProvider)timerProvider {
  return ^id<GACAppCheckTimerProtocol> _Nullable(NSDate *fireDate, dispatch_queue_t queue,
                                                 dispatch_block_t handler) {
    return [[GACAppCheckTimer alloc] initWithFireDate:fireDate dispatchQueue:queue block:handler];
  };
}

+ (nullable instancetype)timerFireDate:(NSDate *)fireDate
                         dispatchQueue:(dispatch_queue_t)dispatchQueue
                                 block:(dispatch_block_t)block {
  return [[GACAppCheckTimer alloc] initWithFireDate:fireDate
                                      dispatchQueue:dispatchQueue
                                              block:block];
}

- (nullable instancetype)initWithFireDate:(NSDate *)date
                            dispatchQueue:(dispatch_queue_t)dispatchQueue
                                    block:(dispatch_block_t)block {
  self = [super init];
  if (self == nil) {
    return nil;
  }

  if (block == nil) {
    return nil;
  }

  NSTimeInterval scheduleInSec = [date timeIntervalSinceNow];
  if (scheduleInSec <= 0) {
    return nil;
  }

  dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, scheduleInSec * NSEC_PER_SEC);
  _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.dispatchQueue);
  dispatch_source_set_timer(_timer, startTime, UINT64_MAX * NSEC_PER_SEC, 0);

  __auto_type __weak weakSelf = self;
  dispatch_source_set_event_handler(_timer, ^{
    __auto_type strongSelf = weakSelf;

    // The initializer returns a one-off timer, so we need to invalidate the dispatch timer to
    // prevent firing again.
    [strongSelf invalidate];
    block();
  });

  dispatch_resume(_timer);

  return self;
}

- (void)dealloc {
  [self invalidate];
}

- (void)invalidate {
  if (self.timer != nil) {
    dispatch_source_cancel(self.timer);
  }
}

@end

NS_ASSUME_NONNULL_END
