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

/**
 * FPRCounterList contains information about a list of counters. Every item in the list is a
 * key value pair, where the key is the reference to the name of a counter and the value is the
 * current count for the key. Counter values can be incremented.
 */
@interface FPRCounterList : NSObject

@property(atomic, nonnull, readonly) NSDictionary<NSString *, NSNumber *> *counters;

/**
 * The number of counters.
 */
@property(atomic, readonly) NSUInteger numberOfCounters;

/** Serial queue to manage incrementing counters. */
@property(nonatomic, nonnull, readonly) dispatch_queue_t counterSerialQueue;

/**
 * Increments the counter for the provided counter name with the provided value.
 *
 * @param counterName Name of the counter.
 * @param incrementValue Value the counter would be incremented with.
 */
- (void)incrementCounterNamed:(nonnull NSString *)counterName by:(NSInteger)incrementValue;

/**
 * Verifies if the metrics are valid.
 *
 * @return A boolean stating if the metrics are valid.
 */
- (BOOL)isValid;

/**
 * Increments the metric for the provided metric name with the provided value.
 *
 * @param metricName Name of the metric.
 * @param incrementValue Value the metric would be incremented with.
 */
- (void)incrementMetric:(nonnull NSString *)metricName byInt:(int64_t)incrementValue;

/**
 * Gets the value of the metric for the provided metric name. If the metric doesn't exist, a 0 is
 * returned.
 *
 * @param metricName The name of metric whose value to get.
 */
- (int64_t)valueForIntMetric:(nonnull NSString *)metricName;

/**
 * Sets the value of the metric for the provided metric name to the provided value. If it is a new
 * counter name, the counter value will be initialized to the value. Does nothing if the trace has
 * not been started or has already been stopped.
 *
 * @param metricName The name of the metric whose value to set.
 * @param value The value to set the metric to.
 */
- (void)setIntValue:(int64_t)value forMetric:(nonnull NSString *)metricName;

/**
 * Deletes the metric with the given name. Does nothing if that metric doesn't exist.
 *
 * @param metricName The name of the metric to delete.
 */
- (void)deleteMetric:(nonnull NSString *)metricName;

@end
