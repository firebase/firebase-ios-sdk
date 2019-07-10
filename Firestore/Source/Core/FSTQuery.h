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

#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"

@class FSTDocument;

namespace core = firebase::firestore::core;
namespace model = firebase::firestore::model;
namespace util = firebase::firestore::util;

NS_ASSUME_NONNULL_BEGIN

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
+ (instancetype)boundWithPosition:(std::vector<model::FieldValue>)position isBefore:(bool)isBefore;

/** Whether this bound is just before or just after the provided position */
@property(nonatomic, assign, readonly, getter=isBefore) bool before;

/** The index position of this bound represented as an array of field values. */
@property(nonatomic, assign, readonly) const std::vector<model::FieldValue> &position;

/** Returns true if a document comes before a bound using the provided sort order. */
- (bool)sortsBeforeDocument:(FSTDocument *)document
             usingSortOrder:(NSArray<FSTSortOrder *> *)sortOrder;

@end

/** FSTQuery represents the internal structure of a Firestore query. */
@interface FSTQuery : NSObject <NSCopying>

- (id)init NS_UNAVAILABLE;

/**
 * Initializes a query with all of its components directly.
 */
- (instancetype)initWithQuery:(core::Query)query
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
 * @param collectionGroup The collection group to be queried over. nullptr if this
 *     is not a collection group query.
 * @return A new instance of FSTQuery.
 */
+ (instancetype)queryWithPath:(model::ResourcePath)path
              collectionGroup:(std::shared_ptr<const std::string>)collectionGroup;

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
- (instancetype)queryByAddingFilter:(std::shared_ptr<core::Filter>)filter;

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
- (const std::shared_ptr<const std::string> &)collectionGroup;

/** The filters on the documents returned by the query. */
- (const core::Query::FilterList &)filters;

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
