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

#include <memory>
#include <string>
#include <utility>

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Util/FSTClasses.h"

#include "Firestore/core/src/firebase/firestore/api/input_validation.h"
#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/objc/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace core = firebase::firestore::core;
namespace objc = firebase::firestore::objc;
namespace util = firebase::firestore::util;
using firebase::firestore::api::ThrowInvalidArgument;
using firebase::firestore::core::Filter;
using firebase::firestore::model::DocumentComparator;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::util::ComparisonResult;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Filter::Operator functions

NSString *FSTStringFromQueryRelationOperator(Filter::Operator filterOperator) {
  switch (filterOperator) {
    case Filter::Operator::LessThan:
      return @"<";
    case Filter::Operator::LessThanOrEqual:
      return @"<=";
    case Filter::Operator::Equal:
      return @"==";
    case Filter::Operator::GreaterThanOrEqual:
      return @">=";
    case Filter::Operator::GreaterThan:
      return @">";
    case Filter::Operator::ArrayContains:
      return @"array_contains";
    default:
      HARD_FAIL("Unknown Filter::Operator %s", filterOperator);
  }
}

@implementation FSTFilter

+ (instancetype)filterWithField:(const FieldPath &)field
                 filterOperator:(Filter::Operator)op
                          value:(FSTFieldValue *)value {
  if (value.type == FieldValue::Type::Null) {
    if (op != Filter::Operator::Equal) {
      ThrowInvalidArgument("Invalid Query. Nil and NSNull only support equality comparisons.");
    }
    return [[FSTNullFilter alloc] initWithField:field];
  } else if (value.isNAN) {
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
                        value:(FSTFieldValue *)value NS_DESIGNATED_INITIALIZER;

/** Returns YES if @a document matches the receiver's constraint. */
- (BOOL)matchesDocument:(FSTDocument *)document;

/**
 * A canonical string identifying the filter. Two different instances of equivalent filters will
 * return the same canonicalID.
 */
- (NSString *)canonicalID;

@end

@implementation FSTRelationFilter

#pragma mark - Constructor methods

- (instancetype)initWithField:(FieldPath)field
               filterOperator:(Filter::Operator)filterOperator
                        value:(FSTFieldValue *)value {
  self = [super init];
  if (self) {
    _field = std::move(field);
    _filterOperator = filterOperator;
    _value = value;
  }
  return self;
}

#pragma mark - Public Methods

- (BOOL)isInequality {
  return self.filterOperator != Filter::Operator::Equal &&
         self.filterOperator != Filter::Operator::ArrayContains;
}

- (const firebase::firestore::model::FieldPath &)field {
  return _field;
}

#pragma mark - NSObject methods

- (NSString *)description {
  return [NSString stringWithFormat:@"%s %@ %@", _field.CanonicalString().c_str(),
                                    FSTStringFromQueryRelationOperator(self.filterOperator),
                                    self.value];
}

- (BOOL)isEqual:(id)other {
  if (self == other) {
    return YES;
  }
  if (![other isKindOfClass:[FSTRelationFilter class]]) {
    return NO;
  }
  return [self isEqualToFilter:(FSTRelationFilter *)other];
}

#pragma mark - Private methods

- (BOOL)matchesDocument:(FSTDocument *)document {
  if (_field.IsKeyFieldPath()) {
    HARD_ASSERT(self.value.type == FieldValue::Type::Reference,
                "Comparing on key, but filter value not a FSTReferenceValue.");
    HARD_ASSERT(self.filterOperator != Filter::Operator::ArrayContains,
                "arrayContains queries don't make sense on document keys.");
    FSTReferenceValue *refValue = (FSTReferenceValue *)self.value;
    NSComparisonResult comparison = util::WrapCompare(document.key, refValue.value.key);
    return [self matchesComparison:comparison];
  } else {
    return [self matchesValue:[document fieldForPath:self.field]];
  }
}

- (NSString *)canonicalID {
  // TODO(b/37283291): This should be collision robust and avoid relying on |description| methods.
  return [NSString stringWithFormat:@"%s%@%@", _field.CanonicalString().c_str(),
                                    FSTStringFromQueryRelationOperator(self.filterOperator),
                                    [self.value value]];
}

- (BOOL)isEqualToFilter:(FSTRelationFilter *)other {
  if (self.filterOperator != other.filterOperator) {
    return NO;
  }
  if (_field != other.field) {
    return NO;
  }
  if (![self.value isEqual:other.value]) {
    return NO;
  }
  return YES;
}

/** Returns YES if receiver is true with the given value as its LHS. */
- (BOOL)matchesValue:(FSTFieldValue *)other {
  if (self.filterOperator == Filter::Operator::ArrayContains) {
    if ([other isMemberOfClass:[FSTArrayValue class]]) {
      FSTArrayValue *arrayValue = (FSTArrayValue *)other;
      return [arrayValue.internalValue containsObject:self.value];
    } else {
      return false;
    }
  } else {
    // Only perform comparison queries on types with matching backend order (such as double and
    // int).
    return self.value.typeOrder == other.typeOrder &&
           [self matchesComparison:[other compare:self.value]];
  }
}

- (BOOL)matchesComparison:(NSComparisonResult)comparison {
  switch (self.filterOperator) {
    case Filter::Operator::LessThan:
      return comparison == NSOrderedAscending;
    case Filter::Operator::LessThanOrEqual:
      return comparison == NSOrderedAscending || comparison == NSOrderedSame;
    case Filter::Operator::Equal:
      return comparison == NSOrderedSame;
    case Filter::Operator::GreaterThanOrEqual:
      return comparison == NSOrderedDescending || comparison == NSOrderedSame;
    case Filter::Operator::GreaterThan:
      return comparison == NSOrderedDescending;
    default:
      HARD_FAIL("Unknown operator: %s", self.filterOperator);
  }
}

@end

#pragma mark - FSTNullFilter

@interface FSTNullFilter () {
  FieldPath _field;
}
@end

@implementation FSTNullFilter
- (instancetype)initWithField:(FieldPath)field {
  if (self = [super init]) {
    _field = std::move(field);
  }
  return self;
}

- (BOOL)matchesDocument:(FSTDocument *)document {
  FSTFieldValue *fieldValue = [document fieldForPath:self.field];
  return fieldValue != nil && fieldValue.type == FieldValue::Type::Null;
}

- (NSString *)canonicalID {
  return [NSString stringWithFormat:@"%s IS NULL", _field.CanonicalString().c_str()];
}

- (const firebase::firestore::model::FieldPath &)field {
  return _field;
}

- (NSString *)description {
  return [self canonicalID];
}

- (BOOL)isEqual:(id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  return _field == ((FSTNullFilter *)other)->_field;
}

- (NSUInteger)hash {
  return util::Hash(_field);
}

@end

#pragma mark - FSTNanFilter

@interface FSTNanFilter () {
  FieldPath _field;
}
@end

@implementation FSTNanFilter

- (instancetype)initWithField:(FieldPath)field {
  if (self = [super init]) {
    _field = std::move(field);
  }
  return self;
}

- (BOOL)matchesDocument:(FSTDocument *)document {
  FSTFieldValue *fieldValue = [document fieldForPath:self.field];
  return fieldValue != nil && fieldValue.isNAN;
}

- (NSString *)canonicalID {
  return [NSString stringWithFormat:@"%s IS NaN", _field.CanonicalString().c_str()];
}

- (const firebase::firestore::model::FieldPath &)field {
  return _field;
}

- (NSString *)description {
  return [self canonicalID];
}

- (BOOL)isEqual:(id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  return _field == ((FSTNanFilter *)other)->_field;
}

- (NSUInteger)hash {
  return util::Hash(_field);
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
    FSTFieldValue *value1 = [document1 fieldForPath:self.field];
    FSTFieldValue *value2 = [document2 fieldForPath:self.field];
    HARD_ASSERT(value1 != nil && value2 != nil,
                "Trying to compare documents on fields that don't exist.");
    result = util::MakeComparisonResult([value1 compare:value2]);
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

@implementation FSTBound

- (instancetype)initWithPosition:(NSArray<FSTFieldValue *> *)position isBefore:(BOOL)isBefore {
  if (self = [super init]) {
    _position = position;
    _before = isBefore;
  }
  return self;
}

+ (instancetype)boundWithPosition:(NSArray<FSTFieldValue *> *)position isBefore:(BOOL)isBefore {
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
  for (FSTFieldValue *component in self.position) {
    [string appendFormat:@"%@", component];
  }
  return string;
}

- (BOOL)sortsBeforeDocument:(FSTDocument *)document
             usingSortOrder:(NSArray<FSTSortOrder *> *)sortOrder {
  HARD_ASSERT(self.position.count <= sortOrder.count,
              "FSTIndexPosition has more components than provided sort order.");
  __block ComparisonResult result = ComparisonResult::Same;
  [self.position enumerateObjectsUsingBlock:^(FSTFieldValue *fieldValue, NSUInteger idx,
                                              BOOL *stop) {
    FSTSortOrder *sortOrderComponent = sortOrder[idx];
    ComparisonResult comparison;
    if (sortOrderComponent.field == FieldPath::KeyFieldPath()) {
      HARD_ASSERT(fieldValue.type == FieldValue::Type::Reference,
                  "FSTBound has a non-key value where the key path is being used %s", fieldValue);
      FSTReferenceValue *refValue = (FSTReferenceValue *)fieldValue;
      comparison = util::Compare(refValue.value.key, document.key);
    } else {
      FSTFieldValue *docValue = [document fieldForPath:sortOrderComponent.field];
      HARD_ASSERT(docValue != nil,
                  "Field should exist since document matched the orderBy already.");
      comparison = util::MakeComparisonResult([fieldValue compare:docValue]);
    }

    if (!sortOrderComponent.isAscending) {
      comparison = util::ReverseOrder(comparison);
    }

    if (!util::Same(comparison)) {
      result = comparison;
      *stop = YES;
    }
  }];

  return self.isBefore ? result <= ComparisonResult::Same : result < ComparisonResult::Same;
}

#pragma mark - NSObject methods

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTBound: position:%@ before:%@>", self.position,
                                    self.isBefore ? @"YES" : @"NO"];
}

- (BOOL)isEqual:(NSObject *)other {
  if (self == other) {
    return YES;
  }
  if (![other isKindOfClass:[FSTBound class]]) {
    return NO;
  }

  FSTBound *otherBound = (FSTBound *)other;

  return [self.position isEqualToArray:otherBound.position] && self.isBefore == otherBound.isBefore;
}

- (NSUInteger)hash {
  return 31 * self.position.hash + (self.isBefore ? 0 : 1);
}

- (instancetype)copyWithZone:(nullable NSZone *)zone {
  return self;
}

@end

#pragma mark - FSTQuery

@interface FSTQuery () {
  // Cached value of the canonicalID property.
  NSString *_canonicalID;
  /** The base path of the query. */
  ResourcePath _path;
}

/** A list of fields given to sort by. This does not include the implicit key sort at the end. */
@property(nonatomic, strong, readonly) NSArray<FSTSortOrder *> *explicitSortOrders;

/** The memoized list of sort orders */
@property(nonatomic, nullable, strong, readwrite) NSArray<FSTSortOrder *> *memoizedSortOrders;

@end

@implementation FSTQuery

#pragma mark - Constructors

+ (instancetype)queryWithPath:(ResourcePath)path {
  return [FSTQuery queryWithPath:std::move(path) collectionGroup:nil];
}

+ (instancetype)queryWithPath:(ResourcePath)path
              collectionGroup:(nullable NSString *)collectionGroup {
  return [[FSTQuery alloc] initWithPath:std::move(path)
                        collectionGroup:collectionGroup
                               filterBy:@[]
                                orderBy:@[]
                                  limit:NSNotFound
                                startAt:nil
                                  endAt:nil];
}

- (instancetype)initWithPath:(ResourcePath)path
             collectionGroup:(nullable NSString *)collectionGroup
                    filterBy:(NSArray<FSTFilter *> *)filters
                     orderBy:(NSArray<FSTSortOrder *> *)sortOrders
                       limit:(NSInteger)limit
                     startAt:(nullable FSTBound *)startAtBound
                       endAt:(nullable FSTBound *)endAtBound {
  if (self = [super init]) {
    _path = std::move(path);
    _collectionGroup = collectionGroup;
    _filters = filters;
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

- (instancetype)queryBySettingLimit:(NSInteger)limit {
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
  return DocumentKey::IsDocumentKey(_path) && !self.collectionGroup && self.filters.count == 0;
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
  return _path;
}

#pragma mark - Private properties

- (NSString *)canonicalID {
  if (_canonicalID) {
    return _canonicalID;
  }

  NSMutableString *canonicalID = [NSMutableString string];
  [canonicalID appendFormat:@"%s", _path.CanonicalString().c_str()];

  if (self.collectionGroup) {
    [canonicalID appendFormat:@"|cg:%@", self.collectionGroup];
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
  if (self.limit != NSNotFound) {
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
  return self.path == other.path && objc::Equals(self.collectionGroup, other.collectionGroup) &&
         self.limit == other.limit && objc::Equals(self.filters, other.filters) &&
         objc::Equals(self.sortOrders, other.sortOrders) &&
         objc::Equals(self.startAt, other.startAt) && objc::Equals(self.endAt, other.endAt);
}

/* Returns YES if the document matches the path and collection group for the receiver. */
- (BOOL)pathAndCollectionGroupMatchDocument:(FSTDocument *)document {
  const ResourcePath &documentPath = document.key.path();
  if (self.collectionGroup) {
    // NOTE: self.path is currently always empty since we don't expose Collection Group queries
    // rooted at a document path yet.
    return document.key.HasCollectionId(util::MakeString(self.collectionGroup)) &&
           self.path.IsPrefixOf(documentPath);
  } else if (DocumentKey::IsDocumentKey(_path)) {
    // Exact match for document queries.
    return self.path == documentPath;
  } else {
    // Shallow ancestor queries by default.
    return self.path.IsPrefixOf(documentPath) && _path.size() == documentPath.size() - 1;
  }
}

/**
 * A document must have a value for every ordering clause in order to show up in the results.
 */
- (BOOL)orderByMatchesDocument:(FSTDocument *)document {
  for (FSTSortOrder *orderBy in self.explicitSortOrders) {
    const FieldPath &fieldPath = orderBy.field;
    // order by key always matches
    if (fieldPath != FieldPath::KeyFieldPath() && [document fieldForPath:fieldPath] == nil) {
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
