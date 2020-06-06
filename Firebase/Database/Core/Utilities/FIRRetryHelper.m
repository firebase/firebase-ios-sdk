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

#import "FIRRetryHelper.h"
#import "FUtilities.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

@interface FIRRetryHelperTask : NSObject

@property(nonatomic, strong) void (^block)(void);

@end

@implementation FIRRetryHelperTask

- (instancetype)initWithBlock:(void (^)(void))block {
    self = [super init];
    if (self != nil) {
        self->_block = [block copy];
    }
    return self;
}

- (BOOL)isCanceled {
    return self.block == nil;
}

- (void)cancel {
    self.block = nil;
}

- (void)execute {
    if (self.block) {
        self.block();
    }
}

@end

@interface FIRRetryHelper ()

@property(nonatomic, strong) dispatch_queue_t dispatchQueue;
@property(nonatomic) NSTimeInterval minRetryDelayAfterFailure;
@property(nonatomic) NSTimeInterval maxRetryDelay;
@property(nonatomic) double retryExponent;
@property(nonatomic) double jitterFactor;

@property(nonatomic) BOOL lastWasSuccess;
@property(nonatomic) NSTimeInterval currentRetryDelay;

@property(nonatomic, strong) FIRRetryHelperTask *scheduledRetry;

@end

@implementation FIRRetryHelper

- (instancetype)initWithDispatchQueue:(dispatch_queue_t)dispatchQueue
            minRetryDelayAfterFailure:(NSTimeInterval)minRetryDelayAfterFailure
                        maxRetryDelay:(NSTimeInterval)maxRetryDelay
                        retryExponent:(double)retryExponent
                         jitterFactor:(double)jitterFactor {
    self = [super init];
    if (self != nil) {
        self->_dispatchQueue = dispatchQueue;
        self->_minRetryDelayAfterFailure = minRetryDelayAfterFailure;
        self->_maxRetryDelay = maxRetryDelay;
        self->_retryExponent = retryExponent;
        self->_jitterFactor = jitterFactor;
        self->_lastWasSuccess = YES;
    }
    return self;
}

- (void)retry:(void (^)(void))block {
    if (self.scheduledRetry != nil) {
        FFLog(@"I-RDB054001", @"Canceling existing retry attempt");
        [self.scheduledRetry cancel];
        self.scheduledRetry = nil;
    }

    NSTimeInterval delay;
    if (self.lastWasSuccess) {
        delay = 0;
    } else {
        if (self.currentRetryDelay == 0) {
            self.currentRetryDelay = self.minRetryDelayAfterFailure;
        } else {
            NSTimeInterval newDelay =
                (self.currentRetryDelay * self.retryExponent);
            self.currentRetryDelay = MIN(newDelay, self.maxRetryDelay);
        }

        delay = ((1 - self.jitterFactor) * self.currentRetryDelay) +
                (self.jitterFactor * self.currentRetryDelay *
                 [FUtilities randomDouble]);
        FFLog(@"I-RDB054002", @"Scheduling retry in %fs", delay);
    }
    self.lastWasSuccess = NO;
    FIRRetryHelperTask *task = [[FIRRetryHelperTask alloc] initWithBlock:block];
    self.scheduledRetry = task;
    dispatch_time_t popTime =
        dispatch_time(DISPATCH_TIME_NOW, (long long)(delay * NSEC_PER_SEC));
    dispatch_after(popTime, self.dispatchQueue, ^{
      if (![task isCanceled]) {
          self.scheduledRetry = nil;
          [task execute];
      }
    });
}

- (void)signalSuccess {
    self.lastWasSuccess = YES;
    self.currentRetryDelay = 0;
}

- (void)cancel {
    if (self.scheduledRetry != nil) {
        FFLog(@"I-RDB054003", @"Canceling existing retry attempt");
        [self.scheduledRetry cancel];
        self.scheduledRetry = nil;
    } else {
        FFLog(@"I-RDB054004", @"No existing retry attempt to cancel");
    }
    self.currentRetryDelay = 0;
}

@end
