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

#import "FIRDocumentReference+Internal.h"
#import "FIRDocumentReference.h"
#import "FIRDocumentSnapshot+Internal.h"
#import "FIRFieldPath+Internal.h"
#import "FIRFirestore+Internal.h"
#import "FIRListenerRegistration+Internal.h"
#import "FIRQuery+Internal.h"
#import "FIRQuerySnapshot+Internal.h"
#import "FIRQuery_Init.h"
#import "FIRSnapshotMetadata+Internal.h"
#import "FSTAssert.h"
#import "FSTAsyncQueryListener.h"
#import "FSTDocument.h"
#import "FSTDocumentKey.h"
#import "FSTEventManager.h"
#import "FSTFieldValue.h"
#import "FSTFirestoreClient.h"
#import "FSTPath.h"
#import "FSTQuery.h"
#import "FSTUsageValidation.h"
#import "FSTUserDataConverter.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRQueryListenOptions ()

- (instancetype)initWithIncludeQueryMetadataChanges:(BOOL)includeQueryMetadataChanges
                     includeDocumentMetadataChanges:(BOOL)includeDocumentMetadataChanges
    NS_DESIGNATED_INITIALIZER;

@end

@implementation FIRQueryListenOptions

+ (instancetype)options {
  return [[FIRQueryListenOptions alloc] init];
}

- (instancetype)initWithIncludeQueryMetadataChanges:(BOOL)includeQueryMetadataChanges
                     includeDocumentMetadataChanges:(BOOL)includeDocumentMetadataChanges {
  if (self = [super init]) {
    _includeQueryMetadataChanges = includeQueryMetadataChanges;
    _includeDocumentMetadataChanges = includeDocumentMetadataChanges;
  }
  return self;
}

- (instancetype)init {
  return [self initWithIncludeQueryMetadataChanges:NO includeDocumentMetadataChanges:NO];
}

- (instancetype)includeQueryMetadataChanges:(BOOL)includeQueryMetadataChanges {
  return [[FIRQueryListenOptions alloc]
      initWithIncludeQueryMetadataChanges:includeQueryMetadataChanges
           includeDocumentMetadataChanges:_includeDocumentMetadataChanges];
}

- (instancetype)includeDocumentMetadataChanges:(BOOL)includeDocumentMetadataChanges {
  return [[FIRQueryListenOptions alloc]
      initWithIncludeQueryMetadataChanges:_includeQueryMetadataChanges
           includeDocumentMetadataChanges:includeDocumentMetadataChanges];
}

@end

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
  if (!other || ![[other class] isEqual:[self class]]) return NO;

  return [self isEqualToQuery:other];
}

- (BOOL)isEqualToQuery:(nullable FIRQuery *)query {
  if (self == query) return YES;
  if (query == nil) return NO;
  if (self.firestore != query.firestore && ![self.firestore isEqual:query.firestore]) return NO;
  if (self.query != query.query && ![self.query isEqual:query.query]) return NO;
  return YES;
}

- (NSUInteger)hash {
  NSUInteger hash = [self.firestore hash];
  hash = hash * 31u + [self.query hash];
  return hash;
}

#pragma mark - Public Methods

- (void)getDocumentsWithCompletion:(void (^)(FIRQuerySnapshot *_Nullable snapshot,
                                             NSError *_Nullable error))completion {
  FSTListenOptions *options = [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:YES
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

    completion(snapshot, nil);
  };

  listenerRegistration = [self addSnapshotListenerInternalWithOptions:options listener:listener];
  dispatch_semaphore_signal(registered);
}

- (id<FIRListenerRegistration>)addSnapshotListener:(FIRQuerySnapshotBlock)listener {
  return [self addSnapshotListenerWithOptions:nil listener:listener];
}

- (id<FIRListenerRegistration>)addSnapshotListenerWithOptions:
                                   (nullable FIRQueryListenOptions *)options
                                                     listener:(FIRQuerySnapshotBlock)listener {
  return [self addSnapshotListenerInternalWithOptions:[self internalOptions:options]
                                             listener:listener];
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
      [[FSTAsyncQueryListener alloc] initWithDispatchQueue:self.firestore.client.userDispatchQueue
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
  return
      [self queryWithFilterOperator:FSTRelationFilterOperatorGreaterThan field:field value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path isGreaterThan:(id)value {
  return [self queryWithFilterOperator:FSTRelationFilterOperatorGreaterThan
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

- (FIRQuery *)queryOrderedByField:(NSString *)field {
  return
      [self queryOrderedByFieldPath:[FIRFieldPath pathWithDotSeparatedString:field] descending:NO];
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
  FSTSortOrder *sortOrder =
      [FSTSortOrder sortOrderWithFieldPath:fieldPath.internalValue ascending:!descending];
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
  return
      [FIRQuery referenceWithQuery:[self.query queryByAddingEndAt:bound] firestore:self.firestore];
}

- (FIRQuery *)queryEndingBeforeValues:(NSArray *)fieldValues {
  FSTBound *bound = [self boundFromFieldValues:fieldValues isBefore:YES];
  return
      [FIRQuery referenceWithQuery:[self.query queryByAddingEndAt:bound] firestore:self.firestore];
}

- (FIRQuery *)queryEndingAtDocument:(FIRDocumentSnapshot *)snapshot {
  FSTBound *bound = [self boundFromSnapshot:snapshot isBefore:NO];
  return
      [FIRQuery referenceWithQuery:[self.query queryByAddingEndAt:bound] firestore:self.firestore];
}

- (FIRQuery *)queryEndingAtValues:(NSArray *)fieldValues {
  FSTBound *bound = [self boundFromFieldValues:fieldValues isBefore:NO];
  return
      [FIRQuery referenceWithQuery:[self.query queryByAddingEndAt:bound] firestore:self.firestore];
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
                                 path:(FSTFieldPath *)fieldPath
                                value:(id)value {
  FSTFieldValue *fieldValue;
  if ([fieldPath isKeyFieldPath]) {
    if ([value isKindOfClass:[NSString class]]) {
      NSString *documentKey = (NSString *)value;
      if ([documentKey containsString:@"/"]) {
        FSTThrowInvalidArgument(
            @"Invalid query. When querying by document ID you must provide "
             "a valid document ID, but '%@' contains a '/' character.",
            documentKey);
      } else if (documentKey.length == 0) {
        FSTThrowInvalidArgument(
            @"Invalid query. When querying by document ID you must provide "
             "a valid document ID, but it was an empty string.");
      }
      FSTResourcePath *path = [self.query.path pathByAppendingSegment:documentKey];
      fieldValue = [FSTReferenceValue referenceValue:[FSTDocumentKey keyWithPath:path]
                                          databaseID:self.firestore.databaseID];
    } else if ([value isKindOfClass:[FIRDocumentReference class]]) {
      FIRDocumentReference *ref = (FIRDocumentReference *)value;
      fieldValue = [FSTReferenceValue referenceValue:ref.key databaseID:self.firestore.databaseID];
    } else {
      FSTThrowInvalidArgument(
          @"Invalid query. When querying by document ID you must provide a "
           "valid string or DocumentReference, but it was of type: %@",
          NSStringFromClass([value class]));
    }
  } else {
    fieldValue = [self.firestore.dataConverter parsedQueryValue:value];
  }

  id<FSTFilter> filter;
  if ([fieldValue isEqual:[FSTNullValue nullValue]]) {
    if (filterOperator != FSTRelationFilterOperatorEqual) {
      FSTThrowInvalidUsage(@"InvalidQueryException",
                           @"Invalid Query. You can only perform equality comparisons on nil / "
                            "NSNull.");
    }
    filter = [[FSTNullFilter alloc] initWithField:fieldPath];
  } else if ([fieldValue isEqual:[FSTDoubleValue nanValue]]) {
    if (filterOperator != FSTRelationFilterOperatorEqual) {
      FSTThrowInvalidUsage(@"InvalidQueryException",
                           @"Invalid Query. You can only perform equality comparisons on NaN.");
    }
    filter = [[FSTNanFilter alloc] initWithField:fieldPath];
  } else {
    filter = [FSTRelationFilter filterWithField:fieldPath
                                 filterOperator:filterOperator
                                          value:fieldValue];
    [self validateNewRelationFilter:filter];
  }
  return [FIRQuery referenceWithQuery:[self.query queryByAddingFilter:filter]
                            firestore:self.firestore];
}

- (void)validateNewRelationFilter:(FSTRelationFilter *)filter {
  if ([filter isInequality]) {
    FSTFieldPath *existingField = [self.query inequalityFilterField];
    if (existingField && ![existingField isEqual:filter.field]) {
      FSTThrowInvalidUsage(
          @"InvalidQueryException",
          @"Invalid Query. All where filters with an inequality "
           "(lessThan, lessThanOrEqual, greaterThan, or greaterThanOrEqual) must be on the same "
           "field. But you have inequality filters on '%@' and '%@'",
          existingField, filter.field);
    }

    FSTFieldPath *firstOrderByField = [self.query firstSortOrderField];
    if (firstOrderByField) {
      [self validateOrderByField:firstOrderByField matchesInequalityField:filter.field];
    }
  }
}

- (void)validateNewOrderByPath:(FSTFieldPath *)fieldPath {
  if (![self.query firstSortOrderField]) {
    // This is the first order by. It must match any inequality.
    FSTFieldPath *inequalityField = [self.query inequalityFilterField];
    if (inequalityField) {
      [self validateOrderByField:fieldPath matchesInequalityField:inequalityField];
    }
  }
}

- (void)validateOrderByField:(FSTFieldPath *)orderByField
      matchesInequalityField:(FSTFieldPath *)inequalityField {
  if (!([orderByField isEqual:inequalityField])) {
    FSTThrowInvalidUsage(
        @"InvalidQueryException",
        @"Invalid query. You have a where filter with an "
         "inequality (lessThan, lessThanOrEqual, greaterThan, or greaterThanOrEqual) on field '%@' "
         "and so you must also use '%@' as your first queryOrderedBy field, but your first "
         "queryOrderedBy is currently on field '%@' instead.",
        inequalityField, inequalityField, orderByField);
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
    if ([sortOrder.field isEqual:[FSTFieldPath keyFieldPath]]) {
      [components addObject:[FSTReferenceValue referenceValue:document.key
                                                   databaseID:self.firestore.databaseID]];
    } else {
      FSTFieldValue *value = [document fieldForPath:sortOrder.field];
      if (value != nil) {
        [components addObject:value];
      } else {
        FSTThrowInvalidUsage(@"InvalidQueryException",
                             @"Invalid query. You are trying to start or end a query using a "
                              "document for which the field '%@' (used as the order by) "
                              "does not exist.",
                             sortOrder.field.canonicalString);
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
    if ([sortOrder.field isEqual:[FSTFieldPath keyFieldPath]]) {
      if (![rawValue isKindOfClass:[NSString class]]) {
        FSTThrowInvalidUsage(@"InvalidQueryException",
                             @"Invalid query. Expected a string for the document ID.");
      }
      NSString *documentID = (NSString *)rawValue;
      if ([documentID containsString:@"/"]) {
        FSTThrowInvalidUsage(@"InvalidQueryException",
                             @"Invalid query. Document ID '%@' contains a slash.", documentID);
      }
      FSTDocumentKey *key =
          [FSTDocumentKey keyWithPath:[self.query.path pathByAppendingSegment:documentID]];
      [components
          addObject:[FSTReferenceValue referenceValue:key databaseID:self.firestore.databaseID]];
    } else {
      FSTFieldValue *fieldValue = [self.firestore.dataConverter parsedQueryValue:rawValue];
      [components addObject:fieldValue];
    }
  }];

  return [FSTBound boundWithPosition:components isBefore:isBefore];
}

/** Converts the public API options object to the internal options object. */
- (FSTListenOptions *)internalOptions:(nullable FIRQueryListenOptions *)options {
  return [[FSTListenOptions alloc]
      initWithIncludeQueryMetadataChanges:options.includeQueryMetadataChanges
           includeDocumentMetadataChanges:options.includeDocumentMetadataChanges
                    waitForSyncWhenOnline:NO];
}

@end

NS_ASSUME_NONNULL_END
