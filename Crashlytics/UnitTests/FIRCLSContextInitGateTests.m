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

#import <XCTest/XCTest.h>

#include <os/lock.h>
#include <stdatomic.h>
#include <string.h>

#import "Crashlytics/Crashlytics/Helpers/FIRCLSContextInitGate.h"

/// Helper function (marked `noinline`) that creates a stack-allocated block capturing stack-local
/// state and returns immediately so its stack frame is popped before `gate` flushes.
__attribute__((noinline)) static void FIRCLSEnqueueStackScopedBlock(
    FIRCLSContextInitGate *gate, int baseValue, NSMutableArray<NSNumber *> *results) {
  int stackLocalMultiplier = 10;
  char stackBuffer[64];
  snprintf(stackBuffer, sizeof(stackBuffer), "val-%d", baseValue * stackLocalMultiplier);
  NSString *stackScopedString = [NSString stringWithUTF8String:stackBuffer];
  [gate performWhenReady:@"test"
                   block:^{
                     NSInteger parsed = [[stackScopedString substringFromIndex:4] integerValue];
                     [results addObject:@(parsed + stackLocalMultiplier)];
                   }];
}

/// Overwrites stack memory after `FIRCLSEnqueueStackScopedBlock` returns so any uncopied stack
/// block reference would observe corrupted state or crash.
__attribute__((noinline)) static int FIRCLSClobberStackMemory(int seed) {
  volatile int scratch[64];
  for (int i = 0; i < 64; i++) {
    scratch[i] = seed ^ (i * 0x5A5A);
  }
  return scratch[63];
}

/// Helper object that re-enters `FIRCLSContextInitGate` from inside `-dealloc` when the last
/// reference held by a buffered block is released at the end of a flush batch.
@interface FIRCLSDeallocReentrancyProbe : NSObject

- (instancetype)initWithGate:(FIRCLSContextInitGate *)gate
              onDeallocBlock:(dispatch_block_t)onDeallocBlock;

@end

@implementation FIRCLSDeallocReentrancyProbe {
  FIRCLSContextInitGate *_gate;
  dispatch_block_t _onDeallocBlock;
}

- (instancetype)initWithGate:(FIRCLSContextInitGate *)gate
              onDeallocBlock:(dispatch_block_t)onDeallocBlock {
  self = [super init];
  if (self) {
    _gate = gate;
    _onDeallocBlock = [onDeallocBlock copy];
  }
  return self;
}

- (void)dealloc {
  [_gate markReadyAndFlush];
  if (_onDeallocBlock) {
    [_gate performWhenReady:@"dealloc" block:_onDeallocBlock];
  }
}

@end

@interface FIRCLSContextInitGateTests : XCTestCase
@end

@implementation FIRCLSContextInitGateTests

- (void)testEmptyGateMarkReadyAndFlushTransitionsToInlineExecution {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];

  // Flushing an empty gate should be a safe no-op that marks it ready.
  [gate markReadyAndFlush];

  __block BOOL ranInline = NO;
  [gate performWhenReady:@"test"
                   block:^{
                     ranInline = YES;
                   }];
  XCTAssertTrue(ranInline);
}

- (void)testPreReadyBlocksAreBufferedDeferredAndFlushedInStrictFIFOOrder {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSNumber *> *order = [NSMutableArray array];

  const int blockCount = 100;
  for (int i = 0; i < blockCount; i++) {
    [gate performWhenReady:@"test"
                     block:^{
                       [order addObject:@(i)];
                     }];
  }

  // Nothing may run before `-markReadyAndFlush`.
  XCTAssertEqual(order.count, 0);

  [gate markReadyAndFlush];

  XCTAssertEqual(order.count, (NSUInteger)blockCount);
  for (int i = 0; i < blockCount; i++) {
    XCTAssertEqualObjects(order[i], @(i));
  }
}

- (void)testThreadAffinityDuringFlushAndPostReady {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];

  os_unfair_lock threadsLock = OS_UNFAIR_LOCK_INIT;
  os_unfair_lock *threadsLockPtr = &threadsLock;
  NSMutableArray<NSThread *> *recordedThreads = [NSMutableArray array];

  // Enqueue from the main thread and from a background global queue.
  XCTAssertTrue([NSThread isMainThread]);
  [gate performWhenReady:@"test"
                   block:^{
                     os_unfair_lock_lock(threadsLockPtr);
                     [recordedThreads addObject:[NSThread currentThread]];
                     os_unfair_lock_unlock(threadsLockPtr);
                   }];

  dispatch_semaphore_t enqueueSem = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    XCTAssertFalse([NSThread isMainThread]);
    [gate performWhenReady:@"test"
                     block:^{
                       os_unfair_lock_lock(threadsLockPtr);
                       [recordedThreads addObject:[NSThread currentThread]];
                       os_unfair_lock_unlock(threadsLockPtr);
                     }];
    dispatch_semaphore_signal(enqueueSem);
  });
  XCTAssertEqual(
      dispatch_semaphore_wait(enqueueSem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0);

  // Flush asynchronously on a dedicated serial background queue while blocking the main thread on
  // a semaphore (avoiding `dispatch_sync`'s caller-thread handoff optimization so `flushQueue`
  // runs on a real background worker thread and proving no main-queue hop occurs).
  dispatch_queue_t flushQueue =
      dispatch_queue_create("com.google.firebase.crashlytics.test.flush", DISPATCH_QUEUE_SERIAL);
  dispatch_semaphore_t flushSem = dispatch_semaphore_create(0);
  __block NSThread *flushThread = nil;
  __block BOOL flushedOnMainThread = YES;
  dispatch_async(flushQueue, ^{
    flushThread = [NSThread currentThread];
    flushedOnMainThread = [NSThread isMainThread];
    [gate markReadyAndFlush];
    dispatch_semaphore_signal(flushSem);
  });
  XCTAssertEqual(
      dispatch_semaphore_wait(flushSem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0);
  XCTAssertFalse(flushedOnMainThread);
  XCTAssertNotNil(flushThread);

  XCTAssertEqual(recordedThreads.count, 2);
  XCTAssertEqual(recordedThreads[0], flushThread);
  XCTAssertEqual(recordedThreads[1], flushThread);

  // Post-ready: main-thread caller runs synchronously inline on main thread before returning.
  __block NSThread *postReadyMainThread = nil;
  [gate performWhenReady:@"test"
                   block:^{
                     postReadyMainThread = [NSThread currentThread];
                   }];
  XCTAssertEqual(postReadyMainThread, [NSThread mainThread]);

  // Post-ready: background-thread caller runs synchronously inline on its own background thread.
  __block NSThread *expectedBgCaller = nil;
  __block NSThread *actualBgExecution = nil;
  dispatch_semaphore_t postReadyBgSem = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    expectedBgCaller = [NSThread currentThread];
    XCTAssertFalse([NSThread isMainThread]);
    [gate performWhenReady:@"test"
                     block:^{
                       actualBgExecution = [NSThread currentThread];
                     }];
    dispatch_semaphore_signal(postReadyBgSem);
  });
  XCTAssertEqual(
      dispatch_semaphore_wait(postReadyBgSem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)),
      0);
  XCTAssertNotNil(expectedBgCaller);
  XCTAssertEqual(actualBgExecution, expectedBgCaller);
}

- (void)testStackAllocatedBlocksCapturingLocalsSurviveCallerReturn {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSNumber *> *results = [NSMutableArray array];

  for (int i = 1; i <= 5; i++) {
    FIRCLSEnqueueStackScopedBlock(gate, i, results);
  }
  (void)FIRCLSClobberStackMemory(0x1234);

  dispatch_queue_t bgQueue =
      dispatch_queue_create("com.google.firebase.crashlytics.test.stack", DISPATCH_QUEUE_SERIAL);
  dispatch_semaphore_t flushSem = dispatch_semaphore_create(0);
  dispatch_async(bgQueue, ^{
    [gate markReadyAndFlush];
    dispatch_semaphore_signal(flushSem);
  });
  XCTAssertEqual(
      dispatch_semaphore_wait(flushSem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0);

  NSArray<NSNumber *> *expected = @[ @20, @30, @40, @50, @60 ];
  XCTAssertEqualObjects(results, expected);
}

- (void)testBufferedBlocksReleaseCapturedObjectsAfterFlushAndOnDealloc {
  // Subcase A: Captured objects are retained while buffered and released as soon as flush finishes.
  __weak NSObject *weakCapturedOnFlush = nil;
  FIRCLSContextInitGate *flushedGate = [[FIRCLSContextInitGate alloc] init];
  @autoreleasepool {
    NSObject *captured = [[NSObject alloc] init];
    weakCapturedOnFlush = captured;
    [flushedGate performWhenReady:@"test"
                            block:^{
                              XCTAssertNotNil(captured);
                            }];
  }
  XCTAssertNotNil(weakCapturedOnFlush, @"Gate must retain buffered block captures prior to flush");

  @autoreleasepool {
    [flushedGate markReadyAndFlush];
  }
  XCTAssertNil(weakCapturedOnFlush,
               @"Flushed gate must nil out _pendingBlocks and release captured objects");

  // Subcase B: Unflushed gate releases buffered blocks on dealloc without executing them.
  __weak NSObject *weakCapturedOnDealloc = nil;
  __block BOOL unflushedBlockRan = NO;
  @autoreleasepool {
    FIRCLSContextInitGate *unflushedGate = [[FIRCLSContextInitGate alloc] init];
    NSObject *captured = [[NSObject alloc] init];
    weakCapturedOnDealloc = captured;
    [unflushedGate performWhenReady:@"test"
                              block:^{
                                unflushedBlockRan = YES;
                                (void)captured;
                              }];
    XCTAssertNotNil(weakCapturedOnDealloc);
  }
  XCTAssertFalse(unflushedBlockRan);
  XCTAssertNil(weakCapturedOnDealloc, @"Deallocating unflushed gate must release pending blocks");
}

- (void)testCapturedObjectDeallocReenteringGateDuringFlushDoesNotDeadlockAndDrainsBlock {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSNumber *> *order = [NSMutableArray array];

  @autoreleasepool {
    FIRCLSDeallocReentrancyProbe *probe =
        [[FIRCLSDeallocReentrancyProbe alloc] initWithGate:gate
                                            onDeallocBlock:^{
                                              [order addObject:@3];
                                            }];

    [gate performWhenReady:@"test"
                     block:^{
                       (void)probe;
                       [order addObject:@1];
                     }];
    [gate performWhenReady:@"test"
                     block:^{
                       [order addObject:@2];
                     }];
  }

  // When Batch 1 (`@1`, `@2`) finishes, `batch` releases Block 1 outside `@synchronized(self)`,
  // triggering `-[FIRCLSDeallocReentrancyProbe dealloc]`, which calls `[gate markReadyAndFlush]`
  // and enqueues `@3` via `-performWhenReady:`. The gate must not deadlock and must drain `@3` in
  // Batch 2 before returning.
  [gate markReadyAndFlush];

  NSArray<NSNumber *> *expected = @[ @1, @2, @3 ];
  XCTAssertEqualObjects(order, expected);
}

- (void)testMultiLevelReentrantPerformWhenReadyDrainsAllGenerationsAndRunsInlinePostReady {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSNumber *> *order = [NSMutableArray array];

  [gate performWhenReady:@"test"
                   block:^{
                     [order addObject:@1];
                     // Enqueued during Batch 1 -> must run in Batch 2 AFTER sibling `@2` finishes.
                     [gate performWhenReady:@"test"
                                      block:^{
                                        [order addObject:@3];
                                        // Enqueued during Batch 2 -> must run in Batch 3 AFTER
                                        // sibling `@4` finishes.
                                        [gate performWhenReady:@"test"
                                                         block:^{
                                                           [order addObject:@5];
                                                         }];
                                      }];
                     [gate performWhenReady:@"test"
                                      block:^{
                                        [order addObject:@4];
                                      }];
                   }];
  [gate performWhenReady:@"test"
                   block:^{
                     [order addObject:@2];
                   }];

  [gate markReadyAndFlush];

  // Post-ready nested `-performWhenReady:` runs synchronously inline inside the outer block.
  [gate performWhenReady:@"test"
                   block:^{
                     [order addObject:@6];
                     [gate performWhenReady:@"test"
                                      block:^{
                                        [order addObject:@7];
                                      }];
                     [order addObject:@8];
                   }];

  NSArray<NSNumber *> *expected = @[ @1, @2, @3, @4, @5, @6, @7, @8 ];
  XCTAssertEqualObjects(order, expected);
}

- (void)testRepeatedConcurrentAndReentrantMarkReadyAndFlushIsIdempotentAndPreservesFIFO {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSNumber *> *order = [NSMutableArray array];

  [gate performWhenReady:@"test"
                   block:^{
                     [order addObject:@1];
                     // Re-entrant `-markReadyAndFlush` while Batch 1 is mid-flight must NOT
                     // prematurely flip
                     // `_isReady` to YES or drop subsequently enqueued items.
                     [gate markReadyAndFlush];
                     [gate performWhenReady:@"test"
                                      block:^{
                                        [order addObject:@3];
                                      }];
                   }];
  [gate performWhenReady:@"test"
                   block:^{
                     [order addObject:@2];
                   }];

  // Race two concurrent threads calling `-markReadyAndFlush` simultaneously.
  dispatch_group_t group = dispatch_group_create();
  dispatch_queue_t concurrentQueue = dispatch_queue_create(
      "com.google.firebase.crashlytics.test.raceflush", DISPATCH_QUEUE_CONCURRENT);
  dispatch_group_async(group, concurrentQueue, ^{
    [gate markReadyAndFlush];
  });
  dispatch_group_async(group, concurrentQueue, ^{
    [gate markReadyAndFlush];
  });
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

  // Subsequent redundant `-markReadyAndFlush` calls after ready must also be safe no-ops.
  [gate markReadyAndFlush];

  NSArray<NSNumber *> *expected = @[ @1, @2, @3 ];
  XCTAssertEqualObjects(order, expected);
}

- (void)testSequentialProducerRacingMarkReadyAndFlushPreservesTotalCausalOrder {
  // Repeat across 50 trials to exercise every interleaving of pre-ready buffering, batch draining,
  // lock contention, and the final `_isReady = YES` flip within the pending capacity limit.
  const int trials = 50;
  const int itemsPerTrial = (int)FIRCLSContextInitGateMaxPendingBlocks;

  dispatch_queue_t flushQueue =
      dispatch_queue_create("com.google.firebase.crashlytics.test.handoff", DISPATCH_QUEUE_SERIAL);

  for (int trial = 0; trial < trials; trial++) {
    FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
    os_unfair_lock orderLock = OS_UNFAIR_LOCK_INIT;
    os_unfair_lock *orderLockPtr = &orderLock;
    NSMutableArray<NSNumber *> *observedOrder =
        [NSMutableArray arrayWithCapacity:(NSUInteger)itemsPerTrial];

    // Pre-seed the first 25 items before kicking off the background flush, then produce the
    // remaining items concurrently with `-markReadyAndFlush`.
    for (int i = 0; i < 25; i++) {
      [gate performWhenReady:@"test"
                       block:^{
                         os_unfair_lock_lock(orderLockPtr);
                         [observedOrder addObject:@(i)];
                         os_unfair_lock_unlock(orderLockPtr);
                       }];
    }

    dispatch_async(flushQueue, ^{
      [gate markReadyAndFlush];
    });

    for (int i = 25; i < itemsPerTrial; i++) {
      [gate performWhenReady:@"test"
                       block:^{
                         os_unfair_lock_lock(orderLockPtr);
                         [observedOrder addObject:@(i)];
                         os_unfair_lock_unlock(orderLockPtr);
                       }];
    }

    // Wait for `flushQueue` to finish in case all items were buffered before flush completed.
    dispatch_sync(flushQueue, ^{
                  });

    XCTAssertEqual(observedOrder.count, (NSUInteger)itemsPerTrial, @"Trial %d lost or duplicated",
                   trial);
    for (int i = 0; i < itemsPerTrial; i++) {
      XCTAssertEqualObjects(observedOrder[i], @(i),
                            @"Trial %d violated single-producer FIFO order at index %d", trial, i);
    }
  }
}

- (void)testHighContentionManyProducersRacingMarkReadyAndFlushExecutesEveryBlockExactlyOnce {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];

  const int producerThreads = 8;
  const int blocksPerThread = (int)(FIRCLSContextInitGateMaxPendingBlocks / producerThreads);
  const int totalBlocks = producerThreads * blocksPerThread;
  XCTAssertEqual((NSUInteger)totalBlocks, FIRCLSContextInitGateMaxPendingBlocks);

  atomic_int *executionCounts = calloc((size_t)totalBlocks, sizeof(atomic_int));
  XCTAssertTrue(executionCounts != NULL);

  dispatch_group_t group = dispatch_group_create();
  dispatch_queue_t concurrentQueue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);

  for (int t = 0; t < producerThreads; t++) {
    dispatch_group_async(group, concurrentQueue, ^{
      for (int i = 0; i < blocksPerThread; i++) {
        int slot = t * blocksPerThread + i;
        [gate
            performWhenReady:@"test"
                       block:^{
                         atomic_fetch_add_explicit(&executionCounts[slot], 1, memory_order_relaxed);
                       }];
      }
    });
  }

  // Trigger `-markReadyAndFlush` amidst active multi-producer traffic.
  dispatch_group_async(group, concurrentQueue, ^{
    [gate markReadyAndFlush];
  });

  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

  for (int slot = 0; slot < totalBlocks; slot++) {
    int count = atomic_load_explicit(&executionCounts[slot], memory_order_relaxed);
    XCTAssertEqual(count, 1, @"Block %d executed %d times instead of once", slot, count);
  }

  free(executionCounts);
}

- (void)testMemoryVisibilityAndTransitionBoundaryAcrossReadyFlip {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  dispatch_semaphore_t flushEnteredBlock = dispatch_semaphore_create(0);
  dispatch_semaphore_t allowFlushToFinish = dispatch_semaphore_create(0);

  // Plain non-atomic variables mutated prior to / during flush; post-ready readers rely on
  // `@synchronized(self)` synchronization when `_isReady` transitions to `YES`.
  __block int nonAtomicInitializedState = 0;
  __block int nonAtomicPreInitAccumulated = 0;

  [gate performWhenReady:@"test"
                   block:^{
                     nonAtomicPreInitAccumulated += 10;
                     dispatch_semaphore_signal(flushEnteredBlock);
                     dispatch_semaphore_wait(allowFlushToFinish, DISPATCH_TIME_FOREVER);
                     nonAtomicPreInitAccumulated += 32;
                   }];

  dispatch_queue_t flushQueue =
      dispatch_queue_create("com.google.firebase.crashlytics.test.slowpath", DISPATCH_QUEUE_SERIAL);
  dispatch_async(flushQueue, ^{
    nonAtomicInitializedState = 1;
    [gate markReadyAndFlush];
  });

  // Wait until `-markReadyAndFlush` is paused mid-block (`_isReady == NO`).
  XCTAssertEqual(dispatch_semaphore_wait(flushEnteredBlock,
                                         dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)),
                 0);

  // Release the flush and hammer `-performWhenReady:` across the exact `_isReady = NO -> YES`
  // boundary within the pending capacity limit, verifying every block sees initialized state and
  // runs once.
  __block atomic_int executedCount = 0;
  const int burstCount = (int)FIRCLSContextInitGateMaxPendingBlocks;
  dispatch_semaphore_signal(allowFlushToFinish);
  for (int i = 0; i < burstCount; i++) {
    [gate performWhenReady:@"test"
                     block:^{
                       XCTAssertEqual(nonAtomicInitializedState, 1);
                       atomic_fetch_add_explicit(&executedCount, 1, memory_order_relaxed);
                     }];
  }

  dispatch_sync(flushQueue, ^{
                });
  XCTAssertEqual(atomic_load_explicit(&executedCount, memory_order_relaxed), burstCount);

  // Verify a fresh background thread calling `-performWhenReady:` post-ready sees all non-atomic
  // writes completed during `-markReadyAndFlush`.
  dispatch_semaphore_t readerSem = dispatch_semaphore_create(0);
  __block int observedInitState = 0;
  __block int observedPreInitSum = 0;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    [gate performWhenReady:@"test"
                     block:^{
                       observedInitState = nonAtomicInitializedState;
                       observedPreInitSum = nonAtomicPreInitAccumulated;
                     }];
    dispatch_semaphore_signal(readerSem);
  });
  XCTAssertEqual(
      dispatch_semaphore_wait(readerSem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0);
  XCTAssertEqual(observedInitState, 1);
  XCTAssertEqual(observedPreInitSum, 42);
}

- (void)testNilBlockPreReadyDuringFlushAndPostReadyIsSafeNoOp {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSNumber *> *executed = [NSMutableArray array];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertNoThrow([gate performWhenReady:@"nil-block" block:nil]);

  [gate performWhenReady:nil
                   block:^{
                     [executed addObject:@1];
                     XCTAssertNoThrow([gate performWhenReady:nil block:nil]);
                   }];

  XCTAssertNoThrow([gate markReadyAndFlush]);
  XCTAssertNoThrow([gate performWhenReady:@"nil-block" block:nil]);
#pragma clang diagnostic pop

  [gate performWhenReady:@"test"
                   block:^{
                     [executed addObject:@2];
                   }];

  NSArray<NSNumber *> *expected = @[ @1, @2 ];
  XCTAssertEqualObjects(executed, expected);
}

- (void)testMultipleGateInstancesHaveIndependentState {
  FIRCLSContextInitGate *gateA = [[FIRCLSContextInitGate alloc] init];
  FIRCLSContextInitGate *gateB = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSString *> *events = [NSMutableArray array];

  [gateA performWhenReady:@"test"
                    block:^{
                      [events addObject:@"A1"];
                    }];
  [gateB performWhenReady:@"test"
                    block:^{
                      [events addObject:@"B1"];
                    }];

  // Flushing `gateA` must not flush or mark `gateB` ready.
  [gateA markReadyAndFlush];
  XCTAssertEqualObjects(events, @[ @"A1" ]);

  [gateA performWhenReady:@"test"
                    block:^{
                      [events addObject:@"A2-inline"];
                    }];
  [gateB performWhenReady:@"test"
                    block:^{
                      [events addObject:@"B2-buffered"];
                    }];
  NSArray<NSString *> *expectedBeforeGateBFlush = @[ @"A1", @"A2-inline" ];
  XCTAssertEqualObjects(events, expectedBeforeGateBFlush);

  [gateB markReadyAndFlush];
  NSArray<NSString *> *expectedAfterGateBFlush = @[ @"A1", @"A2-inline", @"B1", @"B2-buffered" ];
  XCTAssertEqualObjects(events, expectedAfterGateBFlush);
}

- (void)testMarkFailedAndDiscardPendingDropsBufferedAndSubsequentBlocksAndReleasesCaptures {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSString *> *events = [NSMutableArray array];
  __weak FIRCLSDeallocReentrancyProbe *weakProbe = nil;
  __weak NSObject *weakPostFailureCapture = nil;

  @autoreleasepool {
    FIRCLSDeallocReentrancyProbe *probe =
        [[FIRCLSDeallocReentrancyProbe alloc] initWithGate:gate
                                            onDeallocBlock:^{
                                              [events addObject:@"probe-dealloc-should-not-run"];
                                            }];
    weakProbe = probe;

    [gate performWhenReady:@"test"
                     block:^{
                       (void)probe;
                       [events addObject:@"discarded-1"];
                     }];
    [gate performWhenReady:@"test"
                     block:^{
                       [events addObject:@"discarded-2"];
                     }];

    probe = nil;
    XCTAssertNotNil(weakProbe);

    [gate markFailedAndDiscardPending];
  }

  // Discarded blocks must never run, captured objects must be released outside the lock, and
  // re-entering `-performWhenReady:` from `-dealloc` must also be ignored because `_isDiscarded`.
  XCTAssertNil(weakProbe);
  XCTAssertEqual(events.count, 0);

  // Subsequent calls to `-markFailedAndDiscardPending`, `-markReadyAndFlush`, and
  // `-performWhenReady:` must all no-op without retaining new blocks.
  [gate markFailedAndDiscardPending];
  [gate markReadyAndFlush];
  @autoreleasepool {
    NSObject *postFailureCapture = [[NSObject alloc] init];
    weakPostFailureCapture = postFailureCapture;
    [gate performWhenReady:@"test"
                     block:^{
                       (void)postFailureCapture;
                       [events addObject:@"post-failure-should-not-run"];
                     }];
    postFailureCapture = nil;
  }
  XCTAssertNil(weakPostFailureCapture);
  XCTAssertEqual(events.count, 0);
}

- (void)testMarkFailedAndDiscardPendingAfterMarkReadyAndFlushIsNoOp {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSString *> *events = [NSMutableArray array];

  [gate performWhenReady:@"test"
                   block:^{
                     [events addObject:@"pre-init"];
                   }];
  [gate markReadyAndFlush];

  // Once ready, calling `-markFailedAndDiscardPending` must not close the gate.
  [gate markFailedAndDiscardPending];
  [gate performWhenReady:@"test"
                   block:^{
                     [events addObject:@"post-ready-inline"];
                   }];

  NSArray<NSString *> *expected = @[ @"pre-init", @"post-ready-inline" ];
  XCTAssertEqualObjects(events, expected);
}

- (void)testMarkFailedAndDiscardPendingDuringActiveFlushAbortsRemainingPendingBlocks {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSString *> *events = [NSMutableArray array];

  [gate performWhenReady:@"test"
                   block:^{
                     [events addObject:@"batch-1"];
                     [gate performWhenReady:@"test"
                                      block:^{
                                        [events addObject:@"batch-2-should-be-discarded"];
                                      }];
                     [gate markFailedAndDiscardPending];
                   }];

  [gate markReadyAndFlush];

  [gate performWhenReady:@"test"
                   block:^{
                     [events addObject:@"post-abort-should-not-run"];
                   }];

  XCTAssertEqualObjects(events, @[ @"batch-1" ]);
}

- (void)testMarkReadyAndFlushCatchesExceptionAndContinuesFlushingRemainingBlocks {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSString *> *events = [NSMutableArray array];
  __block __weak FIRCLSDeallocReentrancyProbe *weakProbe = nil;

  @autoreleasepool {
    [gate performWhenReady:@"test"
                     block:^{
                       [events addObject:@"batch-1-before-throw"];
                     }];

    [gate performWhenReady:@"test"
                     block:^{
                       [events addObject:@"throwing-block-start"];
                       // Create and enqueue in an inner scope that exits normally before `@throw`
                       // so the throwing stack frame holds no un-cleaned local strong references
                       // under `-fno-objc-arc-exceptions`.
                       {
                         FIRCLSDeallocReentrancyProbe *probe = [[FIRCLSDeallocReentrancyProbe alloc]
                               initWithGate:gate
                             onDeallocBlock:^{
                               [events addObject:@"probe-dealloc-drained"];
                             }];
                         weakProbe = probe;
                         [gate performWhenReady:@"test"
                                          block:^{
                                            (void)probe;
                                            [events addObject:@"batch-2-queued-before-throw"];
                                          }];
                       }
                       @throw [NSException exceptionWithName:@"TestFlushException"
                                                      reason:@"Simulated exception"
                                                    userInfo:nil];
                     }];

    [gate performWhenReady:@"test"
                     block:^{
                       [events addObject:@"batch-1-after-throw"];
                     }];

    XCTAssertNoThrow([gate markReadyAndFlush]);
  }

  XCTAssertNil(weakProbe);
  [gate performWhenReady:@"test"
                   block:^{
                     [events addObject:@"post-flush-inline"];
                   }];

  NSArray<NSString *> *expected = @[
    @"batch-1-before-throw", @"throwing-block-start", @"batch-1-after-throw",
    @"batch-2-queued-before-throw", @"probe-dealloc-drained", @"post-flush-inline"
  ];
  XCTAssertEqualObjects(events, expected);
}

- (void)testPendingBlocksExceedingMaxLimitDropsExcessAndReleasesCapturedObjects {
  XCTAssertEqual(FIRCLSContextInitGateMaxPendingBlocks, 128u);

  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSNumber *> *order = [NSMutableArray array];
  __weak NSObject *weakDroppedCapture = nil;

  @autoreleasepool {
    for (NSUInteger i = 0; i < FIRCLSContextInitGateMaxPendingBlocks; i++) {
      [gate performWhenReady:@"test"
                       block:^{
                         [order addObject:@(i)];
                       }];
    }

    for (NSUInteger excess = 0; excess < 20; excess++) {
      NSObject *capturedByDropped = [[NSObject alloc] init];
      if (excess == 0) {
        weakDroppedCapture = capturedByDropped;
      }
      NSUInteger droppedIndex = FIRCLSContextInitGateMaxPendingBlocks + excess;
      [gate performWhenReady:(excess == 0 ? @"overflow-log" : nil)
                       block:^{
                         (void)capturedByDropped;
                         [order addObject:@(droppedIndex)];
                       }];
    }
  }

  // Dropped blocks must not be retained in `_pendingBlocks` even before flush runs.
  XCTAssertNil(weakDroppedCapture);
  XCTAssertEqual(order.count, 0u);

  [gate markReadyAndFlush];

  XCTAssertEqual(order.count, FIRCLSContextInitGateMaxPendingBlocks);
  for (NSUInteger i = 0; i < FIRCLSContextInitGateMaxPendingBlocks; i++) {
    XCTAssertEqualObjects(order[i], @(i));
  }

  // Once ready, inline calls are never subject to the pre-init pending block limit.
  const NSUInteger postReadyCalls = FIRCLSContextInitGateMaxPendingBlocks + 25;
  __block NSUInteger inlineCount = 0;
  for (NSUInteger i = 0; i < postReadyCalls; i++) {
    [gate performWhenReady:@"test"
                     block:^{
                       inlineCount++;
                     }];
  }
  XCTAssertEqual(inlineCount, postReadyCalls);
}

- (void)testPendingBlockLimitReplenishesAcrossFlushBatches {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  NSMutableArray<NSString *> *events = [NSMutableArray array];

  // Fill Batch 1 to the exact 128-block ceiling; when Batch 1 drains, `_pendingBlocks` is emptied
  // before Block 0 runs, allowing up to 128 Batch-2 blocks while still dropping a 129th.
  [gate performWhenReady:@"test"
                   block:^{
                     [events addObject:@"b1-0"];
                     for (NSUInteger j = 0; j < FIRCLSContextInitGateMaxPendingBlocks + 5; j++) {
                       [gate performWhenReady:@"test"
                                        block:^{
                                          [events addObject:[NSString
                                                                stringWithFormat:@"b2-%lu",
                                                                                 (unsigned long)j]];
                                        }];
                     }
                   }];

  for (NSUInteger i = 1; i < FIRCLSContextInitGateMaxPendingBlocks + 5; i++) {
    [gate performWhenReady:@"test"
                     block:^{
                       [events addObject:[NSString stringWithFormat:@"b1-%lu", (unsigned long)i]];
                     }];
  }

  [gate markReadyAndFlush];

  XCTAssertEqual(events.count, FIRCLSContextInitGateMaxPendingBlocks * 2);
  XCTAssertEqualObjects(events[0], @"b1-0");
  XCTAssertEqualObjects(events[FIRCLSContextInitGateMaxPendingBlocks - 1], @"b1-127");
  XCTAssertEqualObjects(events[FIRCLSContextInitGateMaxPendingBlocks], @"b2-0");
  XCTAssertEqualObjects(events[FIRCLSContextInitGateMaxPendingBlocks * 2 - 1], @"b2-127");
}

- (void)testConcurrentProducersExceedingLimitBufferAtMostMaxPendingBlocks {
  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];

  const int producerThreads = 8;
  const int blocksPerThread = 50;
  const int totalBlocks = producerThreads * blocksPerThread;

  atomic_int *executionCounts = calloc((size_t)totalBlocks, sizeof(atomic_int));
  XCTAssertTrue(executionCounts != NULL);

  dispatch_group_t group = dispatch_group_create();
  dispatch_queue_t concurrentQueue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);

  for (int t = 0; t < producerThreads; t++) {
    dispatch_group_async(group, concurrentQueue, ^{
      for (int i = 0; i < blocksPerThread; i++) {
        int slot = t * blocksPerThread + i;
        [gate
            performWhenReady:@"test"
                       block:^{
                         atomic_fetch_add_explicit(&executionCounts[slot], 1, memory_order_relaxed);
                       }];
      }
    });
  }
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

  [gate markReadyAndFlush];

  NSUInteger totalExecuted = 0;
  for (int slot = 0; slot < totalBlocks; slot++) {
    int count = atomic_load_explicit(&executionCounts[slot], memory_order_relaxed);
    XCTAssertLessThanOrEqual(count, 1, @"Block %d executed more than once", slot);
    totalExecuted += (NSUInteger)count;
  }
  XCTAssertEqual(totalExecuted, FIRCLSContextInitGateMaxPendingBlocks);

  free(executionCounts);
}

- (void)testBlockingFinalFlushAfterMaxNonBlockingFlushesTerminatesAndPreservesFIFO {
  XCTAssertEqual(FIRCLSContextInitGateMaxNonBlockingFlushes, 3u);

  FIRCLSContextInitGate *gate = [[FIRCLSContextInitGate alloc] init];
  os_unfair_lock orderLock = OS_UNFAIR_LOCK_INIT;
  os_unfair_lock *orderLockPtr = &orderLock;
  NSMutableArray<NSNumber *> *order = [NSMutableArray array];
  dispatch_semaphore_t callerReadySem = dispatch_semaphore_create(0);
  dispatch_semaphore_t callerDoneSem = dispatch_semaphore_create(0);
  __block __weak NSObject *weakFinalCapture = nil;

  NSUInteger blockingIndex = FIRCLSContextInitGateMaxNonBlockingFlushes;
  NSUInteger callerIndex = blockingIndex + 1;

  dispatch_block_t nextPassEnqueue = ^{
    @autoreleasepool {
      NSObject *finalCapture = [[NSObject alloc] init];
      weakFinalCapture = finalCapture;
      [gate performWhenReady:@"blocking-final"
                       block:^{
                         (void)finalCapture;
                         dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                           dispatch_semaphore_signal(callerReadySem);
                           [gate performWhenReady:@"caller"
                                            block:^{
                                              os_unfair_lock_lock(orderLockPtr);
                                              [order addObject:@(callerIndex)];
                                              os_unfair_lock_unlock(orderLockPtr);
                                            }];
                           dispatch_semaphore_signal(callerDoneSem);
                         });
                         dispatch_semaphore_wait(callerReadySem, DISPATCH_TIME_FOREVER);
                         usleep(2000);
                         os_unfair_lock_lock(orderLockPtr);
                         [order addObject:@(blockingIndex)];
                         os_unfair_lock_unlock(orderLockPtr);
                       }];
    }
  };

  for (NSUInteger remaining = FIRCLSContextInitGateMaxNonBlockingFlushes; remaining > 0;
       remaining--) {
    NSUInteger passIndex = remaining - 1;
    dispatch_block_t downstream = nextPassEnqueue;
    nextPassEnqueue = ^{
      [gate performWhenReady:@"non-blocking-pass"
                       block:^{
                         os_unfair_lock_lock(orderLockPtr);
                         [order addObject:@(passIndex)];
                         os_unfair_lock_unlock(orderLockPtr);
                         downstream();
                       }];
    };
  }
  nextPassEnqueue();

  @autoreleasepool {
    [gate markReadyAndFlush];
  }

  XCTAssertNil(weakFinalCapture);
  XCTAssertEqual(
      dispatch_semaphore_wait(callerDoneSem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)),
      0);

  NSMutableArray<NSNumber *> *expected = [NSMutableArray arrayWithCapacity:callerIndex + 1];
  for (NSUInteger i = 0; i <= callerIndex; i++) {
    [expected addObject:@(i)];
  }
  XCTAssertEqualObjects(order, expected);
}

@end
