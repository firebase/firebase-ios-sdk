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

#import "FirebasePerformance/Sources/Loggers/FPRGDTLogSampler.h"

#import <GoogleDataTransport/GoogleDataTransport.h>

#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager.h"
#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/FPRConsoleLogger.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTEvent.h"

@class FPRGDTEvent;

@interface FPRGDTLogSampler ()

/** Configuration flags that are used for sampling. */
@property(nonatomic, readonly) FPRConfigurations *flags;

/** Vendor identifier used as the random seed for sampling. */
@property(nonatomic, readonly) double samplingBucketId;

@end

@implementation FPRGDTLogSampler

- (instancetype)init {
  double randomNumberBetween0And1 = ((double)arc4random() / UINT_MAX);
  return [self initWithFlags:[FPRConfigurations sharedInstance]
           samplingThreshold:randomNumberBetween0And1];
}

- (instancetype)initWithFlags:(FPRConfigurations *)flags samplingThreshold:(double)bucket {
  self = [super init];
  if (self) {
    _flags = flags;

    _samplingBucketId = bucket;
    if (bucket > 1 || bucket < 0.0) {
      _samplingBucketId = 1.0;
    }
  }
  return self;
}

/**
 * Samples PerfMetric Events based on sampling logic, event that should be
 * dropped will return nil in this transformer.
 *
 * @param event The event to be evaluated by sampling logic.
 * @return A transformed event, or nil if the transformation dropped the event.
 */
- (GDTCOREvent *)transformGDTEvent:(GDTCOREvent *)event {
  // An event is sampled means that the event is dropped.

  // If the current active session is verbose, do not sample any event.
  if (![event.dataObject isKindOfClass:[FPRGDTEvent class]]) {
    return event;
  }

  FPRGDTEvent *gdtEvent = (FPRGDTEvent *)event.dataObject;
  firebase_perf_v1_PerfMetric perfMetric = gdtEvent.metric;

  // If it is a gaugeEvent, do not sample.
  if (perfMetric.has_gauge_metric) {
    return event;
  }

  // If the traceMetric contains a verbose session, do not sample.
  if (perfMetric.has_trace_metric) {
    firebase_perf_v1_TraceMetric traceMetric = perfMetric.trace_metric;
    // Sessions are ordered so that the first session is the most verbose one.
    if (traceMetric.perf_sessions_count > 0) {
      firebase_perf_v1_PerfSession firstSession = traceMetric.perf_sessions[0];
      if (firstSession.session_verbosity_count > 0) {
        firebase_perf_v1_SessionVerbosity firstVerbosity = firstSession.session_verbosity[0];
        if (firstVerbosity == firebase_perf_v1_SessionVerbosity_GAUGES_AND_SYSTEM_EVENTS) {
          return event;
        }
      }
    }
  }

  // If the networkMetric contains a verbose session, do not sample.
  if (perfMetric.has_network_request_metric) {
    firebase_perf_v1_NetworkRequestMetric networkMetric = perfMetric.network_request_metric;
    // Sessions are ordered so that the first session is the most verbose one.
    if (networkMetric.perf_sessions_count > 0) {
      firebase_perf_v1_PerfSession firstSession = networkMetric.perf_sessions[0];
      if (firstSession.session_verbosity_count > 0) {
        firebase_perf_v1_SessionVerbosity firstVerbosity = firstSession.session_verbosity[0];
        if (firstVerbosity == firebase_perf_v1_SessionVerbosity_GAUGES_AND_SYSTEM_EVENTS) {
          return event;
        }
      }
    }
  }

  if ([self shouldDropEvent:perfMetric]) {
    return nil;
  }

  return event;
}

/**
 * Determines if the log should be dropped based on sampling configuration from remote
 * configuration.
 *
 * @param event The event on which the decision would be made.
 * @return Boolean value of YES if the log should be dropped/sampled out. Otherwise, NO.
 */
- (BOOL)shouldDropEvent:(firebase_perf_v1_PerfMetric)event {
  // Find the correct sampling rate and make the decision to drop or log the event.
  float samplingRate = [self.flags logTraceSamplingRate];
  if (event.has_network_request_metric) {
    samplingRate = [self.flags logNetworkSamplingRate];
  }

  return self.samplingBucketId >= samplingRate;
}

@end
