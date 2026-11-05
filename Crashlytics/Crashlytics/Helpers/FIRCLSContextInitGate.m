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

@implementation FIRCLSContextInitGate {
  BOOL _isReady;
  BOOL _isFlushing;
  NSMutableArray<dispatch_block_t> *_pendingBlocks;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _pendingBlocks = [NSMutableArray array];
  }
  return self;
}

- (void)performWhenReady:(dispatch_block_t)block {
  if (!block) {
    return;
  }

  BOOL shouldRunInline = NO;
  @synchronized(self) {
    if (_isReady) {
      // If context has initialized and the pending blocks queue has been
      // flushed, performs the api call on the calling thread.
      shouldRunInline = YES;
    } else {
      [_pendingBlocks addObject:[block copy]];
    }
  }

  if (shouldRunInline) {
    block();
  }
}

- (void)markReadyAndFlush {
  BOOL startedFlushing = NO;

  while (YES) {
    NSArray<dispatch_block_t> *batch = nil;
    @synchronized(self) {
      if (!startedFlushing) {
        if (_isFlushing || _isReady) {
          return;
        }
        _isFlushing = YES;
        startedFlushing = YES;
      }

      if (_pendingBlocks.count == 0) {
        _pendingBlocks = nil;
        _isFlushing = NO;
        _isReady = YES;
        return;
      }
      batch = [_pendingBlocks copy];
      [_pendingBlocks removeAllObjects];
    }

    // Runs the batch outside of the synchronized block so that API calls that
    // arrive while the queue is being flushed are added to the queue instead of
    // the thread being blocked on the entire queue flushing.
    for (dispatch_block_t block in batch) {
      block();
    }
  }
}

@end
