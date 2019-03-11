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

#import "FIRDocumentChange.h"

#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::ViewSnapshot;

NS_ASSUME_NONNULL_BEGIN

@interface FIRDocumentChange ()

- (instancetype)initWithType:(FIRDocumentChangeType)type
                    document:(FIRDocumentSnapshot *)document
                    oldIndex:(NSUInteger)oldIndex
                    newIndex:(NSUInteger)newIndex NS_DESIGNATED_INITIALIZER;

@end

@implementation FIRDocumentChange (Internal)

+ (FIRDocumentChangeType)documentChangeTypeForChange:(const DocumentViewChange &)change {
  switch (change.type()) {
    case DocumentViewChange::Type::kAdded:
      return FIRDocumentChangeTypeAdded;
    case DocumentViewChange::Type::kModified:
    case DocumentViewChange::Type::kMetadata:
      return FIRDocumentChangeTypeModified;
    case DocumentViewChange::Type::kRemoved:
      return FIRDocumentChangeTypeRemoved;
  }

  HARD_FAIL("Unknown DocumentViewChange::Type: %s", change.type());
}

+ (NSArray<FIRDocumentChange *> *)documentChangesForSnapshot:(const ViewSnapshot &)snapshot
                                      includeMetadataChanges:(BOOL)includeMetadataChanges
                                                   firestore:(FIRFirestore *)firestore {
  if (snapshot.old_documents().isEmpty) {
    // Special case the first snapshot because index calculation is easy and fast. Also all changes
    // on the first snapshot are adds so there are also no metadata-only changes to filter out.
    FSTDocument *_Nullable lastDocument = nil;
    NSUInteger index = 0;
    NSMutableArray<FIRDocumentChange *> *changes = [NSMutableArray array];
    for (const DocumentViewChange &change : snapshot.document_changes()) {
      FIRQueryDocumentSnapshot *document = [FIRQueryDocumentSnapshot
          snapshotWithFirestore:firestore
                    documentKey:change.document().key
                       document:change.document()
                      fromCache:snapshot.from_cache()
               hasPendingWrites:snapshot.mutated_keys().contains(change.document().key)];
      HARD_ASSERT(change.type() == DocumentViewChange::Type::kAdded,
                  "Invalid event type for first snapshot");
      HARD_ASSERT(!lastDocument || snapshot.query().comparator(lastDocument, change.document()) ==
                                       NSOrderedAscending,
                  "Got added events in wrong order");
      [changes addObject:[[FIRDocumentChange alloc] initWithType:FIRDocumentChangeTypeAdded
                                                        document:document
                                                        oldIndex:NSNotFound
                                                        newIndex:index++]];
    }
    return changes;
  } else {
    // A DocumentSet that is updated incrementally as changes are applied to use to lookup the index
    // of a document.
    FSTDocumentSet *indexTracker = snapshot.old_documents();
    NSMutableArray<FIRDocumentChange *> *changes = [NSMutableArray array];
    for (const DocumentViewChange &change : snapshot.document_changes()) {
      if (!includeMetadataChanges && change.type() == DocumentViewChange::Type::kMetadata) {
        continue;
      }

      FIRQueryDocumentSnapshot *document = [FIRQueryDocumentSnapshot
          snapshotWithFirestore:firestore
                    documentKey:change.document().key
                       document:change.document()
                      fromCache:snapshot.from_cache()
               hasPendingWrites:snapshot.mutated_keys().contains(change.document().key)];

      NSUInteger oldIndex = NSNotFound;
      NSUInteger newIndex = NSNotFound;
      if (change.type() != DocumentViewChange::Type::kAdded) {
        oldIndex = [indexTracker indexOfKey:change.document().key];
        HARD_ASSERT(oldIndex != NSNotFound, "Index for document not found");
        indexTracker = [indexTracker documentSetByRemovingKey:change.document().key];
      }
      if (change.type() != DocumentViewChange::Type::kRemoved) {
        indexTracker = [indexTracker documentSetByAddingDocument:change.document()];
        newIndex = [indexTracker indexOfKey:change.document().key];
      }
      [FIRDocumentChange documentChangeTypeForChange:change];
      FIRDocumentChangeType type = [FIRDocumentChange documentChangeTypeForChange:change];
      [changes addObject:[[FIRDocumentChange alloc] initWithType:type
                                                        document:document
                                                        oldIndex:oldIndex
                                                        newIndex:newIndex]];
    }
    return changes;
  }
}

@end

@implementation FIRDocumentChange

- (instancetype)initWithType:(FIRDocumentChangeType)type
                    document:(FIRQueryDocumentSnapshot *)document
                    oldIndex:(NSUInteger)oldIndex
                    newIndex:(NSUInteger)newIndex {
  if (self = [super init]) {
    _type = type;
    _document = document;
    _oldIndex = oldIndex;
    _newIndex = newIndex;
  }
  return self;
}

- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  if (![other isKindOfClass:[FIRDocumentChange class]]) return NO;

  FIRDocumentChange *change = (FIRDocumentChange *)other;
  return self.type == change.type && [self.document isEqual:change.document] &&
         self.oldIndex == change.oldIndex && self.newIndex == change.newIndex;
}

- (NSUInteger)hash {
  NSUInteger result = (NSUInteger)self.type;
  result = result * 31u + [self.document hash];
  result = result * 31u + (NSUInteger)self.oldIndex;
  result = result * 31u + (NSUInteger)self.newIndex;
  return result;
}

@end

NS_ASSUME_NONNULL_END
