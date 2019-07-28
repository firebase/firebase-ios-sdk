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

#import "Firestore/Source/Core/FSTQuery.h"

#include <limits>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Util/FSTClasses.h"

#include "Firestore/core/src/firebase/firestore/api/input_validation.h"
#include "Firestore/core/src/firebase/firestore/core/bound.h"
#include "Firestore/core/src/firebase/firestore/core/direction.h"
#include "Firestore/core/src/firebase/firestore/core/field_filter.h"
#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/order_by.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/objc/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/util/comparison.h"
#include "Firestore/core/src/firebase/firestore/util/equality.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/algorithm/container.h"

namespace core = firebase::firestore::core;
namespace objc = firebase::firestore::objc;
namespace util = firebase::firestore::util;
using firebase::firestore::api::ThrowInvalidArgument;
using firebase::firestore::core::Bound;
using firebase::firestore::core::Direction;
using firebase::firestore::core::Filter;
using firebase::firestore::core::OrderBy;
using firebase::firestore::core::Query;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentComparator;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::util::ComparisonResult;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTQuery

@interface FSTQuery () {
  // The C++ implementation of this query to which FSTQuery delegates.
  Query _query;
}

@end

@implementation FSTQuery

#pragma mark - Constructors

+ (instancetype)queryWithPath:(ResourcePath)path {
  return [FSTQuery queryWithPath:std::move(path) collectionGroup:nullptr];
}

+ (instancetype)queryWithPath:(ResourcePath)path
              collectionGroup:(std::shared_ptr<const std::string>)collectionGroup {
  return [[self alloc] initWithQuery:Query(std::move(path), std::move(collectionGroup))];
}

- (instancetype)initWithQuery:(core::Query)query {
  if (self = [super init]) {
    _query = std::move(query);
  }
  return self;
}

#pragma mark - NSObject methods

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTQuery: canonicalID:%s>", self.canonicalID.c_str()];
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FSTQuery class]]) {
    return NO;
  }
  return [self isEqualToQuery:(FSTQuery *)object];
}

- (NSUInteger)hash {
  return util::Hash(self.canonicalID);
}

- (instancetype)copyWithZone:(nullable NSZone *)zone {
  return self;
}

#pragma mark - Public methods

- (const Query::FilterList &)filters {
  return _query.filters();
}

- (const core::Query::OrderByList &)explicitSortOrders {
  return _query.explicit_order_bys();
}

- (const Query::OrderByList &)sortOrders {
  return _query.order_bys();
}

- (int32_t)limit {
  return _query.limit();
}

- (const std::shared_ptr<Bound> &)startAt {
  return _query.start_at();
}

- (const std::shared_ptr<Bound> &)endAt {
  return _query.end_at();
}

- (instancetype)queryByAddingFilter:(std::shared_ptr<Filter>)filter {
  Query modified = _query.AddingFilter(std::move(filter));
  return [[FSTQuery alloc] initWithQuery:std::move(modified)];
}

- (instancetype)queryByAddingSortOrder:(OrderBy)orderBy {
  HARD_ASSERT(![self isDocumentQuery], "No ordering is allowed for a document query.");

  // TODO(klimt): Validate that the same key isn't added twice.
  Query modified = _query.AddingOrderBy(std::move(orderBy));
  return [[FSTQuery alloc] initWithQuery:std::move(modified)];
}

- (instancetype)queryBySettingLimit:(int32_t)limit {
  return [[FSTQuery alloc] initWithQuery:_query.WithLimit(limit)];
}

- (instancetype)queryByAddingStartAt:(Bound)bound {
  return [[FSTQuery alloc] initWithQuery:_query.StartingAt(std::move(bound))];
}

- (instancetype)queryByAddingEndAt:(Bound)bound {
  return [[FSTQuery alloc] initWithQuery:_query.EndingAt(std::move(bound))];
}

- (instancetype)collectionQueryAtPath:(ResourcePath)path {
  return [[FSTQuery alloc] initWithQuery:_query.AsCollectionQueryAtPath(std::move(path))];
}

- (BOOL)isDocumentQuery {
  return _query.IsDocumentQuery();
}

- (BOOL)isCollectionGroupQuery {
  return self.collectionGroup != nil;
}

- (BOOL)matchesDocument:(FSTDocument *)document {
  Document converted(document);
  return _query.Matches(converted);
}

- (DocumentComparator)comparator {
  Query::OrderByList sortOrders = self.sortOrders;

  return DocumentComparator([sortOrders](FSTDocument *document1, FSTDocument *document2) {
    bool didCompareOnKeyField = false;
    Document convertedDoc1(document1);
    Document converetdDoc2(document2);
    for (const OrderBy &orderBy : sortOrders) {
      ComparisonResult comp = orderBy.Compare(convertedDoc1, converetdDoc2);
      if (!util::Same(comp)) return comp;

      didCompareOnKeyField = didCompareOnKeyField || orderBy.field() == FieldPath::KeyFieldPath();
    }
    HARD_ASSERT(didCompareOnKeyField, "sortOrder of query did not include key ordering");
    return ComparisonResult::Same;
  });
}

- (nullable const FieldPath *)inequalityFilterField {
  return _query.InequalityFilterField();
}

- (BOOL)hasArrayContainsFilter {
  return _query.HasArrayContainsFilter();
}

- (nullable const FieldPath *)firstSortOrderField {
  return _query.FirstOrderByField();
}

/** The base path of the query. */
- (const ResourcePath &)path {
  return _query.path();
}

- (const std::shared_ptr<const std::string> &)collectionGroup {
  return _query.collection_group();
}

- (const std::string &)canonicalID {
  return _query.CanonicalId();
}

#pragma mark - Private methods

- (BOOL)isEqualToQuery:(FSTQuery *)other {
  return _query == other->_query;
}

@end

NS_ASSUME_NONNULL_END
