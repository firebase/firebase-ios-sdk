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
#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/nan_filter.h"
#include "Firestore/core/src/firebase/firestore/core/null_filter.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/core/relation_filter.h"
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
using firebase::firestore::core::Filter;
using firebase::firestore::core::Query;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentComparator;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::util::ComparisonResult;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTSortOrder

@interface FSTSortOrder () {
  /** The field to sort by. */
  FieldPath _field;
}

/** Creates a new sort order with the given field and direction. */
- (instancetype)initWithFieldPath:(FieldPath)fieldPath ascending:(BOOL)ascending;

- (NSString *)canonicalID;

@end

@implementation FSTSortOrder

#pragma mark - Constructor methods

+ (instancetype)sortOrderWithFieldPath:(FieldPath)fieldPath ascending:(BOOL)ascending {
  return [[FSTSortOrder alloc] initWithFieldPath:std::move(fieldPath) ascending:ascending];
}

- (instancetype)initWithFieldPath:(FieldPath)fieldPath ascending:(BOOL)ascending {
  self = [super init];
  if (self) {
    _field = std::move(fieldPath);
    _ascending = ascending;
  }
  return self;
}

- (const FieldPath &)field {
  return _field;
}

#pragma mark - Public methods

- (ComparisonResult)compareDocument:(FSTDocument *)document1 toDocument:(FSTDocument *)document2 {
  ComparisonResult result;
  if (_field == FieldPath::KeyFieldPath()) {
    result = util::Compare(document1.key, document2.key);
  } else {
    absl::optional<FieldValue> value1 = [document1 fieldForPath:self.field];
    absl::optional<FieldValue> value2 = [document2 fieldForPath:self.field];
    HARD_ASSERT(value1.has_value() && value2.has_value(),
                "Trying to compare documents on fields that don't exist.");
    result = value1->CompareTo(*value2);
  }
  if (!self.isAscending) {
    result = util::ReverseOrder(result);
  }
  return result;
}

- (NSString *)canonicalID {
  return [NSString stringWithFormat:@"%s%@", _field.CanonicalString().c_str(),
                                    self.isAscending ? @"asc" : @"desc"];
}

- (BOOL)isEqualToSortOrder:(FSTSortOrder *)other {
  return _field == other->_field && self.isAscending == other.isAscending;
}

#pragma mark - NSObject methods

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTSortOrder: path:%s dir:%@>",
                                    _field.CanonicalString().c_str(),
                                    self.ascending ? @"asc" : @"desc"];
}

- (BOOL)isEqual:(NSObject *)other {
  if (self == other) {
    return YES;
  }
  if (![other isKindOfClass:[FSTSortOrder class]]) {
    return NO;
  }
  return [self isEqualToSortOrder:(FSTSortOrder *)other];
}

- (NSUInteger)hash {
  return [self.canonicalID hash];
}

- (instancetype)copyWithZone:(nullable NSZone *)zone {
  return self;
}

@end

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
             usingSortOrder:(NSArray<FSTSortOrder *> *)sortOrder {
  HARD_ASSERT(_position.size() <= sortOrder.count,
              "FSTIndexPosition has more components than provided sort order.");
  ComparisonResult result = ComparisonResult::Same;
  for (size_t idx = 0; idx < _position.size(); ++idx) {
    const FieldValue &fieldValue = _position[idx];

    FSTSortOrder *sortOrderComponent = sortOrder[idx];
    ComparisonResult comparison;
    if (sortOrderComponent.field == FieldPath::KeyFieldPath()) {
      HARD_ASSERT(fieldValue.type() == FieldValue::Type::Reference,
                  "FSTBound has a non-key value where the key path is being used %s",
                  fieldValue.ToString());
      const auto &ref = fieldValue.reference_value();
      comparison = ref.key().CompareTo(document.key);
    } else {
      absl::optional<FieldValue> docValue = [document fieldForPath:sortOrderComponent.field];
      HARD_ASSERT(docValue.has_value(),
                  "Field should exist since document matched the orderBy already.");
      comparison = fieldValue.CompareTo(*docValue);
    }

    if (!sortOrderComponent.isAscending) {
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

/** A list of fields given to sort by. This does not include the implicit key sort at the end. */
@property(nonatomic, strong, readonly) NSArray<FSTSortOrder *> *explicitSortOrders;

/** The memoized list of sort orders */
@property(nonatomic, nullable, strong, readwrite) NSArray<FSTSortOrder *> *memoizedSortOrders;

@end

@implementation FSTQuery

#pragma mark - Constructors

+ (instancetype)queryWithPath:(ResourcePath)path {
  return [FSTQuery queryWithPath:std::move(path) collectionGroup:nullptr];
}

+ (instancetype)queryWithPath:(ResourcePath)path
              collectionGroup:(std::shared_ptr<const std::string>)collectionGroup {
  return [[self alloc] initWithQuery:Query(std::move(path), std::move(collectionGroup))
                             orderBy:@[]
                               limit:Query::kNoLimit
                             startAt:nil
                               endAt:nil];
}

- (instancetype)initWithQuery:(core::Query)query
                      orderBy:(NSArray<FSTSortOrder *> *)sortOrders
                        limit:(int32_t)limit
                      startAt:(nullable FSTBound *)startAtBound
                        endAt:(nullable FSTBound *)endAtBound {
  if (self = [super init]) {
    _query = std::move(query);
    _explicitSortOrders = sortOrders;
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

- (NSArray *)sortOrders {
  if (self.memoizedSortOrders == nil) {
    const FieldPath *inequalityField = [self inequalityFilterField];
    const FieldPath *firstSortOrderField = [self firstSortOrderField];
    if (inequalityField && !firstSortOrderField) {
      // In order to implicitly add key ordering, we must also add the inequality filter field for
      // it to be a valid query. Note that the default inequality field and key ordering is
      // ascending.
      if (inequalityField->IsKeyFieldPath()) {
        self.memoizedSortOrders = @[ [FSTSortOrder sortOrderWithFieldPath:FieldPath::KeyFieldPath()
                                                                ascending:YES] ];
      } else {
        self.memoizedSortOrders = @[
          [FSTSortOrder sortOrderWithFieldPath:*inequalityField ascending:YES],
          [FSTSortOrder sortOrderWithFieldPath:FieldPath::KeyFieldPath() ascending:YES]
        ];
      }
    } else {
      HARD_ASSERT(!inequalityField || *inequalityField == *firstSortOrderField,
                  "First orderBy %s should match inequality field %s.",
                  firstSortOrderField->CanonicalString(), inequalityField->CanonicalString());

      __block BOOL foundKeyOrder = NO;

      NSMutableArray *result = [NSMutableArray array];
      for (FSTSortOrder *sortOrder in self.explicitSortOrders) {
        [result addObject:sortOrder];
        if (sortOrder.field == FieldPath::KeyFieldPath()) {
          foundKeyOrder = YES;
        }
      }

      if (!foundKeyOrder) {
        // The direction of the implicit key ordering always matches the direction of the last
        // explicit sort order
        BOOL lastIsAscending =
            self.explicitSortOrders.count > 0 ? self.explicitSortOrders.lastObject.ascending : YES;
        [result addObject:[FSTSortOrder sortOrderWithFieldPath:FieldPath::KeyFieldPath()
                                                     ascending:lastIsAscending]];
      }

      self.memoizedSortOrders = result;
    }
  }
  return self.memoizedSortOrders;
}

- (instancetype)queryByAddingFilter:(std::shared_ptr<Filter>)filter {
  return [[FSTQuery alloc] initWithQuery:_query.Filter(std::move(filter))
                                 orderBy:self.explicitSortOrders
                                   limit:self.limit
                                 startAt:self.startAt
                                   endAt:self.endAt];
}

- (instancetype)queryByAddingSortOrder:(FSTSortOrder *)sortOrder {
  HARD_ASSERT(![self isDocumentQuery], "No ordering is allowed for a document query.");

  // TODO(klimt): Validate that the same key isn't added twice.
  return [[FSTQuery alloc] initWithQuery:_query
                                 orderBy:[self.explicitSortOrders arrayByAddingObject:sortOrder]
                                   limit:self.limit
                                 startAt:self.startAt
                                   endAt:self.endAt];
}

- (instancetype)queryBySettingLimit:(int32_t)limit {
  return [[FSTQuery alloc] initWithQuery:_query
                                 orderBy:self.explicitSortOrders
                                   limit:limit
                                 startAt:self.startAt
                                   endAt:self.endAt];
}

- (instancetype)queryByAddingStartAt:(FSTBound *)bound {
  return [[FSTQuery alloc] initWithQuery:_query
                                 orderBy:self.explicitSortOrders
                                   limit:self.limit
                                 startAt:bound
                                   endAt:self.endAt];
}

- (instancetype)queryByAddingEndAt:(FSTBound *)bound {
  return [[FSTQuery alloc] initWithQuery:_query
                                 orderBy:self.explicitSortOrders
                                   limit:self.limit
                                 startAt:self.startAt
                                   endAt:bound];
}

- (instancetype)collectionQueryAtPath:(ResourcePath)path {
  return [[FSTQuery alloc] initWithQuery:_query.AsCollectionQueryAtPath(std::move(path))
                                 orderBy:self.explicitSortOrders
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
  NSArray<FSTSortOrder *> *sortOrders = self.sortOrders;

  return DocumentComparator([sortOrders](id document1, id document2) {
    bool didCompareOnKeyField = false;
    for (FSTSortOrder *orderBy in sortOrders) {
      ComparisonResult comp = [orderBy compareDocument:document1 toDocument:document2];
      if (!util::Same(comp)) return comp;

      didCompareOnKeyField = didCompareOnKeyField || orderBy.field == FieldPath::KeyFieldPath();
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
  if (self.explicitSortOrders.count > 0) {
    return &self.explicitSortOrders.firstObject.field;
  }
  return nullptr;
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
  for (FSTSortOrder *orderBy in self.sortOrders) {
    [canonicalID appendString:orderBy.canonicalID];
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
         objc::Equals(self.sortOrders, other.sortOrders) &&
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
  for (FSTSortOrder *orderBy in self.explicitSortOrders) {
    const FieldPath &fieldPath = orderBy.field;
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
