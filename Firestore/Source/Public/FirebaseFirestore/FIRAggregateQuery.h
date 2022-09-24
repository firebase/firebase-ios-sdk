/*
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

#import "FIRAggregateSource.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRQuery;
@class FIRAggregateQuerySnapshot;

/**
 * A query that calculates aggregations over an underlying query.
 */
NS_SWIFT_NAME(AggregateQuery)
@interface FIRAggregateQuery : NSObject

/** :nodoc: */
- (instancetype)init __attribute__((unavailable("FIRAggregateQuery cannot be created directly.")));

/** The query whose aggregations will be calculated by this object. */
@property(nonatomic, readonly) FIRQuery *query;

/**
 * Executes this query.
 *
 * @param source The source from which to acquire the aggregate results.
 * @param completion a block to execute once the results have been successfully read.
 *     snapshot will be `nil` only if error is `non-nil`.
 */
- (void)aggregationWithSource:(FIRAggregateSource)source
                   completion:(void (^)(FIRAggregateQuerySnapshot *_Nullable snapshot,
                                        NSError *_Nullable error))completion
    NS_SWIFT_NAME(getAggregation(source:completion:));
@end

NS_ASSUME_NONNULL_END
