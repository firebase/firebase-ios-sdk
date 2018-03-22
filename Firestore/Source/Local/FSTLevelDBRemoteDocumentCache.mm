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

#include <leveldb/db.h>
#include <leveldb/write_batch.h>
#include <string>

#import "Firestore/Protos/objc/firestore/local/MaybeDocument.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Local/FSTWriteGroup.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentDictionary.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Util/FSTAssert.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::model::DocumentKey;
using leveldb::DB;
using leveldb::Iterator;
using leveldb::ReadOptions;
using leveldb::Slice;
using leveldb::Status;
using leveldb::WriteOptions;

@interface FSTLevelDBRemoteDocumentCache ()

@property(nonatomic, strong, readonly) FSTLocalSerializer *serializer;

@end

/**
 * Returns a standard set of read options.
 *
 * For now this is paranoid, but perhaps disable that in production builds.
 */
static ReadOptions StandardReadOptions() {
  ReadOptions options;
  options.verify_checksums = true;
  return options;
}

@implementation FSTLevelDBRemoteDocumentCache {
  // The DB pointer is shared with all cooperating LevelDB-related objects.
  std::shared_ptr<DB> _db;
}

- (instancetype)initWithDB:(std::shared_ptr<DB>)db serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    _db = db;
    _serializer = serializer;
  }
  return self;
}

- (void)shutdown {
  _db.reset();
}

- (void)addEntry:(FSTMaybeDocument *)document group:(FSTWriteGroup *)group {
  std::string key = [self remoteDocumentKey:document.key];
  [group setMessage:[self.serializer encodedMaybeDocument:document] forKey:key];
}

- (void)removeEntryForKey:(const DocumentKey &)documentKey group:(FSTWriteGroup *)group {
  std::string key = [self remoteDocumentKey:documentKey];
  [group removeMessageForKey:key];
}

- (nullable FSTMaybeDocument *)entryForKey:(const DocumentKey &)documentKey {
  std::string key = [FSTLevelDBRemoteDocumentKey keyWithDocumentKey:documentKey];
  std::string value;
  Status status = _db->Get(StandardReadOptions(), key, &value);
  if (status.IsNotFound()) {
    return nil;
  } else if (status.ok()) {
    return [self decodedMaybeDocument:value withKey:documentKey];
  } else {
    FSTFail(@"Fetch document for key (%s) failed with status: %s", documentKey.ToString().c_str(),
            status.ToString().c_str());
  }
}

- (FSTDocumentDictionary *)documentsMatchingQuery:(FSTQuery *)query {
  FSTDocumentDictionary *results = [FSTDocumentDictionary documentDictionary];

  // Documents are ordered by key, so we can use a prefix scan to narrow down
  // the documents we need to match the query against.
  std::string startKey = [FSTLevelDBRemoteDocumentKey keyPrefixWithResourcePath:query.path];
  std::unique_ptr<Iterator> it(_db->NewIterator(StandardReadOptions()));
  it->Seek(startKey);

  FSTLevelDBRemoteDocumentKey *currentKey = [[FSTLevelDBRemoteDocumentKey alloc] init];
  for (; it->Valid() && [currentKey decodeKey:it->key()]; it->Next()) {
    FSTMaybeDocument *maybeDoc =
        [self decodedMaybeDocument:it->value() withKey:currentKey.documentKey];
    if (!query.path.IsPrefixOf(maybeDoc.key.path())) {
      break;
    } else if ([maybeDoc isKindOfClass:[FSTDocument class]]) {
      results = [results dictionaryBySettingObject:(FSTDocument *)maybeDoc forKey:maybeDoc.key];
    }
  }

  Status status = it->status();
  if (!status.ok()) {
    FSTFail(@"Find documents matching query (%@) failed with status: %s", query,
            status.ToString().c_str());
  }

  return results;
}

- (std::string)remoteDocumentKey:(const DocumentKey &)key {
  return [FSTLevelDBRemoteDocumentKey keyWithDocumentKey:key];
}

- (FSTMaybeDocument *)decodedMaybeDocument:(Slice)slice withKey:(const DocumentKey &)documentKey {
  NSData *data =
      [[NSData alloc] initWithBytesNoCopy:(void *)slice.data() length:slice.size() freeWhenDone:NO];

  NSError *error;
  FSTPBMaybeDocument *proto = [FSTPBMaybeDocument parseFromData:data error:&error];
  if (!proto) {
    FSTFail(@"FSTPBMaybeDocument failed to parse: %@", error);
  }

  FSTMaybeDocument *maybeDocument = [self.serializer decodedMaybeDocument:proto];
  FSTAssert([maybeDocument.key isEqualToKey:documentKey],
            @"Read document has key (%s) instead of expected key (%s).",
            maybeDocument.key.ToString().c_str(), documentKey.ToString().c_str());
  return maybeDocument;
}

@end

NS_ASSUME_NONNULL_END
