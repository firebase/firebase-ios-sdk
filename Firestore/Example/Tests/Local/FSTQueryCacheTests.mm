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
#import "Firestore/Source/Model/FSTDocumentKey.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/third_party/Immutable/Tests/FSTImmutableSortedSet+Testing.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FSTQueryCacheTests {
  FSTQuery *_queryRooms;
  FSTListenSequenceNumber _previousSequenceNumber;
  FSTTargetID _previousTargetID;
  FSTTestSnapshotVersion _previousSnapshotVersion;
}

- (void)setUp {
  [super setUp];

  _queryRooms = FSTTestQuery(@"rooms");
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

  XCTAssertNil([self.queryCache queryDataForQuery:_queryRooms]);
}

- (void)testSetAndReadAQuery {
  if ([self isTestBaseClass]) return;

  FSTQueryData *queryData = [self queryDataWithQuery:_queryRooms];
  [self addQueryData:queryData];

  FSTQueryData *result = [self.queryCache queryDataForQuery:_queryRooms];
  XCTAssertEqualObjects(result.query, queryData.query);
  XCTAssertEqual(result.targetID, queryData.targetID);
  XCTAssertEqualObjects(result.resumeToken, queryData.resumeToken);
}

- (void)testCanonicalIDCollision {
  if ([self isTestBaseClass]) return;

  // Type information is currently lost in our canonicalID implementations so this currently an
  // easy way to force colliding canonicalIDs
  FSTQuery *q1 = [FSTTestQuery(@"a") queryByAddingFilter:FSTTestFilter(@"foo", @"==", @(1))];
  FSTQuery *q2 = [FSTTestQuery(@"a") queryByAddingFilter:FSTTestFilter(@"foo", @"==", @"1")];
  XCTAssertEqualObjects(q1.canonicalID, q2.canonicalID);

  FSTQueryData *data1 = [self queryDataWithQuery:q1];
  [self addQueryData:data1];

  // Using the other query should not return the query cache entry despite equal canonicalIDs.
  XCTAssertNil([self.queryCache queryDataForQuery:q2]);
  XCTAssertEqualObjects([self.queryCache queryDataForQuery:q1], data1);

  FSTQueryData *data2 = [self queryDataWithQuery:q2];
  [self addQueryData:data2];
  XCTAssertEqual([self.queryCache count], 2);

  XCTAssertEqualObjects([self.queryCache queryDataForQuery:q1], data1);
  XCTAssertEqualObjects([self.queryCache queryDataForQuery:q2], data2);

  [self removeQueryData:data1];
  XCTAssertNil([self.queryCache queryDataForQuery:q1]);
  XCTAssertEqualObjects([self.queryCache queryDataForQuery:q2], data2);
  XCTAssertEqual([self.queryCache count], 1);

  [self removeQueryData:data2];
  XCTAssertNil([self.queryCache queryDataForQuery:q1]);
  XCTAssertNil([self.queryCache queryDataForQuery:q2]);
  XCTAssertEqual([self.queryCache count], 0);
}

- (void)testSetQueryToNewValue {
  if ([self isTestBaseClass]) return;

  FSTQueryData *queryData1 =
      [self queryDataWithQuery:_queryRooms targetID:1 listenSequenceNumber:10 version:1];
  [self addQueryData:queryData1];

  FSTQueryData *queryData2 =
      [self queryDataWithQuery:_queryRooms targetID:1 listenSequenceNumber:10 version:2];
  [self addQueryData:queryData2];

  FSTQueryData *result = [self.queryCache queryDataForQuery:_queryRooms];
  XCTAssertNotEqualObjects(queryData2.resumeToken, queryData1.resumeToken);
  XCTAssertNotEqualObjects(queryData2.snapshotVersion, queryData1.snapshotVersion);
  XCTAssertEqualObjects(result.resumeToken, queryData2.resumeToken);
  XCTAssertEqualObjects(result.snapshotVersion, queryData2.snapshotVersion);
}

- (void)testRemoveQuery {
  if ([self isTestBaseClass]) return;

  FSTQueryData *queryData1 = [self queryDataWithQuery:_queryRooms];
  [self addQueryData:queryData1];

  [self removeQueryData:queryData1];

  FSTQueryData *result = [self.queryCache queryDataForQuery:_queryRooms];
  XCTAssertNil(result);
}

- (void)testRemoveNonExistentQuery {
  if ([self isTestBaseClass]) return;

  FSTQueryData *queryData = [self queryDataWithQuery:_queryRooms];

  // no-op, but make sure it doesn't throw.
  XCTAssertNoThrow([self removeQueryData:queryData]);
}

- (void)testRemoveQueryRemovesMatchingKeysToo {
  if ([self isTestBaseClass]) return;

  FSTQueryData *rooms = [self queryDataWithQuery:_queryRooms];
  [self addQueryData:rooms];

  FSTDocumentKey *key1 = FSTTestDocKey(@"rooms/foo");
  FSTDocumentKey *key2 = FSTTestDocKey(@"rooms/bar");
  [self addMatchingKey:key1 forTargetID:rooms.targetID];
  [self addMatchingKey:key2 forTargetID:rooms.targetID];

  XCTAssertTrue([self.queryCache containsKey:key1]);
  XCTAssertTrue([self.queryCache containsKey:key2]);

  [self removeQueryData:rooms];
  XCTAssertFalse([self.queryCache containsKey:key1]);
  XCTAssertFalse([self.queryCache containsKey:key2]);
}

- (void)testAddOrRemoveMatchingKeys {
  if ([self isTestBaseClass]) return;

  FSTDocumentKey *key = FSTTestDocKey(@"foo/bar");

  XCTAssertFalse([self.queryCache containsKey:key]);

  [self addMatchingKey:key forTargetID:1];
  XCTAssertTrue([self.queryCache containsKey:key]);

  [self addMatchingKey:key forTargetID:2];
  XCTAssertTrue([self.queryCache containsKey:key]);

  [self removeMatchingKey:key forTargetID:1];
  XCTAssertTrue([self.queryCache containsKey:key]);

  [self removeMatchingKey:key forTargetID:2];
  XCTAssertFalse([self.queryCache containsKey:key]);
}

- (void)testRemoveMatchingKeysForTargetID {
  if ([self isTestBaseClass]) return;

  FSTDocumentKey *key1 = FSTTestDocKey(@"foo/bar");
  FSTDocumentKey *key2 = FSTTestDocKey(@"foo/baz");
  FSTDocumentKey *key3 = FSTTestDocKey(@"foo/blah");

  [self addMatchingKey:key1 forTargetID:1];
  [self addMatchingKey:key2 forTargetID:1];
  [self addMatchingKey:key3 forTargetID:2];
  XCTAssertTrue([self.queryCache containsKey:key1]);
  XCTAssertTrue([self.queryCache containsKey:key2]);
  XCTAssertTrue([self.queryCache containsKey:key3]);

  [self removeMatchingKeysForTargetID:1];
  XCTAssertFalse([self.queryCache containsKey:key1]);
  XCTAssertFalse([self.queryCache containsKey:key2]);
  XCTAssertTrue([self.queryCache containsKey:key3]);

  [self removeMatchingKeysForTargetID:2];
  XCTAssertFalse([self.queryCache containsKey:key1]);
  XCTAssertFalse([self.queryCache containsKey:key2]);
  XCTAssertFalse([self.queryCache containsKey:key3]);
}

- (void)testRemoveEmitsGarbageEvents {
  if ([self isTestBaseClass]) return;

  FSTEagerGarbageCollector *garbageCollector = [[FSTEagerGarbageCollector alloc] init];
  [garbageCollector addGarbageSource:self.queryCache];
  FSTAssertEqualSets([garbageCollector collectGarbage], @[]);

  FSTQueryData *rooms = [self queryDataWithQuery:FSTTestQuery(@"rooms")];
  FSTDocumentKey *room1 = FSTTestDocKey(@"rooms/bar");
  FSTDocumentKey *room2 = FSTTestDocKey(@"rooms/foo");
  [self addQueryData:rooms];
  [self addMatchingKey:room1 forTargetID:rooms.targetID];
  [self addMatchingKey:room2 forTargetID:rooms.targetID];

  FSTQueryData *halls = [self queryDataWithQuery:FSTTestQuery(@"halls")];
  FSTDocumentKey *hall1 = FSTTestDocKey(@"halls/bar");
  FSTDocumentKey *hall2 = FSTTestDocKey(@"halls/foo");
  [self addQueryData:halls];
  [self addMatchingKey:hall1 forTargetID:halls.targetID];
  [self addMatchingKey:hall2 forTargetID:halls.targetID];

  FSTAssertEqualSets([garbageCollector collectGarbage], @[]);

  [self removeMatchingKey:room1 forTargetID:rooms.targetID];
  FSTAssertEqualSets([garbageCollector collectGarbage], @[ room1 ]);

  [self removeQueryData:rooms];
  FSTAssertEqualSets([garbageCollector collectGarbage], @[ room2 ]);

  [self removeMatchingKeysForTargetID:halls.targetID];
  FSTAssertEqualSets([garbageCollector collectGarbage], (@[ hall1, hall2 ]));
}

- (void)testMatchingKeysForTargetID {
  if ([self isTestBaseClass]) return;

  FSTDocumentKey *key1 = FSTTestDocKey(@"foo/bar");
  FSTDocumentKey *key2 = FSTTestDocKey(@"foo/baz");
  FSTDocumentKey *key3 = FSTTestDocKey(@"foo/blah");

  [self addMatchingKey:key1 forTargetID:1];
  [self addMatchingKey:key2 forTargetID:1];
  [self addMatchingKey:key3 forTargetID:2];

  FSTAssertEqualSets([self.queryCache matchingKeysForTargetID:1], (@[ key1, key2 ]));
  FSTAssertEqualSets([self.queryCache matchingKeysForTargetID:2], @[ key3 ]);

  [self addMatchingKey:key1 forTargetID:2];
  FSTAssertEqualSets([self.queryCache matchingKeysForTargetID:1], (@[ key1, key2 ]));
  FSTAssertEqualSets([self.queryCache matchingKeysForTargetID:2], (@[ key1, key3 ]));
}

- (void)testHighestListenSequenceNumber {
  if ([self isTestBaseClass]) return;

  FSTQueryData *query1 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery(@"rooms")
                                                    targetID:1
                                        listenSequenceNumber:10
                                                     purpose:FSTQueryPurposeListen];
  [self addQueryData:query1];
  FSTQueryData *query2 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery(@"halls")
                                                    targetID:2
                                        listenSequenceNumber:20
                                                     purpose:FSTQueryPurposeListen];
  [self addQueryData:query2];
  XCTAssertEqual([self.queryCache highestListenSequenceNumber], 20);

  // TargetIDs never come down.
  [self removeQueryData:query2];
  XCTAssertEqual([self.queryCache highestListenSequenceNumber], 20);

  // A query with an empty result set still counts.
  FSTQueryData *query3 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery(@"garages")
                                                    targetID:42
                                        listenSequenceNumber:100
                                                     purpose:FSTQueryPurposeListen];
  [self addQueryData:query3];
  XCTAssertEqual([self.queryCache highestListenSequenceNumber], 100);

  [self removeQueryData:query1];
  XCTAssertEqual([self.queryCache highestListenSequenceNumber], 100);

  [self removeQueryData:query3];
  XCTAssertEqual([self.queryCache highestListenSequenceNumber], 100);

  // Verify that the highestTargetID even survives restarts.
  [self.queryCache shutdown];
  self.queryCache = [self.persistence queryCache];
  [self.queryCache start];
  XCTAssertEqual([self.queryCache highestListenSequenceNumber], 100);
}

- (void)testHighestTargetID {
  if ([self isTestBaseClass]) return;

  XCTAssertEqual([self.queryCache highestTargetID], 0);

  FSTQueryData *query1 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery(@"rooms")
                                                    targetID:1
                                        listenSequenceNumber:10
                                                     purpose:FSTQueryPurposeListen];
  FSTDocumentKey *key1 = FSTTestDocKey(@"rooms/bar");
  FSTDocumentKey *key2 = FSTTestDocKey(@"rooms/foo");
  [self addQueryData:query1];
  [self addMatchingKey:key1 forTargetID:1];
  [self addMatchingKey:key2 forTargetID:1];

  FSTQueryData *query2 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery(@"halls")
                                                    targetID:2
                                        listenSequenceNumber:20
                                                     purpose:FSTQueryPurposeListen];
  FSTDocumentKey *key3 = FSTTestDocKey(@"halls/foo");
  [self addQueryData:query2];
  [self addMatchingKey:key3 forTargetID:2];
  XCTAssertEqual([self.queryCache highestTargetID], 2);

  // TargetIDs never come down.
  [self removeQueryData:query2];
  XCTAssertEqual([self.queryCache highestTargetID], 2);

  // A query with an empty result set still counts.
  FSTQueryData *query3 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery(@"garages")
                                                    targetID:42
                                        listenSequenceNumber:100
                                                     purpose:FSTQueryPurposeListen];
  [self addQueryData:query3];
  XCTAssertEqual([self.queryCache highestTargetID], 42);

  [self removeQueryData:query1];
  XCTAssertEqual([self.queryCache highestTargetID], 42);

  [self removeQueryData:query3];
  XCTAssertEqual([self.queryCache highestTargetID], 42);

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

/** Adds the given query data to the queryCache under test, committing immediately. */
- (void)addQueryData:(FSTQueryData *)queryData {
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"addQueryData"];
  [self.queryCache addQueryData:queryData group:group];
  [self.persistence commitGroup:group];
}

/** Removes the given query data from the queryCache under test, committing immediately. */
- (void)removeQueryData:(FSTQueryData *)queryData {
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"removeQueryData"];
  [self.queryCache removeQueryData:queryData group:group];
  [self.persistence commitGroup:group];
}

- (void)addMatchingKey:(FSTDocumentKey *)key forTargetID:(FSTTargetID)targetID {
  FSTDocumentKeySet *keys = [FSTDocumentKeySet keySet];
  keys = [keys setByAddingObject:key];

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"addMatchingKeys"];
  [self.queryCache addMatchingKeys:keys forTargetID:targetID group:group];
  [self.persistence commitGroup:group];
}

- (void)removeMatchingKey:(FSTDocumentKey *)key forTargetID:(FSTTargetID)targetID {
  FSTDocumentKeySet *keys = [FSTDocumentKeySet keySet];
  keys = [keys setByAddingObject:key];

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"removeMatchingKeys"];
  [self.queryCache removeMatchingKeys:keys forTargetID:targetID group:group];
  [self.persistence commitGroup:group];
}

- (void)removeMatchingKeysForTargetID:(FSTTargetID)targetID {
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"removeMatchingKeysForTargetID"];
  [self.queryCache removeMatchingKeysForTargetID:targetID group:group];
  [self.persistence commitGroup:group];
}

@end

NS_ASSUME_NONNULL_END
