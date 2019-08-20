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
#include <utility>

#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Util/FSTClasses.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace core = firebase::firestore::core;
namespace testutil = firebase::firestore::testutil;

using firebase::firestore::local::QueryData;
using firebase::firestore::local::QueryPurpose;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::nanopb::ByteString;

using testutil::Filter;
using testutil::Query;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTQueryCacheTests {
  core::Query _queryRooms;
  ListenSequenceNumber _previousSequenceNumber;
  TargetId _previousTargetID;
  FSTTestSnapshotVersion _previousSnapshotVersion;
}

- (void)setUp {
  [super setUp];

  _queryRooms = Query("rooms");
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

  self.persistence.run("testReadQueryNotInCache", [&]() {
    XCTAssertEqual(self.queryCache->GetTarget(_queryRooms), absl::nullopt);
  });
}

- (void)testSetAndReadAQuery {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testSetAndReadAQuery", [&]() {
    QueryData queryData = [self queryDataWithQuery:_queryRooms];
    self.queryCache->AddTarget(queryData);

    auto result = self.queryCache->GetTarget(_queryRooms);
    XCTAssertNotEqual(result, absl::nullopt);
    XCTAssertEqual(result->query(), queryData.query());
    XCTAssertEqual(result->target_id(), queryData.target_id());
    XCTAssertEqual(result->resume_token(), queryData.resume_token());
  });
}

- (void)testCanonicalIDCollision {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testCanonicalIDCollision", [&]() {
    // Type information is currently lost in our canonicalID implementations so this currently an
    // easy way to force colliding canonicalIDs
    core::Query q1 = Query("a").AddingFilter(Filter("foo", "==", 1));
    core::Query q2 = Query("a").AddingFilter(Filter("foo", "==", "1"));
    XCTAssertEqual(q1.CanonicalId(), q2.CanonicalId());

    QueryData data1 = [self queryDataWithQuery:q1];
    self.queryCache->AddTarget(data1);

    // Using the other query should not return the query cache entry despite equal canonicalIDs.
    XCTAssertEqual(self.queryCache->GetTarget(q2), absl::nullopt);
    XCTAssertEqual(self.queryCache->GetTarget(q1), data1);

    QueryData data2 = [self queryDataWithQuery:q2];
    self.queryCache->AddTarget(data2);
    XCTAssertEqual(self.queryCache->size(), 2);

    XCTAssertEqual(self.queryCache->GetTarget(q1), data1);
    XCTAssertEqual(self.queryCache->GetTarget(q2), data2);

    self.queryCache->RemoveTarget(data1);
    XCTAssertEqual(self.queryCache->GetTarget(q1), absl::nullopt);
    XCTAssertEqual(self.queryCache->GetTarget(q2), data2);
    XCTAssertEqual(self.queryCache->size(), 1);

    self.queryCache->RemoveTarget(data2);
    XCTAssertEqual(self.queryCache->GetTarget(q1), absl::nullopt);
    XCTAssertEqual(self.queryCache->GetTarget(q2), absl::nullopt);
    XCTAssertEqual(self.queryCache->size(), 0);
  });
}

- (void)testSetQueryToNewValue {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testSetQueryToNewValue", [&]() {
    QueryData queryData1 = [self queryDataWithQuery:_queryRooms
                                           targetID:1
                               listenSequenceNumber:10
                                            version:1];
    self.queryCache->AddTarget(queryData1);

    QueryData queryData2 = [self queryDataWithQuery:_queryRooms
                                           targetID:1
                               listenSequenceNumber:10
                                            version:2];
    self.queryCache->AddTarget(queryData2);

    auto result = self.queryCache->GetTarget(_queryRooms);
    XCTAssertNotEqual(queryData2.resume_token(), queryData1.resume_token());
    XCTAssertNotEqual(queryData2.snapshot_version(), queryData1.snapshot_version());
    XCTAssertEqual(result->resume_token(), queryData2.resume_token());
    XCTAssertEqual(result->snapshot_version(), queryData2.snapshot_version());
  });
}

- (void)testRemoveQuery {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testRemoveQuery", [&]() {
    QueryData queryData1 = [self queryDataWithQuery:_queryRooms];
    self.queryCache->AddTarget(queryData1);

    self.queryCache->RemoveTarget(queryData1);

    auto result = self.queryCache->GetTarget(_queryRooms);
    XCTAssertEqual(result, absl::nullopt);
  });
}

- (void)testRemoveNonExistentQuery {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testRemoveNonExistentQuery", [&]() {
    QueryData queryData = [self queryDataWithQuery:_queryRooms];

    // no-op, but make sure it doesn't throw.
    XCTAssertNoThrow(self.queryCache->RemoveTarget(queryData));
  });
}

- (void)testRemoveQueryRemovesMatchingKeysToo {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testRemoveQueryRemovesMatchingKeysToo", [&]() {
    QueryData rooms = [self queryDataWithQuery:_queryRooms];
    self.queryCache->AddTarget(rooms);

    DocumentKey key1 = testutil::Key("rooms/foo");
    DocumentKey key2 = testutil::Key("rooms/bar");
    [self addMatchingKey:key1 forTargetID:rooms.target_id()];
    [self addMatchingKey:key2 forTargetID:rooms.target_id()];

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
    QueryData query1(Query("rooms"), 1, 10, QueryPurpose::Listen);
    self.queryCache->AddTarget(query1);
    QueryData query2(Query("halls"), 2, 20, QueryPurpose::Listen);
    self.queryCache->AddTarget(query2);
    XCTAssertEqual(self.queryCache->highest_listen_sequence_number(), 20);

    // Sequence numbers never come down.
    self.queryCache->RemoveTarget(query2);
    XCTAssertEqual(self.queryCache->highest_listen_sequence_number(), 20);

    QueryData query3(Query("garages"), 42, 100, QueryPurpose::Listen);
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

    QueryData query1(Query("rooms"), 1, 10, QueryPurpose::Listen);
    DocumentKey key1 = testutil::Key("rooms/bar");
    DocumentKey key2 = testutil::Key("rooms/foo");
    self.queryCache->AddTarget(query1);
    [self addMatchingKey:key1 forTargetID:1];
    [self addMatchingKey:key2 forTargetID:1];

    QueryData query2(Query("halls"), 2, 20, QueryPurpose::Listen);
    DocumentKey key3 = testutil::Key("halls/foo");
    self.queryCache->AddTarget(query2);
    [self addMatchingKey:key3 forTargetID:2];
    XCTAssertEqual(self.queryCache->highest_target_id(), 2);

    // TargetIDs never come down.
    self.queryCache->RemoveTarget(query2);
    XCTAssertEqual(self.queryCache->highest_target_id(), 2);

    // A query with an empty result set still counts.
    QueryData query3(Query("garages"), 42, 100, QueryPurpose::Listen);
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
 * Creates a new QueryData object from the given parameters, synthesizing a resume token from the
 * snapshot version.
 */
- (QueryData)queryDataWithQuery:(core::Query)query {
  return [self queryDataWithQuery:std::move(query)
                         targetID:++_previousTargetID
             listenSequenceNumber:++_previousSequenceNumber
                          version:++_previousSnapshotVersion];
}

- (QueryData)queryDataWithQuery:(core::Query)query
                       targetID:(TargetId)targetID
           listenSequenceNumber:(ListenSequenceNumber)sequenceNumber
                        version:(FSTTestSnapshotVersion)version {
  ByteString resumeToken = testutil::ResumeToken(version);
  return QueryData(std::move(query), targetID, sequenceNumber, QueryPurpose::Listen,
                   testutil::Version(version), resumeToken);
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
