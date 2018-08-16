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

#import <Foundation/Foundation.h>

#include "Firestore/core/src/firebase/firestore/model/types.h"

@class FSTDispatchQueue;
@protocol FSTOnlineStateDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * A component used by the FSTRemoteStore to track the OnlineState (that is, whether or not the
 * client as a whole should be considered to be online or offline), implementing the appropriate
 * heuristics.
 *
 * In particular, when the client is trying to connect to the backend, we allow up to
 * kMaxWatchStreamFailures within kOnlineStateTimeout for a connection to succeed. If we have too
 * many failures or the timeout elapses, then we set the OnlineState to Offline, and
 * the client will behave as if it is offline (getDocument() calls will return cached data, etc.).
 */
@interface FSTOnlineStateTracker : NSObject

- (instancetype)initWithWorkerDispatchQueue:(FSTDispatchQueue *)queue;

- (instancetype)init NS_UNAVAILABLE;

/** A delegate to be notified on OnlineState changes. */
@property(nonatomic, weak) id<FSTOnlineStateDelegate> onlineStateDelegate;

/**
 * Called by FSTRemoteStore when a watch stream is started (including on each backoff attempt).
 *
 * If this is the first attempt, it sets the OnlineState to Unknown and starts the
 * onlineStateTimer.
 */
- (void)handleWatchStreamStart;

/**
 * Called by FSTRemoteStore when a watch stream fails.
 *
 * Updates our OnlineState as appropriate. The first failure moves us to OnlineState::Unknown.
 * We then may allow multiple failures (based on kMaxWatchStreamFailures) before we actually
 * transition to OnlineState::Offline.
 */
- (void)handleWatchStreamFailure:(NSError *)error;

/**
 * Explicitly sets the OnlineState to the specified state.
 *
 * Note that this resets the timers / failure counters, etc. used by our Offline heuristics, so
 * it must not be used in place of handleWatchStreamStart and handleWatchStreamFailure.
 */
- (void)updateState:(firebase::firestore::model::OnlineState)newState;

@end

NS_ASSUME_NONNULL_END
