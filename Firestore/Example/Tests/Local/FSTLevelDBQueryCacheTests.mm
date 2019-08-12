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

#import "Firestore/Source/Local/FSTLevelDB.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#import "Firestore/Example/Tests/Local/FSTQueryCacheTests.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_query_cache.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::Timestamp;
using firebase::firestore::local::LevelDbQueryCache;
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
  ReferenceSet _additionalReferences;
}

- (LevelDbQueryCache *)getCache:(id<FSTPersistence>)persistence {
  return static_cast<LevelDbQueryCache *>(persistence.queryCache);
}

- (void)setUp {
  [super setUp];

  self.persistence = [FSTPersistenceTestHelpers levelDBPersistence];
  self.queryCache = [self getCache:self.persistence];
  [self.persistence.referenceDelegate addInMemoryPins:&_additionalReferences];
}

- (void)tearDown {
  [super tearDown];
  self.persistence = nil;
  self.queryCache = nil;
}

- (void)testMetadataPersistedAcrossRestarts {
  [self.persistence shutdown];
  self.persistence = nil;

  Path dir = [FSTPersistenceTestHelpers levelDBDir];

  FSTLevelDB *db1 = [FSTPersistenceTestHelpers levelDBPersistenceWithDir:dir];
  LevelDbQueryCache *queryCache = [self getCache:db1];

  XCTAssertEqual(0, queryCache->highest_listen_sequence_number());
  XCTAssertEqual(0, queryCache->highest_target_id());
  SnapshotVersion versionZero;
  XCTAssertEqual(versionZero, queryCache->GetLastRemoteSnapshotVersion());

  ListenSequenceNumber minimumSequenceNumber = 1234;
  TargetId lastTargetId = 5;
  SnapshotVersion lastVersion(Timestamp(1, 2));

  db1.run("add query data", [&]() {
    core::Query query = Query("some/path");
    QueryData queryData(std::move(query), lastTargetId, minimumSequenceNumber,
                        QueryPurpose::Listen);
    queryCache->AddTarget(queryData);
    queryCache->SetLastRemoteSnapshotVersion(lastVersion);
  });

  [db1 shutdown];
  db1 = nil;

  FSTLevelDB *db2 = [FSTPersistenceTestHelpers levelDBPersistenceWithDir:dir];
  db2.run("verify sequence number", [&]() {
    // We should remember the previous sequence number, and the next transaction should
    // have a higher one.
    XCTAssertGreaterThan(db2.currentSequenceNumber, minimumSequenceNumber);
  });

  LevelDbQueryCache *queryCache2 = [self getCache:db2];
  XCTAssertEqual(lastTargetId, queryCache2->highest_target_id());
  XCTAssertEqual(lastVersion, queryCache2->GetLastRemoteSnapshotVersion());

  [db2 shutdown];
  db2 = nil;
}

- (void)testRemoveMatchingKeysForTargetID {
  self.persistence.run("testRemoveMatchingKeysForTargetID", [&]() {
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
