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
#include "Firestore/core/src/firebase/firestore/util/delayed_constructor.h"
#include "Firestore/core/src/firebase/firestore/util/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace objc = firebase::firestore::util::objc;
namespace util = firebase::firestore::util;
using firebase::firestore::immutable::SortedSet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::util::DelayedConstructor;

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::model::DocumentSetComparator;

@implementation FSTDocumentSet {
  DelayedConstructor<DocumentSet> _delegate;
}

+ (instancetype)documentSetWithComparator:(NSComparator)comparator {
  DocumentSet wrapped{comparator};
  return [[FSTDocumentSet alloc] initWithDocumentSet:std::move(wrapped)];
}

- (instancetype)initWithDocumentSet:(DocumentSet &&)documentSet {
  self = [super init];
  if (self) {
    _delegate.Init(std::move(documentSet));
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) return YES;
  if (![other isMemberOfClass:[FSTDocumentSet class]]) return NO;

  FSTDocumentSet *otherSet = (FSTDocumentSet *)other;
  return *_delegate == *(otherSet->_delegate);
}

- (NSUInteger)hash {
  return _delegate->Hash();
}

- (NSString *)description {
  return util::WrapNSString(_delegate->ToString());
}

- (NSUInteger)count {
  return _delegate->size();
}

- (BOOL)isEmpty {
  return _delegate->empty();
}

- (BOOL)containsKey:(const DocumentKey &)key {
  return _delegate->ContainsKey(key);
}

- (FSTDocument *_Nullable)documentForKey:(const DocumentKey &)key {
  return _delegate->GetDocument(key);
}

- (FSTDocument *_Nullable)firstDocument {
  return _delegate->GetFirstDocument();
}

- (FSTDocument *_Nullable)lastDocument {
  return _delegate->GetLastDocument();
}

- (NSUInteger)indexOfKey:(const DocumentKey &)key {
  size_t index = _delegate->IndexOf(key);
  return index != DocumentSet::npos ? index : NSNotFound;
}

- (const DocumentSet &)documents {
  return *_delegate;
}

- (NSArray *)arrayValue {
  NSMutableArray<FSTDocument *> *result = [NSMutableArray arrayWithCapacity:self.count];
  for (FSTDocument *doc : *_delegate) {
    [result addObject:doc];
  }
  return result;
}

- (const DocumentMap &)mapValue {
  return _delegate->GetMapValue();
}

- (instancetype)documentSetByAddingDocument:(FSTDocument *_Nullable)document {
  DocumentSet result = _delegate->insert(document);
  return [[FSTDocumentSet alloc] initWithDocumentSet:std::move(result)];
}

- (instancetype)documentSetByRemovingKey:(const DocumentKey &)key {
  DocumentSet result = _delegate->erase(key);
  return [[FSTDocumentSet alloc] initWithDocumentSet:std::move(result)];
}

@end

NS_ASSUME_NONNULL_END
