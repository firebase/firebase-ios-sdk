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

#include "Firestore/core/src/firebase/firestore/core/bound.h"
#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/order_by.h"
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

/** FSTQuery represents the internal structure of a Firestore query. */
@interface FSTQuery : NSObject <NSCopying>

- (id)init NS_UNAVAILABLE;

/**
 * Initializes a query with all of its components directly.
 */
- (instancetype)initWithQuery:(core::Query)query NS_DESIGNATED_INITIALIZER;

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
- (const core::OrderByList &)explicitSortOrders;

/**
 * Returns the full list of ordering constraints on the query.
 *
 * This might include additional sort orders added implicitly to match the backend behavior.
 */
- (const core::OrderByList &)sortOrders;

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
 * @param orderBy The field and direction to order by.
 * @return the new FSTQuery.
 */
- (instancetype)queryByAddingSortOrder:(core::OrderBy)orderBy;

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
- (instancetype)queryByAddingStartAt:(core::Bound)bound;

/**
 * Creates a new FSTQuery ending at the provided bound.
 *
 * @param bound The bound to end this query at.
 * @return the new FSTQuery.
 */
- (instancetype)queryByAddingEndAt:(core::Bound)bound;

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
- (const core::FilterList &)filters;

/** The maximum number of results to return, or NSNotFound if no limit. */
- (int32_t)limit;

/**
 * A canonical string identifying the query. Two different instances of equivalent queries will
 * return the same canonicalID.
 */
- (const std::string &)canonicalID;

/** An optional bound to start the query at. */
- (const std::shared_ptr<core::Bound> &)startAt;

/** An optional bound to end the query at. */
- (const std::shared_ptr<core::Bound> &)endAt;

@end

NS_ASSUME_NONNULL_END
