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
#import "FirebasePerformance/Sources/Protogen/nanopb/perf_metric.nanopb.h"

NS_ASSUME_NONNULL_BEGIN

/** Logger used to dispatch events to Google Data Transport layer. */
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
@interface FPRGDTLogger : NSObject

/** Log source initialized against. */
@property(nonatomic, readonly) NSInteger logSource;

/** Default initializer. */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Instantiates an instance of this class.
 *
 * @param logSource The log source for this logger to be used.
 * @return Instance of FPRGDTLogger.
 */
- (instancetype)initWithLogSource:(NSInteger)logSource NS_DESIGNATED_INITIALIZER;

/**
 * Logs an event that needs to be dispatched.
 *
 * @remark Events are logged/dispatched asynchronously using a serial dispatch queue.
 * @param event The event to log.
 */
- (void)logEvent:(firebase_perf_v1_PerfMetric)event;

@end

NS_ASSUME_NONNULL_END
