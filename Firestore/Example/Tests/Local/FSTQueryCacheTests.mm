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

#include <set>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Util/FSTClasses.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/third_party/Immutable/Tests/FSTImmutableSortedSet+Testing.h"

#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTQueryCacheTests {
  FSTQuery *_queryRooms;
  ListenSequenceNumber _previousSequenceNumber;
  TargetId _previousTargetID;
  FSTTestSnapshotVersion _previousSnapshotVersion;
}

- (void)setUp {
  [super setUp];

  _queryRooms = FSTTestQuery("rooms");
  _previousSequenceNumber = 1000;
  _previousTargetID = 500;
  _previousSnapshotVersion = 100;
}

- (void)tearDown {
  [self.persistence shutdown];
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

  self.persistence.run("testReadQueryNotInCache",
                       [&]() { XCTAssertNil(self.queryCache->GetTarget(_queryRooms)); });
}

- (void)testSetAndReadAQuery {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testSetAndReadAQuery", [&]() {
    FSTQueryData *queryData = [self queryDataWithQuery:_queryRooms];
    self.queryCache->AddTarget(queryData);

    FSTQueryData *result = self.queryCache->GetTarget(_queryRooms);
    XCTAssertEqualObjects(result.query, queryData.query);
    XCTAssertEqual(result.targetID, queryData.targetID);
    XCTAssertEqualObjects(result.resumeToken, queryData.resumeToken);
  });
}

- (void)testCanonicalIDCollision {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testCanonicalIDCollision", [&]() {
    // Type information is currently lost in our canonicalID implementations so this currently an
    // easy way to force colliding canonicalIDs
    FSTQuery *q1 = [FSTTestQuery("a") queryByAddingFilter:FSTTestFilter("foo", @"==", @(1))];
    FSTQuery *q2 = [FSTTestQuery("a") queryByAddingFilter:FSTTestFilter("foo", @"==", @"1")];
    XCTAssertEqualObjects(q1.canonicalID, q2.canonicalID);

    FSTQueryData *data1 = [self queryDataWithQuery:q1];
    self.queryCache->AddTarget(data1);

    // Using the other query should not return the query cache entry despite equal canonicalIDs.
    XCTAssertNil(self.queryCache->GetTarget(q2));
    XCTAssertEqualObjects(self.queryCache->GetTarget(q1), data1);

    FSTQueryData *data2 = [self queryDataWithQuery:q2];
    self.queryCache->AddTarget(data2);
    XCTAssertEqual(self.queryCache->size(), 2);

    XCTAssertEqualObjects(self.queryCache->GetTarget(q1), data1);
    XCTAssertEqualObjects(self.queryCache->GetTarget(q2), data2);

    self.queryCache->RemoveTarget(data1);
    XCTAssertNil(self.queryCache->GetTarget(q1));
    XCTAssertEqualObjects(self.queryCache->GetTarget(q2), data2);
    XCTAssertEqual(self.queryCache->size(), 1);

    self.queryCache->RemoveTarget(data2);
    XCTAssertNil(self.queryCache->GetTarget(q1));
    XCTAssertNil(self.queryCache->GetTarget(q2));
    XCTAssertEqual(self.queryCache->size(), 0);
  });
}

- (void)testSetQueryToNewValue {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testSetQueryToNewValue", [&]() {
    FSTQueryData *queryData1 = [self queryDataWithQuery:_queryRooms
                                               targetID:1
                                   listenSequenceNumber:10
                                                version:1];
    self.queryCache->AddTarget(queryData1);

    FSTQueryData *queryData2 = [self queryDataWithQuery:_queryRooms
                                               targetID:1
                                   listenSequenceNumber:10
                                                version:2];
    self.queryCache->AddTarget(queryData2);

    FSTQueryData *result = self.queryCache->GetTarget(_queryRooms);
    XCTAssertNotEqualObjects(queryData2.resumeToken, queryData1.resumeToken);
    XCTAssertNotEqual(queryData2.snapshotVersion, queryData1.snapshotVersion);
    XCTAssertEqualObjects(result.resumeToken, queryData2.resumeToken);
    XCTAssertEqual(result.snapshotVersion, queryData2.snapshotVersion);
  });
}

- (void)testRemoveQuery {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testRemoveQuery", [&]() {
    FSTQueryData *queryData1 = [self queryDataWithQuery:_queryRooms];
    self.queryCache->AddTarget(queryData1);

    self.queryCache->RemoveTarget(queryData1);

    FSTQueryData *result = self.queryCache->GetTarget(_queryRooms);
    XCTAssertNil(result);
  });
}

- (void)testRemoveNonExistentQuery {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testRemoveNonExistentQuery", [&]() {
    FSTQueryData *queryData = [self queryDataWithQuery:_queryRooms];

    // no-op, but make sure it doesn't throw.
    XCTAssertNoThrow(self.queryCache->RemoveTarget(queryData));
  });
}

- (void)testRemoveQueryRemovesMatchingKeysToo {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testRemoveQueryRemovesMatchingKeysToo", [&]() {
    FSTQueryData *rooms = [self queryDataWithQuery:_queryRooms];
    self.queryCache->AddTarget(rooms);

    DocumentKey key1 = testutil::Key("rooms/foo");
    DocumentKey key2 = testutil::Key("rooms/bar");
    [self addMatchingKey:key1 forTargetID:rooms.targetID];
    [self addMatchingKey:key2 forTargetID:rooms.targetID];

    XCTAssertTrue(self.queryCache->Contains(key1));
    XCTAssertTrue(self.queryCache->Contains(key2));

    self.queryCache->RemoveTarget(rooms);
    XCTAssertFalse(self.queryCache->Contains(key1));
    XCTAssertFalse(self.queryCache->Contains(key2));
  });
}

- (void)testAddOrRemoveMatchingKeys {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testAddOrRemoveMatchingKeys", [&]() {
    DocumentKey key = testutil::Key("foo/bar");

    XCTAssertFalse(self.queryCache->Contains(key));

    [self addMatchingKey:key forTargetID:1];
    XCTAssertTrue(self.queryCache->Contains(key));

    [self addMatchingKey:key forTargetID:2];
    XCTAssertTrue(self.queryCache->Contains(key));

    [self removeMatchingKey:key forTargetID:1];
    XCTAssertTrue(self.queryCache->Contains(key));

    [self removeMatchingKey:key forTargetID:2];
    XCTAssertFalse(self.queryCache->Contains(key));
  });
}

- (void)testMatchingKeysForTargetID {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testMatchingKeysForTargetID", [&]() {
    DocumentKey key1 = testutil::Key("foo/bar");
    DocumentKey key2 = testutil::Key("foo/baz");
    DocumentKey key3 = testutil::Key("foo/blah");

    [self addMatchingKey:key1 forTargetID:1];
    [self addMatchingKey:key2 forTargetID:1];
    [self addMatchingKey:key3 forTargetID:2];

    XCTAssertEqual(self.queryCache->GetMatchingKeys(1), (DocumentKeySet{key1, key2}));
    XCTAssertEqual(self.queryCache->GetMatchingKeys(2), (DocumentKeySet{key3}));

    [self addMatchingKey:key1 forTargetID:2];
    XCTAssertEqual(self.queryCache->GetMatchingKeys(1), (DocumentKeySet{key1, key2}));
    XCTAssertEqual(self.queryCache->GetMatchingKeys(2), (DocumentKeySet{key1, key3}));
  });
}

- (void)testHighestListenSequenceNumber {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testHighestListenSequenceNumber", [&]() {
    FSTQueryData *query1 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery("rooms")
                                                      targetID:1
                                          listenSequenceNumber:10
                                                       purpose:FSTQueryPurposeListen];
    self.queryCache->AddTarget(query1);
    FSTQueryData *query2 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery("halls")
                                                      targetID:2
                                          listenSequenceNumber:20
                                                       purpose:FSTQueryPurposeListen];
    self.queryCache->AddTarget(query2);
    XCTAssertEqual(self.queryCache->highest_listen_sequence_number(), 20);

    // Sequence numbers never come down.
    self.queryCache->RemoveTarget(query2);
    XCTAssertEqual(self.queryCache->highest_listen_sequence_number(), 20);

    FSTQueryData *query3 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery("garages")
                                                      targetID:42
                                          listenSequenceNumber:100
                                                       purpose:FSTQueryPurposeListen];
    self.queryCache->AddTarget(query3);
    XCTAssertEqual(self.queryCache->highest_listen_sequence_number(), 100);

    self.queryCache->AddTarget(query1);
    XCTAssertEqual(self.queryCache->highest_listen_sequence_number(), 100);

    self.queryCache->RemoveTarget(query3);
    XCTAssertEqual(self.queryCache->highest_listen_sequence_number(), 100);
  });
}

- (void)testHighestTargetID {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testHighestTargetID", [&]() {
    XCTAssertEqual(self.queryCache->highest_target_id(), 0);

    FSTQueryData *query1 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery("rooms")
                                                      targetID:1
                                          listenSequenceNumber:10
                                                       purpose:FSTQueryPurposeListen];
    DocumentKey key1 = testutil::Key("rooms/bar");
    DocumentKey key2 = testutil::Key("rooms/foo");
    self.queryCache->AddTarget(query1);
    [self addMatchingKey:key1 forTargetID:1];
    [self addMatchingKey:key2 forTargetID:1];

    FSTQueryData *query2 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery("halls")
                                                      targetID:2
                                          listenSequenceNumber:20
                                                       purpose:FSTQueryPurposeListen];
    DocumentKey key3 = testutil::Key("halls/foo");
    self.queryCache->AddTarget(query2);
    [self addMatchingKey:key3 forTargetID:2];
    XCTAssertEqual(self.queryCache->highest_target_id(), 2);

    // TargetIDs never come down.
    self.queryCache->RemoveTarget(query2);
    XCTAssertEqual(self.queryCache->highest_target_id(), 2);

    // A query with an empty result set still counts.
    FSTQueryData *query3 = [[FSTQueryData alloc] initWithQuery:FSTTestQuery("garages")
                                                      targetID:42
                                          listenSequenceNumber:100
                                                       purpose:FSTQueryPurposeListen];
    self.queryCache->AddTarget(query3);
    XCTAssertEqual(self.queryCache->highest_target_id(), 42);

    self.queryCache->RemoveTarget(query1);
    XCTAssertEqual(self.queryCache->highest_target_id(), 42);

    self.queryCache->RemoveTarget(query3);
    XCTAssertEqual(self.queryCache->highest_target_id(), 42);
  });
}

- (void)testLastRemoteSnapshotVersion {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testLastRemoteSnapshotVersion", [&]() {
    XCTAssertEqual(self.queryCache->GetLastRemoteSnapshotVersion(), SnapshotVersion::None());

    // Can set the snapshot version.
    self.queryCache->SetLastRemoteSnapshotVersion(testutil::Version(42));
    XCTAssertEqual(self.queryCache->GetLastRemoteSnapshotVersion(), testutil::Version(42));
  });
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
                            targetID:(TargetId)targetID
                listenSequenceNumber:(ListenSequenceNumber)sequenceNumber
                             version:(FSTTestSnapshotVersion)version {
  NSData *resumeToken = FSTTestResumeTokenFromSnapshotVersion(version);
  return [[FSTQueryData alloc] initWithQuery:query
                                    targetID:targetID
                        listenSequenceNumber:sequenceNumber
                                     purpose:FSTQueryPurposeListen
                             snapshotVersion:testutil::Version(version)
                                 resumeToken:resumeToken];
}

- (void)addMatchingKey:(const DocumentKey &)key forTargetID:(TargetId)targetID {
  DocumentKeySet keys{key};
  self.queryCache->AddMatchingKeys(keys, targetID);
}

- (void)removeMatchingKey:(const DocumentKey &)key forTargetID:(TargetId)targetID {
  DocumentKeySet keys{key};
  self.queryCache->RemoveMatchingKeys(keys, targetID);
}

@end

NS_ASSUME_NONNULL_END
