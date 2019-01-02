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

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"

@class FSTDocument;

NS_ASSUME_NONNULL_BEGIN

/**
 * DocumentSet is an immutable (copy-on-write) collection that holds documents in order specified
 * by the provided comparator. We always add a document key comparator on top of what is provided
 * to guarantee document equality based on the key.
 */
@interface FSTDocumentSet : NSObject

/** Creates a new, empty FSTDocumentSet sorted by the given comparator, then by keys. */
+ (instancetype)documentSetWithComparator:(NSComparator)comparator;

- (instancetype)init __attribute__((unavailable("Use a static constructor instead")));

- (NSUInteger)count;

/** Returns true if the dictionary contains no elements. */
- (BOOL)isEmpty;

/** Returns YES if this set contains a document with the given key. */
- (BOOL)containsKey:(const firebase::firestore::model::DocumentKey &)key;

/** Returns the document from this set with the given key if it exists or nil if it doesn't. */
- (FSTDocument *_Nullable)documentForKey:(const firebase::firestore::model::DocumentKey &)key;

/**
 * Returns the first document in the set according to its built in ordering, or nil if the set
 * is empty.
 */
- (FSTDocument *_Nullable)firstDocument;

/**
 * Returns the last document in the set according to its built in ordering, or nil if the set
 * is empty.
 */
- (FSTDocument *_Nullable)lastDocument;

/**
 * Returns the index of the document with the provided key in the document set. Returns NSNotFound
 * if the key is not present.
 */
- (NSUInteger)indexOfKey:(const firebase::firestore::model::DocumentKey &)key;

- (NSEnumerator<FSTDocument *> *)documentEnumerator;

/** Returns a copy of the documents in this set as an array. This is O(n) on the size of the set. */
- (NSArray<FSTDocument *> *)arrayValue;

/**
 * Returns the documents as a `DocumentMap`. This is O(1) as this leverages
 * our internal representation.
 */
- (const firebase::firestore::model::DocumentMap &)mapValue;

/** Returns a new FSTDocumentSet that contains the given document. */
- (instancetype)documentSetByAddingDocument:(FSTDocument *_Nullable)document;

/** Returns a new FSTDocumentSet that excludes any document associated with the given key. */
- (instancetype)documentSetByRemovingKey:(const firebase::firestore::model::DocumentKey &)key;
@end

NS_ASSUME_NONNULL_END
