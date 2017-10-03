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

#import "FIRDocumentReference+Internal.h"
#import "FIRFieldPath+Internal.h"
#import "FIRFirestore+Internal.h"
#import "FIRSnapshotMetadata+Internal.h"
#import "FSTDatabaseID.h"
#import "FSTDocument.h"
#import "FSTDocumentKey.h"
#import "FSTFieldValue.h"
#import "FSTPath.h"
#import "FSTUsageValidation.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRDocumentSnapshot ()

- (instancetype)initWithFirestore:(FIRFirestore *)firestore
                      documentKey:(FSTDocumentKey *)documentKey
                         document:(nullable FSTDocument *)document
                        fromCache:(BOOL)fromCache NS_DESIGNATED_INITIALIZER;

@property(nonatomic, strong, readonly) FIRFirestore *firestore;
@property(nonatomic, strong, readonly) FSTDocumentKey *internalKey;
@property(nonatomic, strong, readonly, nullable) FSTDocument *internalDocument;
@property(nonatomic, assign, readonly) BOOL fromCache;

@end

@implementation FIRDocumentSnapshot (Internal)

+ (instancetype)snapshotWithFirestore:(FIRFirestore *)firestore
                          documentKey:(FSTDocumentKey *)documentKey
                             document:(nullable FSTDocument *)document
                            fromCache:(BOOL)fromCache {
  return [[FIRDocumentSnapshot alloc] initWithFirestore:firestore
                                            documentKey:documentKey
                                               document:document
                                              fromCache:fromCache];
}

@end

@implementation FIRDocumentSnapshot {
  FIRSnapshotMetadata *_cachedMetadata;
}

@dynamic metadata;

- (instancetype)initWithFirestore:(FIRFirestore *)firestore
                      documentKey:(FSTDocumentKey *)documentKey
                         document:(nullable FSTDocument *)document
                        fromCache:(BOOL)fromCache {
  if (self = [super init]) {
    _firestore = firestore;
    _internalKey = documentKey;
    _internalDocument = document;
    _fromCache = fromCache;
  }
  return self;
}

@dynamic exists;

- (BOOL)exists {
  return _internalDocument != nil;
}

- (FIRDocumentReference *)reference {
  return [FIRDocumentReference referenceWithKey:self.internalKey firestore:self.firestore];
}

- (NSString *)documentID {
  return [self.internalKey.path lastSegment];
}

- (FIRSnapshotMetadata *)metadata {
  if (!_cachedMetadata) {
    _cachedMetadata = [FIRSnapshotMetadata
        snapshotMetadataWithPendingWrites:self.internalDocument.hasLocalMutations
                                fromCache:self.fromCache];
  }
  return _cachedMetadata;
}

- (NSDictionary<NSString *, id> *)data {
  FSTDocument *document = self.internalDocument;

  if (!document) {
    FSTThrowInvalidUsage(
        @"NonExistentDocumentException",
        @"Document '%@' doesn't exist. "
        @"Check document.exists to make sure the document exists before calling document.data.",
        self.internalKey);
  }

  return [self convertedObject:[self.internalDocument data]];
}

- (nullable id)objectForKeyedSubscript:(id)key {
  FIRFieldPath *fieldPath;

  if ([key isKindOfClass:[NSString class]]) {
    fieldPath = [FIRFieldPath pathWithDotSeparatedString:key];
  } else if ([key isKindOfClass:[FIRFieldPath class]]) {
    fieldPath = key;
  } else {
    FSTThrowInvalidArgument(@"Subscript key must be an NSString or FIRFieldPath.");
  }

  FSTFieldValue *fieldValue = [[self.internalDocument data] valueForPath:fieldPath.internalValue];
  return [self convertedValue:fieldValue];
}

- (id)convertedValue:(FSTFieldValue *)value {
  if ([value isKindOfClass:[FSTObjectValue class]]) {
    return [self convertedObject:(FSTObjectValue *)value];
  } else if ([value isKindOfClass:[FSTArrayValue class]]) {
    return [self convertedArray:(FSTArrayValue *)value];
  } else if ([value isKindOfClass:[FSTReferenceValue class]]) {
    FSTReferenceValue *ref = (FSTReferenceValue *)value;
    FSTDatabaseID *refDatabase = ref.databaseID;
    FSTDatabaseID *database = self.firestore.databaseID;
    if (![refDatabase isEqualToDatabaseId:database]) {
      // TODO(b/32073923): Log this as a proper warning.
      NSLog(
          @"WARNING: Document %@ contains a document reference within a different database "
           "(%@/%@) which is not supported. It will be treated as a reference within the "
           "current database (%@/%@) instead.",
          self.reference.path, refDatabase.projectID, refDatabase.databaseID, database.projectID,
          database.databaseID);
    }
    return [FIRDocumentReference referenceWithKey:ref.value firestore:self.firestore];
  } else {
    return value.value;
  }
}

- (NSDictionary<NSString *, id> *)convertedObject:(FSTObjectValue *)objectValue {
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  [objectValue.internalValue
      enumerateKeysAndObjectsUsingBlock:^(NSString *key, FSTFieldValue *value, BOOL *stop) {
        result[key] = [self convertedValue:value];
      }];
  return result;
}

- (NSArray<id> *)convertedArray:(FSTArrayValue *)arrayValue {
  NSArray<FSTFieldValue *> *internalValue = arrayValue.internalValue;
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:internalValue.count];
  [internalValue enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
    [result addObject:[self convertedValue:value]];
  }];
  return result;
}

@end

NS_ASSUME_NONNULL_END
