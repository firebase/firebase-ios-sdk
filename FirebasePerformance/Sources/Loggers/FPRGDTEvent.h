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

#import <GoogleDataTransport/GoogleDataTransport.h>
#import "FirebasePerformance/Sources/Protogen/nanopb/perf_metric.nanopb.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Google Data Transport event wrapper used for converting Fireperf nanopb object to
 * GDTEvent object.
 */
@interface FPRGDTEvent : NSObject <GDTCOREventDataObject>

/** firebase_perf_v1_PerfMetric that is going to be converted. */
@property(nonatomic, readonly) firebase_perf_v1_PerfMetric metric;

- (instancetype)init NS_UNAVAILABLE;

/** Converts a firebase_perf_v1_PerfMetric object to a GDTEvent. */
+ (instancetype)gdtEventForPerfMetric:(firebase_perf_v1_PerfMetric)perfMetric;

@end

NS_ASSUME_NONNULL_END
