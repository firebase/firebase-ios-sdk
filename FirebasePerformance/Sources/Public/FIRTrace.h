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

#import <Foundation/Foundation.h>

#import "FIRPerformanceAttributable.h"

/**
 * FIRTrace objects contain information about a "Trace", which is a sequence of steps. Traces can be
 * used to measure the time taken for a sequence of steps.
 * Traces also include "Counters". Counters are used to track information which is cumulative in
 * nature (e.g., Bytes downloaded). Counters are scoped to an FIRTrace object.
 */
NS_EXTENSION_UNAVAILABLE("FirebasePerformance does not support app extensions at this time.")
NS_SWIFT_NAME(Trace)
@interface FIRTrace : NSObject <FIRPerformanceAttributable>

/** @brief Name of the trace. */
@property(nonatomic, copy, readonly, nonnull) NSString *name;

/** @brief Not a valid initializer. */
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
 * Starts the trace.
 */
- (void)start;

/**
 * Stops the trace if the trace is active.
 */
- (void)stop;

#pragma mark - Metrics API

/**
 * Atomically increments the metric for the provided metric name with the provided value. If it is a
 * new metric name, the metric value will be initialized to the value. Does nothing if the trace
 * has not been started or has already been stopped.
 *
 * @param metricName The name of the metric to increment.
 * @param incrementValue The value to increment the metric by.
 */
- (void)incrementMetric:(nonnull NSString *)metricName
                  byInt:(int64_t)incrementValue NS_SWIFT_NAME(incrementMetric(_:by:));

/**
 * Gets the value of the metric for the provided metric name. If the metric doesn't exist, a 0 is
 * returned.
 *
 * @param metricName The name of metric whose value to get.
 * @return The value of the given metric or 0 if it hasn't yet been set.
 */
- (int64_t)valueForIntMetric:(nonnull NSString *)metricName NS_SWIFT_NAME(valueForMetric(_:));

/**
 * Sets the value of the metric for the provided metric name to the provided value. Does nothing if
 * the trace has not been started or has already been stopped.
 *
 * @param metricName The name of the metric to set.
 * @param value The value to set the metric to.
 */
- (void)setIntValue:(int64_t)value
          forMetric:(nonnull NSString *)metricName NS_SWIFT_NAME(setValue(_:forMetric:));

@end
