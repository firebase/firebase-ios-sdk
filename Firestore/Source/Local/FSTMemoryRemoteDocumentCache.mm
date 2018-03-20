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

#import "Firestore/Source/Local/FSTMemoryRemoteDocumentCache.h"

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"

#include "Firestore/core/src/firebase/firestore/model/document_dictionary.h"

using firebase::firestore::model::DocumentDictionary;
using firebase::firestore::model::MaybeDocumentDictionary;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTMemoryRemoteDocumentCache {
  /** Underlying cache of documents. */
  MaybeDocumentDictionary _docs;
}

- (instancetype)init {
  if (self = [super init]) {
    _docs = MaybeDocumentDictionary{};
  }
  return self;
}

- (void)shutdown {
}

- (void)addEntry:(FSTMaybeDocument *)document group:(FSTWriteGroup *)group {
  _docs[document.key] = document;
}

- (void)removeEntryForKey:(FSTDocumentKey *)key group:(FSTWriteGroup *)group {
  _docs.erase(key);
}

- (nullable FSTMaybeDocument *)entryForKey:(FSTDocumentKey *)key {
  const auto iter = _docs.find(key);
  if (iter == _docs.end()) {
    return nil;
  } else {
    return iter->second;
  }
}

- (DocumentDictionary)documentsMatchingQuery:(FSTQuery *)query {
  DocumentDictionary result{};

  // Documents are ordered by key, so we can use a prefix scan to narrow down the documents
  // we need to match the query against.
  FSTDocumentKey *prefix = [FSTDocumentKey keyWithPath:query.path.Append("")];
  for (auto iter = _docs.lower_bound(prefix); iter != _docs.end(); ++iter) {
    if (!query.path.IsPrefixOf(iter->first.path())) {
      break;
    }
    FSTMaybeDocument *maybeDoc = iter->second;
    if (![maybeDoc isKindOfClass:[FSTDocument class]]) {
      continue;
    }
    FSTDocument *doc = (FSTDocument *)maybeDoc;
    if ([query matchesDocument:doc]) {
      result[doc.key] = doc;
    }
  }

  return result;
}

@end

NS_ASSUME_NONNULL_END
