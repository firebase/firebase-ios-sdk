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

#include <memory>
#include <utility>

#import "FIRDocumentReference.h"
#import "FIRFirestoreErrors.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFieldValue+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRFirestoreSource+Internal.h"
#import "Firestore/Source/API/FIRListenerRegistration+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/API/FIRQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTEventManager.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTFieldValue.h"

#include "Firestore/core/src/firebase/firestore/api/input_validation.h"
#include "Firestore/core/src/firebase/firestore/api/query_core.h"
#include "Firestore/core/src/firebase/firestore/core/direction.h"
#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"

namespace util = firebase::firestore::util;
using firebase::firestore::api::Firestore;
using firebase::firestore::api::ListenerRegistration;
using firebase::firestore::api::Query;
using firebase::firestore::api::QuerySnapshot;
using firebase::firestore::api::SnapshotMetadata;
using firebase::firestore::api::Source;
using firebase::firestore::api::ThrowInvalidArgument;
using firebase::firestore::core::AsyncEventListener;
using firebase::firestore::core::Direction;
using firebase::firestore::core::EventListener;
using firebase::firestore::core::Filter;
using firebase::firestore::core::ListenOptions;
using firebase::firestore::core::QueryListener;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::util::MakeNSError;
using firebase::firestore::util::StatusOr;

NS_ASSUME_NONNULL_BEGIN

namespace {

FieldPath MakeFieldPath(NSString *field) {
  return FieldPath::FromDotSeparatedString(util::MakeString(field));
}

FIRQuery *Wrap(Query &&query) {
  return [[FIRQuery alloc] initWithQuery:std::move(query)];
}

}  // namespace

@implementation FIRQuery {
  Query _query;
}

#pragma mark - Constructor Methods

- (instancetype)initWithQuery:(Query &&)query {
  if (self = [super init]) {
    _query = std::move(query);
  }
  return self;
}

- (instancetype)initWithQuery:(FSTQuery *)query firestore:(std::shared_ptr<Firestore>)firestore {
  return [self initWithQuery:Query{query, std::move(firestore)}];
}

#pragma mark - NSObject Methods

- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  auto otherQuery = static_cast<FIRQuery *>(other);
  return _query == otherQuery->_query;
}

- (NSUInteger)hash {
  return _query.Hash();
}

#pragma mark - Public Methods

- (FIRFirestore *)firestore {
  return [FIRFirestore recoverFromFirestore:_query.firestore()];
}

- (void)getDocumentsWithCompletion:(void (^)(FIRQuerySnapshot *_Nullable snapshot,
                                             NSError *_Nullable error))completion {
  _query.GetDocuments(Source::Default, [self wrapQuerySnapshotBlock:completion]);
}

- (void)getDocumentsWithSource:(FIRFirestoreSource)publicSource
                    completion:(void (^)(FIRQuerySnapshot *_Nullable snapshot,
                                         NSError *_Nullable error))completion {
  Source source = api::MakeSource(publicSource);
  _query.GetDocuments(source, [self wrapQuerySnapshotBlock:completion]);
}

- (id<FIRListenerRegistration>)addSnapshotListener:(FIRQuerySnapshotBlock)listener {
  return [self addSnapshotListenerWithIncludeMetadataChanges:NO listener:listener];
}

- (id<FIRListenerRegistration>)
    addSnapshotListenerWithIncludeMetadataChanges:(BOOL)includeMetadataChanges
                                         listener:(FIRQuerySnapshotBlock)listener {
  auto options = ListenOptions::FromIncludeMetadataChanges(includeMetadataChanges);
  return [self addSnapshotListenerInternalWithOptions:options listener:listener];
}

- (id<FIRListenerRegistration>)addSnapshotListenerInternalWithOptions:(ListenOptions)internalOptions
                                                             listener:
                                                                 (FIRQuerySnapshotBlock)listener {
  std::shared_ptr<Firestore> firestore = self.firestore.wrapped;
  FSTQuery *query = self.query;

  // Convert from ViewSnapshots to QuerySnapshots.
  auto view_listener = EventListener<ViewSnapshot>::Create(
      [listener, firestore, query](StatusOr<ViewSnapshot> maybe_snapshot) {
        if (!maybe_snapshot.status().ok()) {
          listener(nil, MakeNSError(maybe_snapshot.status()));
          return;
        }

        ViewSnapshot snapshot = std::move(maybe_snapshot).ValueOrDie();
        SnapshotMetadata metadata(snapshot.has_pending_writes(), snapshot.from_cache());

        listener([[FIRQuerySnapshot alloc] initWithFirestore:firestore
                                               originalQuery:query
                                                    snapshot:std::move(snapshot)
                                                    metadata:std::move(metadata)],
                 nil);
      });

  // Call the view_listener on the user Executor.
  auto async_listener = AsyncEventListener<ViewSnapshot>::Create(firestore->client().userExecutor,
                                                                 std::move(view_listener));

  std::shared_ptr<QueryListener> query_listener =
      [firestore->client() listenToQuery:query options:internalOptions listener:async_listener];

  return [[FSTListenerRegistration alloc]
      initWithRegistration:ListenerRegistration(firestore->client(), std::move(async_listener),
                                                std::move(query_listener))];
}

- (FIRQuery *)queryWhereField:(NSString *)field isEqualTo:(id)value {
  return [self queryWithFilterOperator:Filter::Operator::Equal field:field value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path isEqualTo:(id)value {
  return [self queryWithFilterOperator:Filter::Operator::Equal path:path.internalValue value:value];
}

- (FIRQuery *)queryWhereField:(NSString *)field isLessThan:(id)value {
  return [self queryWithFilterOperator:Filter::Operator::LessThan field:field value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path isLessThan:(id)value {
  return [self queryWithFilterOperator:Filter::Operator::LessThan
                                  path:path.internalValue
                                 value:value];
}

- (FIRQuery *)queryWhereField:(NSString *)field isLessThanOrEqualTo:(id)value {
  return [self queryWithFilterOperator:Filter::Operator::LessThanOrEqual field:field value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path isLessThanOrEqualTo:(id)value {
  return [self queryWithFilterOperator:Filter::Operator::LessThanOrEqual
                                  path:path.internalValue
                                 value:value];
}

- (FIRQuery *)queryWhereField:(NSString *)field isGreaterThan:(id)value {
  return [self queryWithFilterOperator:Filter::Operator::GreaterThan field:field value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path isGreaterThan:(id)value {
  return [self queryWithFilterOperator:Filter::Operator::GreaterThan
                                  path:path.internalValue
                                 value:value];
}

- (FIRQuery *)queryWhereField:(NSString *)field arrayContains:(id)value {
  return [self queryWithFilterOperator:Filter::Operator::ArrayContains field:field value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path arrayContains:(id)value {
  return [self queryWithFilterOperator:Filter::Operator::ArrayContains
                                  path:path.internalValue
                                 value:value];
}

- (FIRQuery *)queryWhereField:(NSString *)field isGreaterThanOrEqualTo:(id)value {
  return [self queryWithFilterOperator:Filter::Operator::GreaterThanOrEqual
                                 field:field
                                 value:value];
}

- (FIRQuery *)queryWhereFieldPath:(FIRFieldPath *)path isGreaterThanOrEqualTo:(id)value {
  return [self queryWithFilterOperator:Filter::Operator::GreaterThanOrEqual
                                  path:path.internalValue
                                 value:value];
}

- (FIRQuery *)queryFilteredUsingComparisonPredicate:(NSPredicate *)predicate {
  NSComparisonPredicate *comparison = (NSComparisonPredicate *)predicate;
  if (comparison.comparisonPredicateModifier != NSDirectPredicateModifier) {
    ThrowInvalidArgument("Invalid query. Predicate cannot have an aggregate modifier.");
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
    ThrowInvalidArgument(
        "Invalid query. Predicate comparisons must include a key path and a constant.");
  }
  // Fallback cases of unsupported comparison operator.
  switch (comparison.predicateOperatorType) {
    case NSCustomSelectorPredicateOperatorType:
      ThrowInvalidArgument("Invalid query. Custom predicate filters are not supported.");
      break;
    default:
      ThrowInvalidArgument("Invalid query. Operator type %s is not supported.",
                           comparison.predicateOperatorType);
  }
}

- (FIRQuery *)queryFilteredUsingCompoundPredicate:(NSPredicate *)predicate {
  NSCompoundPredicate *compound = (NSCompoundPredicate *)predicate;
  if (compound.compoundPredicateType != NSAndPredicateType || compound.subpredicates.count == 0) {
    ThrowInvalidArgument("Invalid query. Only compound queries using AND are supported.");
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
    ThrowInvalidArgument("Invalid query. Block-based predicates are not supported. Please use "
                         "predicateWithFormat to create predicates instead.");
  } else {
    ThrowInvalidArgument("Invalid query. Expect comparison or compound of comparison predicate. "
                         "Please use predicateWithFormat to create predicates.");
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
  return Wrap(_query.OrderBy(fieldPath.internalValue, Direction::FromDescending(descending)));
}

- (FIRQuery *)queryLimitedTo:(NSInteger)limit {
  return Wrap(_query.Limit(static_cast<int64_t>(limit)));
}

- (FIRQuery *)queryStartingAtDocument:(FIRDocumentSnapshot *)snapshot {
  FSTBound *bound = [self boundFromSnapshot:snapshot isBefore:YES];
  return Wrap(_query.StartAt(bound));
}

- (FIRQuery *)queryStartingAtValues:(NSArray *)fieldValues {
  FSTBound *bound = [self boundFromFieldValues:fieldValues isBefore:YES];
  return Wrap(_query.StartAt(bound));
}

- (FIRQuery *)queryStartingAfterDocument:(FIRDocumentSnapshot *)snapshot {
  FSTBound *bound = [self boundFromSnapshot:snapshot isBefore:NO];
  return Wrap(_query.StartAt(bound));
}

- (FIRQuery *)queryStartingAfterValues:(NSArray *)fieldValues {
  FSTBound *bound = [self boundFromFieldValues:fieldValues isBefore:NO];
  return Wrap(_query.StartAt(bound));
}

- (FIRQuery *)queryEndingBeforeDocument:(FIRDocumentSnapshot *)snapshot {
  FSTBound *bound = [self boundFromSnapshot:snapshot isBefore:YES];
  return Wrap(_query.EndAt(bound));
}

- (FIRQuery *)queryEndingBeforeValues:(NSArray *)fieldValues {
  FSTBound *bound = [self boundFromFieldValues:fieldValues isBefore:YES];
  return Wrap(_query.EndAt(bound));
}

- (FIRQuery *)queryEndingAtDocument:(FIRDocumentSnapshot *)snapshot {
  FSTBound *bound = [self boundFromSnapshot:snapshot isBefore:NO];
  return Wrap(_query.EndAt(bound));
}

- (FIRQuery *)queryEndingAtValues:(NSArray *)fieldValues {
  FSTBound *bound = [self boundFromFieldValues:fieldValues isBefore:NO];
  return Wrap(_query.EndAt(bound));
}

#pragma mark - Private Methods

- (FSTFieldValue *)parsedQueryValue:(id)value {
  return [self.firestore.dataConverter parsedQueryValue:value];
}

- (QuerySnapshot::Listener)wrapQuerySnapshotBlock:(FIRQuerySnapshotBlock)block {
  class Converter : public EventListener<QuerySnapshot> {
   public:
    explicit Converter(FIRQuerySnapshotBlock block) : block_(block) {
    }

    void OnEvent(StatusOr<QuerySnapshot> maybe_snapshot) override {
      if (maybe_snapshot.ok()) {
        FIRQuerySnapshot *result =
            [[FIRQuerySnapshot alloc] initWithSnapshot:std::move(maybe_snapshot).ValueOrDie()];
        block_(result, nil);
      } else {
        block_(nil, util::MakeNSError(maybe_snapshot.status()));
      }
    }

   private:
    FIRQuerySnapshotBlock block_;
  };

  return absl::make_unique<Converter>(block);
}

/** Private helper for all of the queryWhereField: methods. */
- (FIRQuery *)queryWithFilterOperator:(Filter::Operator)filterOperator
                                field:(NSString *)field
                                value:(id)value {
  return [self queryWithFilterOperator:filterOperator path:MakeFieldPath(field) value:value];
}

- (FIRQuery *)queryWithFilterOperator:(Filter::Operator)filterOperator
                                 path:(const FieldPath &)fieldPath
                                value:(id)value {
  FSTFieldValue *fieldValue = [self parsedQueryValue:value];
  auto describer = [value] { return util::MakeString(NSStringFromClass([value class])); };
  return Wrap(_query.Filter(fieldPath, filterOperator, fieldValue, describer));
}

/**
 * Create a FSTBound from a query given the document.
 *
 * Note that the FSTBound will always include the key of the document and the position will be
 * unambiguous.
 *
 * Will throw if the document does not contain all fields of the order by of
 * the query or if any of the fields in the order by are an uncommitted server
 * timestamp.
 */
- (FSTBound *)boundFromSnapshot:(FIRDocumentSnapshot *)snapshot isBefore:(BOOL)isBefore {
  if (![snapshot exists]) {
    ThrowInvalidArgument("Invalid query. You are trying to start or end a query using a document "
                         "that doesn't exist.");
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
      [components addObject:[FSTReferenceValue
                                referenceValue:[FSTDocumentKey keyWithDocumentKey:document.key]
                                    databaseID:self.firestore.databaseID]];
    } else {
      FSTFieldValue *value = [document fieldForPath:sortOrder.field];

      if (value.type == FieldValue::Type::ServerTimestamp) {
        ThrowInvalidArgument(
            "Invalid query. You are trying to start or end a query using a document for which the "
            "field '%s' is an uncommitted server timestamp. (Since the value of this field is "
            "unknown, you cannot start/end a query with it.)",
            sortOrder.field.CanonicalString());
      } else if (value != nil) {
        [components addObject:value];
      } else {
        ThrowInvalidArgument(
            "Invalid query. You are trying to start or end a query using a document for which the "
            "field '%s' (used as the order by) does not exist.",
            sortOrder.field.CanonicalString());
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
    ThrowInvalidArgument("Invalid query. You are trying to start or end a query using more values "
                         "than were specified in the order by.");
  }

  NSMutableArray<FSTFieldValue *> *components = [NSMutableArray array];
  [fieldValues enumerateObjectsUsingBlock:^(id rawValue, NSUInteger idx, BOOL *stop) {
    FSTSortOrder *sortOrder = explicitSortOrders[idx];
    FSTFieldValue *fieldValue = [self parsedQueryValue:rawValue];
    if (sortOrder.field.IsKeyFieldPath()) {
      if (fieldValue.type != FieldValue::Type::String) {
        ThrowInvalidArgument("Invalid query. Expected a string for the document ID.");
      }
      const std::string &documentID =
          static_cast<FSTDelegateValue *>(fieldValue).internalValue.string_value();
      if (![self.query isCollectionGroupQuery] && documentID.find('/') != std::string::npos) {
        ThrowInvalidArgument("Invalid query. When querying a collection and ordering by document "
                             "ID, you must pass a plain document ID, but '%s' contains a slash.",
                             documentID);
      }
      ResourcePath path = self.query.path.Append(ResourcePath::FromString(documentID));
      if (!DocumentKey::IsDocumentKey(path)) {
        ThrowInvalidArgument("Invalid query. When querying a collection group and ordering by "
                             "document ID, you must pass a value that results in a valid document "
                             "path, but '%s' is not because it contains an odd number of segments.",
                             path.CanonicalString());
      }
      DocumentKey key{path};
      fieldValue = [FSTReferenceValue referenceValue:[FSTDocumentKey keyWithDocumentKey:key]
                                          databaseID:self.firestore.databaseID];
    }

    [components addObject:fieldValue];
  }];

  return [FSTBound boundWithPosition:components isBefore:isBefore];
}

@end

@implementation FIRQuery (Internal)

- (FSTQuery *)query {
  return _query.query();
}

@end

NS_ASSUME_NONNULL_END
