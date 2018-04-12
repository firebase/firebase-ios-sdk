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

#include <atomic>

#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * removeDelayedCallback is used by FSTDelayedCallback and so we pre-declare it before the rest of
 * the FSTDispatchQueue private interface.
 */
@interface FSTDispatchQueue ()
- (void)removeDelayedCallback:(FSTDelayedCallback *)callback;
@end

#pragma mark - FSTDelayedCallback

/**
 * Represents a callback scheduled to be run in the future on an FSTDispatchQueue.
 *
 * It is created via [FSTDelayedCallback createAndScheduleWithQueue].
 *
 * Supports cancellation (via cancel) and early execution (via skipDelay).
 */
@interface FSTDelayedCallback ()

@property(nonatomic, strong, readonly) FSTDispatchQueue *queue;
@property(nonatomic, assign, readonly) FSTTimerID timerID;
@property(nonatomic, assign, readonly) NSTimeInterval targetTime;
@property(nonatomic, copy) void (^callback)();
/** YES if the callback has been run or canceled. */
@property(nonatomic, getter=isDone) BOOL done;

/**
 * Creates and returns an FSTDelayedCallback that has been scheduled on the provided queue with the
 * provided delay.
 *
 * @param queue The FSTDispatchQueue to run the callback on.
 * @param timerID A FSTTimerID identifying the type of the delayed callback.
 * @param delay The delay before the callback should be scheduled.
 * @param callback The callback block to run.
 * @return The created FSTDelayedCallback instance.
 */
+ (instancetype)createAndScheduleWithQueue:(FSTDispatchQueue *)queue
                                   timerID:(FSTTimerID)timerID
                                     delay:(NSTimeInterval)delay
                                  callback:(void (^)(void))callback;

/**
 * Queues the callback to run immediately (if it hasn't already been run or canceled).
 */
- (void)skipDelay;

@end

@implementation FSTDelayedCallback

- (instancetype)initWithQueue:(FSTDispatchQueue *)queue
                      timerID:(FSTTimerID)timerID
                   targetTime:(NSTimeInterval)targetTime
                     callback:(void (^)(void))callback {
  if (self = [super init]) {
    _queue = queue;
    _timerID = timerID;
    _targetTime = targetTime;
    _callback = callback;
    _done = NO;
  }
  return self;
}

+ (instancetype)createAndScheduleWithQueue:(FSTDispatchQueue *)queue
                                   timerID:(FSTTimerID)timerID
                                     delay:(NSTimeInterval)delay
                                  callback:(void (^)(void))callback {
  NSTimeInterval targetTime = [[NSDate date] timeIntervalSince1970] + delay;
  FSTDelayedCallback *delayedCallback = [[FSTDelayedCallback alloc] initWithQueue:queue
                                                                          timerID:timerID
                                                                       targetTime:targetTime
                                                                         callback:callback];
  [delayedCallback startWithDelay:delay];
  return delayedCallback;
}

/**
 * Starts the timer. This is called immediately after construction by createAndScheduleWithQueue.
 */
- (void)startWithDelay:(NSTimeInterval)delay {
  dispatch_time_t delayNs = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
  dispatch_after(delayNs, self.queue.queue, ^{
    [self.queue enterCheckedOperation:^{
      [self delayDidElapse];
    }];
  });
}

- (void)skipDelay {
  [self.queue dispatchAsyncAllowingSameQueue:^{
    [self delayDidElapse];
  }];
}

- (void)cancel {
  [self.queue verifyIsCurrentQueue];
  if (!self.isDone) {
    // PORTING NOTE: There's no way to actually cancel the dispatched callback, but it'll be a no-op
    // since we set done to YES.
    [self markDone];
  }
}

- (void)delayDidElapse {
  [self.queue verifyIsCurrentQueue];
  if (!self.isDone) {
    [self markDone];
    self.callback();
  }
}

/**
 * Marks this delayed callback as done, and notifies the FSTDispatchQueue that it should be removed.
 */
- (void)markDone {
  self.done = YES;
  [self.queue removeDelayedCallback:self];
}

@end

#pragma mark - FSTDispatchQueue

@interface FSTDispatchQueue ()
/**
 * Callbacks scheduled to be queued in the future. Callbacks are automatically removed after they
 * are run or canceled.
 */
@property(nonatomic, strong, readonly) NSMutableArray<FSTDelayedCallback *> *delayedCallbacks;

- (instancetype)initWithQueue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTDispatchQueue {
  /**
   * Flag set while an FSTDispatchQueue operation is currently executing. Used for assertion
   * sanity-checks.
   */
  std::atomic<bool> _operationInProgress;
}

+ (instancetype)queueWith:(dispatch_queue_t)dispatchQueue {
  return [[FSTDispatchQueue alloc] initWithQueue:dispatchQueue];
}

- (instancetype)initWithQueue:(dispatch_queue_t)queue {
  if (self = [super init]) {
    _operationInProgress = false;
    _queue = queue;
    _delayedCallbacks = [NSMutableArray array];
  }
  return self;
}

- (void)verifyIsCurrentQueue {
  FSTAssert([self onTargetQueue],
            @"We are running on the wrong dispatch queue. Expected '%@' Actual: '%@'",
            [self targetQueueLabel], [self currentQueueLabel]);
  FSTAssert(_operationInProgress,
            @"verifyIsCurrentQueue called outside enterCheckedOperation on queue '%@'",
            [self currentQueueLabel]);
}

- (void)enterCheckedOperation:(void (^)(void))block {
  FSTAssert(!_operationInProgress,
            @"enterCheckedOperation may not be called when an operation is in progress");
  @try {
    _operationInProgress = true;
    [self verifyIsCurrentQueue];
    block();
  } @finally {
    _operationInProgress = false;
  }
}

- (void)dispatchAsync:(void (^)(void))block {
  FSTAssert(![self onTargetQueue] || !_operationInProgress,
            @"dispatchAsync called when we are already running on target dispatch queue '%@'",
            [self targetQueueLabel]);

  dispatch_async(self.queue, ^{
    [self enterCheckedOperation:block];
  });
}

- (void)dispatchAsyncAllowingSameQueue:(void (^)(void))block {
  dispatch_async(self.queue, ^{
    [self enterCheckedOperation:block];
  });
}

- (void)dispatchSync:(void (^)(void))block {
  FSTAssert(![self onTargetQueue] || !_operationInProgress,
            @"dispatchSync called when we are already running on target dispatch queue '%@'",
            [self targetQueueLabel]);

  dispatch_sync(self.queue, ^{
    [self enterCheckedOperation:block];
  });
}

- (FSTDelayedCallback *)dispatchAfterDelay:(NSTimeInterval)delay
                                   timerID:(FSTTimerID)timerID
                                     block:(void (^)(void))block {
  // While not necessarily harmful, we currently don't expect to have multiple callbacks with the
  // same timerID in the queue, so defensively reject them.
  FSTAssert(![self containsDelayedCallbackWithTimerID:timerID],
            @"Attempted to schedule multiple callbacks with id %ld", (unsigned long)timerID);
  FSTDelayedCallback *delayedCallback = [FSTDelayedCallback createAndScheduleWithQueue:self
                                                                               timerID:timerID
                                                                                 delay:delay
                                                                              callback:block];
  [self.delayedCallbacks addObject:delayedCallback];
  return delayedCallback;
}

- (BOOL)containsDelayedCallbackWithTimerID:(FSTTimerID)timerID {
  NSUInteger matchIndex = [self.delayedCallbacks
      indexOfObjectPassingTest:^BOOL(FSTDelayedCallback *obj, NSUInteger idx, BOOL *stop) {
        return obj.timerID == timerID;
      }];
  return matchIndex != NSNotFound;
}

- (void)runDelayedCallbacksUntil:(FSTTimerID)lastTimerID {
  dispatch_semaphore_t doneSemaphore = dispatch_semaphore_create(0);

  [self dispatchAsync:^{
    FSTAssert(lastTimerID == FSTTimerIDAll || [self containsDelayedCallbackWithTimerID:lastTimerID],
              @"Attempted to run callbacks until missing timer ID: %ld",
              (unsigned long)lastTimerID);

    [self sortDelayedCallbacks];
    for (FSTDelayedCallback *callback in self.delayedCallbacks) {
      [callback skipDelay];
      if (lastTimerID != FSTTimerIDAll && callback.timerID == lastTimerID) {
        break;
      }
    }

    // Now that the callbacks are queued, we want to enqueue an additional item to release the
    // 'done' semaphore.
    [self dispatchAsyncAllowingSameQueue:^{
      dispatch_semaphore_signal(doneSemaphore);
    }];
  }];

  dispatch_semaphore_wait(doneSemaphore, DISPATCH_TIME_FOREVER);
}

// NOTE: For performance we could store the callbacks sorted (e.g. using std::priority_queue),
// but this sort only happens in tests (if runDelayedCallbacksUntil: is called), and the size
// is guaranteed to be small since we don't allow duplicate TimerIds (of which there are only 4).
- (void)sortDelayedCallbacks {
  // We want to run callbacks in the same order they'd run if they ran naturally.
  [self.delayedCallbacks
      sortUsingComparator:^NSComparisonResult(FSTDelayedCallback *a, FSTDelayedCallback *b) {
        return a.targetTime < b.targetTime
                   ? NSOrderedAscending
                   : a.targetTime > b.targetTime ? NSOrderedDescending : NSOrderedSame;
      }];
}

/** Called by FSTDelayedCallback when a callback is run or canceled. */
- (void)removeDelayedCallback:(FSTDelayedCallback *)callback {
  NSUInteger index = [self.delayedCallbacks indexOfObject:callback];
  FSTAssert(index != NSNotFound, @"Delayed callback not found.");
  [self.delayedCallbacks removeObjectAtIndex:index];
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
