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

#pragma mark - Filter::Operator functions

@implementation FSTFilter

+ (instancetype)filterWithField:(const FieldPath &)field
                 filterOperator:(Filter::Operator)op
                          value:(FieldValue)value {
  if (value.type() == FieldValue::Type::Null) {
    if (op != Filter::Operator::Equal) {
      ThrowInvalidArgument("Invalid Query. Nil and NSNull only support equality comparisons.");
    }
    return [[FSTNullFilter alloc] initWithField:field];
  } else if (value.is_nan()) {
    if (op != Filter::Operator::Equal) {
      ThrowInvalidArgument("Invalid Query. NaN only supports equality comparisons.");
    }
    return [[FSTNanFilter alloc] initWithField:field];
  } else {
    return [[FSTRelationFilter alloc] initWithField:field filterOperator:op value:value];
  }
}

- (const FieldPath &)field {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (BOOL)matchesDocument:(FSTDocument *)document {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (NSString *)canonicalID {
  @throw FSTAbstractMethodException();  // NOLINT
}

@end

#pragma mark - FSTRelationFilter

@interface FSTRelationFilter () {
  /** The left hand side of the relation. A path into a document field. */
  firebase::firestore::model::FieldPath _field;
}

/**
 * Initializes the receiver relation filter.
 *
 * @param field A path to a field in the document to filter on. The LHS of the expression.
 * @param filterOperator The binary operator to apply.
 * @param value A constant value to compare @a field to. The RHS of the expression.
 */
- (instancetype)initWithField:(FieldPath)field
               filterOperator:(Filter::Operator)filterOperator
                        value:(FieldValue)value NS_DESIGNATED_INITIALIZER;

/** Returns YES if @a document matches the receiver's constraint. */
- (BOOL)matchesDocument:(FSTDocument *)document;

/**
 * A canonical string identifying the filter. Two different instances of equivalent filters will
 * return the same canonicalID.
 */
- (NSString *)canonicalID;

@end

@implementation FSTRelationFilter {
  core::RelationFilter _filter;
}

#pragma mark - Constructor methods

- (instancetype)initWithField:(FieldPath)field
               filterOperator:(Filter::Operator)filterOperator
                        value:(FieldValue)value {
  self = [super init];
  if (self) {
    _filter = core::RelationFilter(std::move(field), filterOperator, std::move(value));
  }
  return self;
}

#pragma mark - Public Methods

- (BOOL)isInequality {
  return _filter.IsInequality();
}

- (const model::FieldPath &)field {
  return _filter.field();
}

- (core::Filter::Operator)filterOperator {
  return _filter.op();
}

- (const model::FieldValue &)value {
  return _filter.value();
}

#pragma mark - NSObject methods

- (NSString *)description {
  return util::MakeNSString(_filter.ToString());
}

- (BOOL)isEqual:(id)other {
  if (self == other) return YES;
  if (![other isKindOfClass:[FSTRelationFilter class]]) return NO;

  return _filter == ((FSTRelationFilter *)other)->_filter;
}

#pragma mark - Private methods

- (BOOL)matchesDocument:(FSTDocument *)document {
  model::Document converted(document);
  return _filter.Matches(converted);
}

- (NSString *)canonicalID {
  return util::MakeNSString(_filter.CanonicalId());
}

@end

#pragma mark - FSTNullFilter

@implementation FSTNullFilter {
  core::NullFilter _filter;
}

- (instancetype)initWithField:(FieldPath)field {
  if (self = [super init]) {
    _filter = core::NullFilter(std::move(field));
  }
  return self;
}

- (BOOL)matchesDocument:(FSTDocument *)document {
  model::Document converted(document);
  return _filter.Matches(converted);
}

- (NSString *)canonicalID {
  return util::MakeNSString(_filter.CanonicalId());
}

- (const firebase::firestore::model::FieldPath &)field {
  return _filter.field();
}

- (NSString *)description {
  return util::MakeNSString(_filter.ToString());
}

- (BOOL)isEqual:(id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  return _filter == ((FSTNullFilter *)other)->_filter;
}

- (NSUInteger)hash {
  return _filter.Hash();
}

@end

#pragma mark - FSTNanFilter

@implementation FSTNanFilter {
  core::NanFilter _filter;
}

- (instancetype)initWithField:(FieldPath)field {
  if (self = [super init]) {
    _filter = core::NanFilter(field);
  }
  return self;
}

- (BOOL)matchesDocument:(FSTDocument *)document {
  model::Document converted(document);
  return _filter.Matches(converted);
}

- (NSString *)canonicalID {
  return util::MakeNSString(_filter.CanonicalId());
}

- (const firebase::firestore::model::FieldPath &)field {
  return _filter.field();
}

- (NSString *)description {
  return util::MakeNSString(_filter.ToString());
}

- (BOOL)isEqual:(id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  return _filter == ((FSTNanFilter *)other)->_filter;
}

- (NSUInteger)hash {
  return _filter.Hash();
}
@end

#pragma mark - FSTSortOrder

@interface FSTSortOrder () {
  /** The field to sort by. */
  firebase::firestore::model::FieldPath _field;
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

- (const firebase::firestore::model::FieldPath &)field {
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

namespace {

Query::FilterList MakeFilters(NSArray<FSTFilter *> *filters) {
  Query::FilterList result;
  for (FSTFilter *filter in filters) {
    std::shared_ptr<Filter> converted;
    if ([filter isKindOfClass:[FSTRelationFilter class]]) {
      FSTRelationFilter *relationFilter = (FSTRelationFilter *)filter;
      converted =
          Filter::Create(relationFilter.field, relationFilter.filterOperator, relationFilter.value);
    } else if ([filter isKindOfClass:[FSTNanFilter class]]) {
      converted = Filter::Create(filter.field, Filter::Operator::Equal, FieldValue::Nan());
    } else if ([filter isKindOfClass:[FSTNullFilter class]]) {
      converted = Filter::Create(filter.field, Filter::Operator::Equal, FieldValue::Null());
    } else {
      HARD_FAIL("Unknown filter type: %s", [filter description]);
    }

    result.push_back(std::move(converted));
  }
  return result;
}

NSArray<FSTFilter *> *MakeFSTFilters(const Query::FilterList &filters) {
  NSMutableArray<FSTFilter *> *result = [[NSMutableArray alloc] initWithCapacity:filters.size()];
  for (const auto &filter : filters) {
    FSTFilter *converted;
    if (filter->type() == Filter::Type::kRelationFilter) {
      const auto &relationFilter = std::static_pointer_cast<core::RelationFilter>(filter);
      converted = [FSTFilter filterWithField:relationFilter->field()
                              filterOperator:relationFilter->op()
                                       value:relationFilter->value()];
    } else if (filter->type() == Filter::Type::kNanFilter) {
      converted = [[FSTNanFilter alloc] initWithField:filter->field()];
    } else if (filter->type() == Filter::Type::kNullFilter) {
      converted = [[FSTNullFilter alloc] initWithField:filter->field()];
    } else {
      HARD_FAIL("Unknown filter type: %s", filter->ToString());
    }

    [result addObject:converted];
  }
  return result;
}

}  // namespace

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
  return [[FSTQuery alloc] initWithPath:std::move(path)
                        collectionGroup:std::move(collectionGroup)
                               filterBy:@[]
                                orderBy:@[]
                                  limit:Query::kNoLimit
                                startAt:nil
                                  endAt:nil];
}

- (instancetype)initWithPath:(ResourcePath)path
             collectionGroup:(std::shared_ptr<const std::string>)collectionGroup
                    filterBy:(NSArray<FSTFilter *> *)filters
                     orderBy:(NSArray<FSTSortOrder *> *)sortOrders
                       limit:(int32_t)limit
                     startAt:(nullable FSTBound *)startAtBound
                       endAt:(nullable FSTBound *)endAtBound {
  Query query(std::move(path), std::move(collectionGroup), MakeFilters(filters));
  return [self initWithQuery:std::move(query)
                     orderBy:sortOrders
                       limit:limit
                     startAt:startAtBound
                       endAt:endAtBound];
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

- (NSArray<FSTFilter *> *)filters {
  return MakeFSTFilters(_query.filters());
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

- (instancetype)queryByAddingFilter:(FSTFilter *)filter {
  HARD_ASSERT(![self isDocumentQuery], "No filtering allowed for document query");

  const FieldPath *newInequalityField = nullptr;
  if ([filter isKindOfClass:[FSTRelationFilter class]] &&
      [((FSTRelationFilter *)filter) isInequality]) {
    newInequalityField = &filter.field;
  }
  const FieldPath *queryInequalityField = [self inequalityFilterField];
  HARD_ASSERT(
      !queryInequalityField || !newInequalityField || *queryInequalityField == *newInequalityField,
      "Query must only have one inequality field.");

  return [[FSTQuery alloc] initWithPath:self.path
                        collectionGroup:self.collectionGroup
                               filterBy:[self.filters arrayByAddingObject:filter]
                                orderBy:self.explicitSortOrders
                                  limit:self.limit
                                startAt:self.startAt
                                  endAt:self.endAt];
}

- (instancetype)queryByAddingSortOrder:(FSTSortOrder *)sortOrder {
  HARD_ASSERT(![self isDocumentQuery], "No ordering is allowed for a document query.");

  // TODO(klimt): Validate that the same key isn't added twice.
  return [[FSTQuery alloc] initWithPath:self.path
                        collectionGroup:self.collectionGroup
                               filterBy:self.filters
                                orderBy:[self.explicitSortOrders arrayByAddingObject:sortOrder]
                                  limit:self.limit
                                startAt:self.startAt
                                  endAt:self.endAt];
}

- (instancetype)queryBySettingLimit:(int32_t)limit {
  return [[FSTQuery alloc] initWithPath:self.path
                        collectionGroup:self.collectionGroup
                               filterBy:self.filters
                                orderBy:self.explicitSortOrders
                                  limit:limit
                                startAt:self.startAt
                                  endAt:self.endAt];
}

- (instancetype)queryByAddingStartAt:(FSTBound *)bound {
  return [[FSTQuery alloc] initWithPath:self.path
                        collectionGroup:self.collectionGroup
                               filterBy:self.filters
                                orderBy:self.explicitSortOrders
                                  limit:self.limit
                                startAt:bound
                                  endAt:self.endAt];
}

- (instancetype)queryByAddingEndAt:(FSTBound *)bound {
  return [[FSTQuery alloc] initWithPath:self.path
                        collectionGroup:self.collectionGroup
                               filterBy:self.filters
                                orderBy:self.explicitSortOrders
                                  limit:self.limit
                                startAt:self.startAt
                                  endAt:bound];
}

- (instancetype)collectionQueryAtPath:(firebase::firestore::model::ResourcePath)path {
  return [[FSTQuery alloc] initWithPath:path
                        collectionGroup:nil
                               filterBy:self.filters
                                orderBy:self.explicitSortOrders
                                  limit:self.limit
                                startAt:self.startAt
                                  endAt:self.endAt];
}

- (BOOL)isDocumentQuery {
  return DocumentKey::IsDocumentKey(self.path) && !self.collectionGroup && self.filters.count == 0;
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
  for (FSTFilter *filter in self.filters) {
    if ([filter isKindOfClass:[FSTRelationFilter class]] &&
        ((FSTRelationFilter *)filter).isInequality) {
      return &filter.field;
    }
  }
  return nullptr;
}

- (BOOL)hasArrayContainsFilter {
  for (FSTFilter *filter in self.filters) {
    if ([filter isKindOfClass:[FSTRelationFilter class]] &&
        ((FSTRelationFilter *)filter).filterOperator == Filter::Operator::ArrayContains) {
      return YES;
    }
  }
  return NO;
}

- (nullable const FieldPath *)firstSortOrderField {
  if (self.explicitSortOrders.count > 0) {
    return &self.explicitSortOrders.firstObject.field;
  }
  return nullptr;
}

/** The base path of the query. */
- (const firebase::firestore::model::ResourcePath &)path {
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
  for (FSTFilter *predicate in self.filters) {
    [canonicalID appendFormat:@"%@", [predicate canonicalID]];
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
  for (FSTFilter *filter in self.filters) {
    if (![filter matchesDocument:document]) {
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
