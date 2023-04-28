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

NS_ASSUME_NONNULL_BEGIN

@class FIRAggregateQuery;

/**
 * The results of executing an `AggregateQuery`.
 */
NS_SWIFT_NAME(AggregateQuerySnapshot)
@interface FIRAggregateQuerySnapshot : NSObject

/** :nodoc: */
- (instancetype)init
    __attribute__((unavailable("FIRAggregateQuerySnapshot cannot be created directly.")));

/** The query that was executed to produce this result. */
@property(nonatomic, readonly) FIRAggregateQuery* query;

/** The number of documents in the result set of the underlying query. */
@property(nonatomic, readonly) NSNumber* count;

@end

NS_ASSUME_NONNULL_END
