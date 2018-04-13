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

#import "Firestore/Source/Util/FSTDispatchQueue.h"

@class XCTestExpectation;

NS_ASSUME_NONNULL_BEGIN

/**
 * Dispatch queue used in the integration tests that caps delayed executions at 1.0 seconds.
 */
@interface FSTTestDispatchQueue : FSTDispatchQueue

/** Creates and returns an FSTTestDispatchQueue wrapping the specified dispatch_queue_t. */
+ (instancetype)queueWith:(dispatch_queue_t)dispatchQueue;

/**
 * Registers a test expectation that is fulfilled when the next delayed callback finished
 * executing.
 */
- (void)fulfillOnExecution:(XCTestExpectation *)expectation;

@end

NS_ASSUME_NONNULL_END
