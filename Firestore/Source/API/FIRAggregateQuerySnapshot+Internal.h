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

#import "FIRAggregateQuerySnapshot.h"

#import "FIRAggregateField.h"
#import "FIRDocumentSnapshot.h"

#include "Firestore/core/src/api/api_fwd.h"

@class FIRAggregateQuery;

namespace model = firebase::firestore::model;

NS_ASSUME_NONNULL_BEGIN

@interface FIRAggregateQuerySnapshot (/* init */)

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithObject:(model::ObjectValue)result
                         query:(FIRAggregateQuery *)query NS_DESIGNATED_INITIALIZER;

@end

// TODO(sum/avg) move the contents of this FuturePublicApi category to
// ../Public/FirebaseFirestore/FIRAggregateQuerySnapshot.h
@interface FIRAggregateQuerySnapshot (FuturePublicApi)

/**
 * Gets the aggregation result for the specified aggregation without loss of precision. No coercion
 * of data types or values is performed.
 *
 * See the `AggregateField` class for the expected aggregration result values and types. Numeric
 * aggregation results will be boxed in an `NSNumber`.
 *
 * @param aggregation An instance of `AggregateField` that specifies which aggregation result to
 * return.
 * @return Returns the aggregation result from the server without loss of precision.
 * @warning Throws an `InvalidArgument` exception if the aggregation was not requested in the
 * `AggregateQuery`.
 * @see `AggregateField`
 */
- (nullable id)valueForAggregation:(FIRAggregateField *)aggregation NS_SWIFT_NAME(get(_:));

@end

NS_ASSUME_NONNULL_END
