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

#import "FirebasePerformance/Sources/AppActivity/FPRAppActivityTracker.h"
#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeData.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeCollector.h"

NS_ASSUME_NONNULL_BEGIN

@class FPRCPUGaugeCollector;

/** Delegate method for the CPU Gauge collector to report back the CPU gauge data. */
@protocol FPRCPUGaugeCollectorDelegate

/**
 * Reports the collected CPU gauge data back to its delegate.
 *
 * @param collector CPU gauge collector that collected the information.
 * @param gaugeData CPU gauge data.
 */
- (void)cpuGaugeCollector:(FPRCPUGaugeCollector *)collector gaugeData:(FPRCPUGaugeData *)gaugeData;

@end

/** CPU Gauge collector implementation. This class collects the CPU utilitization and reports back
 *  to the delegate.
 */
@interface FPRCPUGaugeCollector : NSObject <FPRGaugeCollector>

/** Reference to the delegate object. */
@property(nonatomic, weak, readonly) id<FPRCPUGaugeCollectorDelegate> delegate;

/**
 * Initializes the CPU collector object with the delegate object provided.
 *
 * @param delegate Delegate object to which the CPU gauge data is provided.
 * @return Instance of the CPU Gauge collector.
 */
- (instancetype)initWithDelegate:(id<FPRCPUGaugeCollectorDelegate>)delegate
    NS_DESIGNATED_INITIALIZER;

/**
 * Initializer for the CPU Gauge collector. This is not available.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
