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

#import "Firestore/Source/Model/FSTDocumentSet.h"

#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/third_party/Immutable/FSTImmutableSortedSet.h"

#include "Firestore/core/src/firebase/firestore/immutable/sorted_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/util/range.h"

namespace objc = firebase::firestore::util::objc;
using firebase::firestore::immutable::SortedSet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::util::range;

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::model::DocumentSetComparator;

/**
 * The type of the main collection of documents in an FSTDocumentSet.
 * @see FSTDocumentSet#sortedSet
 */
using SetType = SortedSet<FSTDocument *, DocumentSetComparator>;

@interface FSTDocumentSet ()

- (instancetype)initWithIndex:(DocumentMap &&)index
                          set:(SetType &&)sortedSet NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTDocumentSet {
  /**
   * The main collection of documents in the FSTDocumentSet. The documents are ordered by a
   * comparator supplied from a query. The SetType collection exists in addition to the index to
   * allow ordered traversal of the FSTDocumentSet.
   */
  SetType _sortedSet;

  /**
   * An index of the documents in the FSTDocumentSet, indexed by document key. The index
   * exists to guarantee the uniqueness of document keys in the set and to allow lookup and removal
   * of documents by key.
   */
  DocumentMap _index;
}

+ (instancetype)documentSetWithComparator:(NSComparator)comparator {
  SetType set{DocumentSetComparator(comparator)};
  return [[FSTDocumentSet alloc] initWithIndex:DocumentMap {} set:std::move(set)];
}

- (instancetype)initWithIndex:(DocumentMap &&)index set:(SetType &&)sortedSet {
  self = [super init];
  if (self) {
    _index = std::move(index);
    _sortedSet = std::move(sortedSet);
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isMemberOfClass:[FSTDocumentSet class]]) {
    return NO;
  }

  FSTDocumentSet *otherSet = (FSTDocumentSet *)other;
  if ([self count] != [otherSet count]) {
    return NO;
  }

  SetType::const_iterator selfIter = _sortedSet.begin();
  SetType::const_iterator selfEnd = _sortedSet.end();

  SetType::const_iterator otherIter = otherSet->_sortedSet.begin();
  SetType::const_iterator otherEnd = otherSet->_sortedSet.end();

  while (selfIter != selfEnd && otherIter != otherEnd) {
    FSTDocument *selfDoc = *selfIter;
    FSTDocument *otherDoc = *otherIter;
    if (![selfDoc isEqual:otherDoc]) {
      return NO;
    }
    ++selfIter;
    ++otherIter;
  }
  return YES;
}

- (NSUInteger)hash {
  NSUInteger hash = 0;
  for (FSTDocument *doc : _sortedSet) {
    hash = 31 * hash + [doc hash];
  }
  return hash;
}

- (NSString *)description {
  return objc::Description(_sortedSet);
}

- (NSUInteger)count {
  return _index.size();
}

- (BOOL)isEmpty {
  return _index.empty();
}

- (BOOL)containsKey:(const DocumentKey &)key {
  return _index.underlying_map().find(key) != _index.underlying_map().end();
}

- (FSTDocument *_Nullable)documentForKey:(const DocumentKey &)key {
  auto found = _index.underlying_map().find(key);
  return found != _index.underlying_map().end() ? static_cast<FSTDocument *>(found->second) : nil;
}

- (FSTDocument *_Nullable)firstDocument {
  auto result = _sortedSet.min();
  return result != _sortedSet.end() ? *result : nil;
}

- (FSTDocument *_Nullable)lastDocument {
  auto result = _sortedSet.max();
  return result != _sortedSet.end() ? *result : nil;
}

- (NSUInteger)indexOfKey:(const DocumentKey &)key {
  FSTDocument *doc = [self documentForKey:key];
  return doc ? _sortedSet.find_index(doc) : NSNotFound;
}

- (const SetType &)documents {
  return _sortedSet;
}

- (NSArray *)arrayValue {
  NSMutableArray<FSTDocument *> *result = [NSMutableArray arrayWithCapacity:self.count];
  for (FSTDocument *doc : _sortedSet) {
    [result addObject:doc];
  }
  return result;
}

- (const DocumentMap &)mapValue {
  return _index;
}

- (instancetype)documentSetByAddingDocument:(FSTDocument *_Nullable)document {
  // TODO(mcg): look into making document nonnull.
  if (!document) {
    return self;
  }

  // Remove any prior mapping of the document's key before adding, preventing sortedSet from
  // accumulating values that aren't in the index.
  FSTDocumentSet *removed = [self documentSetByRemovingKey:document.key];

  DocumentMap index = removed->_index.insert(document.key, document);
  SetType set = removed->_sortedSet.insert(document);
  return [[FSTDocumentSet alloc] initWithIndex:std::move(index) set:std::move(set)];
}

- (instancetype)documentSetByRemovingKey:(const DocumentKey &)key {
  FSTDocument *doc = [self documentForKey:key];
  if (!doc) {
    return self;
  }

  DocumentMap index = _index.erase(key);
  SetType set = _sortedSet.erase(doc);
  return [[FSTDocumentSet alloc] initWithIndex:std::move(index) set:std::move(set)];
}

@end

NS_ASSUME_NONNULL_END
