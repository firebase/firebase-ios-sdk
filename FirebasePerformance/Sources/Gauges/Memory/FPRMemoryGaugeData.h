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
 * Class that contains memory gauge information for any point in time.
 */
@interface FPRMemoryGaugeData : NSObject

/** @brief Time at which memory data was measured. */
@property(nonatomic, readonly) NSDate *collectionTime;

/** @brief Heap memory that is used. */
@property(nonatomic, readonly) u_long heapUsed;

/** @brief Heap memory that is available. */
@property(nonatomic, readonly) u_long heapAvailable;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Creates an instance of memory gauge data with the provided information.
 *
 * @param collectionTime Time at which the gauge data was collected.
 * @param heapUsed Heap memory that is used.
 * @param heapAvailable Heap memory that is available.
 * @return Instance of memory gauge data.
 */
- (instancetype)initWithCollectionTime:(NSDate *)collectionTime
                              heapUsed:(u_long)heapUsed
                         heapAvailable:(u_long)heapAvailable NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
