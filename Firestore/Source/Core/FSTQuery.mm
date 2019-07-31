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

#pragma mark - FSTBound

@implementation FSTBound {
  std::vector<FieldValue> _position;
}

- (instancetype)initWithPosition:(std::vector<FieldValue>)position isBefore:(bool)isBefore {
  if (self = [super init]) {
    _position = std::move(position);
    _before = isBefore;
  }
  return self;
}

+ (instancetype)boundWithPosition:(std::vector<FieldValue>)position isBefore:(bool)isBefore {
  return [[FSTBound alloc] initWithPosition:position isBefore:isBefore];
}

- (NSString *)canonicalString {
  // TODO(b/29183165): Make this collision robust.
  NSMutableString *string = [NSMutableString string];
  if (self.isBefore) {
    [string appendString:@"b:"];
  } else {
    [string appendString:@"a:"];
  }
  for (const FieldValue &component : _position) {
    [string appendFormat:@"%s", component.ToString().c_str()];
  }
  return string;
}

- (bool)sortsBeforeDocument:(FSTDocument *)document
             usingSortOrder:(const Query::OrderByList &)sortOrder {
  HARD_ASSERT(_position.size() <= sortOrder.size(),
              "FSTIndexPosition has more components than provided sort order.");
  ComparisonResult result = ComparisonResult::Same;
  for (size_t idx = 0; idx < _position.size(); ++idx) {
    const FieldValue &fieldValue = _position[idx];

    const OrderBy &sortOrderComponent = sortOrder[idx];
    ComparisonResult comparison;
    if (sortOrderComponent.field() == FieldPath::KeyFieldPath()) {
      HARD_ASSERT(fieldValue.type() == FieldValue::Type::Reference,
                  "FSTBound has a non-key value where the key path is being used %s",
                  fieldValue.ToString());
      const auto &ref = fieldValue.reference_value();
      comparison = ref.key().CompareTo(document.key);
    } else {
      absl::optional<FieldValue> docValue = [document fieldForPath:sortOrderComponent.field()];
      HARD_ASSERT(docValue.has_value(),
                  "Field should exist since document matched the orderBy already.");
      comparison = fieldValue.CompareTo(*docValue);
    }

    if (!sortOrderComponent.ascending()) {
      comparison = util::ReverseOrder(comparison);
    }

    if (!util::Same(comparison)) {
      result = comparison;
      break;
    }
  }

  return self.isBefore ? result <= ComparisonResult::Same : result < ComparisonResult::Same;
}

#pragma mark - NSObject methods

- (NSString *)description {
  return
      [NSString stringWithFormat:@"<FSTBound: position:%s before:%@>",
                                 util::ToString(_position).c_str(), self.isBefore ? @"YES" : @"NO"];
}

- (BOOL)isEqual:(NSObject *)other {
  if (self == other) {
    return YES;
  }
  if (![other isKindOfClass:[FSTBound class]]) {
    return NO;
  }

  FSTBound *otherBound = (FSTBound *)other;

  return _position == otherBound->_position && self.isBefore == otherBound.isBefore;
}

- (NSUInteger)hash {
  return util::Hash(self.position, self.isBefore);
}

- (instancetype)copyWithZone:(nullable NSZone *)zone {
  return self;
}

@end

#pragma mark - FSTQuery

@interface FSTQuery () {
  // Cached value of the canonicalID property.
  NSString *_canonicalID;

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
  return [[self alloc] initWithQuery:Query(std::move(path), std::move(collectionGroup))
                               limit:Query::kNoLimit
                             startAt:nil
                               endAt:nil];
}

- (instancetype)initWithQuery:(core::Query)query
                        limit:(int32_t)limit
                      startAt:(nullable FSTBound *)startAtBound
                        endAt:(nullable FSTBound *)endAtBound {
  if (self = [super init]) {
    _query = std::move(query);
    _limit = limit;
    _startAt = startAtBound;
    _endAt = endAtBound;
  }
  return self;
}

#pragma mark - NSObject methods

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTQuery: canonicalID:%@>", self.canonicalID];
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
  return [self.canonicalID hash];
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

- (instancetype)queryByAddingFilter:(std::shared_ptr<Filter>)filter {
  Query modified = _query.AddingFilter(std::move(filter));
  return [[FSTQuery alloc] initWithQuery:std::move(modified)
                                   limit:self.limit
                                 startAt:self.startAt
                                   endAt:self.endAt];
}

- (instancetype)queryByAddingSortOrder:(OrderBy)orderBy {
  HARD_ASSERT(![self isDocumentQuery], "No ordering is allowed for a document query.");

  // TODO(klimt): Validate that the same key isn't added twice.
  Query modified = _query.AddingOrderBy(std::move(orderBy));
  return [[FSTQuery alloc] initWithQuery:std::move(modified)
                                   limit:self.limit
                                 startAt:self.startAt
                                   endAt:self.endAt];
}

- (instancetype)queryBySettingLimit:(int32_t)limit {
  return [[FSTQuery alloc] initWithQuery:_query limit:limit startAt:self.startAt endAt:self.endAt];
}

- (instancetype)queryByAddingStartAt:(FSTBound *)bound {
  return [[FSTQuery alloc] initWithQuery:_query limit:self.limit startAt:bound endAt:self.endAt];
}

- (instancetype)queryByAddingEndAt:(FSTBound *)bound {
  return [[FSTQuery alloc] initWithQuery:_query limit:self.limit startAt:self.startAt endAt:bound];
}

- (instancetype)collectionQueryAtPath:(ResourcePath)path {
  return [[FSTQuery alloc] initWithQuery:_query.AsCollectionQueryAtPath(std::move(path))
                                   limit:self.limit
                                 startAt:self.startAt
                                   endAt:self.endAt];
}

- (BOOL)isDocumentQuery {
  return _query.IsDocumentQuery();
}

- (BOOL)isCollectionGroupQuery {
  return self.collectionGroup != nil;
}

- (BOOL)matchesDocument:(FSTDocument *)document {
  return [self pathAndCollectionGroupMatchDocument:document] &&
         [self orderByMatchesDocument:document] && [self filtersMatchDocument:document] &&
         [self boundsMatchDocument:document];
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

#pragma mark - Private properties

- (NSString *)canonicalID {
  if (_canonicalID) {
    return _canonicalID;
  }

  NSMutableString *canonicalID = [NSMutableString string];
  [canonicalID appendFormat:@"%s", self.path.CanonicalString().c_str()];

  if (self.collectionGroup) {
    [canonicalID appendFormat:@"|cg:%s", self.collectionGroup->c_str()];
  }

  // Add filters.
  [canonicalID appendString:@"|f:"];
  for (const auto &filter : self.filters) {
    [canonicalID appendFormat:@"%s", filter->CanonicalId().c_str()];
  }

  // Add order by.
  [canonicalID appendString:@"|ob:"];
  for (const OrderBy &orderBy : self.sortOrders) {
    [canonicalID appendFormat:@"%s", orderBy.CanonicalId().c_str()];
  }

  // Add limit.
  if (self.limit != Query::kNoLimit) {
    [canonicalID appendFormat:@"|l:%ld", (long)self.limit];
  }

  if (self.startAt) {
    [canonicalID appendFormat:@"|lb:%@", self.startAt.canonicalString];
  }

  if (self.endAt) {
    [canonicalID appendFormat:@"|ub:%@", self.endAt.canonicalString];
  }

  _canonicalID = canonicalID;
  return canonicalID;
}

#pragma mark - Private methods

- (BOOL)isEqualToQuery:(FSTQuery *)other {
  return _query == other->_query && self.limit == other.limit &&
         objc::Equals(self.startAt, other.startAt) && objc::Equals(self.endAt, other.endAt);
}

/* Returns YES if the document matches the path and collection group for the receiver. */
- (BOOL)pathAndCollectionGroupMatchDocument:(FSTDocument *)document {
  const ResourcePath &documentPath = document.key.path();
  if (self.collectionGroup) {
    // NOTE: self.path is currently always empty since we don't expose Collection Group queries
    // rooted at a document path yet.
    return document.key.HasCollectionId(*self.collectionGroup) &&
           self.path.IsPrefixOf(documentPath);
  } else if (DocumentKey::IsDocumentKey(self.path)) {
    // Exact match for document queries.
    return self.path == documentPath;
  } else {
    // Shallow ancestor queries by default.
    return self.path.IsPrefixOf(documentPath) && self.path.size() == documentPath.size() - 1;
  }
}

/**
 * A document must have a value for every ordering clause in order to show up in the results.
 */
- (BOOL)orderByMatchesDocument:(FSTDocument *)document {
  for (const OrderBy &orderBy : self.explicitSortOrders) {
    const FieldPath &fieldPath = orderBy.field();
    // order by key always matches
    if (fieldPath != FieldPath::KeyFieldPath() &&
        [document fieldForPath:fieldPath] == absl::nullopt) {
      return NO;
    }
  }
  return YES;
}

/** Returns YES if the document matches all of the filters in the receiver. */
- (BOOL)filtersMatchDocument:(FSTDocument *)document {
  Document converted(document);

  for (const auto &filter : self.filters) {
    if (!filter->Matches(converted)) {
      return NO;
    }
  }
  return YES;
}

- (BOOL)boundsMatchDocument:(FSTDocument *)document {
  if (self.startAt && ![self.startAt sortsBeforeDocument:document usingSortOrder:self.sortOrders]) {
    return NO;
  }
  if (self.endAt && [self.endAt sortsBeforeDocument:document usingSortOrder:self.sortOrders]) {
    return NO;
  }
  return YES;
}

@end

NS_ASSUME_NONNULL_END
