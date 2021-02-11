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
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager+Private.h"

#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/FPRClient.h"
#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeCollector.h"
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeCollector.h"

#import <UIKit/UIKit.h>

// Number of gauge data information after which that gets flushed to Google Data Transport.
NSInteger const kGaugeDataBatchSize = 25;

@interface FPRGaugeManager () <FPRCPUGaugeCollectorDelegate, FPRMemoryGaugeCollectorDelegate>

/** @brief List of gauges that are currently being actively captured. */
@property(nonatomic, readwrite) FPRGauges activeGauges;

/** @brief List of gauge information collected. Intentionally this is not a typed collection. Gauge
 * data could be CPU Gauge data or Memory gauge data.
 */
@property(nonatomic) NSMutableArray *gaugeData;

/** @brief Currently active sessionID. */
@property(nonatomic, readwrite) NSString *currentSessionId;

@end

@implementation FPRGaugeManager

+ (instancetype)sharedInstance {
  static FPRGaugeManager *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[FPRGaugeManager alloc] initWithGauges:FPRGaugeNone];
  });
  return instance;
}

- (instancetype)initWithGauges:(FPRGauges)gauges {
  self = [super init];
  if (self) {
    _activeGauges = FPRGaugeNone;
    _gaugeData = [[NSMutableArray alloc] init];
    _gaugeDataProtectionQueue =
        dispatch_queue_create("com.google.perf.gaugeManager.gaugeData", DISPATCH_QUEUE_SERIAL);
    _isColdStart = YES;
    [self startAppActivityTracking];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIApplicationDidBecomeActiveNotification
                                                object:[UIApplication sharedApplication]];

  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIApplicationWillResignActiveNotification
                                                object:[UIApplication sharedApplication]];
}

/**
 * Starts tracking the application state changes.
 */
- (void)startAppActivityTracking {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appStateChanged:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:[UIApplication sharedApplication]];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appStateChanged:)
                                               name:UIApplicationWillResignActiveNotification
                                             object:[UIApplication sharedApplication]];
}

- (void)appStateChanged:(NSNotification *)notification {
  FPRApplicationState applicationState = [FPRAppActivityTracker sharedInstance].applicationState;
  [self.cpuGaugeCollector updateSamplingFrequencyForApplicationState:applicationState];
  [self.memoryGaugeCollector updateSamplingFrequencyForApplicationState:applicationState];
  self.isColdStart = NO;
}

#pragma mark - Implementation methods

- (BOOL)gaugeCollectionEnabled {
  // Allow gauge collection to happen during cold start. During dispatch time, we do another check
  // to make sure if gauge collection is enabled. This is to accomodate gauge metric collection
  // during app_start scenario.
  if (self.isColdStart) {
    return YES;
  }

  // Check if the SDK is enabled to collect gauge data.
  BOOL sdkEnabled = [[FPRConfigurations sharedInstance] sdkEnabled];
  if (!sdkEnabled) {
    return NO;
  }

  return [FPRConfigurations sharedInstance].isDataCollectionEnabled;
}

- (void)startCollectingGauges:(FPRGauges)gauges forSessionId:(NSString *)sessionId {
  [self prepareAndDispatchGaugeData];

  self.currentSessionId = sessionId;
  if (self.gaugeCollectionEnabled) {
    if ((gauges & FPRGaugeCPU) == FPRGaugeCPU) {
      self.cpuGaugeCollector = [[FPRCPUGaugeCollector alloc] initWithDelegate:self];
    }
    if ((gauges & FPRGaugeMemory) == FPRGaugeMemory) {
      self.memoryGaugeCollector = [[FPRMemoryGaugeCollector alloc] initWithDelegate:self];
    }

    self.activeGauges = self.activeGauges | gauges;
  }
}

- (void)stopCollectingGauges:(FPRGauges)gauges {
  if ((gauges & FPRGaugeCPU) == FPRGaugeCPU) {
    self.cpuGaugeCollector = nil;
  }

  if ((gauges & FPRGaugeMemory) == FPRGaugeMemory) {
    self.memoryGaugeCollector = nil;
  }

  self.activeGauges = self.activeGauges & ~(gauges);

  [self prepareAndDispatchGaugeData];
}

- (void)collectAllGauges {
  if (self.cpuGaugeCollector) {
    [self.cpuGaugeCollector collectMetric];
  }

  if (self.memoryGaugeCollector) {
    [self.memoryGaugeCollector collectMetric];
  }
}

- (void)dispatchMetric:(id)gaugeMetric {
  // If the gauge metric is of type CPU, then dispatch only if CPU collection is enabled.
  if ([gaugeMetric isKindOfClass:[FPRCPUGaugeData class]] &&
      ((self.activeGauges & FPRGaugeCPU) == FPRGaugeCPU)) {
    [self addGaugeData:gaugeMetric];
  }

  // If the gauge metric is of type memory, then dispatch only if memory collection is enabled.
  if ([gaugeMetric isKindOfClass:[FPRMemoryGaugeData class]] &&
      ((self.activeGauges & FPRGaugeMemory) == FPRGaugeMemory)) {
    [self addGaugeData:gaugeMetric];
  }
}

#pragma mark - Utils

- (void)prepareAndDispatchGaugeData {
  NSArray *currentBatch = self.gaugeData;
  NSString *currentSessionId = self.currentSessionId;
  self.gaugeData = [[NSMutableArray alloc] init];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    if (currentBatch.count > 0) {
      [[FPRClient sharedInstance] logGaugeMetric:currentBatch forSessionId:currentSessionId];
      FPRLogDebug(kFPRGaugeManagerDataCollected, @"Logging %lu gauge metrics.",
                  (unsigned long)currentBatch.count);
    }
  });
}

/**
 * Adds the gauge to the batch and decide on when to dispatch the events to Google Data Transport.
 *
 * @param gaugeData Gauge data received from the collectors.
 */
- (void)addGaugeData:(id)gaugeData {
  dispatch_async(self.gaugeDataProtectionQueue, ^{
    if (gaugeData) {
      [self.gaugeData addObject:gaugeData];

      if (self.gaugeData.count >= kGaugeDataBatchSize) {
        [self prepareAndDispatchGaugeData];
      }
    }
  });
}

#pragma mark - FPRCPUGaugeCollectorDelegate methods

- (void)cpuGaugeCollector:(FPRCPUGaugeCollector *)collector gaugeData:(FPRCPUGaugeData *)gaugeData {
  [self addGaugeData:gaugeData];
}

#pragma mark - FPRMemoryGaugeCollectorDelegate methods

- (void)memoryGaugeCollector:(FPRMemoryGaugeCollector *)collector
                   gaugeData:(FPRMemoryGaugeData *)gaugeData {
  [self addGaugeData:gaugeData];
}

@end
