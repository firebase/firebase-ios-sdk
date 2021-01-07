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

#import "FirebasePerformance/Sources/Loggers/FPRGDTRateLimiter.h"

#import <UIKit/UIKit.h>

#import "FirebasePerformance/Sources/Common/FPRPerfDate.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Extension that is added on top of the class FPRGDTRateLimiter to make the
 * private methods visible between the implementation file and the unit tests.
 */
@interface FPRGDTRateLimiter ()

/**
 * Number of events that are allowed per minute. This is an internal variable used only for unit
 * testing.
 */
@property(nonatomic) CGFloat overrideRate;

/**
 * Number of network events that are allowed per minute. This is an internal variable used only for
 * unit testing.
 */
@property(nonatomic) CGFloat overrideNetworkRate;

/** Number of trace events that can be sent in burst per minute. */
@property(nonatomic) NSInteger traceEventBurstSize;

/** Number of network events that can be sent in burst per minute. */
@property(nonatomic) NSInteger networkEventburstSize;

/** Total number of trace events that are allowed to be sent . */
@property(nonatomic) NSInteger allowedTraceEventsCount;

/** Number of network events that are allowed to be sent . */
@property(nonatomic) NSInteger allowedNetworkEventsCount;

/** Time at which the last trace event was sent. */
@property(nonatomic) NSDate *lastTraceEventTime;

/** Time at which the last network event was sent. */
@property(nonatomic) NSDate *lastNetworkEventTime;

/** @brief Override configurations. */
@property(nonatomic) FPRConfigurations *configurations;

/**
 * Creates an instance of the FPRGDTRateLimiter with the defined date.
 *
 * @param date The date object used for time calculations.
 * @return An instance of the rate limiter.
 */
- (instancetype)initWithDate:(id<FPRDate>)date;

@end

NS_ASSUME_NONNULL_END
