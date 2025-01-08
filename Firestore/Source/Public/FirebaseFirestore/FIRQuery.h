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

#import "FIRFirestoreSource.h"
#import "FIRListenerRegistration.h"
#import "FIRSnapshotListenOptions.h"

@class FIRAggregateQuery;
@class FIRAggregateField;
@class FIRFieldPath;
@class FIRFirestore;
@class FIRFilter;
@class FIRQuerySnapshot;
@class FIRDocumentSnapshot;

NS_ASSUME_NONNULL_BEGIN

/**
 * A block type used to handle failable snapshot method callbacks.
 */
typedef void (^FIRQuerySnapshotBlock)(FIRQuerySnapshot *_Nullable snapshot,
                                      NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/**
 * A `Query` refers to a query which you can read or listen to. You can also construct
 * refined `Query` objects by adding filters and ordering.
 */
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(Query)
@interface FIRQuery : NSObject
/** :nodoc: */
- (id)init __attribute__((unavailable("FIRQuery cannot be created directly.")));

/** The `Firestore` instance that created this query (useful for performing transactions, etc.). */
@property(nonatomic, strong, readonly) FIRFirestore *firestore;

#pragma mark - Retrieving Data
/**
 * Reads the documents matching this query.
 *
 * This method attempts to provide up-to-date data when possible by waiting for
 * data from the server, but it may return cached data or fail if you are
 * offline and the server cannot be reached. See the
 * `getDocuments(source:completion:)` method to change this behavior.
 *
 * @param completion a block to execute once the documents have been successfully read.
 *     documentSet will be `nil` only if error is `non-nil`.
 */
- (void)getDocumentsWithCompletion:
    (void (^)(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error))completion
    NS_SWIFT_NAME(getDocuments(completion:));

/**
 * Reads the documents matching this query.
 *
 * @param source indicates whether the results should be fetched from the cache
 *     only (`Source.cache`), the server only (`Source.server`), or to attempt
 *     the server and fall back to the cache (`Source.default`).
 * @param completion a block to execute once the documents have been successfully read.
 *     documentSet will be `nil` only if error is `non-nil`.
 */
- (void)getDocumentsWithSource:(FIRFirestoreSource)source
                    completion:(void (^)(FIRQuerySnapshot *_Nullable snapshot,
                                         NSError *_Nullable error))completion
    NS_SWIFT_NAME(getDocuments(source:completion:));

/**
 * Attaches a listener for `QuerySnapshot` events.
 *
 * @param listener The listener to attach.
 *
 * @return A `ListenerRegistration` object that can be used to remove this listener.
 */
- (id<FIRListenerRegistration>)addSnapshotListener:
    (void (^)(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error))listener
    NS_SWIFT_NAME(addSnapshotListener(_:));

/**
 * Attaches a listener for `QuerySnapshot` events.
 *
 * @param includeMetadataChanges Whether metadata-only changes (i.e. only
 *     `DocumentSnapshot.metadata` changed) should trigger snapshot events.
 * @param listener The listener to attach.
 *
 * @return A `ListenerRegistration` that can be used to remove this listener.
 */
- (id<FIRListenerRegistration>)
    addSnapshotListenerWithIncludeMetadataChanges:(BOOL)includeMetadataChanges
                                         listener:(void (^)(FIRQuerySnapshot *_Nullable snapshot,
                                                            NSError *_Nullable error))listener
    NS_SWIFT_NAME(addSnapshotListener(includeMetadataChanges:listener:));

/**
 * Attaches a listener for `QuerySnapshot` events.
 * @param options Sets snapshot listener options, including whether metadata-only changes should
 *     trigger snapshot events, the source to listen to, the executor to use to call the
 *     listener, or the activity to scope the listener to.
 * @param listener The listener to attach.
 *
 * @return A `ListenerRegistration` that can be used to remove this listener.
 */
- (id<FIRListenerRegistration>)
    addSnapshotListenerWithOptions:(FIRSnapshotListenOptions *)options
                          listener:(void (^)(FIRQuerySnapshot *_Nullable snapshot,
                                             NSError *_Nullable error))listener
    NS_SWIFT_NAME(addSnapshotListener(options:listener:));

#pragma mark - Filtering Data
/**
 * Creates and returns a new Query with the additional filter.
 *
 * @param filter The new filter to apply to the existing query.
 * @return The newly created Query.
 */
- (FIRQuery *)queryWhereFilter:(FIRFilter *)filter NS_SWIFT_NAME(whereFilter(_:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * contain the specified field and the value must be equal to the specified value.
 *
 * @param field The name of the field to compare.
 * @param value The value the field must be equal to.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereField:(NSString *)field
                    isEqualTo:(id)value NS_SWIFT_NAME(whereField(_:isEqualTo:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * contain the specified field and the value does not equal the specified value.
 *
 * @param path The path of the field to compare.
 * @param value The value the field must be equal to.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path
                     isNotEqualTo:(id)value NS_SWIFT_NAME(whereField(_:isNotEqualTo:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * contain the specified field and the value does not equal the specified value.
 *
 * @param field The name of the field to compare.
 * @param value The value the field must be equal to.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereField:(NSString *)field
                 isNotEqualTo:(id)value NS_SWIFT_NAME(whereField(_:isNotEqualTo:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * contain the specified field and the value must be equal to the specified value.
 *
 * @param path The path of the field to compare.
 * @param value The value the field must be equal to.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path
                        isEqualTo:(id)value NS_SWIFT_NAME(whereField(_:isEqualTo:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * contain the specified field and the value must be less than the specified value.
 *
 * @param field The name of the field to compare.
 * @param value The value the field must be less than.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereField:(NSString *)field
                   isLessThan:(id)value NS_SWIFT_NAME(whereField(_:isLessThan:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * contain the specified field and the value must be less than the specified value.
 *
 * @param path The path of the field to compare.
 * @param value The value the field must be less than.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path
                       isLessThan:(id)value NS_SWIFT_NAME(whereField(_:isLessThan:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * contain the specified field and the value must be less than or equal to the specified value.
 *
 * @param field The name of the field to compare
 * @param value The value the field must be less than or equal to.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereField:(NSString *)field
          isLessThanOrEqualTo:(id)value NS_SWIFT_NAME(whereField(_:isLessThanOrEqualTo:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * contain the specified field and the value must be less than or equal to the specified value.
 *
 * @param path The path of the field to compare
 * @param value The value the field must be less than or equal to.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path
              isLessThanOrEqualTo:(id)value NS_SWIFT_NAME(whereField(_:isLessThanOrEqualTo:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * contain the specified field and the value must greater than the specified value.
 *
 * @param field The name of the field to compare
 * @param value The value the field must be greater than.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereField:(NSString *)field
                isGreaterThan:(id)value NS_SWIFT_NAME(whereField(_:isGreaterThan:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * contain the specified field and the value must greater than the specified value.
 *
 * @param path The path of the field to compare
 * @param value The value the field must be greater than.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path
                    isGreaterThan:(id)value NS_SWIFT_NAME(whereField(_:isGreaterThan:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * contain the specified field and the value must be greater than or equal to the specified value.
 *
 * @param field The name of the field to compare
 * @param value The value the field must be greater than.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereField:(NSString *)field
       isGreaterThanOrEqualTo:(id)value NS_SWIFT_NAME(whereField(_:isGreaterThanOrEqualTo:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * contain the specified field and the value must be greater than or equal to the specified value.
 *
 * @param path The path of the field to compare
 * @param value The value the field must be greater than.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path
           isGreaterThanOrEqualTo:(id)value NS_SWIFT_NAME(whereField(_:isGreaterThanOrEqualTo:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must contain
 * the specified field, it must be an array, and the array must contain the provided value.
 *
 * A query can have only one `arrayContains` filter.
 *
 * @param field The name of the field containing an array to search
 * @param value The value that must be contained in the array
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereField:(NSString *)field
                arrayContains:(id)value NS_SWIFT_NAME(whereField(_:arrayContains:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must contain
 * the specified field, it must be an array, and the array must contain the provided value.
 *
 * A query can have only one `arrayContains` filter.
 *
 * @param path The path of the field containing an array to search
 * @param value The value that must be contained in the array
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path
                    arrayContains:(id)value NS_SWIFT_NAME(whereField(_:arrayContains:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must contain
 * the specified field, the value must be an array, and that array must contain at least one value
 * from the provided array.
 *
 * A query can have only one `arrayContainsAny` filter and it cannot be combined with
 * `arrayContains` or `in` filters.
 *
 * @param field The name of the field containing an array to search.
 * @param values The array that contains the values to match.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereField:(NSString *)field
             arrayContainsAny:(NSArray<id> *)values NS_SWIFT_NAME(whereField(_:arrayContainsAny:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must contain
 * the specified field, the value must be an array, and that array must contain at least one value
 * from the provided array.
 *
 * A query can have only one `arrayContainsAny` filter and it cannot be combined with
 * `arrayContains` or `in` filters.
 *
 * @param path The path of the field containing an array to search.
 * @param values The array that contains the values to match.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path
                 arrayContainsAny:(NSArray<id> *)values
    NS_SWIFT_NAME(whereField(_:arrayContainsAny:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must contain
 * the specified field and the value must equal one of the values from the provided array.
 *
 * A query can have only one `in` filter, and it cannot be combined with an `arrayContainsAny`
 * filter.
 *
 * @param field The name of the field to search.
 * @param values The array that contains the values to match.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereField:(NSString *)field
                           in:(NSArray<id> *)values NS_SWIFT_NAME(whereField(_:in:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must contain
 * the specified field and the value must equal one of the values from the provided array.
 *
 * A query can have only one `in` filter, and it cannot be combined with an `arrayContainsAny`
 * filter.
 *
 * @param path The path of the field to search.
 * @param values The array that contains the values to match.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path
                               in:(NSArray<id> *)values NS_SWIFT_NAME(whereField(_:in:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must contain
 * the specified field and the value does not equal any of the values from the provided array.
 *
 * One special case is that `notIn` filters cannot match `nil` values. To query for documents
 * where a field exists and is `nil`, use a `notEqual` filter, which can handle this special case.
 *
 * A query can have only one `notIn` filter, and it cannot be combined with an `arrayContains`,
 * `arrayContainsAny`, `in`, or `notEqual` filter.
 *
 * @param field The name of the field to search.
 * @param values The array that contains the values to match.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereField:(NSString *)field
                        notIn:(NSArray<id> *)values NS_SWIFT_NAME(whereField(_:notIn:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must contain
 * the specified field and the value does not equal any of the values from the provided array.
 *
 * One special case is that `notIn` filters cannot match `nil` values. To query for documents
 * where a field exists and is `nil`, use a `notEqual` filter, which can handle this special case.
 *
 * Passing in a `null` value into the `values` array results in no document matches. To query
 * for documents where a field is not `null`, use a `notEqual` filter.
 *
 * @param path The path of the field to search.
 * @param values The array that contains the values to match.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path
                            notIn:(NSArray<id> *)values NS_SWIFT_NAME(whereField(_:notIn:));

/**
 * Creates and returns a new `Query` with the additional filter that documents must
 * satisfy the specified predicate.
 *
 * @param predicate The predicate the document must satisfy. Can be either comparison
 *     or compound of comparison. In particular, block-based predicate is not supported.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryFilteredUsingPredicate:(NSPredicate *)predicate NS_SWIFT_NAME(filter(using:));

#pragma mark - Sorting Data
/**
 * Creates and returns a new `Query` that's additionally sorted by the specified field.
 *
 * @param field The field to sort by.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryOrderedByField:(NSString *)field NS_SWIFT_NAME(order(by:));

/**
 * Creates and returns a new `Query` that's additionally sorted by the specified field.
 *
 * @param path The field to sort by.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryOrderedByFieldPath:(FIRFieldPath *)path NS_SWIFT_NAME(order(by:));

/**
 * Creates and returns a new `Query` that's additionally sorted by the specified field,
 * optionally in descending order instead of ascending.
 *
 * @param field The field to sort by.
 * @param descending Whether to sort descending.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryOrderedByField:(NSString *)field
                       descending:(BOOL)descending NS_SWIFT_NAME(order(by:descending:));

/**
 * Creates and returns a new `Query` that's additionally sorted by the specified field,
 * optionally in descending order instead of ascending.
 *
 * @param path The field to sort by.
 * @param descending Whether to sort descending.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryOrderedByFieldPath:(FIRFieldPath *)path
                           descending:(BOOL)descending NS_SWIFT_NAME(order(by:descending:));

#pragma mark - Limiting Data
/**
 * Creates and returns a new `Query` that only returns the first matching documents up to
 * the specified number.
 *
 * @param limit The maximum number of items to return.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryLimitedTo:(NSInteger)limit NS_SWIFT_NAME(limit(to:));

/**
 * Creates and returns a new `Query` that only returns the last matching documents up to
 * the specified number.
 *
 * A query with a `limit(toLast:)` clause must have at least one `orderBy` clause.
 *
 * @param limit The maximum number of items to return.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryLimitedToLast:(NSInteger)limit NS_SWIFT_NAME(limit(toLast:));

#pragma mark - Choosing Endpoints
/**
 * Creates and returns a new `Query` that starts at the provided document (inclusive). The
 * starting position is relative to the order of the query. The document must contain all of the
 * fields provided in the orderBy of this query.
 *
 * @param document The snapshot of the document to start at.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryStartingAtDocument:(FIRDocumentSnapshot *)document
    NS_SWIFT_NAME(start(atDocument:));

/**
 * Creates and returns a new `Query` that starts at the provided fields relative to the order of
 * the query. The order of the field values must match the order of the order by clauses of the
 * query.
 *
 * @param fieldValues The field values to start this query at, in order of the query's order by.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryStartingAtValues:(NSArray *)fieldValues NS_SWIFT_NAME(start(at:));

/**
 * Creates and returns a new `Query` that starts after the provided document (exclusive). The
 * starting position is relative to the order of the query. The document must contain all of the
 * fields provided in the orderBy of this query.
 *
 * @param document The snapshot of the document to start after.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryStartingAfterDocument:(FIRDocumentSnapshot *)document
    NS_SWIFT_NAME(start(afterDocument:));

/**
 * Creates and returns a new `Query` that starts after the provided fields relative to the order
 * of the query. The order of the field values must match the order of the order by clauses of the
 * query.
 *
 * @param fieldValues The field values to start this query after, in order of the query's orderBy.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryStartingAfterValues:(NSArray *)fieldValues NS_SWIFT_NAME(start(after:));

/**
 * Creates and returns a new `Query` that ends before the provided document (exclusive). The end
 * position is relative to the order of the query. The document must contain all of the fields
 * provided in the orderBy of this query.
 *
 * @param document The snapshot of the document to end before.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryEndingBeforeDocument:(FIRDocumentSnapshot *)document
    NS_SWIFT_NAME(end(beforeDocument:));

/**
 * Creates and returns a new `Query` that ends before the provided fields relative to the order
 * of the query. The order of the field values must match the order of the order by clauses of the
 * query.
 *
 * @param fieldValues The field values to end this query before, in order of the query's order by.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryEndingBeforeValues:(NSArray *)fieldValues NS_SWIFT_NAME(end(before:));

/**
 * Creates and returns a new `Query` that ends at the provided document (exclusive). The end
 * position is relative to the order of the query. The document must contain all of the fields
 * provided in the orderBy of this query.
 *
 * @param document The snapshot of the document to end at.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryEndingAtDocument:(FIRDocumentSnapshot *)document NS_SWIFT_NAME(end(atDocument:));

/**
 * Creates and returns a new `Query` that ends at the provided fields relative to the order of
 * the query. The order of the field values must match the order of the order by clauses of the
 * query.
 *
 * @param fieldValues The field values to end this query at, in order of the query's order by.
 *
 * @return The created `Query`.
 */
- (FIRQuery *)queryEndingAtValues:(NSArray *)fieldValues NS_SWIFT_NAME(end(at:));

#pragma mark - Aggregation

/**
 * A query that counts the documents in the result set of this query without actually downloading
 * the documents.
 *
 * Using this `AggregateQuery` to count the documents is efficient because only the final count, not
 * the documents' data, is downloaded. The `AggregateQuery` can count the documents in cases where
 * the result set is prohibitively large to download entirely (thousands of documents).
 */
@property(nonatomic, readonly) FIRAggregateQuery *count;

/**
 * Creates and returns a new `AggregateQuery` that aggregates the documents in the result set
 * of this query without actually downloading the documents.
 *
 * Using an `AggregateQuery` to perform aggregations is efficient because only the final aggregation
 * values, not the documents' data, is downloaded. The returned `AggregateQuery` can perform
 * aggregations of the documents in cases where the result set is prohibitively large to download
 * entirely (thousands of documents).
 *
 * @param aggregateFields Specifies the aggregate operations to perform on the result set of this
 * query.
 *
 * @return An `AggregateQuery` encapsulating this `Query` and `AggregateField`s, which can be used
 * to query the server for the aggregation results.
 */
- (FIRAggregateQuery *)aggregate:(NSArray<FIRAggregateField *> *)aggregateFields
    NS_SWIFT_NAME(aggregate(_:));

@end

NS_ASSUME_NONNULL_END
