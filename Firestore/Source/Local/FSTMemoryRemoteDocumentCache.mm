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

#include "Firestore/core/src/firebase/firestore/local/memory_remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"

using firebase::firestore::local::MemoryRemoteDocumentCache;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::MaybeDocumentMap;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTMemoryRemoteDocumentCache {
  MemoryRemoteDocumentCache _cache;
}

- (void)addEntry:(FSTMaybeDocument *)document {
  _cache.AddEntry(document);
}

- (void)removeEntryForKey:(const DocumentKey &)key {
  _cache.RemoveEntry(key);
}

- (nullable FSTMaybeDocument *)entryForKey:(const DocumentKey &)key {
  return _cache.Get(key);
}

- (MaybeDocumentMap)entriesForKeys:(const DocumentKeySet &)keys {
  return _cache.GetAll(keys);
}

- (DocumentMap)documentsMatchingQuery:(FSTQuery *)query {
  return _cache.GetMatchingDocuments(query);
}

- (std::vector<DocumentKey>)removeOrphanedDocuments:
                                (FSTMemoryLRUReferenceDelegate *)referenceDelegate
                              throughSequenceNumber:(ListenSequenceNumber)upperBound {
  return _cache.RemoveOrphanedDocuments(referenceDelegate, upperBound);
}

- (size_t)byteSizeWithSerializer:(FSTLocalSerializer *)serializer {
  return _cache.CalculateByteSize(serializer);
}

@end

NS_ASSUME_NONNULL_END
