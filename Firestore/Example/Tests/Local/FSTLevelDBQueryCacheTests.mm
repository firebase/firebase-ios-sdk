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

#import "Firestore/Source/Local/FSTLevelDBQueryCache.h"

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#import "Firestore/Example/Tests/Local/FSTQueryCacheTests.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

using firebase::Timestamp;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::util::Path;

NS_ASSUME_NONNULL_BEGIN

@interface FSTLevelDBQueryCacheTests : FSTQueryCacheTests
@end

/**
 * The tests for FSTLevelDBQueryCache are performed on the FSTQueryCache protocol in
 * FSTQueryCacheTests. This class is merely responsible for setting up and tearing down the
 * @a queryCache.
 */
@implementation FSTLevelDBQueryCacheTests

- (void)setUp {
  [super setUp];

  self.persistence = [FSTPersistenceTestHelpers levelDBPersistence];
  self.queryCache = [self.persistence queryCache];
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
  FSTLevelDBQueryCache *queryCache = [db1 queryCache];

  XCTAssertEqual(0, queryCache.highestListenSequenceNumber);
  XCTAssertEqual(0, queryCache.highestTargetID);
  SnapshotVersion versionZero;
  XCTAssertEqual(versionZero, queryCache.lastRemoteSnapshotVersion);

  ListenSequenceNumber minimumSequenceNumber = 1234;
  TargetId lastTargetId = 5;
  SnapshotVersion lastVersion(Timestamp(1, 2));

  db1.run("add query data", [&]() {
    FSTQuery *query = [FSTQuery queryWithPath:ResourcePath{"some", "path"}];
    FSTQueryData *queryData = [[FSTQueryData alloc] initWithQuery:query
                                                         targetID:lastTargetId
                                             listenSequenceNumber:minimumSequenceNumber
                                                          purpose:FSTQueryPurposeListen];
    [queryCache addQueryData:queryData];
    [queryCache setLastRemoteSnapshotVersion:lastVersion];
  });

  [db1 shutdown];
  db1 = nil;

  FSTLevelDB *db2 = [FSTPersistenceTestHelpers levelDBPersistenceWithDir:dir];
  db2.run("verify sequence number", [&]() {
    // We should remember the previous sequence number, and the next transaction should
    // have a higher one.
    XCTAssertGreaterThan(db2.currentSequenceNumber, minimumSequenceNumber);
  });

  FSTLevelDBQueryCache *queryCache2 = [db2 queryCache];
  XCTAssertEqual(lastTargetId, queryCache2.highestTargetID);
  XCTAssertEqual(lastVersion, queryCache2.lastRemoteSnapshotVersion);

  [db2 shutdown];
  db2 = nil;
}

@end

NS_ASSUME_NONNULL_END
