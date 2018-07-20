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

#import "Firestore/Example/Tests/Local/FSTLRUGarbageCollectorTests.h"

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLevelDBQueryCache.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"

using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::ResourcePath;

NS_ASSUME_NONNULL_BEGIN

@interface FSTLevelDBLRUGarbageCollectorTests : FSTLRUGarbageCollectorTests
@end

@implementation FSTLevelDBLRUGarbageCollectorTests

- (FSTLevelDB *)newPersistence {
  return [FSTPersistenceTestHelpers levelDBPersistence];
}

- (void)testHighestSequenceNumberPersisted {
  DatabaseId database_id{"p", "d"};

  FSTSerializerBeta *remoteSerializer = [[FSTSerializerBeta alloc] initWithDatabaseID:&database_id];
  FSTLocalSerializer *serializer =
          [[FSTLocalSerializer alloc] initWithRemoteSerializer:remoteSerializer];
  NSString *dir = [FSTPersistenceTestHelpers levelDBDir];

  FSTLevelDB *db1 = [[FSTLevelDB alloc] initWithDirectory:dir serializer:serializer];
  NSError *error;
  [db1 start:&error];
  XCTAssertNil(error);
  FSTLevelDBQueryCache *queryCache = db1.run("setup first db", [&]() -> FSTLevelDBQueryCache * {
    FSTLevelDBQueryCache *queryCache = [db1 queryCache];
    [queryCache start];
    return queryCache;
  });

  XCTAssertEqual(0, queryCache.highestListenSequenceNumber);

  FSTListenSequenceNumber expected = 1234;
  db1.run("add query data", [&]() {
    FSTQuery *query = [FSTQuery queryWithPath:ResourcePath{"some", "path"}];
    FSTQueryData *queryData = [[FSTQueryData alloc] initWithQuery:query
                                                         targetID:1
                                             listenSequenceNumber:expected
                                                          purpose:FSTQueryPurposeListen];
    [queryCache addQueryData:queryData];
  });

  [db1 shutdown];
  db1 = nil;

  FSTLevelDB *db2 = [[FSTLevelDB alloc] initWithDirectory:dir serializer:serializer];
  [db2 start:&error];
  XCTAssertNil(error);
  db2.run("verify sequence number", [&]() {
    // We should remember the previous sequence number, and the next transaction should
    // have a higher one.
    XCTAssertGreaterThan(db2.currentSequenceNumber, expected);
  });
}

@end

NS_ASSUME_NONNULL_END