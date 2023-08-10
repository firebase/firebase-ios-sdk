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

#import "FIRAggregateQuery+Internal.h"

#import "Firestore/Source/API/FIRAggregateField+Internal.h"
#import "Firestore/Source/API/FIRAggregateQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"

#include "Firestore/core/src/api/aggregate_query.h"
#include "Firestore/core/src/util/error_apple.h"

using firebase::firestore::api::AggregateQuery;
using firebase::firestore::model::AggregateField;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::util::StatusOr;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FIRAggregateQuery

@implementation FIRAggregateQuery {
  FIRQuery *_query;
  std::unique_ptr<AggregateQuery> _aggregateQuery;
}

- (instancetype)initWithQuery:(FIRQuery *)query
              aggregateFields:(NSArray<FIRAggregateField *> *)aggregateFields {
  if (self = [super init]) {
    _query = query;

    std::vector<AggregateField> _aggregateFields;
    for (FIRAggregateField *field in aggregateFields) {
      _aggregateFields.push_back([field createInternalValue]);
    }

    _aggregateQuery =
        absl::make_unique<AggregateQuery>(query.apiQuery.Aggregate(std::move(_aggregateFields)));
  }
  return self;
}

#pragma mark - NSObject Methods

- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  auto otherQuery = static_cast<FIRAggregateQuery *>(other);
  return [_query isEqual:otherQuery->_query] && *_aggregateQuery == *(otherQuery->_aggregateQuery);
}

- (NSUInteger)hash {
  return _aggregateQuery->Hash();
}

#pragma mark - Public Methods

- (FIRQuery *)query {
  return _query;
}

- (void)aggregationWithSource:(FIRAggregateSource)source
                   completion:(void (^)(FIRAggregateQuerySnapshot *_Nullable snapshot,
                                        NSError *_Nullable error))completion {
  _aggregateQuery->GetAggregate([self, completion](const StatusOr<ObjectValue> &result) {
    if (result.ok()) {
      completion([[FIRAggregateQuerySnapshot alloc] initWithObject:result.ValueOrDie() query:self],
                 nil);
    } else {
      completion(nil, MakeNSError(result.status()));
    }
  });
}

@end

NS_ASSUME_NONNULL_END
