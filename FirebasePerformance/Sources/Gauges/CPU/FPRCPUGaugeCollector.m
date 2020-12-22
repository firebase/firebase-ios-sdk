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

#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeCollector.h"
#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeCollector+Private.h"

#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"

#import "FirebasePerformance/Sources/FPRConsoleLogger.h"

#import <assert.h>
#import <mach/mach.h>

@interface FPRCPUGaugeCollector ()

/** @brief Timer property used for the frequency of CPU data collection. */
@property(nonatomic) dispatch_source_t timerSource;

/** @brief Gauge collector queue on which the gauge data collected. */
@property(nonatomic) dispatch_queue_t gaugeCollectorQueue;

/** @brief Boolean to see if the timer is active or paused. */
@property(nonatomic) BOOL timerPaused;

@end

/**
 * Fetches the CPU metric and returns an instance of FPRCPUGaugeData.
 *
 * This implementation is inspired by the following references:
 * http://web.mit.edu/darwin/src/modules/xnu/osfmk/man/thread_basic_info.html
 * https://stackoverflow.com/a/8382889
 *
 * @return Instance of FPRCPUGaugeData.
 */
FPRCPUGaugeData *fprCollectCPUMetric() {
  kern_return_t kernelReturnValue;
  mach_msg_type_number_t task_info_count;
  task_info_data_t taskInfo;
  thread_array_t threadList;
  mach_msg_type_number_t threadCount;
  task_basic_info_t taskBasicInfo;
  thread_basic_info_t threadBasicInfo;

  NSDate *collectionTime = [NSDate date];
  // Get the task info to find out the CPU time used by terminated threads.
  task_info_count = TASK_BASIC_INFO_COUNT;
  kernelReturnValue =
      task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)taskInfo, &task_info_count);
  if (kernelReturnValue != KERN_SUCCESS) {
    return nil;
  }
  taskBasicInfo = (task_basic_info_t)taskInfo;

  // Get the current set of threads and find their CPU time.
  kernelReturnValue = task_threads(mach_task_self(), &threadList, &threadCount);
  if (kernelReturnValue != KERN_SUCCESS) {
    return nil;
  }

  uint64_t totalUserTimeUsec =
      taskBasicInfo->user_time.seconds * USEC_PER_SEC + taskBasicInfo->user_time.microseconds;
  uint64_t totalSystemTimeUsec =
      taskBasicInfo->system_time.seconds * USEC_PER_SEC + taskBasicInfo->system_time.microseconds;
  thread_info_data_t threadInfo;
  mach_msg_type_number_t threadInfoCount;

  for (int i = 0; i < (int)threadCount; i++) {
    threadInfoCount = THREAD_INFO_MAX;
    kernelReturnValue =
        thread_info(threadList[i], THREAD_BASIC_INFO, (thread_info_t)threadInfo, &threadInfoCount);
    if (kernelReturnValue != KERN_SUCCESS) {
      return nil;
    }

    threadBasicInfo = (thread_basic_info_t)threadInfo;
    if (!(threadBasicInfo->flags & TH_FLAGS_IDLE)) {
      totalUserTimeUsec += threadBasicInfo->user_time.seconds * USEC_PER_SEC +
                           threadBasicInfo->user_time.microseconds;
      totalSystemTimeUsec += threadBasicInfo->system_time.seconds * USEC_PER_SEC +
                             threadBasicInfo->system_time.microseconds;
    }
  }

  kernelReturnValue =
      vm_deallocate(mach_task_self(), (vm_offset_t)threadList, threadCount * sizeof(thread_t));
  assert(kernelReturnValue == KERN_SUCCESS);

  FPRCPUGaugeData *gaugeData = [[FPRCPUGaugeData alloc] initWithCollectionTime:collectionTime
                                                                    systemTime:totalSystemTimeUsec
                                                                      userTime:totalUserTimeUsec];
  return gaugeData;
}

@implementation FPRCPUGaugeCollector

- (instancetype)initWithDelegate:(id<FPRCPUGaugeCollectorDelegate>)delegate {
  self = [super init];
  if (self) {
    _delegate = delegate;
    _gaugeCollectorQueue =
        dispatch_queue_create("com.google.firebase.FPRCPUGaugeCollector", DISPATCH_QUEUE_SERIAL);
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
                               ? [self.configurations cpuSamplingFrequencyInBackgroundInMS]
                               : [self.configurations cpuSamplingFrequencyInForegroundInMS];
  [self captureCPUGaugeAtFrequency:frequencyInMs];
}

/**
 * Captures the CPU gauge at a defined frequency.
 *
 * @param frequencyInMs Frequency at which the CPU gauges are collected.
 */
- (void)captureCPUGaugeAtFrequency:(uint32_t)frequencyInMs {
  [self stopCollecting];
  if (frequencyInMs > 0) {
    self.timerSource =
        dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.gaugeCollectorQueue);
    dispatch_source_set_timer(self.timerSource,
                              dispatch_time(DISPATCH_TIME_NOW, frequencyInMs * NSEC_PER_MSEC),
                              frequencyInMs * NSEC_PER_MSEC, (1ull * NSEC_PER_SEC) / 10);
    FPRCPUGaugeCollector __weak *weakSelf = self;
    dispatch_source_set_event_handler(weakSelf.timerSource, ^{
      FPRCPUGaugeCollector *strongSelf = weakSelf;
      if (strongSelf) {
        [strongSelf collectMetric];
      }
    });
    dispatch_resume(self.timerSource);
    self.timerPaused = NO;
  } else {
    FPRLogDebug(kFPRCPUCollection, @"CPU metric collection is disabled.");
  }
}

- (void)collectMetric {
  FPRCPUGaugeData *gaugeMetric = fprCollectCPUMetric();
  [self.delegate cpuGaugeCollector:self gaugeData:gaugeMetric];
}

@end
