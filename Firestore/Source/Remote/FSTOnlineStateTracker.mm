/*
 * Copyright 2018 Google
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

#import "Firestore/Source/Remote/FSTOnlineStateTracker.h"
#import "Firestore/Source/Remote/FSTRemoteStore.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"
#import "Firestore/Source/Util/FSTLogger.h"

NS_ASSUME_NONNULL_BEGIN

// To deal with transient failures, we allow multiple stream attempts before giving up and
// transitioning from FSTOnlineState Unknown to Offline.
static const int kMaxWatchStreamFailures = 2;

// To deal with stream attempts that don't succeed or fail in a timely manner, we have a
// timeout for FSTOnlineState to reach Online or Offline. If the timeout is reached, we transition
// to Offline rather than waiting indefinitely.
static const NSTimeInterval kOnlineStateTimeout = 10;

@interface FSTOnlineStateTracker ()

/** The current FSTOnlineState. */
@property(nonatomic, assign) FSTOnlineState state;

/**
 * A count of consecutive failures to open the stream. If it reaches the maximum defined by
 * kMaxWatchStreamFailures, we'll revert to FSTOnlineStateOffline.
 */
@property(nonatomic, assign) int watchStreamFailures;

/**
 * A timer that elapses after kOnlineStateTimeout, at which point we transition from FSTOnlineState
 * Unknown to Offline without waiting for the stream to actually fail (kMaxWatchStreamFailures
 * times).
 */
@property(nonatomic, strong, nullable) FSTDelayedCallback *onlineStateTimer;

/**
 * Whether the client should log a warning message if it fails to connect to the backend
 * (initially YES, cleared after a successful stream, or if we've logged the message already).
 */
@property(nonatomic, assign) BOOL shouldWarnClientIsOffline;

/** The FSTDispatchQueue to use for running timers (and to call onlineStateDelegate). */
@property(nonatomic, strong, readonly) FSTDispatchQueue *queue;

@end

@implementation FSTOnlineStateTracker
- (instancetype)initWithWorkerDispatchQueue:(FSTDispatchQueue *)queue {
  if (self = [super init]) {
    _queue = queue;
    _state = FSTOnlineStateUnknown;
    _shouldWarnClientIsOffline = YES;
  }
  return self;
}

- (void)handleWatchStreamStart {
  if (self.watchStreamFailures == 0) {
    [self setAndBroadcastState:FSTOnlineStateUnknown];

    FSTAssert(!self.onlineStateTimer, @"onlineStateTimer shouldn't be started yet");
    self.onlineStateTimer = [self.queue
        dispatchAfterDelay:kOnlineStateTimeout
                   timerID:FSTTimerIDOnlineStateTimeout
                     block:^{
                       self.onlineStateTimer = nil;
                       FSTAssert(
                           self.state == FSTOnlineStateUnknown,
                           @"Timer should be canceled if we transitioned to a different state.");
                       FSTLog(
                           @"Watch stream didn't reach Online or Offline within %f seconds. "
                           @"Considering "
                            "client offline.",
                           kOnlineStateTimeout);
                       [self logClientOfflineWarningIfNecessary];
                       [self setAndBroadcastState:FSTOnlineStateOffline];

                       // NOTE: handleWatchStreamFailure will continue to increment
                       // watchStreamFailures even though we are already marked Offline but this is
                       // non-harmful.
                     }];
  }
}

- (void)handleWatchStreamFailure {
  if (self.state == FSTOnlineStateOnline) {
    [self setAndBroadcastState:FSTOnlineStateUnknown];

    // To get to FSTOnlineStateOnline, updateState: must have been called which would have reset
    // our heuristics.
    FSTAssert(self.watchStreamFailures == 0, @"watchStreamFailures must be 0");
    FSTAssert(!self.onlineStateTimer, @"onlineStateTimer must be nil");
  } else {
    self.watchStreamFailures++;
    if (self.watchStreamFailures >= kMaxWatchStreamFailures) {
      [self clearOnlineStateTimer];
      [self logClientOfflineWarningIfNecessary];
      [self setAndBroadcastState:FSTOnlineStateOffline];
    }
  }
}

- (void)updateState:(FSTOnlineState)newState {
  [self clearOnlineStateTimer];
  self.watchStreamFailures = 0;

  if (newState == FSTOnlineStateOnline) {
    // We've connected to watch at least once. Don't warn the developer about being offline going
    // forward.
    self.shouldWarnClientIsOffline = NO;
  }

  [self setAndBroadcastState:newState];
}

- (void)setAndBroadcastState:(FSTOnlineState)newState {
  if (newState != self.state) {
    self.state = newState;
    [self.onlineStateDelegate applyChangedOnlineState:newState];
  }
}

- (void)logClientOfflineWarningIfNecessary {
  if (self.shouldWarnClientIsOffline) {
    FSTWarn(@"Could not reach Firestore backend.");
    self.shouldWarnClientIsOffline = NO;
  }
}

- (void)clearOnlineStateTimer {
  if (self.onlineStateTimer) {
    [self.onlineStateTimer cancel];
    self.onlineStateTimer = nil;
  }
}

@end

NS_ASSUME_NONNULL_END
