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

#import <XCTest/XCTest.h>

#include <memory>
#include <unordered_map>
#include <utility>
#include <vector>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/remote/existence_filter.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/memory/memory.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::ExistenceFilter;
using firebase::firestore::remote::ExistenceFilterWatchChange;
using firebase::firestore::remote::RemoteEvent;
using firebase::firestore::remote::TargetChange;
using firebase::firestore::remote::TestTargetMetadataProvider;
using firebase::firestore::remote::WatchChange;
using firebase::firestore::remote::WatchChangeAggregator;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WatchTargetChangeState;
using firebase::firestore::testutil::VectorOfUniquePtrs;
using firebase::firestore::util::MakeString;
using firebase::firestore::util::Status;

NS_ASSUME_NONNULL_BEGIN

namespace {

template <typename... Elems>
std::vector<std::unique_ptr<WatchChange>> Changes(Elems... elems) {
  return VectorOfUniquePtrs<WatchChange>(std::move(elems)...);
}

// These helpers work around the fact that `make_unique` cannot deduce the
// desired type (`vector<TargetId>` in this case) from an initialization list
// (e.g., `{1,2}`).
std::unique_ptr<DocumentWatchChange> MakeDocChange(std::vector<TargetId> updated,
                                                   std::vector<TargetId> removed,
                                                   DocumentKey key,
                                                   FSTMaybeDocument *doc) {
  return absl::make_unique<DocumentWatchChange>(std::move(updated), std::move(removed),
                                                std::move(key), doc);
}

std::unique_ptr<WatchTargetChange> MakeTargetChange(WatchTargetChangeState state,
                                                    std::vector<TargetId> target_ids) {
  return absl::make_unique<WatchTargetChange>(state, std::move(target_ids));
}

std::unique_ptr<WatchTargetChange> MakeTargetChange(WatchTargetChangeState state,
                                                    std::vector<TargetId> target_ids,
                                                    NSData *token) {
  return absl::make_unique<WatchTargetChange>(state, std::move(target_ids), token);
}

}  // namespace

@interface FSTRemoteEventTests : XCTestCase
@end

@implementation FSTRemoteEventTests {
  NSData *_resumeToken1;
  TestTargetMetadataProvider _targetMetadataProvider;
  std::unordered_map<TargetId, int> _noOutstandingResponses;
}

- (void)setUp {
  _resumeToken1 = [@"resume1" dataUsingEncoding:NSUTF8StringEncoding];
}

/**
 * Creates a map with query data for the provided target IDs. All targets are considered active
 * and query a collection named "coll".
 */
- (std::unordered_map<TargetId, FSTQueryData *>)queryDataForTargets:
    (std::initializer_list<TargetId>)targetIDs {
  std::unordered_map<TargetId, FSTQueryData *> targets;
  for (TargetId targetID : targetIDs) {
    FSTQuery *query = FSTTestQuery("coll");
    targets[targetID] = [[FSTQueryData alloc] initWithQuery:query
                                                   targetID:targetID
                                       listenSequenceNumber:0
                                                    purpose:FSTQueryPurposeListen];
  }
  return targets;
}

/**
 * Creates a map with query data for the provided target IDs. All targets are marked as limbo
 * queries for the document at "coll/limbo".
 */
- (std::unordered_map<TargetId, FSTQueryData *>)queryDataForLimboTargets:
    (std::initializer_list<TargetId>)targetIDs {
  std::unordered_map<TargetId, FSTQueryData *> targets;
  for (TargetId targetID : targetIDs) {
    FSTQuery *query = FSTTestQuery("coll/limbo");
    targets[targetID] = [[FSTQueryData alloc] initWithQuery:query
                                                   targetID:targetID
                                       listenSequenceNumber:0
                                                    purpose:FSTQueryPurposeLimboResolution];
  }
  return targets;
}

/**
 * Creates an aggregator initialized with the set of provided `WatchChange`s. Tests can add further
 * changes via `HandleDocumentChange`, `HandleTargetChange` and `HandleExistenceFilterChange`.
 *
 * @param targetMap A map of query data for all active targets. The map must include an entry for
 * every target referenced by any of the watch changes.
 * @param outstandingResponses The number of outstanding ACKs a target has to receive before it is
 * considered active, or `_noOutstandingResponses` if all targets are already active.
 * @param existingKeys The set of documents that are considered synced with the test targets as
 * part of a previous listen. To modify this set during test execution, invoke
 * `_targetMetadataProvider.SetSyncedKeys()`.
 * @param watchChanges The watch changes to apply before returning the aggregator. Supported
 * changes are `DocumentWatchChange` and `WatchTargetChange`.
 */
- (WatchChangeAggregator)
    aggregatorWithTargetMap:(const std::unordered_map<TargetId, FSTQueryData *> &)targetMap
       outstandingResponses:(const std::unordered_map<TargetId, int> &)outstandingResponses
               existingKeys:(DocumentKeySet)existingKeys
                    changes:(const std::vector<std::unique_ptr<WatchChange>> &)watchChanges {
  WatchChangeAggregator aggregator{&_targetMetadataProvider};

  std::vector<TargetId> targetIDs;
  for (const auto &kv : targetMap) {
    TargetId targetID = kv.first;
    FSTQueryData *queryData = kv.second;

    targetIDs.push_back(targetID);
    _targetMetadataProvider.SetSyncedKeys(existingKeys, queryData);
  };

  for (const auto &kv : outstandingResponses) {
    TargetId targetID = kv.first;
    int count = kv.second;
    for (int i = 0; i < count; ++i) {
      aggregator.RecordPendingTargetRequest(targetID);
    }
  }

  for (const std::unique_ptr<WatchChange> &change : watchChanges) {
    switch (change->type()) {
      case WatchChange::Type::Document: {
        aggregator.HandleDocumentChange(*static_cast<const DocumentWatchChange *>(change.get()));
        break;
      }
      case WatchChange::Type::TargetChange: {
        aggregator.HandleTargetChange(*static_cast<const WatchTargetChange *>(change.get()));
        break;
      }
      default:
        HARD_ASSERT("Encountered unexpected type of WatchChange");
    }
  }

  aggregator.HandleTargetChange(
      WatchTargetChange{WatchTargetChangeState::NoChange, targetIDs, _resumeToken1});

  return aggregator;
}

/**
 * Creates a single remote event that includes target changes for all provided `WatchChange`s.
 *
 * @param snapshotVersion The version at which to create the remote event. This corresponds to the
 * snapshot version provided by the NO_CHANGE event.
 * @param targetMap A map of query data for all active targets. The map must include an entry for
 * every target referenced by any of the watch changes.
 * @param outstandingResponses The number of outstanding ACKs a target has to receive before it is
 * considered active, or `_noOutstandingResponses` if all targets are already active.
 * @param existingKeys The set of documents that are considered synced with the test targets as
 * part of a previous listen.
 * @param watchChanges The watch changes to apply before creating the remote event. Supported
 * changes are `DocumentWatchChange` and `WatchTargetChange`.
 */
- (RemoteEvent)
    remoteEventAtSnapshotVersion:(FSTTestSnapshotVersion)snapshotVersion
                       targetMap:(std::unordered_map<TargetId, FSTQueryData *>)targetMap
            outstandingResponses:(const std::unordered_map<TargetId, int> &)outstandingResponses
                    existingKeys:(DocumentKeySet)existingKeys
                         changes:(const std::vector<std::unique_ptr<WatchChange>> &)watchChanges {
  WatchChangeAggregator aggregator = [self aggregatorWithTargetMap:targetMap
                                              outstandingResponses:outstandingResponses
                                                      existingKeys:existingKeys
                                                           changes:watchChanges];
  return aggregator.CreateRemoteEvent(testutil::Version(snapshotVersion));
}

- (void)testWillAccumulateDocumentAddedAndRemovedEvents {
  // The target map that contains an entry for every target in this test. If a target ID is
  // omitted, the target is considered inactive and `TestTargetMetadataProvider` will fail on
  // access.
  std::unordered_map<TargetId, FSTQueryData *> targetMap{
      [self queryDataForTargets:{1, 2, 3, 4, 5, 6}]};

  FSTDocument *existingDoc = FSTTestDoc("docs/1", 1, @{@"value" : @1}, DocumentState::kSynced);
  auto change1 = MakeDocChange({1, 2, 3}, {4, 5, 6}, existingDoc.key, existingDoc);

  FSTDocument *newDoc = FSTTestDoc("docs/2", 2, @{@"value" : @2}, DocumentState::kSynced);
  auto change2 = MakeDocChange({1, 4}, {2, 6}, newDoc.key, newDoc);

  // Create a remote event that includes both `change1` and `change2` as well as a NO_CHANGE event
  // with the default resume token (`_resumeToken1`).
  // As `existingDoc` is provided as an existing key, any updates to this document will be treated
  // as modifications rather than adds.
  RemoteEvent event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:_noOutstandingResponses
                            existingKeys:DocumentKeySet{existingDoc.key}
                                 changes:Changes(std::move(change1), std::move(change2))];
  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  XCTAssertEqual(event.document_updates().size(), 2);
  XCTAssertEqualObjects(event.document_updates().at(existingDoc.key), existingDoc);
  XCTAssertEqualObjects(event.document_updates().at(newDoc.key), newDoc);

  // 'change1' and 'change2' affect six different targets
  XCTAssertEqual(event.target_changes().size(), 6);

  TargetChange targetChange1{_resumeToken1, false, DocumentKeySet{newDoc.key},
                             DocumentKeySet{existingDoc.key}, DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(1) == targetChange1);

  TargetChange targetChange2{_resumeToken1, false, DocumentKeySet{},
                             DocumentKeySet{existingDoc.key}, DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(2) == targetChange2);

  TargetChange targetChange3{_resumeToken1, false, DocumentKeySet{},
                             DocumentKeySet{existingDoc.key}, DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(3) == targetChange3);

  TargetChange targetChange4{_resumeToken1, false, DocumentKeySet{newDoc.key}, DocumentKeySet{},
                             DocumentKeySet{existingDoc.key}};
  XCTAssertTrue(event.target_changes().at(4) == targetChange4);

  TargetChange targetChange5{_resumeToken1, false, DocumentKeySet{}, DocumentKeySet{},
                             DocumentKeySet{existingDoc.key}};
  XCTAssertTrue(event.target_changes().at(5) == targetChange5);

  TargetChange targetChange6{_resumeToken1, false, DocumentKeySet{}, DocumentKeySet{},
                             DocumentKeySet{existingDoc.key}};
  XCTAssertTrue(event.target_changes().at(6) == targetChange6);
}

- (void)testWillIgnoreEventsForPendingTargets {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1}]};

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, DocumentState::kSynced);
  auto change1 = MakeDocChange({1}, {}, doc1.key, doc1);
  auto change2 = MakeTargetChange(WatchTargetChangeState::Removed, {1});
  auto change3 = MakeTargetChange(WatchTargetChangeState::Added, {1});
  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{@"value" : @2}, DocumentState::kSynced);
  auto change4 = MakeDocChange({1}, {}, doc2.key, doc2);

  // We're waiting for the unwatch and watch ack
  std::unordered_map<TargetId, int> outstandingResponses{{1, 2}};

  RemoteEvent event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:outstandingResponses
                            existingKeys:DocumentKeySet {}
                                 changes:Changes(std::move(change1), std::move(change2),
                                                 std::move(change3), std::move(change4))];
  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  // doc1 is ignored because it was part of an inactive target, but doc2 is in the changes
  // because it become active.
  XCTAssertEqual(event.document_updates().size(), 1);
  XCTAssertEqualObjects(event.document_updates().at(doc2.key), doc2);

  XCTAssertEqual(event.target_changes().size(), 1);
}

- (void)testWillIgnoreEventsForRemovedTargets {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{}]};

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, DocumentState::kSynced);
  auto change1 = MakeDocChange({1}, {}, doc1.key, doc1);
  auto change2 = MakeTargetChange(WatchTargetChangeState::Removed, {1});

  // We're waiting for the unwatch ack
  std::unordered_map<TargetId, int> outstandingResponses{{1, 1}};

  RemoteEvent event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:outstandingResponses
                            existingKeys:DocumentKeySet {}
                                 changes:Changes(std::move(change1), std::move(change2))];
  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  // doc1 is ignored because it was part of an inactive target
  XCTAssertEqual(event.document_updates().size(), 0);

  // Target 1 is ignored because it was removed
  XCTAssertEqual(event.target_changes().size(), 0);
}

- (void)testWillKeepResetMappingEvenWithUpdates {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1}]};

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, DocumentState::kSynced);
  auto change1 = MakeDocChange({1}, {}, doc1.key, doc1);

  // Reset stream, ignoring doc1
  auto change2 = MakeTargetChange(WatchTargetChangeState::Reset, {1});

  // Add doc2, doc3
  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{@"value" : @2}, DocumentState::kSynced);
  auto change3 = MakeDocChange({1}, {}, doc2.key, doc2);

  FSTDocument *doc3 = FSTTestDoc("docs/3", 3, @{@"value" : @3}, DocumentState::kSynced);
  auto change4 = MakeDocChange({1}, {}, doc3.key, doc3);

  // Remove doc2 again, should not show up in reset mapping
  auto change5 = MakeDocChange({}, {1}, doc2.key, doc2);

  RemoteEvent event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:_noOutstandingResponses
                            existingKeys:DocumentKeySet{doc1.key}
                                 changes:Changes(std::move(change1), std::move(change2),
                                                 std::move(change3), std::move(change4),
                                                 std::move(change5))];
  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  XCTAssertEqual(event.document_updates().size(), 3);
  XCTAssertEqualObjects(event.document_updates().at(doc1.key), doc1);
  XCTAssertEqualObjects(event.document_updates().at(doc2.key), doc2);
  XCTAssertEqualObjects(event.document_updates().at(doc3.key), doc3);

  XCTAssertEqual(event.target_changes().size(), 1);

  // Only doc3 is part of the new mapping
  TargetChange expectedChange{_resumeToken1, false, DocumentKeySet{doc3.key}, DocumentKeySet{},
                              DocumentKeySet{doc1.key}};
  XCTAssertTrue(event.target_changes().at(1) == expectedChange);
}

- (void)testWillHandleSingleReset {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1}]};

  // Reset target
  WatchTargetChange change{WatchTargetChangeState::Reset, {1}};

  WatchChangeAggregator aggregator = [self aggregatorWithTargetMap:targetMap
                                              outstandingResponses:_noOutstandingResponses
                                                      existingKeys:DocumentKeySet {}
                                                           changes:{}];
  aggregator.HandleTargetChange(change);

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));

  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  XCTAssertEqual(event.document_updates().size(), 0);
  XCTAssertEqual(event.target_changes().size(), 1);

  // Reset mapping is empty
  TargetChange expectedChange{
      [NSData data], false, DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(1) == expectedChange);
}

- (void)testWillHandleTargetAddAndRemovalInSameBatch {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1, 2}]};

  FSTDocument *doc1a = FSTTestDoc("docs/1", 1, @{@"value" : @1}, DocumentState::kSynced);
  auto change1 = MakeDocChange({1}, {2}, doc1a.key, doc1a);

  FSTDocument *doc1b = FSTTestDoc("docs/1", 1, @{@"value" : @2}, DocumentState::kSynced);
  auto change2 = MakeDocChange({2}, {1}, doc1b.key, doc1b);

  RemoteEvent event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:_noOutstandingResponses
                            existingKeys:DocumentKeySet{doc1a.key}
                                 changes:Changes(std::move(change1), std::move(change2))];
  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  XCTAssertEqual(event.document_updates().size(), 1);
  XCTAssertEqualObjects(event.document_updates().at(doc1b.key), doc1b);

  XCTAssertEqual(event.target_changes().size(), 2);

  TargetChange targetChange1{_resumeToken1, false, DocumentKeySet{}, DocumentKeySet{},
                             DocumentKeySet{doc1b.key}};
  XCTAssertTrue(event.target_changes().at(1) == targetChange1);

  TargetChange targetChange2{_resumeToken1, false, DocumentKeySet{}, DocumentKeySet{doc1b.key},
                             DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(2) == targetChange2);
}

- (void)testTargetCurrentChangeWillMarkTheTargetCurrent {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1}]};

  auto change = MakeTargetChange(WatchTargetChangeState::Current, {1}, _resumeToken1);

  RemoteEvent event = [self remoteEventAtSnapshotVersion:3
                                               targetMap:targetMap
                                    outstandingResponses:_noOutstandingResponses
                                            existingKeys:DocumentKeySet {}
                                                 changes:Changes(std::move(change))];

  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  XCTAssertEqual(event.document_updates().size(), 0);
  XCTAssertEqual(event.target_changes().size(), 1);

  TargetChange targetChange1{_resumeToken1, true, DocumentKeySet{}, DocumentKeySet{},
                             DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(1) == targetChange1);
}

- (void)testTargetAddedChangeWillResetPreviousState {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1, 3}]};

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, DocumentState::kSynced);
  auto change1 = MakeDocChange({1, 3}, {2}, doc1.key, doc1);
  auto change2 = MakeTargetChange(WatchTargetChangeState::Current, {1, 2, 3}, _resumeToken1);
  auto change3 = MakeTargetChange(WatchTargetChangeState::Removed, {1});
  auto change4 = MakeTargetChange(WatchTargetChangeState::Removed, {2});
  auto change5 = MakeTargetChange(WatchTargetChangeState::Added, {1});
  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{@"value" : @2}, DocumentState::kSynced);
  auto change6 = MakeDocChange({1}, {3}, doc2.key, doc2);

  std::unordered_map<TargetId, int> outstandingResponses{{1, 2}, {2, 1}};

  RemoteEvent event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:outstandingResponses
                            existingKeys:DocumentKeySet{doc2.key}
                                 changes:Changes(std::move(change1), std::move(change2),
                                                 std::move(change3), std::move(change4),
                                                 std::move(change5), std::move(change6))];

  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  XCTAssertEqual(event.document_updates().size(), 2);
  XCTAssertEqualObjects(event.document_updates().at(doc1.key), doc1);
  XCTAssertEqualObjects(event.document_updates().at(doc2.key), doc2);

  // target 1 and 3 are affected (1 because of re-add), target 2 is not because of remove
  XCTAssertEqual(event.target_changes().size(), 2);

  // doc1 was before the remove, so it does not show up in the mapping.
  // Current was before the remove.
  TargetChange targetChange1{_resumeToken1, false, DocumentKeySet{}, DocumentKeySet{doc2.key},
                             DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(1) == targetChange1);

  // Doc1 was before the remove
  // Current was before the remove
  TargetChange targetChange3{_resumeToken1, true, DocumentKeySet{doc1.key}, DocumentKeySet{},
                             DocumentKeySet{doc2.key}};
  XCTAssertTrue(event.target_changes().at(3) == targetChange3);
}

- (void)testNoChangeWillStillMarkTheAffectedTargets {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1}]};

  WatchChangeAggregator aggregator = [self aggregatorWithTargetMap:targetMap
                                              outstandingResponses:_noOutstandingResponses
                                                      existingKeys:DocumentKeySet {}
                                                           changes:{}];

  WatchTargetChange change{WatchTargetChangeState::NoChange, {1}, _resumeToken1};
  aggregator.HandleTargetChange(change);

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));

  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  XCTAssertEqual(event.document_updates().size(), 0);
  XCTAssertEqual(event.target_changes().size(), 1);

  TargetChange targetChange{_resumeToken1, false, DocumentKeySet{}, DocumentKeySet{},
                            DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(1) == targetChange);
}

- (void)testExistenceFilterMismatchClearsTarget {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1, 2}]};

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, DocumentState::kSynced);
  auto change1 = MakeDocChange({1}, {}, doc1.key, doc1);
  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{@"value" : @2}, DocumentState::kSynced);
  auto change2 = MakeDocChange({1}, {}, doc2.key, doc2);
  auto change3 = MakeTargetChange(WatchTargetChangeState::Current, {1}, _resumeToken1);

  WatchChangeAggregator aggregator = [self
      aggregatorWithTargetMap:targetMap
         outstandingResponses:_noOutstandingResponses
                 existingKeys:DocumentKeySet{doc1.key, doc2.key}
                      changes:Changes(std::move(change1), std::move(change2), std::move(change3))];

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));

  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  XCTAssertEqual(event.document_updates().size(), 2);
  XCTAssertEqualObjects(event.document_updates().at(doc1.key), doc1);
  XCTAssertEqualObjects(event.document_updates().at(doc2.key), doc2);

  XCTAssertEqual(event.target_changes().size(), 2);

  TargetChange targetChange1{_resumeToken1, true, DocumentKeySet{},
                             DocumentKeySet{doc1.key, doc2.key}, DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(1) == targetChange1);

  TargetChange targetChange2{_resumeToken1, false, DocumentKeySet{}, DocumentKeySet{},
                             DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(2) == targetChange2);

  // The existence filter mismatch will remove the document from target 1,
  // but not synthesize a document delete.
  ExistenceFilterWatchChange change4{ExistenceFilter{1}, 1};
  aggregator.HandleExistenceFilter(change4);

  event = aggregator.CreateRemoteEvent(testutil::Version(4));

  TargetChange targetChange3{
      [NSData data], false, DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{doc1.key, doc2.key}};
  XCTAssertTrue(event.target_changes().at(1) == targetChange3);

  XCTAssertEqual(event.target_changes().size(), 1);
  XCTAssertEqual(event.target_mismatches().size(), 1);
  XCTAssertEqual(event.document_updates().size(), 0);
}

- (void)testExistenceFilterMismatchRemovesCurrentChanges {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1}]};

  WatchChangeAggregator aggregator = [self aggregatorWithTargetMap:targetMap
                                              outstandingResponses:_noOutstandingResponses
                                                      existingKeys:DocumentKeySet {}
                                                           changes:{}];

  WatchTargetChange markCurrent{WatchTargetChangeState::Current, {1}, _resumeToken1};
  aggregator.HandleTargetChange(markCurrent);

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, DocumentState::kSynced);
  DocumentWatchChange addDoc{{1}, {}, doc1.key, doc1};
  aggregator.HandleDocumentChange(addDoc);

  // The existence filter mismatch will remove the document from target 1, but not synthesize a
  // document delete.
  ExistenceFilterWatchChange existenceFilter{ExistenceFilter{0}, 1};
  aggregator.HandleExistenceFilter(existenceFilter);

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));

  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  XCTAssertEqual(event.document_updates().size(), 1);
  XCTAssertEqual(event.target_mismatches().size(), 1);
  XCTAssertEqualObjects(event.document_updates().at(doc1.key), doc1);

  XCTAssertEqual(event.target_changes().size(), 1);

  TargetChange targetChange1{
      [NSData data], false, DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(1) == targetChange1);
}

- (void)testDocumentUpdate {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1}]};

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, DocumentState::kSynced);
  auto change1 = MakeDocChange({1}, {}, doc1.key, doc1);
  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{@"value" : @2}, DocumentState::kSynced);
  auto change2 = MakeDocChange({1}, {}, doc2.key, doc2);

  WatchChangeAggregator aggregator =
      [self aggregatorWithTargetMap:targetMap
               outstandingResponses:_noOutstandingResponses
                       existingKeys:DocumentKeySet {}
                            changes:Changes(std::move(change1), std::move(change2))];

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));

  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  XCTAssertEqual(event.document_updates().size(), 2);
  XCTAssertEqualObjects(event.document_updates().at(doc1.key), doc1);
  XCTAssertEqualObjects(event.document_updates().at(doc2.key), doc2);

  _targetMetadataProvider.SetSyncedKeys(DocumentKeySet{doc1.key, doc2.key}, targetMap[1]);

  FSTDeletedDocument *deletedDoc1 = [FSTDeletedDocument documentWithKey:doc1.key
                                                                version:testutil::Version(3)
                                                  hasCommittedMutations:NO];
  DocumentWatchChange change3{{}, {1}, deletedDoc1.key, deletedDoc1};
  aggregator.HandleDocumentChange(change3);

  FSTDocument *updatedDoc2 = FSTTestDoc("docs/2", 3, @{@"value" : @2}, DocumentState::kSynced);
  DocumentWatchChange change4{{1}, {}, updatedDoc2.key, updatedDoc2};
  aggregator.HandleDocumentChange(change4);

  FSTDocument *doc3 = FSTTestDoc("docs/3", 3, @{@"value" : @3}, DocumentState::kSynced);
  DocumentWatchChange change5{{1}, {}, doc3.key, doc3};
  aggregator.HandleDocumentChange(change5);

  event = aggregator.CreateRemoteEvent(testutil::Version(3));

  XCTAssertEqual(event.snapshot_version(), testutil::Version(3));
  XCTAssertEqual(event.document_updates().size(), 3);
  // doc1 is replaced
  XCTAssertEqualObjects(event.document_updates().at(doc1.key), deletedDoc1);
  // doc2 is updated
  XCTAssertEqualObjects(event.document_updates().at(doc2.key), updatedDoc2);
  // doc3 is new
  XCTAssertEqualObjects(event.document_updates().at(doc3.key), doc3);

  // Target is unchanged
  XCTAssertEqual(event.target_changes().size(), 1);

  TargetChange targetChange1{_resumeToken1, false, DocumentKeySet{doc3.key},
                             DocumentKeySet{updatedDoc2.key}, DocumentKeySet{deletedDoc1.key}};
  XCTAssertTrue(event.target_changes().at(1) == targetChange1);
}

- (void)testResumeTokensHandledPerTarget {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1, 2}]};

  WatchChangeAggregator aggregator = [self aggregatorWithTargetMap:targetMap
                                              outstandingResponses:_noOutstandingResponses
                                                      existingKeys:DocumentKeySet {}
                                                           changes:{}];

  WatchTargetChange change1{WatchTargetChangeState::Current, {1}, _resumeToken1};
  aggregator.HandleTargetChange(change1);

  NSData *resumeToken2 = [@"resume2" dataUsingEncoding:NSUTF8StringEncoding];
  WatchTargetChange change2{WatchTargetChangeState::Current, {2}, resumeToken2};
  aggregator.HandleTargetChange(change2);

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));
  XCTAssertEqual(event.target_changes().size(), 2);

  TargetChange targetChange1{_resumeToken1, true, DocumentKeySet{}, DocumentKeySet{},
                             DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(1) == targetChange1);

  TargetChange targetChange2{resumeToken2, true, DocumentKeySet{}, DocumentKeySet{},
                             DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(2) == targetChange2);
}

- (void)testLastResumeTokenWins {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1, 2}]};

  WatchChangeAggregator aggregator = [self aggregatorWithTargetMap:targetMap
                                              outstandingResponses:_noOutstandingResponses
                                                      existingKeys:DocumentKeySet {}
                                                           changes:{}];

  WatchTargetChange change1{WatchTargetChangeState::Current, {1}, _resumeToken1};
  aggregator.HandleTargetChange(change1);

  NSData *resumeToken2 = [@"resume2" dataUsingEncoding:NSUTF8StringEncoding];
  WatchTargetChange change2{WatchTargetChangeState::NoChange, {1}, resumeToken2};
  aggregator.HandleTargetChange(change2);

  NSData *resumeToken3 = [@"resume3" dataUsingEncoding:NSUTF8StringEncoding];
  WatchTargetChange change3{WatchTargetChangeState::NoChange, {2}, resumeToken3};
  aggregator.HandleTargetChange(change3);

  RemoteEvent event = aggregator.CreateRemoteEvent(testutil::Version(3));
  XCTAssertEqual(event.target_changes().size(), 2);

  TargetChange targetChange1{resumeToken2, true, DocumentKeySet{}, DocumentKeySet{},
                             DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(1) == targetChange1);

  TargetChange targetChange2{resumeToken3, false, DocumentKeySet{}, DocumentKeySet{},
                             DocumentKeySet{}};
  XCTAssertTrue(event.target_changes().at(2) == targetChange2);
}

- (void)testSynthesizeDeletes {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForLimboTargets:{1}]};
  DocumentKey limboKey = testutil::Key("coll/limbo");

  auto resolveLimboTarget = MakeTargetChange(WatchTargetChangeState::Current, {1});
  RemoteEvent event = [self remoteEventAtSnapshotVersion:3
                                               targetMap:targetMap
                                    outstandingResponses:_noOutstandingResponses
                                            existingKeys:DocumentKeySet {}
                                                 changes:Changes(std::move(resolveLimboTarget))];

  FSTDeletedDocument *expected = [FSTDeletedDocument documentWithKey:limboKey
                                                             version:event.snapshot_version()
                                               hasCommittedMutations:NO];
  XCTAssertEqualObjects(event.document_updates().at(limboKey), expected);
  XCTAssertTrue(event.limbo_document_changes().contains(limboKey));
}

- (void)testDoesntSynthesizeDeletesForWrongState {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{1}]};

  auto wrongState = MakeTargetChange(WatchTargetChangeState::NoChange, {1});

  RemoteEvent event = [self remoteEventAtSnapshotVersion:3
                                               targetMap:targetMap
                                    outstandingResponses:_noOutstandingResponses
                                            existingKeys:DocumentKeySet {}
                                                 changes:Changes(std::move(wrongState))];

  XCTAssertEqual(event.document_updates().size(), 0);
  XCTAssertEqual(event.limbo_document_changes().size(), 0);
}

- (void)testDoesntSynthesizeDeletesForExistingDoc {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForTargets:{3}]};

  auto hasDocument = MakeTargetChange(WatchTargetChangeState::Current, {3});

  RemoteEvent event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:_noOutstandingResponses
                            existingKeys:DocumentKeySet{FSTTestDocKey(@"coll/limbo")}
                                 changes:Changes(std::move(hasDocument))];

  XCTAssertEqual(event.document_updates().size(), 0);
  XCTAssertEqual(event.limbo_document_changes().size(), 0);
}

- (void)testSeparatesDocumentUpdates {
  std::unordered_map<TargetId, FSTQueryData *> targetMap{[self queryDataForLimboTargets:{1}]};

  FSTDocument *newDoc = FSTTestDoc("docs/new", 1, @{@"key" : @"value"}, DocumentState::kSynced);
  auto newDocChange = MakeDocChange({1}, {}, newDoc.key, newDoc);

  FSTDocument *existingDoc =
      FSTTestDoc("docs/existing", 1, @{@"some" : @"data"}, DocumentState::kSynced);
  auto existingDocChange = MakeDocChange({1}, {}, existingDoc.key, existingDoc);

  FSTDeletedDocument *deletedDoc = FSTTestDeletedDoc("docs/deleted", 1, NO);
  auto deletedDocChange = MakeDocChange({}, {1}, deletedDoc.key, deletedDoc);

  FSTDeletedDocument *missingDoc = FSTTestDeletedDoc("docs/missing", 1, NO);
  auto missingDocChange = MakeDocChange({}, {1}, missingDoc.key, missingDoc);

  RemoteEvent event = [self
      remoteEventAtSnapshotVersion:3
                         targetMap:targetMap
              outstandingResponses:_noOutstandingResponses
                      existingKeys:DocumentKeySet{existingDoc.key, deletedDoc.key}
                           changes:Changes(std::move(newDocChange), std::move(existingDocChange),
                                           std::move(deletedDocChange),
                                           std::move(missingDocChange))];

  TargetChange targetChange2{_resumeToken1, false, DocumentKeySet{newDoc.key},
                             DocumentKeySet{existingDoc.key}, DocumentKeySet{deletedDoc.key}};

  XCTAssertTrue(event.target_changes().at(1) == targetChange2);
}

- (void)testTracksLimboDocuments {
  std::unordered_map<TargetId, FSTQueryData *> targetMap = [self queryDataForTargets:{1}];
  auto additionalTargets = [self queryDataForLimboTargets:{2}];
  targetMap.insert(additionalTargets.begin(), additionalTargets.end());

  // Add 3 docs: 1 is limbo and non-limbo, 2 is limbo-only, 3 is non-limbo
  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"key" : @"value"}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("docs/2", 1, @{@"key" : @"value"}, DocumentState::kSynced);
  FSTDocument *doc3 = FSTTestDoc("docs/3", 1, @{@"key" : @"value"}, DocumentState::kSynced);

  // Target 2 is a limbo target
  auto docChange1 = MakeDocChange({1, 2}, {}, doc1.key, doc1);
  auto docChange2 = MakeDocChange({2}, {}, doc2.key, doc2);
  auto docChange3 = MakeDocChange({1}, {}, doc3.key, doc3);
  auto targetsChange = MakeTargetChange(WatchTargetChangeState::Current, {1, 2});

  RemoteEvent event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:_noOutstandingResponses
                            existingKeys:DocumentKeySet {}
                                 changes:Changes(std::move(docChange1), std::move(docChange2),
                                                 std::move(docChange3), std::move(targetsChange))];

  DocumentKeySet limboDocChanges = event.limbo_document_changes();
  // Doc1 is in both limbo and non-limbo targets, therefore not tracked as limbo
  XCTAssertFalse(limboDocChanges.contains(doc1.key));
  // Doc2 is only in the limbo target, so is tracked as a limbo document
  XCTAssertTrue(limboDocChanges.contains(doc2.key));
  // Doc3 is only in the non-limbo target, therefore not tracked as limbo
  XCTAssertFalse(limboDocChanges.contains(doc3.key));
}

@end

NS_ASSUME_NONNULL_END
