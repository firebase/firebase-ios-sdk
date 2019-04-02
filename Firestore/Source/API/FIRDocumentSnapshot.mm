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

#import "FIRDocumentSnapshot.h"

#include <utility>

#include "Firestore/core/src/firebase/firestore/util/warnings.h"

#import "FIRFirestoreSettings.h"

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTFieldValue.h"

#include "Firestore/core/src/firebase/firestore/api/document_snapshot.h"
#include "Firestore/core/src/firebase/firestore/api/firestore.h"
#include "Firestore/core/src/firebase/firestore/api/input_validation.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::api::DocumentSnapshot;
using firebase::firestore::api::Firestore;
using firebase::firestore::api::ThrowInvalidArgument;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldValue;
using firebase::firestore::util::WrapNSString;

NS_ASSUME_NONNULL_BEGIN

namespace {

/**
 * Converts a public FIRServerTimestampBehavior into its internal equivalent.
 */
ServerTimestampBehavior InternalServerTimestampBehavior(FIRServerTimestampBehavior behavior) {
  switch (behavior) {
    case FIRServerTimestampBehaviorNone:
      return ServerTimestampBehavior::None;
    case FIRServerTimestampBehaviorEstimate:
      return ServerTimestampBehavior::Estimate;
    case FIRServerTimestampBehaviorPrevious:
      return ServerTimestampBehavior::Previous;
    default:
      HARD_FAIL("Unexpected server timestamp option: %s", behavior);
  }
}

}  // namespace

@implementation FIRDocumentSnapshot {
  DocumentSnapshot _snapshot;

  FIRSnapshotMetadata *_cachedMetadata;
}

- (instancetype)initWithSnapshot:(DocumentSnapshot &&)snapshot {
  if (self = [super init]) {
    _snapshot = std::move(snapshot);
  }
  return self;
}

- (instancetype)initWithFirestore:(Firestore *)firestore
                      documentKey:(DocumentKey)documentKey
                         document:(nullable FSTDocument *)document
                         metadata:(SnapshotMetadata)metadata {
  DocumentSnapshot wrapped{firestore, std::move(documentKey), document, std::move(metadata)};
  return [self initWithSnapshot:std::move(wrapped)];
}

- (instancetype)initWithFirestore:(Firestore *)firestore
                      documentKey:(DocumentKey)documentKey
                         document:(nullable FSTDocument *)document
                        fromCache:(bool)fromCache
                 hasPendingWrites:(bool)hasPendingWrites {
  return [self initWithFirestore:firestore
                     documentKey:std::move(documentKey)
                        document:document
                        metadata:SnapshotMetadata(hasPendingWrites, fromCache)];
}

// NSObject Methods
- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  // self class could be FIRDocumentSnapshot or subtype. So we compare with base type explicitly.
  if (![other isKindOfClass:[FIRDocumentSnapshot class]]) return NO;

  return _snapshot == static_cast<FIRDocumentSnapshot *>(other)->_snapshot;
}

- (NSUInteger)hash {
  return _snapshot.Hash();
}

@dynamic exists;

- (BOOL)exists {
  return _snapshot.exists();
}

- (FSTDocument *)internalDocument {
  return _snapshot.internal_document();
}

- (FIRDocumentReference *)reference {
  return [[FIRDocumentReference alloc] initWithReference:_snapshot.CreateReference()];
}

- (NSString *)documentID {
  return WrapNSString(_snapshot.document_id());
}

@dynamic metadata;

- (FIRSnapshotMetadata *)metadata {
  if (!_cachedMetadata) {
    _cachedMetadata = [[FIRSnapshotMetadata alloc] initWithMetadata:_snapshot.metadata()];
  }
  return _cachedMetadata;
}

- (nullable NSDictionary<NSString *, id> *)data {
  return [self dataWithServerTimestampBehavior:FIRServerTimestampBehaviorNone];
}

- (nullable NSDictionary<NSString *, id> *)dataWithServerTimestampBehavior:
    (FIRServerTimestampBehavior)serverTimestampBehavior {
  FSTFieldValueOptions *options = [self optionsForServerTimestampBehavior:serverTimestampBehavior];
  FSTObjectValue *data = _snapshot.GetData();
  return data == nil ? nil : [self convertedObject:data options:options];
}

- (nullable id)valueForField:(id)field {
  return [self valueForField:field serverTimestampBehavior:FIRServerTimestampBehaviorNone];
}

- (nullable id)valueForField:(id)field
     serverTimestampBehavior:(FIRServerTimestampBehavior)serverTimestampBehavior {
  FIRFieldPath *fieldPath;
  if ([field isKindOfClass:[NSString class]]) {
    fieldPath = [FIRFieldPath pathWithDotSeparatedString:field];
  } else if ([field isKindOfClass:[FIRFieldPath class]]) {
    fieldPath = field;
  } else {
    ThrowInvalidArgument("Subscript key must be an NSString or FIRFieldPath.");
  }

  FSTFieldValue *fieldValue = _snapshot.GetValue(fieldPath.internalValue);
  FSTFieldValueOptions *options = [self optionsForServerTimestampBehavior:serverTimestampBehavior];
  return fieldValue == nil ? nil : [self convertedValue:fieldValue options:options];
}

- (nullable id)objectForKeyedSubscript:(id)key {
  return [self valueForField:key];
}

- (FSTFieldValueOptions *)optionsForServerTimestampBehavior:
    (FIRServerTimestampBehavior)serverTimestampBehavior {
  SUPPRESS_DEPRECATED_DECLARATIONS_BEGIN()
  return [[FSTFieldValueOptions alloc]
      initWithServerTimestampBehavior:InternalServerTimestampBehavior(serverTimestampBehavior)
         timestampsInSnapshotsEnabled:_snapshot.firestore()
                                          ->settings()
                                          .timestampsInSnapshotsEnabled];
  SUPPRESS_END()
}

- (id)convertedValue:(FSTFieldValue *)value options:(FSTFieldValueOptions *)options {
  if (value.type == FieldValue::Type::Object) {
    return [self convertedObject:(FSTObjectValue *)value options:options];
  } else if (value.type == FieldValue::Type::Array) {
    return [self convertedArray:(FSTArrayValue *)value options:options];
  } else if (value.type == FieldValue::Type::Reference) {
    FSTReferenceValue *ref = (FSTReferenceValue *)value;
    const DatabaseId *refDatabase = ref.databaseID;
    const DatabaseId *database = &_snapshot.firestore()->database_id();
    if (*refDatabase != *database) {
      // TODO(b/32073923): Log this as a proper warning.
      NSLog(@"WARNING: Document %@ contains a document reference within a different database "
             "(%s/%s) which is not supported. It will be treated as a reference within the "
             "current database (%s/%s) instead.",
            self.reference.path, refDatabase->project_id().c_str(),
            refDatabase->database_id().c_str(), database->project_id().c_str(),
            database->database_id().c_str());
    }
    DocumentKey key = [[ref valueWithOptions:options] key];
    return [[FIRDocumentReference alloc] initWithKey:key firestore:_snapshot.firestore()];
  } else {
    return [value valueWithOptions:options];
  }
}

- (NSDictionary<NSString *, id> *)convertedObject:(FSTObjectValue *)objectValue
                                          options:(FSTFieldValueOptions *)options {
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  [objectValue.internalValue
      enumerateKeysAndObjectsUsingBlock:^(NSString *key, FSTFieldValue *value, BOOL *stop) {
        result[key] = [self convertedValue:value options:options];
      }];
  return result;
}

- (NSArray<id> *)convertedArray:(FSTArrayValue *)arrayValue
                        options:(FSTFieldValueOptions *)options {
  NSArray<FSTFieldValue *> *internalValue = arrayValue.internalValue;
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:internalValue.count];
  [internalValue enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
    [result addObject:[self convertedValue:value options:options]];
  }];
  return result;
}

@end

@implementation FIRQueryDocumentSnapshot

- (NSDictionary<NSString *, id> *)data {
  NSDictionary<NSString *, id> *data = [super data];
  HARD_ASSERT(data, "Document in a QueryDocumentSnapshot should exist");
  return data;
}

- (NSDictionary<NSString *, id> *)dataWithServerTimestampBehavior:
    (FIRServerTimestampBehavior)serverTimestampBehavior {
  NSDictionary<NSString *, id> *data =
      [super dataWithServerTimestampBehavior:serverTimestampBehavior];
  HARD_ASSERT(data, "Document in a QueryDocumentSnapshot should exist");
  return data;
}

@end

NS_ASSUME_NONNULL_END
