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

#include <utility>

#import "Firestore/Source/API/FIRQuerySnapshot+Internal.h"

#import "FIRFirestore.h"
#import "FIRSnapshotMetadata.h"
#import "Firestore/Source/API/FIRDocumentChange+Internal.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"

using firebase::firestore::core::ViewSnapshot;

NS_ASSUME_NONNULL_BEGIN

@interface FIRQuerySnapshot ()

- (instancetype)initWithFirestore:(FIRFirestore *)firestore
                    originalQuery:(FSTQuery *)query
                         snapshot:(ViewSnapshot &&)snapshot
                         metadata:(FIRSnapshotMetadata *)metadata;

@property(nonatomic, strong, readonly) FIRFirestore *firestore;
@property(nonatomic, strong, readonly) FSTQuery *originalQuery;
- (const ViewSnapshot &)snapshot;

@end

@implementation FIRQuerySnapshot (Internal)

+ (instancetype)snapshotWithFirestore:(FIRFirestore *)firestore
                        originalQuery:(FSTQuery *)query
                             snapshot:(ViewSnapshot)snapshot
                             metadata:(FIRSnapshotMetadata *)metadata {
  return [[FIRQuerySnapshot alloc] initWithFirestore:firestore
                                       originalQuery:query
                                            snapshot:std::move(snapshot)
                                            metadata:metadata];
}

@end

@implementation FIRQuerySnapshot {
  // Cached value of the documents property.
  NSArray<FIRQueryDocumentSnapshot *> *_documents;

  // Cached value of the documentChanges property.
  NSArray<FIRDocumentChange *> *_documentChanges;
  BOOL _documentChangesIncludeMetadataChanges;

  ViewSnapshot _snapshot;
}

- (instancetype)initWithFirestore:(FIRFirestore *)firestore
                    originalQuery:(FSTQuery *)query
                         snapshot:(ViewSnapshot &&)snapshot
                         metadata:(FIRSnapshotMetadata *)metadata {
  if (self = [super init]) {
    _firestore = firestore;
    _originalQuery = query;
    _snapshot = std::move(snapshot);
    _metadata = metadata;
    _documentChangesIncludeMetadataChanges = NO;
  }
  return self;
}

- (const ViewSnapshot &)snapshot {
  return _snapshot;
}

// NSObject Methods
- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  if (![[other class] isEqual:[self class]]) return NO;

  return [self isEqualToSnapshot:other];
}

- (BOOL)isEqualToSnapshot:(nullable FIRQuerySnapshot *)snapshot {
  if (self == snapshot) return YES;
  if (snapshot == nil) return NO;

  return [self.firestore isEqual:snapshot.firestore] &&
         [self.originalQuery isEqual:snapshot.originalQuery] && _snapshot == snapshot.snapshot &&
         [self.metadata isEqual:snapshot.metadata];
}

- (NSUInteger)hash {
  NSUInteger hash = [self.firestore hash];
  hash = hash * 31u + [self.originalQuery hash];
  hash = hash * 31u + _snapshot.Hash();
  hash = hash * 31u + [self.metadata hash];
  return hash;
}

@dynamic empty;

- (FIRQuery *)query {
  return [FIRQuery referenceWithQuery:self.originalQuery firestore:self.firestore];
}

- (BOOL)isEmpty {
  return _snapshot.documents().isEmpty;
}

// This property is exposed as an NSInteger instead of an NSUInteger since (as of Xcode 8.1)
// Swift bridges NSUInteger as UInt, and we want to avoid forcing Swift users to cast their ints
// where we can. See cr/146959032 for additional context.
- (NSInteger)count {
  return _snapshot.documents().count;
}

- (NSArray<FIRQueryDocumentSnapshot *> *)documents {
  if (!_documents) {
    FSTDocumentSet *documentSet = _snapshot.documents();
    FIRFirestore *firestore = self.firestore;
    BOOL fromCache = self.metadata.fromCache;

    NSMutableArray<FIRQueryDocumentSnapshot *> *result = [NSMutableArray array];
    for (FSTDocument *document in documentSet.documentEnumerator) {
      [result addObject:[FIRQueryDocumentSnapshot
                            snapshotWithFirestore:firestore
                                      documentKey:document.key
                                         document:document
                                        fromCache:fromCache
                                 hasPendingWrites:_snapshot.mutated_keys().contains(document.key)]];
    }

    _documents = result;
  }
  return _documents;
}

- (NSArray<FIRDocumentChange *> *)documentChanges {
  return [self documentChangesWithIncludeMetadataChanges:NO];
}

- (NSArray<FIRDocumentChange *> *)documentChangesWithIncludeMetadataChanges:
    (BOOL)includeMetadataChanges {
  if (includeMetadataChanges && _snapshot.excludes_metadata_changes()) {
    FSTThrowInvalidArgument(
        @"To include metadata changes with your document changes, you must call "
        @"addSnapshotListener(includeMetadataChanges: true).");
  }

  if (!_documentChanges || _documentChangesIncludeMetadataChanges != includeMetadataChanges) {
    _documentChanges = [FIRDocumentChange documentChangesForSnapshot:_snapshot
                                              includeMetadataChanges:includeMetadataChanges
                                                           firestore:self.firestore];
    _documentChangesIncludeMetadataChanges = includeMetadataChanges;
  }
  return _documentChanges;
}

@end

NS_ASSUME_NONNULL_END
