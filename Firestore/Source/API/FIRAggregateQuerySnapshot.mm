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

#import "FIRAggregateQuerySnapshot+Internal.h"

#import "FIRAggregateQuery.h"
#import "FIRQuery.h"

#import "Firestore/Source/API/FIRAggregateField+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FSTUserDataWriter.h"

#include "absl/types/optional.h"

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/model/aggregate_alias.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/util/exception.h"

using firebase::firestore::google_firestore_v1_Value;
using firebase::firestore::model::AggregateAlias;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::util::ThrowInvalidArgument;

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAggregateQuerySnapshot {
  ObjectValue _result;
  FIRAggregateQuery *_query;
}

- (instancetype)initWithObject:(ObjectValue)result query:(FIRAggregateQuery *)query {
  if (self = [super init]) {
    _result = std::move(result);
    _query = query;
  }
  return self;
}

#pragma mark - NSObject Methods

- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  auto otherSnap = static_cast<FIRAggregateQuerySnapshot *>(other);
  return _result == otherSnap->_result && [_query isEqual:otherSnap->_query];
}

- (NSUInteger)hash {
  NSUInteger result = [_query hash];
  result = 31 * result + _result.Hash();
  return result;
}

#pragma mark - Public Methods

- (NSNumber *)count {
  return (NSNumber *)[self valueForAggregation:[FIRAggregateField aggregateFieldForCount]];
}

- (FIRAggregateQuery *)query {
  return _query;
}

- (nullable id)valueForAggregation:(FIRAggregateField *)aggregation {
  FIRServerTimestampBehavior serverTimestampBehavior = FIRServerTimestampBehaviorNone;
  AggregateAlias alias = [aggregation createAlias];
  absl::optional<google_firestore_v1_Value> fieldValue = _result.Get(alias.StringValue());
  if (!fieldValue) {
    std::string path{""};
    if (aggregation.fieldPath) {
      path = [aggregation.fieldPath internalValue].CanonicalString();
    }

    ThrowInvalidArgument("'%s(%s)' was not requested in the aggregation query.", [aggregation name],
                         path);
  }
  FSTUserDataWriter *dataWriter =
      [[FSTUserDataWriter alloc] initWithFirestore:_query.query.firestore.wrapped
                           serverTimestampBehavior:serverTimestampBehavior];
  return [dataWriter convertedValue:*fieldValue];
}

@end

NS_ASSUME_NONNULL_END
