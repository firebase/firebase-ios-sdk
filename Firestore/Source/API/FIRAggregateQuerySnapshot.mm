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
#import "Firestore/Source/API/FSTUserDataWriter.h"

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/api/document_snapshot.h"
#include "Firestore/core/src/model/field_path.h"

using firebase::firestore::google_firestore_v1_Value;
using firebase::firestore::api::DocumentSnapshot;
using firebase::firestore::model::FieldPath;

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAggregateQuerySnapshot {
  DocumentSnapshot _snapshot;
  FIRAggregateQuery* _query;
}

- (instancetype)initWithSnapshot:(api::DocumentSnapshot &&)snapshot query:(FIRAggregateQuery*)query {
  if (self = [super init]) {
    _snapshot = std::move(snapshot);
    _query = query;
  }
  return self;
}

#pragma mark - NSObject Methods

- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  auto otherSnap = static_cast<FIRAggregateQuerySnapshot*>(other);
  return _result == otherSnap->_result && [_query isEqual:otherSnap->_query];
}

- (NSUInteger)hash {
  NSUInteger result = [_query hash];
  result = 31 * result + [[self count] hash];
  return result;
}

#pragma mark - Public Methods

- (NSNumber*)count {
  return [NSNumber numberWithLongLong:_result];
}

- (FIRAggregateQuery*)query {
  return _query;
}

- (nullable id)valueForAggregationX:(FIRAggregateField*)aggregation NS_SWIFT_NAME(get(_:)) {
  // TODO(sumavg) implement this method
  aggregation.
        return [NSNumber numberWithDouble:100.5];
}


- (nullable id)valueForAggregation:(FIRAggregateField*)aggregation NS_SWIFT_NAME(get(_:)) {
  return [self valueForAggregation:aggregation serverTimestampBehavior:FIRServerTimestampBehaviorNone];
}

- (nullable id)valueForAggregation:(FIRAggregateField*)aggregation
           serverTimestampBehavior:(FIRServerTimestampBehavior)serverTimestampBehavior {

  absl::optional<google_firestore_v1_Value> fieldValue = _snapshot.GetValue(aggregation);
  if (!fieldValue) return nil;
  FSTUserDataWriter *dataWriter =
      [[FSTUserDataWriter alloc] initWithFirestore:_snapshot.firestore()
                           serverTimestampBehavior:serverTimestampBehavior];
  return [dataWriter convertedValue:*fieldValue];
}

@end

NS_ASSUME_NONNULL_END
