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

#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeCollector.h"
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeCollector+Private.h"

#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/FPRConsoleLogger.h"

#include <malloc/malloc.h>

@interface FPRMemoryGaugeCollector ()

/** @brief Timer property used for the frequency of CPU data collection. */
@property(nonatomic) dispatch_source_t timerSource;

/** @brief Gauge collector queue on which the gauge data collected. */
@property(nonatomic) dispatch_queue_t gaugeCollectorQueue;

/** @brief Boolean to see if the timer is active or paused. */
@property(nonatomic) BOOL timerPaused;

@end

FPRMemoryGaugeData *fprCollectMemoryMetric(void) {
  NSDate *collectionTime = [NSDate date];

  struct mstats ms = mstats();
  FPRMemoryGaugeData *gaugeData = [[FPRMemoryGaugeData alloc] initWithCollectionTime:collectionTime
                                                                            heapUsed:ms.bytes_used
                                                                       heapAvailable:ms.bytes_free];
  return gaugeData;
}

@implementation FPRMemoryGaugeCollector

- (instancetype)initWithDelegate:(id<FPRMemoryGaugeCollectorDelegate>)delegate {
  self = [super init];
  if (self) {
    _delegate = delegate;
    _gaugeCollectorQueue =
        dispatch_queue_create("com.google.firebase.FPRMemoryGaugeCollector", DISPATCH_QUEUE_SERIAL);
    _configurations = [FPRConfigurations sharedInstance];
    _timerPaused = YES;
    [self updateSamplingFrequencyForApplicationState:[FPRAppActivityTracker sharedInstance]
                                                         .applicationState];
  }
  return self;
}

- (void)stopCollecting {
  if (self.timerPaused == NO) {
    dispatch_source_cancel(self.timerSource);
    self.timerPaused = YES;
  }
}

- (void)resumeCollecting {
  [self updateSamplingFrequencyForApplicationState:[FPRAppActivityTracker sharedInstance]
                                                       .applicationState];
}

- (void)updateSamplingFrequencyForApplicationState:(FPRApplicationState)applicationState {
  uint32_t frequencyInMs = (applicationState == FPRApplicationStateBackground)
                               ? [self.configurations memorySamplingFrequencyInBackgroundInMS]
                               : [self.configurations memorySamplingFrequencyInForegroundInMS];
  [self captureMemoryGaugeAtFrequency:frequencyInMs];
}

#pragma mark - Internal methods.

/**
 * Captures the memory gauge at a defined frequency.
 *
 * @param frequencyInMs Frequency at which the memory gauges are collected.
 */
- (void)captureMemoryGaugeAtFrequency:(uint32_t)frequencyInMs {
  [self stopCollecting];
  if (frequencyInMs > 0) {
    self.timerSource =
        dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.gaugeCollectorQueue);
    dispatch_source_set_timer(self.timerSource,
                              dispatch_time(DISPATCH_TIME_NOW, frequencyInMs * NSEC_PER_MSEC),
                              frequencyInMs * NSEC_PER_MSEC, (1ull * NSEC_PER_SEC) / 10);
    FPRMemoryGaugeCollector __weak *weakSelf = self;
    dispatch_source_set_event_handler(weakSelf.timerSource, ^{
      FPRMemoryGaugeCollector *strongSelf = weakSelf;
      if (strongSelf) {
        [strongSelf collectMetric];
      }
    });
    dispatch_resume(self.timerSource);
    self.timerPaused = NO;
  } else {
    FPRLogDebug(kFPRMemoryCollection, @"Memory metric collection is disabled.");
  }
}

- (void)collectMetric {
  FPRMemoryGaugeData *gaugeMetric = fprCollectMemoryMetric();
  [self.delegate memoryGaugeCollector:self gaugeData:gaugeMetric];
}

@end
