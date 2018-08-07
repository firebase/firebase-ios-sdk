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

#import <Foundation/Foundation.h>

#import "Firestore/Source/Core/FSTTypes.h"

#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A collection of references to a document from some kind of numbered entity (either a targetID or
 * batchID). As references are added to or removed from the set corresponding events are emitted to
 * a registered garbage collector.
 *
 * Each reference is represented by a FSTDocumentReference object. Each of them contains enough
 * information to uniquely identify the reference. They are all stored primarily in a set sorted
 * by key. A document is considered garbage if there's no references in that set (this can be
 * efficiently checked thanks to sorting by key).
 *
 * FSTReferenceSet also keeps a secondary set that contains references sorted by IDs. This one is
 * used to efficiently implement removal of all references by some target ID.
 */
@interface FSTReferenceSet : NSObject

/** Returns YES if the reference set contains no references. */
- (BOOL)isEmpty;

/** Adds a reference to the given document key for the given ID. */
- (void)addReferenceToKey:(const firebase::firestore::model::DocumentKey &)key forID:(int)ID;

/** Add references to the given document keys for the given ID. */
- (void)addReferencesToKeys:(const firebase::firestore::model::DocumentKeySet &)keys forID:(int)ID;

/** Removes a reference to the given document key for the given ID. */
- (void)removeReferenceToKey:(const firebase::firestore::model::DocumentKey &)key forID:(int)ID;

/** Removes references to the given document keys for the given ID. */
- (void)removeReferencesToKeys:(const firebase::firestore::model::DocumentKeySet &)keys
                         forID:(int)ID;

/** Clears all references with a given ID. Calls -removeReferenceToKey: for each key removed. */
- (void)removeReferencesForID:(int)ID;

/** Clears all references for all IDs. */
- (void)removeAllReferences;

/** Returns all of the document keys that have had references added for the given ID. */
- (firebase::firestore::model::DocumentKeySet)referencedKeysForID:(int)ID;

/**
 * Checks to see if there are any references to a document with the given key.
 */
- (BOOL)containsKey:(const firebase::firestore::model::DocumentKey &)key;

@end

NS_ASSUME_NONNULL_END
