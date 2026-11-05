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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Coordinates pre-initialization callback buffering and post-initialization
 * caller-thread execution for Crashlytics APIs.
 *
 * Encapsulates the pending callback buffer, lock, and readiness flag so
 * callers cannot access or mutate buffered callbacks outside the lock.
 */
@interface FIRCLSContextInitGate : NSObject

/**
 * Performs `block` synchronously on the calling thread once the gate is ready;
 * otherwise buffers `block` in FIFO order until `-markReadyAndFlush` drains it.
 */
- (void)performWhenReady:(dispatch_block_t)block;

/**
 * Drains all buffered blocks in FIFO order and transitions the gate permanently
 * to ready so all subsequent `-performWhenReady:` calls run inline on the
 * caller's thread. Any `NSException` thrown by a buffered block is caught and
 * logged so remaining blocks still drain and the gate transitions to ready.
 */
- (void)markReadyAndFlush;

/**
 * Discards all buffered blocks without invoking them and permanently closes the
 * gate so any subsequent `-performWhenReady:` calls are also ignored.
 */
- (void)markFailedAndDiscardPending;

@end

NS_ASSUME_NONNULL_END
