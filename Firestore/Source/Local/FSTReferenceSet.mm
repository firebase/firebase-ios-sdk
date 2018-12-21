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

#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"

using firebase::firestore::local::ReferenceSet;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTReferenceSet

@implementation FSTReferenceSet {
  ReferenceSet _references;
}

#pragma mark - Initializer

#pragma mark - Testing helper methods

- (BOOL)isEmpty {
  return _references.empty();
}

- (NSUInteger)count {
  return _references.size();
}

#pragma mark - Public methods

- (void)addReferenceToKey:(const DocumentKey &)key forID:(int)ID {
  _references.AddReference(key, ID);
}

- (void)addReferencesToKeys:(const DocumentKeySet &)keys forID:(int)ID {
  _references.AddReferences(keys, ID);
}

- (void)removeReferenceToKey:(const DocumentKey &)key forID:(int)ID {
  _references.RemoveReference(key, ID);
}

- (void)removeReferencesToKeys:(const DocumentKeySet &)keys forID:(int)ID {
  _references.RemoveReferences(keys, ID);
}

- (DocumentKeySet)removeReferencesForID:(int)ID {
  return _references.RemoveReferences(ID);
}

- (void)removeAllReferences {
  _references.RemoveAllReferences();
}

- (void)removeReference:(FSTDocumentReference *)reference {
  _references.RemoveReference(reference.key, reference.ID);
}

- (DocumentKeySet)referencedKeysForID:(int)ID {
  return _references.ReferencedKeys(ID);
}

- (BOOL)containsKey:(const DocumentKey &)key {
  return _references.ContainsKey(key);
}

@end

NS_ASSUME_NONNULL_END
