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

NS_ASSUME_NONNULL_BEGIN

/**
 * Class that contains CPU gauge information for any point in time.
 */
@interface FPRCPUGaugeData : NSObject

/** @brief Time which which CPU data was measured. */
@property(nonatomic, readonly) NSDate *collectionTime;

/** @brief CPU system time used in microseconds. */
@property(nonatomic, readonly) uint64_t systemTime;

/** @brief CPU user time used in microseconds. */
@property(nonatomic, readonly) uint64_t userTime;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Creates an instance of CPU gauge data with the provided information.
 *
 * @param collectionTime Time at which the gauge data was collected.
 * @param systemTime CPU system time in microseconds.
 * @param userTime CPU user time in microseconds.
 * @return Instance of CPU gauge data.
 */
- (instancetype)initWithCollectionTime:(NSDate *)collectionTime
                            systemTime:(uint64_t)systemTime
                              userTime:(uint64_t)userTime NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
