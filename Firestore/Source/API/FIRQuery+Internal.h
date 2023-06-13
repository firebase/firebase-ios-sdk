/*
 * Copyright 2017 Google
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

#import "FIRAggregateField.h"
#import "FIRQuery.h"

#include <memory>

#include "Firestore/core/src/api/api_fwd.h"
#include "Firestore/core/src/core/core_fwd.h"

@class FIRFilter;

namespace api = firebase::firestore::api;
namespace core = firebase::firestore::core;

NS_ASSUME_NONNULL_BEGIN

@interface FIRQuery (/* Init */)

- (instancetype)initWithQuery:(api::Query &&)query NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithQuery:(core::Query)query
                    firestore:(std::shared_ptr<api::Firestore>)firestore;

@end

/** Internal FIRQuery API we don't want exposed in our public header files. */
@interface FIRQuery (Internal)

- (const core::Query &)query;

- (const api::Query &)apiQuery;

@end

// TODO(sum/avg) move the contents of this FuturePublicApi category to
// ../Public/FirebaseFirestore/FIRAggregateQuerySnapshot.h
@interface FIRQuery (FuturePublicApi)

/**
 * Creates and returns a new `AggregateQuery` that aggregates the documents in the result set
 * of this query, without actually downloading the documents.
 *
 * Using an `AggregateQuery` to perform aggregations is efficient because only the final aggregation
 * values, not the documents' data, is downloaded. The query can even aggregate the documents if the
 * result set would be prohibitively large to download entirely (e.g. thousands of documents).
 *
 * @param aggregations Specifies the aggregation operations to perform on the result set of this
 * query.
 *
 * @return An `AggregateQuery` encapsulating this `Query` and `AggregateField`s, which can be used
 * to query the server for the aggregation results.
 */
- (FIRAggregateQuery *)aggregate:(NSArray<FIRAggregateField *> *)aggregations
    NS_SWIFT_NAME(aggregate(_:));

@end

NS_ASSUME_NONNULL_END
