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

#import "FirebasePerformance/Sources/Gauges/FPRGaugeCollector.h"
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeData.h"

NS_ASSUME_NONNULL_BEGIN

@class FPRMemoryGaugeCollector;

/** Delegate method for the memory Gauge collector to report back the memory gauge data. */
@protocol FPRMemoryGaugeCollectorDelegate

/**
 * Reports the collected memory gauge data back to its delegate.
 *
 * @param collector memory gauge collector that collected the information.
 * @param gaugeData memory gauge data.
 */
- (void)memoryGaugeCollector:(FPRMemoryGaugeCollector *)collector
                   gaugeData:(FPRMemoryGaugeData *)gaugeData;

@end

@interface FPRMemoryGaugeCollector : NSObject <FPRGaugeCollector>

/** Reference to the delegate object. */
@property(nonatomic, weak, readonly) id<FPRMemoryGaugeCollectorDelegate> delegate;

/**
 * Initializes the memory collector object with the delegate object provided.
 *
 * @param delegate Delegate object to which the memory gauge data is provided.
 * @return Instance of the memory gauge collector.
 */
- (instancetype)initWithDelegate:(id<FPRMemoryGaugeCollectorDelegate>)delegate
    NS_DESIGNATED_INITIALIZER;

/**
 * Initializer for the memory Gauge collector. This is not available.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
