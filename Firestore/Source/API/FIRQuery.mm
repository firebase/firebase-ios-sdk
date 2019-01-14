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

#import "FIRQuery.h"

#import "FIRDocumentReference.h"
#import "FIRFirestoreErrors.h"
#import "FIRFirestoreSource.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRListenerRegistration+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FIRQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRQuery_Init.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTEventManager.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Util/FSTAsyncQueryListener.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::ResourcePath;

NS_ASSUME_NONNULL_BEGIN

@interface FIRQuery ()
@property(nonatomic, strong, readonly) FSTQuery *query;
@end

@implementation FIRQuery (Internal)
+ (instancetype)referenceWithQuery:(FSTQuery *)query firestore:(FIRFirestore *)firestore {
  return [[FIRQuery alloc] initWithQuery:query firestore:firestore];
}
@end

@implementation FIRQuery

#pragma mark - Constructor Methods

- (instancetype)initWithQuery:(FSTQuery *)query firestore:(FIRFirestore *)firestore {
  if (self = [super init]) {
    _query = query;
    _firestore = firestore;
  }
  return self;
}

#pragma mark - NSObject Methods

- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  return [self isEqualToQuery:other];
}

- (BOOL)isEqualToQuery:(nullable FIRQuery *)query {
  if (self == query) return YES;
  if (query == nil) return NO;

  return [self.firestore isEqual:query.firestore] && [self.query isEqual:query.query];
}

- (NSUInteger)hash {
  NSUInteger hash = [self.firestore hash];
  hash = hash * 31u + [self.query hash];
  return hash;
}

#pragma mark - Public Methods

- (void)getDocumentsWithCompletion:(void (^)(FIRQuerySnapshot *_Nullable snapshot,
                                             NSError *_Nullable error))completion {
  [self getDocumentsWithSource:FIRFirestoreSourceDefault completion:completion];
}

- (void)getDocumentsWithSource:(FIRFirestoreSource)source
                    completion:(void (^)(FIRQuerySnapshot *_Nullable snapshot,
                                         NSError *_Nullable error))completion {
  if (source == FIRFirestoreSourceCache) {
    [self.firestore.client getDocumentsFromLocalCache:self completion:completion];
    return;
  }

  FSTListenOptions *listenOptions =
      [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:YES
                                     includeDocumentMetadataChanges:YES
                                              waitForSyncWhenOnline:YES];

  dispatch_semaphore_t registered = dispatch_semaphore_create(0);
  __block id<FIRListenerRegistration> listenerRegistration;
  FIRQuerySnapshotBlock listener = ^(FIRQuerySnapshot *snapshot, NSError *error) {
    if (error) {
      completion(nil, error);
      return;
    }

    // Remove query first before passing event to user to avoid user actions affecting the
    // now stale query.
    dispatch_semaphore_wait(registered, DISPATCH_TIME_FOREVER);
    [listenerRegistration remove];

    if (snapshot.metadata.fromCache && source == FIRFirestoreSourceServer) {
      completion(nil,
                 [NSError errorWithDomain:FIRFirestoreErrorDomain
                                     code:FIRFirestoreErrorCodeUnavailable
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Failed to get documents from server. (However, these "
                                       @"documents may exist in the local cache. Run again "
                                       @"without setting source to FIRFirestoreSourceServer to "
                                       @"retrieve the cached documents.)"
                                 }]);
    } else {
      completion(snapshot, nil);
    }
  };

  listenerRegistration = [self addSnapshotListenerInternalWithOptions:listenOptions
                                                             listener:listener];
  dispatch_semaphore_signal(registered);
}

- (id<FIRListenerRegistration>)addSnapshotListener:(FIRQuerySnapshotBlock)listener {
  return [self addSnapshotListenerWithIncludeMetadataChanges:NO listener:listener];
}

- (id<FIRListenerRegistration>)
    addSnapshotListenerWithIncludeMetadataChanges:(BOOL)includeMetadataChanges
                                         listener:(FIRQuerySnapshotBlock)listener {
  auto options = [self internalOptionsForIncludeMetadataChanges:includeMetadataChanges];
  return [self addSnapshotListenerInternalWithOptions:options listener:listener];
}

- (id<FIRListenerRegistration>)
    addSnapshotListenerInternalWithOptions:(FSTListenOptions *)internalOptions
                                  listener:(FIRQuerySnapshotBlock)listener {
  FIRFirestore *firestore = self.firestore;
  FSTQuery *query = self.query;

  FSTViewSnapshotHandler snapshotHandler = ^(FSTViewSnapshot *snapshot, NSError *error) {
    if (error) {
      listener(nil, error);
      return;
    }

    FIRSnapshotMetadata *metadata =
        [FIRSnapshotMetadata snapshotMetadataWithPendingWrites:snapshot.hasPendingWrites
                                                     fromCache:snapshot.fromCache];

    listener([FIRQuerySnapshot snapshotWithFirestore:firestore
                                       originalQuery:query
                                            snapshot:snapshot
                                            metadata:metadata],
             nil);
  };

  FSTAsyncQueryListener *asyncListener =
      [[FSTAsyncQueryListener alloc] initWithExecutor:self.firestore.client.userExecutor
                                      snapshotHandler:snapshotHandler];

  FSTQueryListener *internalListener =
      [firestore.client listenToQuery:query
                              options:internalOptions
                  viewSnapshotHandler:[asyncListener asyncSnapshotHandler]];
  return [[FSTListenerRegistration alloc] initWithClient:self.firestore.client
                                           asyncListener:asyncListener
                                        internalListener:internalListener];
}

- (FIRQuery *)queryWhereField:(NSString *)field isEqualTo:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorEqual field:field value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path isEqualTo:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorEqual
                                  path:path.internalValue
                                 value:value];
}

- (FIRQuery *)queryWhereField:(NSString *)field isLessThan:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorLessThan field:field value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path isLessThan:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorLessThan
                                  path:path.internalValue
                                 value:value];
}

- (FIRQuery *)queryWhereField:(NSString *)field isLessThanOrEqualTo:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorLessThanOrEqual
                                 field:field
                                 value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path isLessThanOrEqualTo:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorLessThanOrEqual
                                  path:path.internalValue
                                 value:value];
}

- (FIRQuery *)queryWhereField:(NSString *)field isGreaterThan:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorGreaterThan
                                 field:field
                                 value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path isGreaterThan:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorGreaterThan
                                  path:path.internalValue
                                 value:value];
}

- (FIRQuery *)queryWhereField:(NSString *)field arrayContains:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorArrayContains
                                 field:field
                                 value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path arrayContains:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorArrayContains
                                  path:path.internalValue
                                 value:value];
}

- (FIRQuery *)queryWhereField:(NSString *)field isGreaterThanOrEqualTo:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorGreaterThanOrEqual
                                 field:field
                                 value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path isGreaterThanOrEqualTo:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorGreaterThanOrEqual
                                  path:path.internalValue
                                 value:value];
}

- (FIRQuery *)queryFilteredUsingComparisonPredicate:(NSPredicate *)predicate {
  NSComparisonPredicate *comparison = (NSComparisonPredicate *)predicate;
  if (comparison.comparisonPredicateModifier != NSDirectPredicateModifier) {
    FSTThrowInvalidArgument(@"Invalid query. Predicate cannot have an aggregate modifier.");
  }
  NSString *path;
  id value = nil;
  if ([comparison.leftExpression expressionType] == NSKeyPathExpressionType &&
      [comparison.rightExpression expressionType] == NSConstantValueExpressionType) {
    path = comparison.leftExpression.keyPath;
    value = comparison.rightExpression.constantValue;
    switch (comparison.predicateOperatorType) {
      case NSEqualToPredicateOperatorType:
        return [self queryWhereField:path isEqualTo:value];
      case NSLessThanPredicateOperatorType:
        return [self queryWhereField:path isLessThan:value];
      case NSLessThanOrEqualToPredicateOperatorType:
        return [self queryWhereField:path isLessThanOrEqualTo:value];
      case NSGreaterThanPredicateOperatorType:
        return [self queryWhereField:path isGreaterThan:value];
      case NSGreaterThanOrEqualToPredicateOperatorType:
        return [self queryWhereField:path isGreaterThanOrEqualTo:value];
      default:;  // Fallback below to throw assertion.
    }
  } else if ([comparison.leftExpression expressionType] == NSConstantValueExpressionType &&
             [comparison.rightExpression expressionType] == NSKeyPathExpressionType) {
    path = comparison.rightExpression.keyPath;
    value = comparison.leftExpression.constantValue;
    switch (comparison.predicateOperatorType) {
      case NSEqualToPredicateOperatorType:
        return [self queryWhereField:path isEqualTo:value];
      case NSLessThanPredicateOperatorType:
        return [self queryWhereField:path isGreaterThan:value];
      case NSLessThanOrEqualToPredicateOperatorType:
        return [self queryWhereField:path isGreaterThanOrEqualTo:value];
      case NSGreaterThanPredicateOperatorType:
        return [self queryWhereField:path isLessThan:value];
      case NSGreaterThanOrEqualToPredicateOperatorType:
        return [self queryWhereField:path isLessThanOrEqualTo:value];
      default:;  // Fallback below to throw assertion.
    }
  } else {
    FSTThrowInvalidArgument(
        @"Invalid query. Predicate comparisons must include a key path and a constant.");
  }
  // Fallback cases of unsupported comparison operator.
  switch (comparison.predicateOperatorType) {
    case NSCustomSelectorPredicateOperatorType:
      FSTThrowInvalidArgument(@"Invalid query. Custom predicate filters are not supported.");
      break;
    default:
      FSTThrowInvalidArgument(@"Invalid query. Operator type %lu is not supported.",
                              (unsigned long)comparison.predicateOperatorType);
  }
}

- (FIRQuery *)queryFilteredUsingCompoundPredicate:(NSPredicate *)predicate {
  NSCompoundPredicate *compound = (NSCompoundPredicate *)predicate;
  if (compound.compoundPredicateType != NSAndPredicateType || compound.subpredicates.count == 0) {
    FSTThrowInvalidArgument(@"Invalid query. Only compound queries using AND are supported.");
  }
  FIRQuery *query = self;
  for (NSPredicate *pred in compound.subpredicates) {
    query = [query queryFilteredUsingPredicate:pred];
  }
  return query;
}

- (FIRQuery *)queryFilteredUsingPredicate:(NSPredicate *)predicate {
  if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
    return [self queryFilteredUsingComparisonPredicate:predicate];
  } else if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
    return [self queryFilteredUsingCompoundPredicate:predicate];
  } else if ([predicate isKindOfClass:[[NSPredicate
                                          predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
                                            return true;
                                          }] class]]) {
    FSTThrowInvalidArgument(@"Invalid query. Block-based predicates are not "
                             "supported. Please use predicateWithFormat to "
                             "create predicates instead.");
  } else {
    FSTThrowInvalidArgument(@"Invalid query. Expect comparison or compound of "
                             "comparison predicate. Please use "
                             "predicateWithFormat to create predicates.");
  }
}

- (FIRQuery *)queryOrderedByField:(NSString *)field {
  return [self queryOrderedByFieldPath:[FIRFieldPath pathWithDotSeparatedString:field]
                            descending:NO];
}

- (FIRQuery *)queryOrderedByFieldPath:(FIRFieldPath *)fieldPath {
  return [self queryOrderedByFieldPath:fieldPath descending:NO];
}

- (FIRQuery *)queryOrderedByField:(NSString *)field descending:(BOOL)descending {
  return [self queryOrderedByFieldPath:[FIRFieldPath pathWithDotSeparatedString:field]
                            descending:descending];
}

- (FIRQuery *)queryOrderedByFieldPath:(FIRFieldPath *)fieldPath descending:(BOOL)descending {
  [self validateNewOrderByPath:fieldPath.internalValue];
  if (self.query.startAt) {
    FSTThrowInvalidUsage(
        @"InvalidQueryException",
        @"Invalid query. You must not specify a starting point before specifying the order by.");
  }
  if (self.query.endAt) {
    FSTThrowInvalidUsage(
        @"InvalidQueryException",
        @"Invalid query. You must not specify an ending point before specifying the order by.");
  }
  FSTSortOrder *sortOrder = [FSTSortOrder sortOrderWithFieldPath:fieldPath.internalValue
                                                       ascending:!descending];
  return [FIRQuery referenceWithQuery:[self.query queryByAddingSortOrder:sortOrder]
                            firestore:self.firestore];
}

- (FIRQuery *)queryLimitedTo:(NSInteger)limit {
  if (limit <= 0) {
    FSTThrowInvalidArgument(@"Invalid Query. Query limit (%ld) is invalid. Limit must be positive.",
                            (long)limit);
  }
  return [FIRQuery referenceWithQuery:[self.query queryBySettingLimit:limit] firestore:_firestore];
}

- (FIRQuery *)queryStartingAtDocument:(FIRDocumentSnapshot *)snapshot {
  FSTBound *bound = [self boundFromSnapshot:snapshot isBefore:YES];
  return [FIRQuery referenceWithQuery:[self.query queryByAddingStartAt:bound]
                            firestore:self.firestore];
}

- (FIRQuery *)queryStartingAtValues:(NSArray *)fieldValues {
  FSTBound *bound = [self boundFromFieldValues:fieldValues isBefore:YES];
  return [FIRQuery referenceWithQuery:[self.query queryByAddingStartAt:bound]
                            firestore:self.firestore];
}

- (FIRQuery *)queryStartingAfterDocument:(FIRDocumentSnapshot *)snapshot {
  FSTBound *bound = [self boundFromSnapshot:snapshot isBefore:NO];
  return [FIRQuery referenceWithQuery:[self.query queryByAddingStartAt:bound]
                            firestore:self.firestore];
}

- (FIRQuery *)queryStartingAfterValues:(NSArray *)fieldValues {
  FSTBound *bound = [self boundFromFieldValues:fieldValues isBefore:NO];
  return [FIRQuery referenceWithQuery:[self.query queryByAddingStartAt:bound]
                            firestore:self.firestore];
}

- (FIRQuery *)queryEndingBeforeDocument:(FIRDocumentSnapshot *)snapshot {
  FSTBound *bound = [self boundFromSnapshot:snapshot isBefore:YES];
  return [FIRQuery referenceWithQuery:[self.query queryByAddingEndAt:bound]
                            firestore:self.firestore];
}

- (FIRQuery *)queryEndingBeforeValues:(NSArray *)fieldValues {
  FSTBound *bound = [self boundFromFieldValues:fieldValues isBefore:YES];
  return [FIRQuery referenceWithQuery:[self.query queryByAddingEndAt:bound]
                            firestore:self.firestore];
}

- (FIRQuery *)queryEndingAtDocument:(FIRDocumentSnapshot *)snapshot {
  FSTBound *bound = [self boundFromSnapshot:snapshot isBefore:NO];
  return [FIRQuery referenceWithQuery:[self.query queryByAddingEndAt:bound]
                            firestore:self.firestore];
}

- (FIRQuery *)queryEndingAtValues:(NSArray *)fieldValues {
  FSTBound *bound = [self boundFromFieldValues:fieldValues isBefore:NO];
  return [FIRQuery referenceWithQuery:[self.query queryByAddingEndAt:bound]
                            firestore:self.firestore];
}

#pragma mark - Private Methods

/** Private helper for all of the queryWhereField: methods. */
- (FIRQuery *)queryWithFilterOperator:(FSTRelationFilterOperator)filterOperator
                                field:(NSString *)field
                                value:(id)value {
  return [self queryWithFilterOperator:filterOperator
                                  path:[FIRFieldPath pathWithDotSeparatedString:field].internalValue
                                 value:value];
}

- (FIRQuery *)queryWithFilterOperator:(FSTRelationFilterOperator)filterOperator
                                 path:(const FieldPath &)fieldPath
                                value:(id)value {
  FSTFieldValue *fieldValue;
  if (fieldPath.IsKeyFieldPath()) {
    if (filterOperator == FSTRelationFilterOperatorArrayContains) {
      FSTThrowInvalidArgument(
          @"Invalid query. You can't perform arrayContains queries on document ID since document "
           "IDs are not arrays.");
    }
    if ([value isKindOfClass:[NSString class]]) {
      NSString *documentKey = (NSString *)value;
      if ([documentKey containsString:@"/"]) {
        FSTThrowInvalidArgument(@"Invalid query. When querying by document ID you must provide "
                                 "a valid document ID, but '%@' contains a '/' character.",
                                documentKey);
      } else if (documentKey.length == 0) {
        FSTThrowInvalidArgument(@"Invalid query. When querying by document ID you must provide "
                                 "a valid document ID, but it was an empty string.");
      }
      ResourcePath path = self.query.path.Append([documentKey UTF8String]);
      fieldValue = [FSTReferenceValue referenceValue:DocumentKey{path}
                                          databaseID:self.firestore.databaseID];
    } else if ([value isKindOfClass:[FIRDocumentReference class]]) {
      FIRDocumentReference *ref = (FIRDocumentReference *)value;
      fieldValue = [FSTReferenceValue referenceValue:ref.key databaseID:self.firestore.databaseID];
    } else {
      FSTThrowInvalidArgument(@"Invalid query. When querying by document ID you must provide a "
                               "valid string or DocumentReference, but it was of type: %@",
                              NSStringFromClass([value class]));
    }
  } else {
    fieldValue = [self.firestore.dataConverter parsedQueryValue:value];
  }

  FSTFilter *filter = [FSTFilter filterWithField:fieldPath
                                  filterOperator:filterOperator
                                           value:fieldValue];

  if ([filter isKindOfClass:[FSTRelationFilter class]]) {
    [self validateNewRelationFilter:(FSTRelationFilter *)filter];
  }

  return [FIRQuery referenceWithQuery:[self.query queryByAddingFilter:filter]
                            firestore:self.firestore];
}

- (void)validateNewRelationFilter:(FSTRelationFilter *)filter {
  if ([filter isInequality]) {
    const FieldPath *existingField = [self.query inequalityFilterField];
    if (existingField && *existingField != filter.field) {
      FSTThrowInvalidUsage(
          @"InvalidQueryException",
          @"Invalid Query. All where filters with an inequality "
           "(lessThan, lessThanOrEqual, greaterThan, or greaterThanOrEqual) must be on the same "
           "field. But you have inequality filters on '%s' and '%s'",
          existingField->CanonicalString().c_str(), filter.field.CanonicalString().c_str());
    }

    const FieldPath *firstOrderByField = [self.query firstSortOrderField];
    if (firstOrderByField) {
      [self validateOrderByField:*firstOrderByField matchesInequalityField:filter.field];
    }
  } else if (filter.filterOperator == FSTRelationFilterOperatorArrayContains) {
    if ([self.query hasArrayContainsFilter]) {
      FSTThrowInvalidUsage(@"InvalidQueryException",
                           @"Invalid Query. Queries only support a single arrayContains filter.");
    }
  }
}

- (void)validateNewOrderByPath:(const FieldPath &)fieldPath {
  if (![self.query firstSortOrderField]) {
    // This is the first order by. It must match any inequality.
    const FieldPath *inequalityField = [self.query inequalityFilterField];
    if (inequalityField) {
      [self validateOrderByField:fieldPath matchesInequalityField:*inequalityField];
    }
  }
}

- (void)validateOrderByField:(const FieldPath &)orderByField
      matchesInequalityField:(const FieldPath &)inequalityField {
  if (orderByField != inequalityField) {
    FSTThrowInvalidUsage(
        @"InvalidQueryException",
        @"Invalid query. You have a where filter with an "
         "inequality (lessThan, lessThanOrEqual, greaterThan, or greaterThanOrEqual) on field '%s' "
         "and so you must also use '%s' as your first queryOrderedBy field, but your first "
         "queryOrderedBy is currently on field '%s' instead.",
        inequalityField.CanonicalString().c_str(), inequalityField.CanonicalString().c_str(),
        orderByField.CanonicalString().c_str());
  }
}

/**
 * Create a FSTBound from a query given the document.
 *
 * Note that the FSTBound will always include the key of the document and the position will be
 * unambiguous.
 *
 * Will throw if the document does not contain all fields of the order by of the query.
 */
- (FSTBound *)boundFromSnapshot:(FIRDocumentSnapshot *)snapshot isBefore:(BOOL)isBefore {
  if (![snapshot exists]) {
    FSTThrowInvalidUsage(@"InvalidQueryException",
                         @"Invalid query. You are trying to start or end a query using a document "
                         @"that doesn't exist.");
  }
  FSTDocument *document = snapshot.internalDocument;
  NSMutableArray<FSTFieldValue *> *components = [NSMutableArray array];

  // Because people expect to continue/end a query at the exact document provided, we need to
  // use the implicit sort order rather than the explicit sort order, because it's guaranteed to
  // contain the document key. That way the position becomes unambiguous and the query
  // continues/ends exactly at the provided document. Without the key (by using the explicit sort
  // orders), multiple documents could match the position, yielding duplicate results.
  for (FSTSortOrder *sortOrder in self.query.sortOrders) {
    if (sortOrder.field == FieldPath::KeyFieldPath()) {
      [components addObject:[FSTReferenceValue referenceValue:document.key
                                                   databaseID:self.firestore.databaseID]];
    } else {
      FSTFieldValue *value = [document fieldForPath:sortOrder.field];
      if (value != nil) {
        [components addObject:value];
      } else {
        FSTThrowInvalidUsage(@"InvalidQueryException",
                             @"Invalid query. You are trying to start or end a query using a "
                              "document for which the field '%s' (used as the order by) "
                              "does not exist.",
                             sortOrder.field.CanonicalString().c_str());
      }
    }
  }
  return [FSTBound boundWithPosition:components isBefore:isBefore];
}

/** Converts a list of field values to an FSTBound. */
- (FSTBound *)boundFromFieldValues:(NSArray<id> *)fieldValues isBefore:(BOOL)isBefore {
  // Use explicit sort order because it has to match the query the user made
  NSArray<FSTSortOrder *> *explicitSortOrders = self.query.explicitSortOrders;
  if (fieldValues.count > explicitSortOrders.count) {
    FSTThrowInvalidUsage(@"InvalidQueryException",
                         @"Invalid query. You are trying to start or end a query using more values "
                         @"than were specified in the order by.");
  }

  NSMutableArray<FSTFieldValue *> *components = [NSMutableArray array];
  [fieldValues enumerateObjectsUsingBlock:^(id rawValue, NSUInteger idx, BOOL *stop) {
    FSTSortOrder *sortOrder = explicitSortOrders[idx];
    if (sortOrder.field == FieldPath::KeyFieldPath()) {
      if (![rawValue isKindOfClass:[NSString class]]) {
        FSTThrowInvalidUsage(@"InvalidQueryException",
                             @"Invalid query. Expected a string for the document ID.");
      }
      NSString *documentID = (NSString *)rawValue;
      if ([documentID containsString:@"/"]) {
        FSTThrowInvalidUsage(@"InvalidQueryException",
                             @"Invalid query. Document ID '%@' contains a slash.", documentID);
      }
      const DocumentKey key{self.query.path.Append([documentID UTF8String])};
      [components addObject:[FSTReferenceValue referenceValue:key
                                                   databaseID:self.firestore.databaseID]];
    } else {
      FSTFieldValue *fieldValue = [self.firestore.dataConverter parsedQueryValue:rawValue];
      [components addObject:fieldValue];
    }
  }];

  return [FSTBound boundWithPosition:components isBefore:isBefore];
}

/** Converts the public API options object to the internal options object. */
- (FSTListenOptions *)internalOptionsForIncludeMetadataChanges:(BOOL)includeMetadataChanges {
  return [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:includeMetadataChanges
                                        includeDocumentMetadataChanges:includeMetadataChanges
                                                 waitForSyncWhenOnline:NO];
}

@end

NS_ASSUME_NONNULL_END
