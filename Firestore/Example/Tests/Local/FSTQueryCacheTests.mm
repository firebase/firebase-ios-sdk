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

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Local/FSTEagerGarbageCollector.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Local/FSTWriteGroup.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/third_party/Immutable/Tests/FSTImmutableSortedSet+Testing.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::model::DocumentKey;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTQueryCacheTests {
  FSTQuery *_queryRooms;
  FSTListenSequenceNumber _previousSequenceNumber;
  FSTTargetID _previousTargetID;
  FSTTestSnapshotVersion _previousSnapshotVersion;
}

- (void)setUp {
  [super setUp];

  _queryRooms = FSTTestQuery("rooms");
  _previousSequenceNumber = 1000;
  _previousTargetID = 500;
  _previousSnapshotVersion = 100;
}

/**
 * Xcode will run tests from any class that extends XCTestCase, but this doesn't work for
 * FSTSpecTests since it is incomplete without the implementations supplied by its subclasses.
 */
- (BOOL)isTestBaseClass {
  return [self class] == [FSTQueryCacheTests class];
}

- (void)testReadQueryNotInCache {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"ReadQueryNotInCache"];
  XCTAssertNil([self.queryCache queryDataForQuery:_queryRooms]);
  [self.persistence commitGroup:group];
}

- (void)testSetAndReadAQuery {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"SetAndReadQuery"];
  FSTQueryData *queryData = [self queryDataWithQuery:_queryRooms];
  [self.queryCache addQueryData:queryData group:group];

  FSTQueryData *result = [self.queryCache queryDataForQuery:_queryRooms];
  XCTAssertEqualObjects(result.query, queryData.query);
  XCTAssertEqual(result.targetID, queryData.targetID);
  XCTAssertEqualObjects(result.resumeToken, queryData.resumeToken);
  [self.persistence commitGroup:group];
}

- (void)testCanonicalIDCollision {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"CanonicalIDCollision"];
  // Type information is currently lost in our canonicalID implementations so this currently an
  // easy way to force colliding canonicalIDs
  FSTQuery *q1 = [FSTTestQuery("a") queryByAddingFilter:FSTTestFilter("foo", @"==", @(1))];
  FSTQuery *q2 = [FSTTestQuery("a") queryByAddingFilter:FSTTestFilter("foo", @"==", @"1")];
  XCTAssertEqualObjects(q1.canonicalID, q2.canonicalID);

  FSTQueryData *data1 = [self queryDataWithQuery:q1];
  [self.queryCache addQueryData:data1 group:group];

  // Using the other query should not return the query cache entry despite equal canonicalIDs.
  XCTAssertNil([self.queryCache queryDataForQuery:q2]);
  XCTAssertEqualObjects([self.queryCache queryDataForQuery:q1], data1);

  FSTQueryData *data2 = [self queryDataWithQuery:q2];
  [self.queryCache addQueryData:data2 group:group];
  XCTAssertEqual([self.queryCache count], 2);

  XCTAssertEqualObjects([self.queryCache queryDataForQuery:q1], data1);
  XCTAssertEqualObjects([self.queryCache queryDataForQuery:q2], data2);

  [self.queryCache removeQueryData:data1 group:group];
  XCTAssertNil([self.queryCache queryDataForQuery:q1]);
  XCTAssertEqualObjects([self.queryCache queryDataForQuery:q2], data2);
  XCTAssertEqual([self.queryCache count], 1);

  [self.queryCache removeQueryData:data2 group:group];
  XCTAssertNil([self.queryCache queryDataForQuery:q1]);
  XCTAssertNil([self.queryCache queryDataForQuery:q2]);
  XCTAssertEqual([self.queryCache count], 0);
  [self.persistence commitGroup:group];
}

- (void)testSetQueryToNewValue {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"SetQueryToNewValue"];
  FSTQueryData *queryData1 =
      [self queryDataWithQuery:_queryRooms targetID:1 listenSequenceNumber:10 version:1];
  [self.queryCache addQueryData:queryData1 group:group];

  FSTQueryData *queryData2 =
      [self queryDataWithQuery:_queryRooms targetID:1 listenSequenceNumber:10 version:2];
  [self.queryCache addQueryData:queryData2 group:group];

  FSTQueryData *result = [self.queryCache queryDataForQuery:_queryRooms];
  XCTAssertNotEqualObjects(queryData2.resumeToken, queryData1.resumeToken);
  XCTAssertNotEqualObjects(queryData2.snapshotVersion, queryData1.snapshotVersion);
  XCTAssertEqualObjects(result.resumeToken, queryData2.resumeToken);
  XCTAssertEqualObjects(result.snapshotVersion, queryData2.snapshotVersion);
  [self.persistence commitGroup:group];
}

- (void)testRemoveQuery {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"RemoveQuery"];
  FSTQueryData *queryData1 = [self queryDataWithQuery:_queryRooms];
  [self.queryCache addQueryData:queryData1 group:group];

  [self.queryCache removeQueryData:queryData1 group:group];

  FSTQueryData *result = [self.queryCache queryDataForQuery:_queryRooms];
  XCTAssertNil(result);
  [self.persistence commitGroup:group];
}

- (void)testRemoveNonExistentQuery {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"RemoveNonExistentQuery"];
  FSTQueryData *queryData = [self queryDataWithQuery:_queryRooms];

  // no-op, but make sure it doesn't throw.
  XCTAssertNoThrow([self.queryCache removeQueryData:queryData group:group]);
  [self.persistence commitGroup:group];
}

- (void)testRemoveQueryRemovesMatchingKeysToo {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group =
      [self.persistence startGroupWithAction:@"RemoveQueryRemovesMatchingKeysToo"];
  FSTQueryData *rooms = [self queryDataWithQuery:_queryRooms];
  [self.queryCache addQueryData:rooms group:group];

  DocumentKey key1 = testutil::Key("rooms/foo");
  DocumentKey key2 = testutil::Key("rooms/bar");
  [self addMatchingKey:key1 forTargetID:rooms.targetID group:group];
  [self addMatchingKey:key2 forTargetID:rooms.targetID group:group];

  XCTAssertTrue([self.queryCache containsKey:key1]);
  XCTAssertTrue([self.queryCache containsKey:key2]);

  [self.queryCache removeQueryData:rooms group:group];
  XCTAssertFalse([self.queryCache containsKey:key1]);
  XCTAssertFalse([self.queryCache containsKey:key2]);
  [self.persistence commitGroup:group];
}

- (void)testAddOrRemoveMatchingKeys {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"AddOrRemoveMatchingKeys"];
  DocumentKey key = testutil::Key("foo/bar");

  XCTAssertFalse([self.queryCache containsKey:key]);

  [self addMatchingKey:key forTargetID:1 group:group];
  XCTAssertTrue([self.queryCache containsKey:key]);

  [self addMatchingKey:key forTargetID:2 group:group];
  XCTAssertTrue([self.queryCache containsKey:key]);

  [self removeMatchingKey:key forTargetID:1 group:group];
  XCTAssertTrue([self.queryCache containsKey:key]);

  [self removeMatchingKey:key forTargetID:2 group:group];
  XCTAssertFalse([self.queryCache containsKey:key]);
  [self.persistence commitGroup:group];
}

- (void)testRemoveMatchingKeysForTargetID {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"RemoveMatchingKeysForTargetID"];
  DocumentKey key1 = testutil::Key("foo/bar");
  DocumentKey key2 = testutil::Key("foo/baz");
  DocumentKey key3 = testutil::Key("foo/blah");

  [self addMatchingKey:key1 forTargetID:1 group:group];
  [self addMatchingKey:key2 forTargetID:1 group:group];
  [self addMatchingKey:key3 forTargetID:2 group:group];
  XCTAssertTrue([self.queryCache containsKey:key1]);
  XCTAssertTrue([self.queryCache containsKey:key2]);
  XCTAssertTrue([self.queryCache containsKey:key3]);

  [self.queryCache removeMatchingKeysForTargetID:1 group:group];
  XCTAssertFalse([self.queryCache containsKey:key1]);
  XCTAssertFalse([self.queryCache containsKey:key2]);
  XCTAssertTrue([self.queryCache containsKey:key3]);

  [self.queryCache removeMatchingKeysForTargetID:2 group:group];
  XCTAssertFalse([self.queryCache containsKey:key1]);
  XCTAssertFalse([self.queryCache containsKey:key2]);
  XCTAssertFalse([self.queryCache containsKey:key3]);
  [self.persistence commitGroup:group];
}

- (void)testRemoveEmitsGarbageEvents {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"RemoveEmitsGarbageEvents"];
  FSTEagerGarbageCollector *garbageCollector = [[FSTEagerGarbageCollector alloc] init];
  [garbageCollector addGarbageSource:self.queryCache];
  XCTAssertEqual([garbageCollector collectGarbage], std::set<DocumentKey>({}));

  FSTQueryData *rooms = [self queryDataWithQuery:FSTTestQuery("rooms")];
  DocumentKey room1 = testutil::Key("rooms/bar");
  DocumentKey room2 = testutil::Key("rooms/foo");
  [self.queryCache addQueryData:rooms group:group];
  [self addMatchingKey:room1 forTargetID:rooms.targetID group:group];
  [self addMatchingKey:room2 forTargetID:rooms.targetID group:group];

  FSTQueryData *halls = [self queryDataWithQuery:FSTTestQuery("halls")];
  DocumentKey hall1 = testutil::Key("halls/bar");
  DocumentKey hall2 = testutil::Key("halls/foo");
  [self.queryCache addQueryData:halls group:group];
  [self addMatchingKey:hall1 forTargetID:halls.targetID group:group];
  [self addMatchingKey:hall2 forTargetID:halls.targetID group:group];

  XCTAssertEqual([garbageCollector collectGarbage], std::set<DocumentKey>({}));

  [self removeMatchingKey:room1 forTargetID:rooms.targetID group:group];
  XCTAssertEqual([garbageCollector collectGarbage], std::set<DocumentKey>({room1}));

  [self.queryCache removeQueryData:rooms group:group];
  XCTAssertEqual([garbageCollector collectGarbage], std::set<DocumentKey>({room2}));

  [self.queryCache removeMatchingKeysForTargetID:halls.targetID group:group];
  XCTAssertEqual([garbageCollector collectGarbage], std::set<DocumentKey>({hall1, hall2}));
  [self.persistence commitGroup:group];
}

- (void)testMatchingKeysForTargetID {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"MatchingKeysForTargetID"];
  DocumentKey key1 = testutil::Key("foo/bar");
  DocumentKey key2 = testutil::Key("foo/baz");
  DocumentKey key3 = testutil::Key("foo/blah");

  [self addMatchingKey:key1 forTargetID:1 group:group];
  [self addMatchingKey:key2 forTargetID:1 group:group];
  [self addMatchingKey:key3 forTargetID:2 group:group];

  FSTAssertEqualSets([self.queryCache matchingKeysForTargetID:1], (@[ key1, key2 ]));
  FSTAssertEqualSets([self.queryCache matchingKeysForTargetID:2], @[ key3 ]);

  [self addMatchingKey:key1 forTargetID:2 group:group];
  FSTAssertEqualSets([self.queryCache matchingKeysForTargetID:1], (@[ key1, key2 ]));
  FSTAssertEqualSets([self.queryCache matchingKeysForTargetID:2], (@[ key1, key3 ]));
  [self.persistence commitGroup:group];
}

- (void)testHighestListenSequenceNumber {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"HighestListenSequenceNumber"];
  FSTQueryData *query1 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery("rooms")
                                                    targetID:1
                                        listenSequenceNumber:10
                                                     purpose:FSTQueryPurposeListen];
  [self.queryCache addQueryData:query1 group:group];
  FSTQueryData *query2 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery("halls")
                                                    targetID:2
                                        listenSequenceNumber:20
                                                     purpose:FSTQueryPurposeListen];
  [self.queryCache addQueryData:query2 group:group];
  XCTAssertEqual([self.queryCache highestListenSequenceNumber], 20);

  // TargetIDs never come down.
  [self.queryCache removeQueryData:query2 group:group];
  XCTAssertEqual([self.queryCache highestListenSequenceNumber], 20);

  // A query with an empty result set still counts.
  FSTQueryData *query3 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery("garages")
                                                    targetID:42
                                        listenSequenceNumber:100
                                                     purpose:FSTQueryPurposeListen];
  [self.queryCache addQueryData:query3 group:group];
  XCTAssertEqual([self.queryCache highestListenSequenceNumber], 100);

  [self.queryCache removeQueryData:query1 group:group];
  XCTAssertEqual([self.queryCache highestListenSequenceNumber], 100);

  [self.queryCache removeQueryData:query3 group:group];
  XCTAssertEqual([self.queryCache highestListenSequenceNumber], 100);
  [self.persistence commitGroup:group];

  // Verify that the highestTargetID even survives restarts.
  [self.queryCache shutdown];
  self.queryCache = [self.persistence queryCache];
  [self.queryCache start];
  XCTAssertEqual([self.queryCache highestListenSequenceNumber], 100);
}

- (void)testHighestTargetID {
  if ([self isTestBaseClass]) return;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"RemoveMatchingKeysForTargetID"];
  XCTAssertEqual([self.queryCache highestTargetID], 0);

  FSTQueryData *query1 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery("rooms")
                                                    targetID:1
                                        listenSequenceNumber:10
                                                     purpose:FSTQueryPurposeListen];
  DocumentKey key1 = testutil::Key("rooms/bar");
  DocumentKey key2 = testutil::Key("rooms/foo");
  [self.queryCache addQueryData:query1 group:group];
  [self addMatchingKey:key1 forTargetID:1 group:group];
  [self addMatchingKey:key2 forTargetID:1 group:group];

  FSTQueryData *query2 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery("halls")
                                                    targetID:2
                                        listenSequenceNumber:20
                                                     purpose:FSTQueryPurposeListen];
  DocumentKey key3 = testutil::Key("halls/foo");
  [self.queryCache addQueryData:query2 group:group];
  [self addMatchingKey:key3 forTargetID:2 group:group];
  XCTAssertEqual([self.queryCache highestTargetID], 2);

  // TargetIDs never come down.
  [self.queryCache removeQueryData:query2 group:group];
  XCTAssertEqual([self.queryCache highestTargetID], 2);

  // A query with an empty result set still counts.
  FSTQueryData *query3 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery("garages")
                                                    targetID:42
                                        listenSequenceNumber:100
                                                     purpose:FSTQueryPurposeListen];
  [self.queryCache addQueryData:query3 group:group];
  XCTAssertEqual([self.queryCache highestTargetID], 42);

  [self.queryCache removeQueryData:query1 group:group];
  XCTAssertEqual([self.queryCache highestTargetID], 42);

  [self.queryCache removeQueryData:query3 group:group];
  XCTAssertEqual([self.queryCache highestTargetID], 42);
  [self.persistence commitGroup:group];
  // Verify that the highestTargetID even survives restarts.
  [self.queryCache shutdown];
  self.queryCache = [self.persistence queryCache];
  [self.queryCache start];
  XCTAssertEqual([self.queryCache highestTargetID], 42);
}

- (void)testLastRemoteSnapshotVersion {
  if ([self isTestBaseClass]) return;

  XCTAssertEqualObjects([self.queryCache lastRemoteSnapshotVersion],
                        [FSTSnapshotVersion noVersion]);

  // Can set the snapshot version.
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"setLastRemoteSnapshotVersion"];
  [self.queryCache setLastRemoteSnapshotVersion:FSTTestVersion(42) group:group];
  [self.persistence commitGroup:group];
  XCTAssertEqualObjects([self.queryCache lastRemoteSnapshotVersion], FSTTestVersion(42));

  // Snapshot version persists restarts.
  self.queryCache = [self.persistence queryCache];
  [self.queryCache start];
  XCTAssertEqualObjects([self.queryCache lastRemoteSnapshotVersion], FSTTestVersion(42));
}

#pragma mark - Helpers

/**
 * Creates a new FSTQueryData object from the given parameters, synthesizing a resume token from
 * the snapshot version.
 */
- (FSTQueryData *)queryDataWithQuery:(FSTQuery *)query {
  return [self queryDataWithQuery:query
                         targetID:++_previousTargetID
             listenSequenceNumber:++_previousSequenceNumber
                          version:++_previousSnapshotVersion];
}

- (FSTQueryData *)queryDataWithQuery:(FSTQuery *)query
                            targetID:(FSTTargetID)targetID
                listenSequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                             version:(FSTTestSnapshotVersion)version {
  NSData *resumeToken = FSTTestResumeTokenFromSnapshotVersion(version);
  return [[FSTQueryData alloc] initWithQuery:query
                                    targetID:targetID
                        listenSequenceNumber:sequenceNumber
                                     purpose:FSTQueryPurposeListen
                             snapshotVersion:FSTTestVersion(version)
                                 resumeToken:resumeToken];
}

- (void)addMatchingKey:(const DocumentKey &)key
           forTargetID:(FSTTargetID)targetID
                 group:(FSTWriteGroup *)group {
  FSTDocumentKeySet *keys = [FSTDocumentKeySet keySet];
  keys = [keys setByAddingObject:key];
  [self.queryCache addMatchingKeys:keys forTargetID:targetID group:group];
}

- (void)removeMatchingKey:(const DocumentKey &)key
              forTargetID:(FSTTargetID)targetID
                    group:(FSTWriteGroup *)group {
  FSTDocumentKeySet *keys = [FSTDocumentKeySet keySet];
  keys = [keys setByAddingObject:key];
  [self.queryCache removeMatchingKeys:keys forTargetID:targetID group:group];
}

@end

NS_ASSUME_NONNULL_END
