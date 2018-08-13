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
#import "Firestore/Source/Model/FSTDocumentDictionary.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"

#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "leveldb/db.h"
#include "leveldb/write_batch.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::local::LevelDbRemoteDocumentKey;
using firebase::firestore::local::LevelDbTransaction;
using firebase::firestore::model::DocumentKey;
using leveldb::DB;
using leveldb::Status;

@interface FSTLevelDBRemoteDocumentCache ()

@property(nonatomic, strong, readonly) FSTLocalSerializer *serializer;

@end

@implementation FSTLevelDBRemoteDocumentCache {
  FSTLevelDB *_db;
}

- (instancetype)initWithDB:(FSTLevelDB *)db serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    _db = db;
    _serializer = serializer;
  }
  return self;
}

- (void)addEntry:(FSTMaybeDocument *)document {
  std::string key = [self remoteDocumentKey:document.key];
  _db.currentTransaction->Put(key, [self.serializer encodedMaybeDocument:document]);
}

- (void)removeEntryForKey:(const DocumentKey &)documentKey {
  std::string key = [self remoteDocumentKey:documentKey];
  _db.currentTransaction->Delete(key);
}

- (nullable FSTMaybeDocument *)entryForKey:(const DocumentKey &)documentKey {
  std::string key = LevelDbRemoteDocumentKey::Key(documentKey);
  std::string value;
  Status status = _db.currentTransaction->Get(key, &value);
  if (status.IsNotFound()) {
    return nil;
  } else if (status.ok()) {
    return [self decodeMaybeDocument:value withKey:documentKey];
  } else {
    HARD_FAIL("Fetch document for key (%s) failed with status: %s", documentKey.ToString(),
              status.ToString());
  }
}

- (FSTDocumentDictionary *)documentsMatchingQuery:(FSTQuery *)query {
  FSTDocumentDictionary *results = [FSTDocumentDictionary documentDictionary];

  // Documents are ordered by key, so we can use a prefix scan to narrow down
  // the documents we need to match the query against.
  std::string startKey = LevelDbRemoteDocumentKey::KeyPrefix(query.path);
  auto it = _db.currentTransaction->NewIterator();
  it->Seek(startKey);

  LevelDbRemoteDocumentKey currentKey;
  for (; it->Valid() && currentKey.Decode(it->key()); it->Next()) {
    FSTMaybeDocument *maybeDoc =
        [self decodeMaybeDocument:it->value() withKey:currentKey.document_key()];
    if (!query.path.IsPrefixOf(maybeDoc.key.path())) {
      break;
    } else if ([maybeDoc isKindOfClass:[FSTDocument class]]) {
      results = [results dictionaryBySettingObject:(FSTDocument *)maybeDoc forKey:maybeDoc.key];
    }
  }

  return results;
}

- (std::string)remoteDocumentKey:(const DocumentKey &)key {
  return LevelDbRemoteDocumentKey::Key(key);
}

- (FSTMaybeDocument *)decodeMaybeDocument:(absl::string_view)encoded
                                  withKey:(const DocumentKey &)documentKey {
  NSData *data = [[NSData alloc] initWithBytesNoCopy:(void *)encoded.data()
                                              length:encoded.size()
                                        freeWhenDone:NO];

  NSError *error;
  FSTPBMaybeDocument *proto = [FSTPBMaybeDocument parseFromData:data error:&error];
  if (!proto) {
    HARD_FAIL("FSTPBMaybeDocument failed to parse: %s", error);
  }

  FSTMaybeDocument *maybeDocument = [self.serializer decodedMaybeDocument:proto];
  HARD_ASSERT(maybeDocument.key == documentKey,
              "Read document has key (%s) instead of expected key (%s).",
              maybeDocument.key.ToString(), documentKey.ToString());
  return maybeDocument;
}

@end

NS_ASSUME_NONNULL_END
