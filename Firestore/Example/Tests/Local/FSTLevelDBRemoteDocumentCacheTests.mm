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

#include <memory>
#include <string>

#import "Firestore/Example/Tests/Local/FSTRemoteDocumentCacheTests.h"

#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/util/ordered_code.h"
#include "Firestore/core/test/firebase/firestore/local/persistence_testing.h"
#include "absl/memory/memory.h"
#include "leveldb/db.h"

NS_ASSUME_NONNULL_BEGIN

using leveldb::WriteOptions;
using firebase::firestore::local::LevelDbPersistence;
using firebase::firestore::local::LevelDbPersistenceForTesting;
using firebase::firestore::local::LevelDbRemoteDocumentCache;
using firebase::firestore::local::RemoteDocumentCache;
using firebase::firestore::util::OrderedCode;

// A dummy document value, useful for testing code that's known to examine only document keys.
static const char *kDummy = "1";

/**
 * The tests for FSTLevelDBRemoteDocumentCache are performed on the FSTRemoteDocumentCache
 * protocol in FSTRemoteDocumentCacheTests. This class is merely responsible for setting up and
 * tearing down the @a remoteDocumentCache.
 */
@interface FSTLevelDBRemoteDocumentCacheTests : FSTRemoteDocumentCacheTests
@end

@implementation FSTLevelDBRemoteDocumentCacheTests {
  std::unique_ptr<LevelDbPersistence> _db;
  LevelDbRemoteDocumentCache *_cache;
}

- (void)setUp {
  [super setUp];
  _db = LevelDbPersistenceForTesting();
  self.persistence = _db.get();
  HARD_ASSERT(!_cache, "Previous cache not torn down");
  _cache = _db->remote_document_cache();

  // Write a couple dummy rows that should appear before/after the remote_documents table to make
  // sure the tests are unaffected.
  [self writeDummyRowWithSegments:@[ @"remote_documentr", @"foo", @"bar" ]];
  [self writeDummyRowWithSegments:@[ @"remote_documentsa", @"foo", @"bar" ]];
}

- (RemoteDocumentCache *_Nullable)remoteDocumentCache {
  return _cache;
}

- (void)tearDown {
  [super tearDown];
  self.remoteDocumentCache = nil;
  self.persistence = nil;
  _cache = nullptr;
  _db.reset();
}

- (void)writeDummyRowWithSegments:(NSArray<NSString *> *)segments {
  std::string key;
  for (NSString *segment in segments) {
    OrderedCode::WriteString(&key, segment.UTF8String);
  }

  _db->ptr()->Put(WriteOptions(), key, kDummy);
}

@end

NS_ASSUME_NONNULL_END
