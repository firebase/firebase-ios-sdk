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

#include "Firestore/core/src/firebase/firestore/local/leveldb_remote_document_cache.h"

#import <Foundation/Foundation.h>

#include <string>

#import "Firestore/Protos/objc/firestore/local/MaybeDocument.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "leveldb/db.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::MaybeDocumentMap;
using leveldb::Status;

namespace firebase {
namespace firestore {
namespace local {

LevelDbRemoteDocumentCache::LevelDbRemoteDocumentCache(
    FSTLevelDB* db, FSTLocalSerializer* serializer)
    : db_(db), serializer_(serializer) {
}

void LevelDbRemoteDocumentCache::Add(FSTMaybeDocument* document) {
  std::string ldb_key = LevelDbRemoteDocumentKey::Key(document.key);
  db_.currentTransaction->Put(ldb_key,
                              [serializer_ encodedMaybeDocument:document]);
}

void LevelDbRemoteDocumentCache::Remove(const DocumentKey& key) {
  std::string ldb_key = LevelDbRemoteDocumentKey::Key(key);
  db_.currentTransaction->Delete(ldb_key);
}

FSTMaybeDocument* _Nullable LevelDbRemoteDocumentCache::Get(
    const DocumentKey& key) {
  std::string ldb_key = LevelDbRemoteDocumentKey::Key(key);
  std::string value;
  Status status = db_.currentTransaction->Get(ldb_key, &value);
  if (status.IsNotFound()) {
    return nil;
  } else if (status.ok()) {
    return DecodeMaybeDocument(value, key);
  } else {
    HARD_FAIL("Fetch document for key (%s) failed with status: %s",
              key.ToString(), status.ToString());
  }
}

MaybeDocumentMap LevelDbRemoteDocumentCache::GetAll(
    const DocumentKeySet& keys) {
  MaybeDocumentMap results;

  LevelDbRemoteDocumentKey currentKey;
  auto it = db_.currentTransaction->NewIterator();

  for (const DocumentKey& key : keys) {
    it->Seek(LevelDbRemoteDocumentKey::Key(key));
    if (!it->Valid() || !currentKey.Decode(it->key()) ||
        currentKey.document_key() != key) {
      results = results.insert(key, nil);
    } else {
      results = results.insert(key, DecodeMaybeDocument(it->value(), key));
    }
  }

  return results;
}

DocumentMap LevelDbRemoteDocumentCache::GetMatching(FSTQuery* query) {
  DocumentMap results;

  // Documents are ordered by key, so we can use a prefix scan to narrow down
  // the documents we need to match the query against.
  std::string startKey = LevelDbRemoteDocumentKey::KeyPrefix(query.path);
  auto it = db_.currentTransaction->NewIterator();
  it->Seek(startKey);

  LevelDbRemoteDocumentKey currentKey;
  for (; it->Valid() && currentKey.Decode(it->key()); it->Next()) {
    FSTMaybeDocument* maybeDoc =
        DecodeMaybeDocument(it->value(), currentKey.document_key());
    if (!query.path.IsPrefixOf(maybeDoc.key.path())) {
      break;
    } else if ([maybeDoc isKindOfClass:[FSTDocument class]]) {
      results =
          results.insert(maybeDoc.key, static_cast<FSTDocument*>(maybeDoc));
    }
  }

  return results;
}

FSTMaybeDocument* LevelDbRemoteDocumentCache::DecodeMaybeDocument(
    absl::string_view encoded, const DocumentKey& key) {
  NSData* data = [[NSData alloc] initWithBytesNoCopy:(void*)encoded.data()
                                              length:encoded.size()
                                        freeWhenDone:NO];

  NSError* error;
  FSTPBMaybeDocument* proto = [FSTPBMaybeDocument parseFromData:data
                                                          error:&error];
  if (!proto) {
    HARD_FAIL("FSTPBMaybeDocument failed to parse: %s", error);
  }

  FSTMaybeDocument* maybeDocument = [serializer_ decodedMaybeDocument:proto];
  HARD_ASSERT(maybeDocument.key == key,
              "Read document has key (%s) instead of expected key (%s).",
              maybeDocument.key.ToString(), key.ToString());
  return maybeDocument;
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
