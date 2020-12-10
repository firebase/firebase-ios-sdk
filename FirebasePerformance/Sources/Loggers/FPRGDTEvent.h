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

#import "GoogleDataTransport/GDTCORLibrary/Internal/GoogleDataTransportInternal.h"

NS_ASSUME_NONNULL_BEGIN

@class FPRMSGPerfMetric;

/**
 * Google Data Transport event wrapper used for converting Fireperf Proto object to
 * GDTEvent object.
 */
@interface FPRGDTEvent : NSObject <GDTCOREventDataObject>

/** Perf metric that is going to be converted. */
@property(nonatomic, readonly) FPRMSGPerfMetric *metric;

- (instancetype)init NS_UNAVAILABLE;

/** Converts a PerfMetric event to a GDTEvent. */
+ (instancetype)gdtEventForPerfMetric:(FPRMSGPerfMetric *)perfMetric;

@end

NS_ASSUME_NONNULL_END
