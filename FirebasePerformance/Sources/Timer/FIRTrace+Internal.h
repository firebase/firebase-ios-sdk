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

#import "FirebasePerformance/Sources/FIRPerformance+Internal.h"

/**
 * Extension that is added on top of the class FIRTrace to make certain methods used internally
 * within the SDK, but not public facing. A category could be ideal, but Firebase recommends not
 * using categories as that mandates including -ObjC flag for build which is an extra step for the
 * developer.
 */
@interface FIRTrace () <FIRPerformanceAttributable>

/** @brief List of currently active counters. */
@property(atomic, readonly, nonnull) NSDictionary<NSString *, NSNumber *> *counters;

/** @brief The number of active counters on the given trace. */
@property(atomic, readonly) NSUInteger numberOfCounters;

/** Denotes if the trace is internal. */
@property(nonatomic, getter=isInternal) BOOL internal;

/** @brief List of sessions the trace is associated with. */
@property(nonnull, atomic, readonly) NSArray<FPRSessionDetails *> *sessions;

/**
 * Creates an instance of FIRTrace.
 *
 * @param name The name of the Trace. Name cannot be an empty string.
 *
 * @return An instance of FIRTrace.
 */
- (nullable instancetype)initWithName:(nonnull NSString *)name;

/**
 * Creates an instance of FIRTrace.
 *
 * @param name Name of the Trace. Name cannot be an empty string.
 *
 * @return An instance of FIRTrace.
 */
- (nullable instancetype)initTraceWithName:(nonnull NSString *)name NS_DESIGNATED_INITIALIZER;

/**
 * Creates an instance of internal FIRTrace. Internal FIRTrace objects do not have any validation on
 * the name provided except that it cannot be empty.
 *
 * @param name Name of the Trace. Name cannot be an empty string.
 *
 * @return An instance of FIRTrace.
 */
- (nullable instancetype)initInternalTraceWithName:(nonnull NSString *)name;

/**
 * Starts the trace with a specified start time.
 *
 * @param startTime Start time of the trace. If the startTime is nil, current time will be set.
 */
- (void)startWithStartTime:(nullable NSDate *)startTime;

/**
 * Creates a stage inside the trace with a defined start time. This stops the already existing
 * active stage if any and starts the new stage with the name provided. If the startTime is nil, the
 * start time of the stage is set to the current date.

 * @param stageName Name of the stages.
 * @param startTime Start time of the stage.
 */
- (void)startStageNamed:(nonnull NSString *)stageName startTime:(nullable NSDate *)startTime;

/** Cancels the trace without sending an event to Google Data Transport. */
- (void)cancel;

/**
 * Deletes a metric with the given name. If the metric doesnt exist, this has no effect.
 *
 * @param metricName The name of the metric to delete.
 */
- (void)deleteMetric:(nonnull NSString *)metricName;

@end
