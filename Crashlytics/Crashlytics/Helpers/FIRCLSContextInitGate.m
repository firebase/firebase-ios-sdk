// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "Crashlytics/Crashlytics/Helpers/FIRCLSContextInitGate.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"

const NSUInteger FIRCLSContextInitGateMaxPendingBlocks = 128;
const NSUInteger FIRCLSContextInitGateMaxNonBlockingFlushes = 3;

typedef NS_ENUM(NSInteger, FIRCLSContextInitGateState) {
  FIRCLSContextInitGateStatePending,
  FIRCLSContextInitGateStateFlushing,
  FIRCLSContextInitGateStateReady,
  FIRCLSContextInitGateStateFailed,
};

@implementation FIRCLSContextInitGate {
  FIRCLSContextInitGateState _state;
  NSMutableArray<dispatch_block_t> *_pendingBlocks;
  // TODO(#16837): Remove `_didLogMaxPendingBlocksError` once a fix for #16837 is implemented.
  BOOL _didLogMaxPendingBlocksError;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _state = FIRCLSContextInitGateStatePending;
    _pendingBlocks = [NSMutableArray array];
    _didLogMaxPendingBlocksError = NO;
  }
  return self;
}

- (void)performWhenReady:(nullable NSString *)contextLog block:(dispatch_block_t)block {
  if (!block) {
    return;
  }

  @synchronized(self) {
    switch (_state) {
      case FIRCLSContextInitGateStatePending:
      case FIRCLSContextInitGateStateFlushing:
        [self addPendingBlock:block contextLog:contextLog];
        return;
      case FIRCLSContextInitGateStateFailed:
        return;
      case FIRCLSContextInitGateStateReady:
        break;
    }
  }

  block();
}

- (void)markReadyAndFlush {
  @synchronized(self) {
    if (_state != FIRCLSContextInitGateStatePending) {
      return;
    }
    _state = FIRCLSContextInitGateStateFlushing;
  }

  for (NSUInteger pass = 0; pass < FIRCLSContextInitGateMaxNonBlockingFlushes; pass++) {
    NSArray<dispatch_block_t> *batch = nil;
    @synchronized(self) {
      if (_state != FIRCLSContextInitGateStateFlushing) {
        return;
      }

      if (_pendingBlocks.count == 0) {
        _pendingBlocks = nil;
        _state = FIRCLSContextInitGateStateReady;
        return;
      }

      batch = [_pendingBlocks copy];
      [_pendingBlocks removeAllObjects];
    }

    // Runs the batch outside of the synchronized block so that API calls that
    // arrive while the queue is being flushed are added to the queue instead of
    // the thread being blocked on the entire queue flushing.
    [self flushBatch:batch];
  }

  // If the queue has not drained after max non-blocking flushes, block the
  // caller to drain the queue.
  NSArray<dispatch_block_t> *finalBatch = nil;
  @synchronized(self) {
    if (_state != FIRCLSContextInitGateStateFlushing) {
      return;
    }
    finalBatch = [_pendingBlocks copy];
    _pendingBlocks = nil;
    _state = FIRCLSContextInitGateStateReady;
    [self flushBatch:finalBatch];
  }
  // Release `finalBatch` outside `@synchronized(self)` so any captured object
  // `-dealloc` hooks run without holding the lock.
  (void)finalBatch;
}

- (void)markFailedAndDiscardPending {
  NSMutableArray<dispatch_block_t> *discardedBlocks = nil;
  @synchronized(self) {
    if (_state == FIRCLSContextInitGateStateReady || _state == FIRCLSContextInitGateStateFailed) {
      return;
    }
    discardedBlocks = _pendingBlocks;
    _pendingBlocks = nil;
    _state = FIRCLSContextInitGateStateFailed;
  }
  // Release discarded blocks outside `@synchronized(self)` so any captured
  // object `-dealloc` hooks run without holding the lock.
  (void)discardedBlocks;
}

#pragma mark - Private Helpers

/// Must be called from inside `@synchronized(self)`.
- (void)addPendingBlock:(dispatch_block_t)block contextLog:(nullable NSString *)contextLog {
  if (!_pendingBlocks) {
    return;
  }
  if (_pendingBlocks.count >= FIRCLSContextInitGateMaxPendingBlocks) {
    // TODO(#16837): Remove `_didLogMaxPendingBlocksError` once a fix for #16837 is implemented.
    if (!_didLogMaxPendingBlocksError) {
      _didLogMaxPendingBlocksError = YES;
      FIRCLSErrorLog(@"Maximum pending pre-init API calls (%lu) reached; dropping call: %@",
                     (unsigned long)FIRCLSContextInitGateMaxPendingBlocks, contextLog);
    }
    return;
  }
  [_pendingBlocks addObject:[block copy]];
}

- (void)flushBatch:(NSArray<dispatch_block_t> *)batch {
  for (dispatch_block_t block in batch) {
    @try {
      block();
    } @catch (NSException *exception) {
      FIRCLSErrorLog(@"Exception while flushing pre-init API call: %@", exception);
    }
  }
}

@end
