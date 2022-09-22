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

@class FIRAggregateQuery;

/**
 * An `AggregateQuerySnapshot` contains results of a `AggregateQuery`.
 */
NS_SWIFT_NAME(AggregateQuerySnapshot)
@interface FIRAggregateQuerySnapshot : NSObject

/** The original `AggregateQuery` this snapshot is a result of. */
@property(nonatomic, readonly) FIRAggregateQuery* _Nonnull query;

/**
 * The result of a document count aggregation. Null if no count aggregation is
 *     available in the result.
 */
@property(nonatomic, readonly) NSNumber* _Nullable count;

@end
