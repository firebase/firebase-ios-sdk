/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/src/firebase/firestore/immutable/sorted_set.h"
#include "Firestore/core/src/firebase/firestore/local/document_reference.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"

namespace firebase {
namespace firestore {
namespace local {
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using model::DocumentKey;
using model::DocumentKeySet;

#pragma mark - FSTReferenceSet

class ReferenceSet {
  /** A set of outstanding references to a document sorted by key. */
  SortedSet<DocumentReference> references_by_key() const {
    return references_by_key_;
  }
  void set_references_by_key(SortedSet<DocumentReference> references_by_key) {
    references_by_key_ = references_by_key;
  }

  /** A set of outstanding references to a document sorted by target ID (or
   * batch ID). */
  SortedSet<DocumentReference> references_by_id() const {
    return references_by_id_;
  }
  void set_references_by_id(SortedSet<DocumentReference> references_by_id) {
    references_by_id_ = references_by_id;
  }

 private:
  SortedSet<DocumentReference> references_by_key_;
  SortedSet<DocumentReference> references_by_id_;
};

#pragma mark - Initializer

ReferenceSet::ReferenceSet() {
  self = [super init];
  if (self) {
    references_by_key_ =
        [SortedSet setWithComparator:DocumentReferenceComparatorByKey];
    references_by_id_ =
        [SortedSet setWithComparator:DocumentReferenceComparatorById];
  }
  return self;
}

#pragma mark - Testing helper methods

bool ReferenceSet::empty() {
  return [references_by_key_ isEmpty];
}

size_t ReferenceSet::size() {
  return references_by_key_.count;
}

#pragma mark - Public methods

void ReferenceSet::AddReference(
    const firebase::firestore::model::DocumentKey& key, int id) {
  DocumentReference reference =
      [[DocumentReference alloc] initWithKey:key ID:ID];
  references_by_key_ = [references_by_key_ setByAddingObject:reference];
  references_by_id_ = [references_by_id_ setByAddingObject:reference];
}

void ReferenceSet::AddReferences(
    const firebase::firestore::model::DocumentKeySet& keys, int id) {
  for (const DocumentKey& key : keys) {
    [self addReferenceToKey:key forID:ID];
  }
}

void ReferenceSet::RemoveReference(
    const firebase::firestore::model::DocumentKey& key, int id) {
  [self removeReference:[[DocumentReference alloc] initWithKey:key ID:ID]];
}

void ReferenceSet::RemoveReferences(
    const firebase::firestore::model::DocumentKeySet& keys, int id) {
  for (const DocumentKey& key : keys) {
    [self removeReferenceToKey:key forID:ID];
  }
}

void ReferenceSet::RemoveReferences(int id) {
  DocumentReference start =
      [[DocumentReference alloc] initWithKey:DocumentKey::Empty() ID:ID];
  DocumentReference end =
      [[DocumentReference alloc] initWithKey:DocumentKey::Empty() ID:(ID + 1)];

  [references_by_id_
      enumerateObjectsFrom:start
                        to:end
                usingBlock:^(DocumentReference reference, BOOL* stop) {
                  [self removeReference:reference];
                }];
}

void ReferenceSet::RemoveAllReferences() {
  for (DocumentReference reference in references_by_key_.objectEnumerator) {
    [self removeReference:reference];
  }
}

void ReferenceSet::RemoveReference(const DocumentReference& reference) {
  references_by_key_ = [references_by_key_ setByRemovingObject:reference];
  references_by_id_ = [references_by_id_ setByRemovingObject:reference];
}

firebase::firestore::model::DocumentKeySet ReferenceSet::ReferencedKeys(
    int id) {
  DocumentReference start =
      [[DocumentReference alloc] initWithKey:DocumentKey::Empty() ID:ID];
  DocumentReference end =
      [[DocumentReference alloc] initWithKey:DocumentKey::Empty() ID:(ID + 1)];

  __block DocumentKeySet keys;
  [references_by_id_
      enumerateObjectsFrom:start
                        to:end
                usingBlock:^(DocumentReference reference, BOOL* stop) {
                  keys = keys.insert(reference.key);
                }];
  return keys;
}

bool ReferenceSet::ContainsKey(
    const firebase::firestore::model::DocumentKey& key) {
  // Create a reference with a zero ID as the start position to find any
  // document reference with this key.
  DocumentReference reference =
      [[DocumentReference alloc] initWithKey:key ID:0];

  NSEnumerator<DocumentReference>* enumerator =
      [references_by_key_ objectEnumeratorFrom:reference];
  DocumentReference nullable_ firstReference = [enumerator nextObject];
  return firstReference && firstReference.key == reference.key;
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
