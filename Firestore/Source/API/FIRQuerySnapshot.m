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

#import "Firestore/Source/API/FIRQuerySnapshot+Internal.h"

#import "FIRSnapshotMetadata.h"
#import "Firestore/Source/API/FIRDocumentChange+Internal.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Util/FSTAssert.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRQuerySnapshot ()

- (instancetype)initWithFirestore:(FIRFirestore *)firestore
                    originalQuery:(FSTQuery *)query
                         snapshot:(FSTViewSnapshot *)snapshot
                         metadata:(FIRSnapshotMetadata *)metadata;

@property(nonatomic, strong, readonly) FIRFirestore *firestore;
@property(nonatomic, strong, readonly) FSTQuery *originalQuery;
@property(nonatomic, strong, readonly) FSTViewSnapshot *snapshot;

@end

@implementation FIRQuerySnapshot (Internal)

+ (instancetype)snapshotWithFirestore:(FIRFirestore *)firestore
                        originalQuery:(FSTQuery *)query
                             snapshot:(FSTViewSnapshot *)snapshot
                             metadata:(FIRSnapshotMetadata *)metadata {
  return [[FIRQuerySnapshot alloc] initWithFirestore:firestore
                                       originalQuery:query
                                            snapshot:snapshot
                                            metadata:metadata];
}

@end

@implementation FIRQuerySnapshot {
  // Cached value of the documents property.
  NSArray<FIRQueryDocumentSnapshot *> *_documents;

  // Cached value of the documentChanges property.
  NSArray<FIRDocumentChange *> *_documentChanges;
}

- (instancetype)initWithFirestore:(FIRFirestore *)firestore
                    originalQuery:(FSTQuery *)query
                         snapshot:(FSTViewSnapshot *)snapshot
                         metadata:(FIRSnapshotMetadata *)metadata {
  if (self = [super init]) {
    _firestore = firestore;
    _originalQuery = query;
    _snapshot = snapshot;
    _metadata = metadata;
  }
  return self;
}

@dynamic empty;

- (FIRQuery *)query {
  return [FIRQuery referenceWithQuery:self.originalQuery firestore:self.firestore];
}

- (BOOL)isEmpty {
  return self.snapshot.documents.isEmpty;
}

// This property is exposed as an NSInteger instead of an NSUInteger since (as of Xcode 8.1)
// Swift bridges NSUInteger as UInt, and we want to avoid forcing Swift users to cast their ints
// where we can. See cr/146959032 for additional context.
- (NSInteger)count {
  return self.snapshot.documents.count;
}

- (NSArray<FIRQueryDocumentSnapshot *> *)documents {
  if (!_documents) {
    FSTDocumentSet *documentSet = self.snapshot.documents;
    FIRFirestore *firestore = self.firestore;
    BOOL fromCache = self.metadata.fromCache;

    NSMutableArray<FIRQueryDocumentSnapshot *> *result = [NSMutableArray array];
    for (FSTDocument *document in documentSet.documentEnumerator) {
      [result addObject:[FIRQueryDocumentSnapshot snapshotWithFirestore:firestore
                                                            documentKey:document.key
                                                               document:document
                                                              fromCache:fromCache]];
    }

    _documents = result;
  }
  return _documents;
}

- (NSArray<FIRDocumentChange *> *)documentChanges {
  if (!_documentChanges) {
    _documentChanges =
        [FIRDocumentChange documentChangesForSnapshot:self.snapshot firestore:self.firestore];
  }
  return _documentChanges;
}

@end

NS_ASSUME_NONNULL_END
