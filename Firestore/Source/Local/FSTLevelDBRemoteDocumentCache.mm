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

#import "Firestore/Source/Local/FSTLevelDBRemoteDocumentCache.h"

#include <string>

#import "Firestore/Protos/objc/firestore/local/MaybeDocument.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"

#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/memory/memory.h"
#include "leveldb/db.h"
#include "leveldb/write_batch.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::local::LevelDbRemoteDocumentCache;
using firebase::firestore::local::LevelDbRemoteDocumentKey;
using firebase::firestore::local::LevelDbTransaction;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::MaybeDocumentMap;
using leveldb::DB;
using leveldb::Status;

@implementation FSTLevelDBRemoteDocumentCache {
  std::unique_ptr<LevelDbRemoteDocumentCache> _cache;
}

- (instancetype)initWithDB:(FSTLevelDB *)db serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    _cache = absl::make_unique<LevelDbRemoteDocumentCache>(db, serializer);
  }
  return self;
}

- (void)addEntry:(FSTMaybeDocument *)document {
  _cache->AddEntry(document);
}

- (void)removeEntryForKey:(const DocumentKey &)documentKey {
  _cache->RemoveEntry(documentKey);
}

- (nullable FSTMaybeDocument *)entryForKey:(const DocumentKey &)documentKey {
  return _cache->Get(documentKey);
}

- (MaybeDocumentMap)entriesForKeys:(const DocumentKeySet &)keys {
  return _cache->GetAll(keys);
}

- (DocumentMap)documentsMatchingQuery:(FSTQuery *)query {
  return _cache->GetMatchingDocuments(query);
}

@end

NS_ASSUME_NONNULL_END
