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

#import "Firestore/Example/Tests/Local/FSTQueryCacheTests.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_query_cache.h"
#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/local/reference_delegate.h"
#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/test/firebase/firestore/local/persistence_testing.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace core = firebase::firestore::core;
namespace testutil = firebase::firestore::testutil;

using firebase::Timestamp;
using firebase::firestore::local::LevelDbDir;
using firebase::firestore::local::LevelDbPersistence;
using firebase::firestore::local::LevelDbPersistenceForTesting;
using firebase::firestore::local::LevelDbQueryCache;
using firebase::firestore::local::Persistence;
using firebase::firestore::local::QueryData;
using firebase::firestore::local::QueryPurpose;
using firebase::firestore::local::ReferenceSet;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::util::Path;
using testutil::Query;

NS_ASSUME_NONNULL_BEGIN

@interface FSTLevelDBQueryCacheTests : FSTQueryCacheTests
@end

/**
 * The tests for FSTLevelDBQueryCache are performed on the FSTQueryCache protocol in
 * FSTQueryCacheTests. This class is merely responsible for setting up and tearing down the
 * @a queryCache.
 */
@implementation FSTLevelDBQueryCacheTests {
  std::unique_ptr<LevelDbPersistence> _db;
  ReferenceSet _additionalReferences;
}

- (LevelDbQueryCache *)getCache:(Persistence *)persistence {
  return static_cast<LevelDbQueryCache *>(persistence->query_cache());
}

- (void)setUp {
  [super setUp];

  _db = LevelDbPersistenceForTesting();
  self.persistence = _db.get();
  self.queryCache = [self getCache:_db.get()];
  self.persistence->reference_delegate()->AddInMemoryPins(&_additionalReferences);
}

- (void)tearDown {
  [super tearDown];
  self.persistence = nullptr;
  self.queryCache = nullptr;
}

- (void)testMetadataPersistedAcrossRestarts {
  self.persistence->Shutdown();
  _db.reset();
  self.persistence = nullptr;

  Path dir = LevelDbDir();

  auto db1 = LevelDbPersistenceForTesting(dir);
  LevelDbQueryCache *queryCache = [self getCache:db1.get()];

  XCTAssertEqual(0, queryCache->highest_listen_sequence_number());
  XCTAssertEqual(0, queryCache->highest_target_id());
  SnapshotVersion versionZero;
  XCTAssertEqual(versionZero, queryCache->GetLastRemoteSnapshotVersion());

  ListenSequenceNumber minimumSequenceNumber = 1234;
  TargetId lastTargetId = 5;
  SnapshotVersion lastVersion(Timestamp(1, 2));

  db1->Run("add query data", [&] {
    core::Query query = Query("some/path");
    QueryData queryData(std::move(query), lastTargetId, minimumSequenceNumber,
                        QueryPurpose::Listen);
    queryCache->AddTarget(queryData);
    queryCache->SetLastRemoteSnapshotVersion(lastVersion);
  });

  db1->Shutdown();
  db1.reset();

  auto db2 = LevelDbPersistenceForTesting(dir);
  db2->Run("verify sequence number", [&] {
    // We should remember the previous sequence number, and the next transaction should
    // have a higher one.
    XCTAssertGreaterThan(db2->current_sequence_number(), minimumSequenceNumber);
  });

  LevelDbQueryCache *queryCache2 = [self getCache:db2.get()];
  XCTAssertEqual(lastTargetId, queryCache2->highest_target_id());
  XCTAssertEqual(lastVersion, queryCache2->GetLastRemoteSnapshotVersion());

  db2->Shutdown();
  db2.reset();
}

- (void)testRemoveMatchingKeysForTargetID {
  self.persistence->Run("testRemoveMatchingKeysForTargetID", [&]() {
    DocumentKey key1 = testutil::Key("foo/bar");
    DocumentKey key2 = testutil::Key("foo/baz");
    DocumentKey key3 = testutil::Key("foo/blah");

    LevelDbQueryCache *cache = [self getCache:self.persistence];
    [self addMatchingKey:key1 forTargetID:1];
    [self addMatchingKey:key2 forTargetID:1];
    [self addMatchingKey:key3 forTargetID:2];
    XCTAssertTrue(cache->Contains(key1));
    XCTAssertTrue(cache->Contains(key2));
    XCTAssertTrue(cache->Contains(key3));

    cache->RemoveAllKeysForTarget(1);
    XCTAssertFalse(self.queryCache->Contains(key1));
    XCTAssertFalse(self.queryCache->Contains(key2));
    XCTAssertTrue(self.queryCache->Contains(key3));

    cache->RemoveAllKeysForTarget(2);
    XCTAssertFalse(self.queryCache->Contains(key1));
    XCTAssertFalse(self.queryCache->Contains(key2));
    XCTAssertFalse(self.queryCache->Contains(key3));
  });
}

@end

NS_ASSUME_NONNULL_END
