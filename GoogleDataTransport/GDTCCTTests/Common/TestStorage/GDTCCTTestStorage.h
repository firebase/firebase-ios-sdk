/*
 * Copyright 2020 Google LLC
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
#import <XCTest/XCTest.h>

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORStorageProtocol.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^GDTCCTTestStorageBatchHandler)(GDTCORStorageEventSelector *_Nullable eventSelector,
                                              NSDate *_Nullable expiration,
                                              GDTCORStorageBatchBlock _Nullable completion);

typedef void (^GDTCCTTestStorageHasEventsCompletion)(BOOL hasEvents);
typedef void (^GDTCCTTestStorageHasEventsHandler)(GDTCORTarget target,
                                                  GDTCCTTestStorageHasEventsCompletion completion);

@interface GDTCCTTestStorage : NSObject <GDTCORStorageProtocol>

#pragma mark - Method call expectations.

@property(nonatomic, nullable) XCTestExpectation *batchWithEventSelectorExpectation;
@property(nonatomic, nullable) XCTestExpectation *removeBatchAndDeleteEventsExpectation;
@property(nonatomic, nullable) XCTestExpectation *removeBatchWithoutDeletingEventsExpectation;
@property(nonatomic, nullable) XCTestExpectation *batchIDsForTargetExpectation;

#pragma mark - Blocks to provide custom implementations for the methods.

/// A block to override `batchWithEventSelector:batchExpiration:onComplete:` implementation.
@property(nonatomic, copy, nullable) GDTCCTTestStorageBatchHandler batchWithEventSelectorHandler;
/// A block to override `hasEventsForTarget:onComplete:` implementation.
@property(nonatomic, copy, nullable) GDTCCTTestStorageHasEventsHandler hasEventsForTargetHandler;

#pragma mark - Default test implementations

/// Default test implementation for `batchWithEventSelector:batchExpiration:onComplete:`  method.
- (void)defaultBatchWithEventSelector:(nonnull GDTCORStorageEventSelector *)eventSelector
                      batchExpiration:(nonnull NSDate *)expiration
                           onComplete:(nonnull GDTCORStorageBatchBlock)onComplete;

@end

NS_ASSUME_NONNULL_END
