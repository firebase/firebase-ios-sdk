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

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSInteger const kGaugeDataBatchSize;

/** List of gauges the gauge manager controls. */
typedef NS_OPTIONS(NSUInteger, FPRGauges) {
  FPRGaugeNone = 0,
  FPRGaugeCPU = (1 << 0),
  FPRGaugeMemory = (1 << 1),
};

/** This class controls different gauge collection in the system. List of the gauges this class
 manages are listed above. */
@interface FPRGaugeManager : NSObject

/** @brief List of gauges that are currently being actively captured. */
@property(nonatomic, readonly) FPRGauges activeGauges;

/**
 * Creates an instance of GaugeManager.
 *
 * @return Instance of GaugeManager.
 */
+ (instancetype)sharedInstance;

/**
 * Initializer for the gauge manager. This is not available.
 */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Starts collecting gauge metrics for the specified set of gauges. Calling this will dispatch all
 * the currently existing gauge data and will start collecting the new data with the new sessionId.
 *
 * @param gauges Gauges that needs to be collected.
 * @param sessionId SessionId for which the gauges are collected.
 */
- (void)startCollectingGauges:(FPRGauges)gauges forSessionId:(NSString *)sessionId;

/**
 * Stops collecting gauge metrics for the specified set of gauges. Calling this will dispatch all
 * the existing gauge data.
 *
 * @param gauges Gauges that needs to be stopped collecting.
 */
- (void)stopCollectingGauges:(FPRGauges)gauges;

/**
 * Collects all the gauges.
 */
- (void)collectAllGauges;

/**
 * Takes a gauge metric and tries to dispatch the gauge metric.
 *
 * @param gaugeMetric Gauge metric that needs to be dispatched.
 */
- (void)dispatchMetric:(id)gaugeMetric;

@end

NS_ASSUME_NONNULL_END
