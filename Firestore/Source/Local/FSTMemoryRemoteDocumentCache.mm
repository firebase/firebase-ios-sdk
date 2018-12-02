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

#import <Protobuf/GPBProtocolBuffers.h>
#import "Firestore/Protos/objc/firestore/local/MaybeDocument.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"
#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::MaybeDocumentMap;

NS_ASSUME_NONNULL_BEGIN

/**
 * Returns an estimate of the number of bytes used to store the given
 * document key in memory. This is only an estimate and includes the size
 * of the segments of the path, but not any object overhead or path separators.
 */
static size_t FSTDocumentKeyByteSize(const DocumentKey &key) {
  size_t count = 0;
  for (const auto &segment : key.path()) {
    count += segment.size();
  }
  return count;
}

@interface FSTMemoryRemoteDocumentCache ()

@end

@implementation FSTMemoryRemoteDocumentCache {
  /** Underlying cache of documents. */
  MaybeDocumentMap _docs;
}

- (void)addEntry:(FSTMaybeDocument *)document {
  _docs = _docs.insert(document.key, document);
}

- (void)removeEntryForKey:(const DocumentKey &)key {
  _docs = _docs.erase(key);
}

- (nullable FSTMaybeDocument *)entryForKey:(const DocumentKey &)key {
  auto found = self->_docs.find(key);
  return found != self->_docs.end() ? found->second : nil;
}

- (MaybeDocumentMap)entriesForKeys:(const DocumentKeySet &)keys {
  MaybeDocumentMap results;
  for (const DocumentKey &key : keys) {
    // Make sure each key has a corresponding entry, which is null in case the document is not
    // found.
    results = results.insert(key, [self entryForKey:key]);
  }
  return results;
}

- (MaybeDocumentMap)documentsMatchingQuery:(FSTQuery *)query {
  MaybeDocumentMap result;

  // Documents are ordered by key, so we can use a prefix scan to narrow down the documents
  // we need to match the query against.
  DocumentKey prefix{query.path.Append("")};
  for (auto it = _docs.lower_bound(prefix); it != _docs.end(); ++it) {
    const DocumentKey &key = it->first;
    if (!query.path.IsPrefixOf(key.path())) {
      break;
    }
    FSTMaybeDocument *maybeDoc = nil;
    auto found = _docs.find(key);
    if (found != _docs.end()) {
      maybeDoc = found->second;
    }
    if (![maybeDoc isKindOfClass:[FSTDocument class]]) {
      continue;
    }
    FSTDocument *doc = static_cast<FSTDocument *>(maybeDoc);
    if ([query matchesDocument:doc]) {
      result = result.insert(key, doc);
    }
  }

  return result;
}

- (std::vector<DocumentKey>)removeOrphanedDocuments:
                                (FSTMemoryLRUReferenceDelegate *)referenceDelegate
                              throughSequenceNumber:(ListenSequenceNumber)upperBound {
  std::vector<DocumentKey> removed;
  MaybeDocumentMap updatedDocs = _docs;
  for (const auto &kv : _docs) {
    const DocumentKey &docKey = kv.first;
    if (![referenceDelegate isPinnedAtSequenceNumber:upperBound document:docKey]) {
      updatedDocs = updatedDocs.erase(docKey);
      removed.push_back(docKey);
    }
  }
  _docs = updatedDocs;
  return removed;
}

- (size_t)byteSizeWithSerializer:(FSTLocalSerializer *)serializer {
  size_t count = 0;
  for (const auto &kv : _docs) {
    const DocumentKey &key = kv.first;
    FSTMaybeDocument *doc = kv.second;
    count += FSTDocumentKeyByteSize(key);
    count += [[serializer encodedMaybeDocument:doc] serializedSize];
  }
  return count;
}

@end

NS_ASSUME_NONNULL_END
