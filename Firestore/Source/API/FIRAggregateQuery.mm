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

#import <string>

#import "FIRAggregateQuery+Internal.h"

#import "FIRAggregateField+Internal.h"
#import "FIRAggregateQuerySnapshot+Internal.h"
#import "FIRQuery+Internal.h"
#import "FIRFieldPath+Internal.h"

#include "Firestore/core/src/api/aggregate_query.h"
#include "Firestore/core/src/api/query_core.h"
#include "Firestore/core/src/util/error_apple.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/model/aggregate_field.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FIRAggregateQuery

@implementation FIRAggregateQuery {
  FIRQuery *_query;
  NSArray<FIRAggregateField *> *_aggregations;
  std::vector<model::AggregateField *> _aggregateFields;
  std::unique_ptr<api::AggregateQuery> _aggregation;
}

- (instancetype)initWithQueryAndAggregations:(FIRQuery *)query
                                aggregations:(NSArray<FIRAggregateField *> *)aggregations {
  if (self = [super init]) {
    _query = query;

    for (FIRAggregateField *firField in aggregations) {
      if ([firField isKindOfClass:[FSTSumAggregateField class]]) {
        auto fieldPath = firField.fieldPath.internalValue;
        _aggregateFields.push_back(std::unique_ptr<model::SumAggregateField>(model::AggregateAlias(std::string{"TODO"s}), fieldPath));
      } else if ([firField isKindOfClass:[FSTAverageAggregateField class]]) {
        auto fieldPath = firField.fieldPath.internalValue;
        _aggregateFields.push_back(std::unique_ptr<model::AverageAggregateField>(model::AggregateAlias(std::string{"TODO"s}), fieldPath));
      } else if ([firField isKindOfClass:[FSTCountAggregateField class]]) {
        _aggregateFields.push_back(std::unique_ptr<model::CountAggregateField>(model::AggregateAlias(std::string{"TODO"s})));
      } else {
        // todo fail
      }
    }

    _aggregation = absl::make_unique<api::AggregateQuery>(query.apiQuery.Count());
  }
  return self;
}

#pragma mark - NSObject Methods

- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  auto otherQuery = static_cast<FIRAggregateQuery *>(other);
  return [_query isEqual:otherQuery->_query];
}

- (NSUInteger)hash {
  return [_query hash];
}

#pragma mark - Public Methods

- (FIRQuery *)query {
  return _query;
}

- (void)aggregationWithSource:(FIRAggregateSource)source
                   completion:(void (^)(FIRAggregateQuerySnapshot *_Nullable snapshot,
                                        NSError *_Nullable error))completion {

  _aggregation->Get([self, completion](const firebase::firestore::util::StatusOr<int64_t> &result) {
    if (result.ok()) {
      completion([[FIRAggregateQuerySnapshot alloc] initWithCount:result.ValueOrDie() query:self],
                 nil);
    } else {
      completion(nil, MakeNSError(result.status()));
    }
  });
}

@end

NS_ASSUME_NONNULL_END
