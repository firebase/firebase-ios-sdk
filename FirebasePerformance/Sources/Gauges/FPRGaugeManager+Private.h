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

#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager.h"

#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeCollector.h"
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeCollector.h"

/** This extension should only be used for testing. */
@interface FPRGaugeManager ()

/** @brief Tracks if gauge collection is enabled. */
@property(nonatomic, readonly) BOOL gaugeCollectionEnabled;

/** @brief CPU gauge collector. */
@property(nonatomic, readwrite, nullable) FPRCPUGaugeCollector *cpuGaugeCollector;

/** @brief Memory gauge collector. */
@property(nonatomic, readwrite, nullable) FPRMemoryGaugeCollector *memoryGaugeCollector;

/** @brief Serial queue to manage gauge data collection. */
@property(nonatomic, readwrite, nonnull) dispatch_queue_t gaugeDataProtectionQueue;

/** @brief Tracks if this session is a cold start of the application. */
@property(nonatomic) BOOL isColdStart;

/**
 * Creates an instance of FPRGaugeManager with the gauges required.
 */
- (nonnull instancetype)initWithGauges:(FPRGauges)gauges;

/**
 * Prepares for dispatching the current set of gauge data to Google Data Transport.
 *
 * @param sessionId SessionId that will be used for dispatching the gauge data
 */
- (void)prepareAndDispatchCollectedGaugeDataWithSessionId:(nullable NSString *)sessionId;

@end
