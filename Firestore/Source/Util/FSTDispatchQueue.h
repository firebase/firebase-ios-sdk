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

NS_ASSUME_NONNULL_BEGIN

@interface FSTDispatchQueue : NSObject

/** Creates and returns an FSTDispatchQueue wrapping the specified dispatch_queue_t. */
+ (instancetype)queueWith:(dispatch_queue_t)dispatchQueue;

- (instancetype)init __attribute__((unavailable("Use static constructor method.")));

/**
 * Asserts that we are already running on this queue (actually, we can only verify that the
 * queue's label is the same, but hopefully that's good enough.)
 */
- (void)verifyIsCurrentQueue;

/**
 * Same as dispatch_async() except it asserts that we're not already on the queue, since this
 * generally indicates a bug (and can lead to re-ordering of operations, etc).
 *
 * @param block The block to run.
 */
- (void)dispatchAsync:(void (^)(void))block;

/**
 * Unlike dispatchAsync: this method does not require you to dispatch to a different queue than
 * the current one (thus it is equivalent to a raw dispatch_async()).
 *
 * This is useful, e.g. for dispatching to the user's queue directly from user API call (in which
 * case we don't know if we're already on the user's queue or not).
 *
 * @param block The block to run.
 */
- (void)dispatchAsyncAllowingSameQueue:(void (^)(void))block;

/** The underlying wrapped dispatch_queue_t */
@property(nonatomic, strong, readonly) dispatch_queue_t queue;

@end

NS_ASSUME_NONNULL_END
