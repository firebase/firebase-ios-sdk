// Copyright 2020 Google LLC
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

#import "FirebasePerformance/Sources/Timer/FPRCounterList.h"

#import "FirebasePerformance/Sources/AppActivity/FPRSessionDetails.h"

#import "FirebasePerformance/Sources/AppActivity/FPRTraceBackgroundActivityTracker.h"

#import "FirebasePerformance/Sources/FPRClient+Private.h"
#import "FirebasePerformance/Sources/FPRClient.h"

/**
 * Extension that is added on top of the class FIRTrace to make the private properties visible
 * between the implementation file and the unit tests.
 */
@interface FIRTrace ()

/** @brief NSTimeInterval for which the trace was active. */
@property(nonatomic, assign, readonly) NSTimeInterval totalTraceTimeInterval;

/** @brief Start time of the trace since epoch. */
@property(nonatomic, assign, readonly) NSTimeInterval startTimeSinceEpoch;

/**
 * Starts a stage with the given name. Multiple stages can have a same name. Starting a new stage
 * would stop the previous active stage if any.
 *
 * @param stageName name of the Stage.
 */
- (void)startStageNamed:(nonnull NSString *)stageName;

/** @brief List of stages in the trace. */
@property(nonnull, nonatomic) FPRClient *fprClient;

/** @brief List of stages in the trace. */
@property(nonnull, nonatomic) NSMutableArray<FIRTrace *> *stages;

/** @brief The current active stage. */
@property(nullable, nonatomic) FIRTrace *activeStage;

/** List of counters managed by the Trace. */
@property(nonnull, nonatomic, readonly) FPRCounterList *counterList;

/** Background state of the trace. */
@property(nonatomic, readonly) FPRTraceState backgroundTraceState;

/** @brief List of sessions the trace is associated with. */
@property(nonatomic, readwrite, nonnull) NSMutableArray<FPRSessionDetails *> *activeSessions;

/** @brief Serial queue to manage sessionId updates. */
@property(nonnull, nonatomic, readonly) dispatch_queue_t sessionIdSerialQueue;

/**
 * Verifies if the trace contains all necessary and valid information.
 *
 * @return A boolean stating if the Trace is complete.
 */
- (BOOL)isCompleteAndValid;

@end
