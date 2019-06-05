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

#import <Foundation/Foundation.h>

#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"

@class FSTDocument;
@class FSTFieldValue;

namespace core = firebase::firestore::core;
namespace model = firebase::firestore::model;
namespace util = firebase::firestore::util;

NS_ASSUME_NONNULL_BEGIN

/** Interface used for all query filters. */
@interface FSTFilter : NSObject

/**
 * Creates a filter for the provided path, operator, and value.
 *
 * Note that if the relational operator is Filter::Operator::Equal and the
 * value is FieldValue::Null() or FieldValue::Nan(), this will return the
 * appropriate FSTNullFilter or FSTNanFilter class instead of a
 * FSTRelationFilter.
 */
+ (instancetype)filterWithField:(const model::FieldPath &)field
                 filterOperator:(core::Filter::Operator)op
                          value:(FSTFieldValue *)value;

/** Returns the field the Filter operates over. Abstract method. */
- (const model::FieldPath &)field;

/** Returns true if a document matches the filter. Abstract method. */
- (BOOL)matchesDocument:(FSTDocument *)document;

/** A unique ID identifying the filter; used when serializing queries. Abstract method. */
- (NSString *)canonicalID;

@end

/**
 * FSTRelationFilter is a document filter constraint on a query with a single relation operator.
 * It is similar to NSComparisonPredicate, except customized for Firestore semantics.
 */
@interface FSTRelationFilter : FSTFilter

/**
 * Creates a new constraint for filtering documents.
 *
 * @param field A path to a field in the document to filter on. The LHS of the expression.
 * @param filterOperator The binary operator to apply.
 * @param value A constant value to compare @a field to. The RHS of the expression.
 * @return A new instance of FSTRelationFilter.
 */
- (instancetype)initWithField:(model::FieldPath)field
               filterOperator:(core::Filter::Operator)filterOperator
                        value:(FSTFieldValue *)value;

- (instancetype)init NS_UNAVAILABLE;

/** Returns YES if the receiver is not an equality relation. */
- (BOOL)isInequality;

/** The left hand side of the relation. A path into a document field. */
- (const model::FieldPath &)field;

/** The type of equality/inequality operator to use in the relation. */
@property(nonatomic, assign, readonly) core::Filter::Operator filterOperator;

/** The right hand side of the relation. A constant value to compare to. */
@property(nonatomic, strong, readonly) FSTFieldValue *value;

@end

/** Filter that matches NULL values. */
@interface FSTNullFilter : FSTFilter
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithField:(model::FieldPath)field NS_DESIGNATED_INITIALIZER;
@end

/** Filter that matches NAN values. */
@interface FSTNanFilter : FSTFilter
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithField:(model::FieldPath)field NS_DESIGNATED_INITIALIZER;
@end

/** FSTSortOrder is a field and direction to order query results by. */
@interface FSTSortOrder : NSObject <NSCopying>

/** Creates a new sort order with the given field and direction. */
+ (instancetype)sortOrderWithFieldPath:(model::FieldPath)fieldPath ascending:(BOOL)ascending;

- (instancetype)init NS_UNAVAILABLE;

/** Compares two documents based on the field and direction of this sort order. */
- (util::ComparisonResult)compareDocument:(FSTDocument *)document1
                               toDocument:(FSTDocument *)document2;

/** The field to sort by. */
- (const model::FieldPath &)field;

/** The direction of the sort. */
@property(nonatomic, assign, readonly, getter=isAscending) BOOL ascending;

@end

/**
 * FSTBound represents a bound of a query.
 *
 * The bound is specified with the given components representing a position and whether it's just
 * before or just after the position (relative to whatever the query order is).
 *
 * The position represents a logical index position for a query. It's a prefix of values for
 * the (potentially implicit) order by clauses of a query.
 *
 * FSTBound provides a function to determine whether a document comes before or after a bound.
 * This is influenced by whether the position is just before or just after the provided values.
 */
@interface FSTBound : NSObject <NSCopying>

/**
 * Creates a new bound.
 *
 * @param position The position relative to the sort order.
 * @param isBefore Whether this bound is just before or just after the position.
 */
+ (instancetype)boundWithPosition:(NSArray<FSTFieldValue *> *)position isBefore:(BOOL)isBefore;

/** Whether this bound is just before or just after the provided position */
@property(nonatomic, assign, readonly, getter=isBefore) BOOL before;

/** The index position of this bound represented as an array of field values. */
@property(nonatomic, strong, readonly) NSArray<FSTFieldValue *> *position;

/** Returns YES if a document comes before a bound using the provided sort order. */
- (BOOL)sortsBeforeDocument:(FSTDocument *)document
             usingSortOrder:(NSArray<FSTSortOrder *> *)sortOrder;

@end

/** FSTQuery represents the internal structure of a Firestore query. */
@interface FSTQuery : NSObject <NSCopying>

- (id)init NS_UNAVAILABLE;

/**
 * Initializes a query with all of its components directly.
 */
- (instancetype)initWithPath:(model::ResourcePath)path
             collectionGroup:(nullable NSString *)collectionGroup
                    filterBy:(NSArray<FSTFilter *> *)filters
                     orderBy:(NSArray<FSTSortOrder *> *)sortOrders
                       limit:(int32_t)limit
                     startAt:(nullable FSTBound *)startAtBound
                       endAt:(nullable FSTBound *)endAtBound NS_DESIGNATED_INITIALIZER;

/**
 * Creates and returns a new FSTQuery.
 *
 * @param path The path to the collection to be queried over.
 * @return A new instance of FSTQuery.
 */
+ (instancetype)queryWithPath:(model::ResourcePath)path;

/**
 * Creates and returns a new FSTQuery.
 *
 * @param path The path to the location to be queried over. Must currently be
 *     empty in the case of a collection group query.
 * @param collectionGroup The collection group to be queried over. nil if this
 *     is not a collection group query.
 * @return A new instance of FSTQuery.
 */
+ (instancetype)queryWithPath:(model::ResourcePath)path
              collectionGroup:(nullable NSString *)collectionGroup;

/**
 * Returns the list of ordering constraints that were explicitly requested on the query by the
 * user.
 *
 * Note that the actual query performed might add additional sort orders to match the behavior
 * of the backend.
 */
- (NSArray<FSTSortOrder *> *)explicitSortOrders;

/**
 * Returns the full list of ordering constraints on the query.
 *
 * This might include additional sort orders added implicitly to match the backend behavior.
 */
- (NSArray<FSTSortOrder *> *)sortOrders;

/**
 * Creates a new FSTQuery with an additional filter.
 *
 * @param filter The predicate to filter by.
 * @return the new FSTQuery.
 */
- (instancetype)queryByAddingFilter:(FSTFilter *)filter;

/**
 * Creates a new FSTQuery with an additional ordering constraint.
 *
 * @param sortOrder The key and direction to order by.
 * @return the new FSTQuery.
 */
- (instancetype)queryByAddingSortOrder:(FSTSortOrder *)sortOrder;

/**
 * Returns a new FSTQuery with the given limit on how many results can be returned.
 *
 * @param limit The maximum number of results to return. If @a limit <= 0, behavior is unspecified.
 *     If @a limit == NSNotFound, then no limit is applied.
 */
- (instancetype)queryBySettingLimit:(int32_t)limit;

/**
 * Creates a new FSTQuery starting at the provided bound.
 *
 * @param bound The bound to start this query at.
 * @return the new FSTQuery.
 */
- (instancetype)queryByAddingStartAt:(FSTBound *)bound;

/**
 * Creates a new FSTQuery ending at the provided bound.
 *
 * @param bound The bound to end this query at.
 * @return the new FSTQuery.
 */
- (instancetype)queryByAddingEndAt:(FSTBound *)bound;

/**
 * Helper to convert a collection group query into a collection query at a specific path. This is
 * used when executing collection group queries, since we have to split the query into a set of
 * collection queries at multiple paths.
 */
- (instancetype)collectionQueryAtPath:(model::ResourcePath)path;

/** Returns YES if the receiver is query for a specific document. */
- (BOOL)isDocumentQuery;

/** Returns YES if the receiver is a collection group query. */
- (BOOL)isCollectionGroupQuery;

/** Returns YES if the @a document matches the constraints of the receiver. */
- (BOOL)matchesDocument:(FSTDocument *)document;

/** Returns a comparator that will sort documents according to the receiver's sort order. */
- (model::DocumentComparator)comparator;

/** Returns the field of the first filter on the receiver that's an inequality, or nullptr if none.
 */
- (nullable const model::FieldPath *)inequalityFilterField;

/** Returns YES if the query has an arrayContains filter already. */
- (BOOL)hasArrayContainsFilter;

/** Returns the first field in an order-by constraint, or nullptr if none. */
- (nullable const model::FieldPath *)firstSortOrderField;

/** The base path of the query. */
- (const model::ResourcePath &)path;

/** The collection group of the query. */
@property(nonatomic, nullable, strong, readonly) NSString *collectionGroup;

/** The filters on the documents returned by the query. */
@property(nonatomic, strong, readonly) NSArray<FSTFilter *> *filters;

/** The maximum number of results to return, or NSNotFound if no limit. */
@property(nonatomic, assign, readonly) int32_t limit;

/**
 * A canonical string identifying the query. Two different instances of equivalent queries will
 * return the same canonicalID.
 */
@property(nonatomic, strong, readonly) NSString *canonicalID;

/** An optional bound to start the query at. */
@property(nonatomic, nullable, strong, readonly) FSTBound *startAt;

/** An optional bound to end the query at. */
@property(nonatomic, nullable, strong, readonly) FSTBound *endAt;

@end

NS_ASSUME_NONNULL_END
