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

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

using firebase::firestore::model::DocumentKey;

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

- (void)addReferencesToKeys:(FSTDocumentKeySet *)keys forID:(int)ID {
  [keys enumerateObjectsUsingBlock:^(FSTDocumentKey *key, BOOL *stop) {
    [self addReferenceToKey:key forID:ID];
  }];
}

- (void)removeReferenceToKey:(const DocumentKey &)key forID:(int)ID {
  [self removeReference:[[FSTDocumentReference alloc] initWithKey:key ID:ID]];
}

- (void)removeReferencesToKeys:(FSTDocumentKeySet *)keys forID:(int)ID {
  [keys enumerateObjectsUsingBlock:^(FSTDocumentKey *key, BOOL *stop) {
    [self removeReferenceToKey:key forID:ID];
  }];
}

- (void)removeReferencesForID:(int)ID {
  FSTDocumentReference *start =
      [[FSTDocumentReference alloc] initWithKey:DocumentKey::Empty() ID:ID];
  FSTDocumentReference *end =
      [[FSTDocumentReference alloc] initWithKey:DocumentKey::Empty() ID:(ID + 1)];

  [self.referencesByID enumerateObjectsFrom:start
                                         to:end
                                 usingBlock:^(FSTDocumentReference *reference, BOOL *stop) {
                                   [self removeReference:reference];
                                 }];
}

- (void)removeAllReferences {
  for (FSTDocumentReference *reference in self.referencesByKey.objectEnumerator) {
    [self removeReference:reference];
  }
}

- (void)removeReference:(FSTDocumentReference *)reference {
  self.referencesByKey = [self.referencesByKey setByRemovingObject:reference];
  self.referencesByID = [self.referencesByID setByRemovingObject:reference];
  [self.garbageCollector addPotentialGarbageKey:reference.key];
}

- (FSTDocumentKeySet *)referencedKeysForID:(int)ID {
  FSTDocumentReference *start =
      [[FSTDocumentReference alloc] initWithKey:DocumentKey::Empty() ID:ID];
  FSTDocumentReference *end =
      [[FSTDocumentReference alloc] initWithKey:DocumentKey::Empty() ID:(ID + 1)];

  __block FSTDocumentKeySet *keys = [FSTDocumentKeySet keySet];
  [self.referencesByID enumerateObjectsFrom:start
                                         to:end
                                 usingBlock:^(FSTDocumentReference *reference, BOOL *stop) {
                                   keys = [keys setByAddingObject:reference.key];
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
