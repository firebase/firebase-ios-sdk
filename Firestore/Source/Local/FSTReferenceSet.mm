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

#import "Firestore/Source/Local/FSTReferenceSet.h"

#import "Firestore/Source/Local/FSTDocumentReference.h"
#import "Firestore/third_party/Immutable/FSTImmutableSortedSet.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTReferenceSet

@interface FSTReferenceSet ()

/** A set of outstanding references to a document sorted by key. */
@property(nonatomic, strong) FSTImmutableSortedSet<FSTDocumentReference *> *referencesByKey;

/** A set of outstanding references to a document sorted by target ID (or batch ID). */
@property(nonatomic, strong) FSTImmutableSortedSet<FSTDocumentReference *> *referencesByID;

@end

@implementation FSTReferenceSet

#pragma mark - Initializer

- (instancetype)init {
  self = [super init];
  if (self) {
    _referencesByKey =
        [FSTImmutableSortedSet setWithComparator:FSTDocumentReferenceComparatorByKey];
    _referencesByID = [FSTImmutableSortedSet setWithComparator:FSTDocumentReferenceComparatorByID];
  }
  return self;
}

#pragma mark - Testing helper methods

- (BOOL)isEmpty {
  return [self.referencesByKey isEmpty];
}

- (NSUInteger)count {
  return self.referencesByKey.count;
}

#pragma mark - Public methods

- (void)addReferenceToKey:(const DocumentKey &)key forID:(int)ID {
  FSTDocumentReference *reference = [[FSTDocumentReference alloc] initWithKey:key ID:ID];
  self.referencesByKey = [self.referencesByKey setByAddingObject:reference];
  self.referencesByID = [self.referencesByID setByAddingObject:reference];
}

- (void)addReferencesToKeys:(const DocumentKeySet &)keys forID:(int)ID {
  for (const DocumentKey &key : keys) {
    [self addReferenceToKey:key forID:ID];
  }
}

- (void)removeReferenceToKey:(const DocumentKey &)key forID:(int)ID {
  [self removeReference:[[FSTDocumentReference alloc] initWithKey:key ID:ID]];
}

- (void)removeReferencesToKeys:(const DocumentKeySet &)keys forID:(int)ID {
  for (const DocumentKey &key : keys) {
    [self removeReferenceToKey:key forID:ID];
  }
}

- (DocumentKeySet)removeReferencesForID:(int)ID {
  FSTDocumentReference *start =
      [[FSTDocumentReference alloc] initWithKey:DocumentKey::Empty() ID:ID];
  FSTDocumentReference *end =
      [[FSTDocumentReference alloc] initWithKey:DocumentKey::Empty() ID:(ID + 1)];

  __block DocumentKeySet keys;
  [self.referencesByID enumerateObjectsFrom:start
                                         to:end
                                 usingBlock:^(FSTDocumentReference *reference, BOOL *stop) {
                                   [self removeReference:reference];
                                   keys = keys.insert(reference.key);
                                 }];
  return keys;
}

- (void)removeAllReferences {
  for (FSTDocumentReference *reference in self.referencesByKey.objectEnumerator) {
    [self removeReference:reference];
  }
}

- (void)removeReference:(FSTDocumentReference *)reference {
  self.referencesByKey = [self.referencesByKey setByRemovingObject:reference];
  self.referencesByID = [self.referencesByID setByRemovingObject:reference];
}

- (DocumentKeySet)referencedKeysForID:(int)ID {
  FSTDocumentReference *start =
      [[FSTDocumentReference alloc] initWithKey:DocumentKey::Empty() ID:ID];
  FSTDocumentReference *end =
      [[FSTDocumentReference alloc] initWithKey:DocumentKey::Empty() ID:(ID + 1)];

  __block DocumentKeySet keys;
  [self.referencesByID enumerateObjectsFrom:start
                                         to:end
                                 usingBlock:^(FSTDocumentReference *reference, BOOL *stop) {
                                   keys = keys.insert(reference.key);
                                 }];
  return keys;
}

- (BOOL)containsKey:(const DocumentKey &)key {
  // Create a reference with a zero ID as the start position to find any document reference with
  // this key.
  FSTDocumentReference *reference = [[FSTDocumentReference alloc] initWithKey:key ID:0];

  NSEnumerator<FSTDocumentReference *> *enumerator =
      [self.referencesByKey objectEnumeratorFrom:reference];
  FSTDocumentReference *_Nullable firstReference = [enumerator nextObject];
  return firstReference && firstReference.key == reference.key;
}

@end

NS_ASSUME_NONNULL_END
