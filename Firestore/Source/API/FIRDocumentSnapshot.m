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

#import "FIRDocumentSnapshot+Internal.h"
#import "FSTAssert.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/API/FIRSnapshotOptions+Internal.h"
#import "Firestore/Source/Model/FSTDatabaseID.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRSnapshotOptions ()

@property(nonatomic, assign) FSTServerTimestampBehavior serverTimestampBehavior;

@end

@implementation FIRSnapshotOptions

@synthesize serverTimestampBehavior;

- (instancetype)initWithServerTimestampBehavior:
    (FSTServerTimestampBehavior)serverTimestampBehavior {
  self = [super init];

  if (self) {
    self.serverTimestampBehavior = serverTimestampBehavior;
  }
  return self;
}

+ (instancetype)defaultOptions {
  static FIRSnapshotOptions *sharedInstance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    sharedInstance = [[FIRSnapshotOptions alloc]
        initWithServerTimestampBehavior:FSTServerTimestampBehaviorDefault];
  });

  return sharedInstance;
}

+ (instancetype)setServerTimestampBehavior:(FIRServerTimestampBehavior)serverTimestampBehavior {
  switch (serverTimestampBehavior) {
    case FIRServerTimestampBehaviorEstimate:
      return [[FIRSnapshotOptions alloc]
          initWithServerTimestampBehavior:FSTServerTimestampBehaviorEstimate];
    case FIRServerTimestampBehaviorPrevious:
      return [[FIRSnapshotOptions alloc]
          initWithServerTimestampBehavior:FSTServerTimestampBehaviorPrevious];
    default:
      FSTFail(@"Encountered unknown server timestamp behavior: %d", (int)serverTimestampBehavior);
  }
}

@end

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
  return [self dataWithOptions:[FIRSnapshotOptions defaultOptions]];
}

- (NSDictionary<NSString *, id> *)dataWithOptions:(FIRSnapshotOptions *)options {
  FSTDocument *document = self.internalDocument;

  if (!document) {
    FSTThrowInvalidUsage(
        @"NonExistentDocumentException",
        @"Document '%@' doesn't exist. "
        @"Check document.exists to make sure the document exists before calling document.data.",
        self.internalKey);
  }

  return [self convertedObject:[self.internalDocument data]
       serverTimestampBehavior:options.serverTimestampBehavior];
}

- (nullable id)valueForField:(id)field {
  return [self valueForField:field options:[FIRSnapshotOptions defaultOptions]];
}

- (nullable id)valueForField:(id)field options:(FIRSnapshotOptions *)options {
  FIRFieldPath *fieldPath;

  if ([field isKindOfClass:[NSString class]]) {
    fieldPath = [FIRFieldPath pathWithDotSeparatedString:field];
  } else if ([field isKindOfClass:[FIRFieldPath class]]) {
    fieldPath = field;
  } else {
    FSTThrowInvalidArgument(@"Subscript key must be an NSString or FIRFieldPath.");
  }

  FSTFieldValue *fieldValue = [[self.internalDocument data] valueForPath:fieldPath.internalValue];
  return [self convertedValue:fieldValue serverTimestampBehavior:options.serverTimestampBehavior];
}

- (nullable id)objectForKeyedSubscript:(id)key {
  return [self valueForField:key];
}

- (id)convertedValue:(FSTFieldValue *)value
    serverTimestampBehavior:(FSTServerTimestampBehavior)serverTimestampBehavior {
  if ([value isKindOfClass:[FSTObjectValue class]]) {
    return [self convertedObject:(FSTObjectValue *)value
         serverTimestampBehavior:serverTimestampBehavior];
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
    return [FIRDocumentReference referenceWithKey:[ref value] firestore:self.firestore];
  } else if ([value isKindOfClass:[FSTServerTimestampValue class]]) {
    return
        [(FSTServerTimestampValue *)value valueWithServerTimestampBehavior:serverTimestampBehavior];
  } else {
    return value.value;
  }
}

- (NSDictionary<NSString *, id> *)convertedObject:(FSTObjectValue *)objectValue
                          serverTimestampBehavior:
                              (FSTServerTimestampBehavior)serverTimestampBehavior {
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  [objectValue.internalValue
      enumerateKeysAndObjectsUsingBlock:^(NSString *key, FSTFieldValue *value, BOOL *stop) {
        result[key] = [self convertedValue:value serverTimestampBehavior:serverTimestampBehavior];
      }];
  return result;
}

- (NSArray<id> *)convertedArray:(FSTArrayValue *)arrayValue {
  NSArray<FSTFieldValue *> *internalValue = arrayValue.internalValue;
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:internalValue.count];
  [internalValue enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
    [result addObject:[self convertedValue:value
                          serverTimestampBehavior:FSTServerTimestampBehaviorDefault]];
  }];
  return result;
}

@end

NS_ASSUME_NONNULL_END
