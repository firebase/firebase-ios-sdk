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

#import "Firestore/Source/Remote/FSTRemoteEvent.h"

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
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/memory/memory.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::remote::ExistenceFilter;
using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::WatchChange;
using firebase::firestore::remote::WatchTargetChange;
// `make_unique` cannot deduce that the template parameter is intended to
// resolve to a vector of target ids when given an initialization list (e.g.,
// {1, 2}). The type alias is deliberately very short to minimize boilderplate.
using ids = std::vector<TargetId>;

NS_ASSUME_NONNULL_BEGIN

@interface FSTRemoteEventTests : XCTestCase
@end

@implementation FSTRemoteEventTests {
  NSData *_resumeToken1;
  NSMutableDictionary<NSNumber *, NSNumber *> *_noOutstandingResponses;
  FSTTestTargetMetadataProvider *_targetMetadataProvider;
}

- (void)setUp {
  _resumeToken1 = [@"resume1" dataUsingEncoding:NSUTF8StringEncoding];
  _noOutstandingResponses = [NSMutableDictionary dictionary];
  _targetMetadataProvider = [FSTTestTargetMetadataProvider new];
}

/**
 * Creates a map with query data for the provided target IDs. All targets are considered active
 * and query a collection named "coll".
 */
- (NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *)queryDataForTargets:
    (NSArray<FSTBoxedTargetID *> *)targetIDs {
  NSMutableDictionary<FSTBoxedTargetID *, FSTQueryData *> *targets =
      [NSMutableDictionary dictionary];
  for (FSTBoxedTargetID *targetID in targetIDs) {
    FSTQuery *query = FSTTestQuery("coll");
    targets[targetID] = [[FSTQueryData alloc] initWithQuery:query
                                                   targetID:targetID.intValue
                                       listenSequenceNumber:0
                                                    purpose:FSTQueryPurposeListen];
  }
  return targets;
}

/**
 * Creates a map with query data for the provided target IDs. All targets are marked as limbo
 * queries for the document at "coll/limbo".
 */
- (NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *)queryDataForLimboTargets:
    (NSArray<FSTBoxedTargetID *> *)targetIDs {
  NSMutableDictionary<FSTBoxedTargetID *, FSTQueryData *> *targets =
      [NSMutableDictionary dictionary];
  for (FSTBoxedTargetID *targetID in targetIDs) {
    FSTQuery *query = FSTTestQuery("coll/limbo");
    targets[targetID] = [[FSTQueryData alloc] initWithQuery:query
                                                   targetID:targetID.intValue
                                       listenSequenceNumber:0
                                                    purpose:FSTQueryPurposeLimboResolution];
  }
  return targets;
}

/**
 * Creates an aggregator initialized with the set of provided `WatchChange`s. Tests can add further
 * changes via `handleDocumentChange`, `handleTargetChange` and `handleExistenceFilterChange`.
 *
 * @param targetMap A map of query data for all active targets. The map must include an entry for
 * every target referenced by any of the watch changes.
 * @param outstandingResponses The number of outstanding ACKs a target has to receive before it is
 * considered active, or `_noOutstandingResponses` if all targets are already active.
 * @param existingKeys The set of documents that are considered synced with the test targets as
 * part of a previous listen. To modify this set during test execution, invoke
 * `[_targetMetadataProvider setSyncedKeys:forQueryData:]`.
 * @param watchChanges The watch changes to apply before returning the aggregator. Supported
 * changes are `DocumentWatchChange` and `WatchTargetChange`.
 */
- (FSTWatchChangeAggregator *)
    aggregatorWithTargetMap:(const std::unordered_map<TargetId, FSTQueryData *> &)targetMap
       outstandingResponses:
           (nullable NSDictionary<FSTBoxedTargetID *, NSNumber *> *)outstandingResponses
               existingKeys:(DocumentKeySet)existingKeys
                    changes:(const std::vector<std::unique_ptr<WatchChange>> &)watchChanges {
  FSTWatchChangeAggregator *aggregator =
      [[FSTWatchChangeAggregator alloc] initWithTargetMetadataProvider:_targetMetadataProvider];

  std::vector<TargetId> targetIDs;
  for (const auto &kv : targetMap) {
    TargetId targetID = kv.first;
    FSTQueryData *queryData = kv.second;

    targetIDs.push_back(targetID);
    [_targetMetadataProvider setSyncedKeys:existingKeys forQueryData:queryData];
  };

  [outstandingResponses
      enumerateKeysAndObjectsUsingBlock:^(FSTBoxedTargetID *targetID, NSNumber *count, BOOL *stop) {
        for (int i = 0; i < count.intValue; ++i) {
          [aggregator recordTargetRequest:targetID.intValue];
        }
      }];

  for (const std::unique_ptr<WatchChange> &change : watchChanges) {
    switch (change->type()) {
      case WatchChange::Type::Document: {
        [aggregator handleDocumentChange:*static_cast<DocumentWatchChange *>(change.get())];
        break;
      }
      case WatchChange::Type::TargetChange: {
        [aggregator handleTargetChange:*static_cast<WatchTargetChange *>(change.get())];
        break;
      }
      default:
        HARD_ASSERT("Encountered unexpected type of WatchChange");
    }
  }

  [aggregator handleTargetChange:WatchTargetChange{WatchTargetChangeState::NoChange, targetIDs,
                                                   _resumeToken1}];

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
- (FSTRemoteEvent *)
    remoteEventAtSnapshotVersion:(FSTTestSnapshotVersion)snapshotVersion
                       targetMap:(NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *)targetMap
            outstandingResponses:
                (nullable NSDictionary<FSTBoxedTargetID *, NSNumber *> *)outstandingResponses
                    existingKeys:(DocumentKeySet)existingKeys
                         changes:(const std::vector<std::unique_ptr<WatchChange>> &)watchChanges {
  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargetMap:targetMap
                                                  outstandingResponses:outstandingResponses
                                                          existingKeys:existingKeys
                                                               changes:watchChanges];
  return [aggregator remoteEventAtSnapshotVersion:testutil::Version(snapshotVersion)];
}

- (void)testWillAccumulateDocumentAddedAndRemovedEvents {
  // The target map that contains an entry for every target in this test. If a target ID is
  // omitted, the target is considered inactive and FSTTestTargetMetadataProvider will fail on
  // access.
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForTargets:@[ @1, @2, @3, @4, @5, @6 ]];

  FSTDocument *existingDoc = FSTTestDoc("docs/1", 1, @{@"value" : @1}, FSTDocumentStateSynced);
  auto change1 = absl::make_unique<DocumentWatchChange>(ids{1, 2, 3}, ids{4, 5, 6}, existingDoc.key,
                                                        existingDoc);

  FSTDocument *newDoc = FSTTestDoc("docs/2", 2, @{@"value" : @2}, FSTDocumentStateSynced);
  auto change2 = absl::make_unique<DocumentWatchChange>(ids{1, 4}, ids{2, 6}, newDoc.key, newDoc);

  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(change1));
  changes.push_back(std::move(change2));

  // Create a remote event that includes both `change1` and `change2` as well as a NO_CHANGE event
  // with the default resume token (`_resumeToken1`).
  // As `existingDoc` is provided as an existing key, any updates to this document will be treated
  // as modifications rather than adds.
  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:_noOutstandingResponses
                                                existingKeys:DocumentKeySet{existingDoc.key}
                                                     changes:changes];
  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  XCTAssertEqual(event.documentUpdates.size(), 2);
  XCTAssertEqualObjects(event.documentUpdates.at(existingDoc.key), existingDoc);
  XCTAssertEqualObjects(event.documentUpdates.at(newDoc.key), newDoc);

  // 'change1' and 'change2' affect six different targets
  XCTAssertEqual(event.targetChanges.size(), 6);

  FSTTargetChange *targetChange1 =
      FSTTestTargetChange(DocumentKeySet{newDoc.key}, DocumentKeySet{existingDoc.key},
                          DocumentKeySet{}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(1), targetChange1);

  FSTTargetChange *targetChange2 = FSTTestTargetChange(
      DocumentKeySet{}, DocumentKeySet{existingDoc.key}, DocumentKeySet{}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(2), targetChange2);

  FSTTargetChange *targetChange3 = FSTTestTargetChange(
      DocumentKeySet{}, DocumentKeySet{existingDoc.key}, DocumentKeySet{}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(3), targetChange3);

  FSTTargetChange *targetChange4 =
      FSTTestTargetChange(DocumentKeySet{newDoc.key}, DocumentKeySet{},
                          DocumentKeySet{existingDoc.key}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(4), targetChange4);

  FSTTargetChange *targetChange5 = FSTTestTargetChange(
      DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{existingDoc.key}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(5), targetChange5);

  FSTTargetChange *targetChange6 = FSTTestTargetChange(
      DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{existingDoc.key}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(6), targetChange6);
}

- (void)testWillIgnoreEventsForPendingTargets {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap = [self queryDataForTargets:@[ @1 ]];

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, FSTDocumentStateSynced);
  auto change1 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, doc1.key, doc1);
  auto change2 = absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Removed, ids{1});
  auto change3 = absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Added, ids{1});
  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{@"value" : @2}, FSTDocumentStateSynced);
  auto change4 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, doc2.key, doc2);

  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(change1));
  changes.push_back(std::move(change2));
  changes.push_back(std::move(change3));
  changes.push_back(std::move(change4));

  // We're waiting for the unwatch and watch ack
  NSDictionary<NSNumber *, NSNumber *> *outstandingResponses = @{@1 : @2};

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:outstandingResponses
                                                existingKeys:DocumentKeySet {}
                                                     changes:changes];
  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  // doc1 is ignored because it was part of an inactive target, but doc2 is in the changes
  // because it become active.
  XCTAssertEqual(event.documentUpdates.size(), 1);
  XCTAssertEqualObjects(event.documentUpdates.at(doc2.key), doc2);

  XCTAssertEqual(event.targetChanges.size(), 1);
}

- (void)testWillIgnoreEventsForRemovedTargets {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap = [self queryDataForTargets:@[]];

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, FSTDocumentStateSynced);
  auto change1 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, doc1.key, doc1);
  auto change2 = absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Removed, ids{1});

  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(change1));
  changes.push_back(std::move(change2));

  // We're waiting for the unwatch ack
  NSDictionary<NSNumber *, NSNumber *> *outstandingResponses = @{@1 : @1};

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:outstandingResponses
                                                existingKeys:DocumentKeySet {}
                                                     changes:changes];
  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  // doc1 is ignored because it was part of an inactive target
  XCTAssertEqual(event.documentUpdates.size(), 0);

  // Target 1 is ignored because it was removed
  XCTAssertEqual(event.targetChanges.size(), 0);
}

- (void)testWillKeepResetMappingEvenWithUpdates {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap = [self queryDataForTargets:@[ @1 ]];

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, FSTDocumentStateSynced);
  auto change1 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, doc1.key, doc1);

  // Reset stream, ignoring doc1
  auto change2 = absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Reset, ids{1});

  // Add doc2, doc3
  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{@"value" : @2}, FSTDocumentStateSynced);
  auto change3 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, doc2.key, doc2);

  FSTDocument *doc3 = FSTTestDoc("docs/3", 3, @{@"value" : @3}, FSTDocumentStateSynced);
  auto change4 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, doc3.key, doc3);

  // Remove doc2 again, should not show up in reset mapping
  auto change5 = absl::make_unique<DocumentWatchChange>(ids{}, ids{1}, doc2.key, doc2);

  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(change1));
  changes.push_back(std::move(change2));
  changes.push_back(std::move(change3));
  changes.push_back(std::move(change4));
  changes.push_back(std::move(change5));

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:_noOutstandingResponses
                                                existingKeys:DocumentKeySet{doc1.key}
                                                     changes:changes];
  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  XCTAssertEqual(event.documentUpdates.size(), 3);
  XCTAssertEqualObjects(event.documentUpdates.at(doc1.key), doc1);
  XCTAssertEqualObjects(event.documentUpdates.at(doc2.key), doc2);
  XCTAssertEqualObjects(event.documentUpdates.at(doc3.key), doc3);

  XCTAssertEqual(event.targetChanges.size(), 1);

  // Only doc3 is part of the new mapping
  FSTTargetChange *expectedChange = FSTTestTargetChange(
      DocumentKeySet{doc3.key}, DocumentKeySet{}, DocumentKeySet{doc1.key}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(1), expectedChange);
}

- (void)testWillHandleSingleReset {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap = [self queryDataForTargets:@[ @1 ]];

  // Reset target
  WatchTargetChange change{WatchTargetChangeState::Reset, {1}};

  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargetMap:targetMap
                                                  outstandingResponses:_noOutstandingResponses
                                                          existingKeys:DocumentKeySet {}
                                                               changes:{}];
  [aggregator handleTargetChange:change];

  FSTRemoteEvent *event = [aggregator remoteEventAtSnapshotVersion:testutil::Version(3)];

  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  XCTAssertEqual(event.documentUpdates.size(), 0);
  XCTAssertEqual(event.targetChanges.size(), 1);

  // Reset mapping is empty
  FSTTargetChange *expectedChange =
      FSTTestTargetChange(DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{}, [NSData data], NO);
  XCTAssertEqualObjects(event.targetChanges.at(1), expectedChange);
}

- (void)testWillHandleTargetAddAndRemovalInSameBatch {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForTargets:@[ @1, @2 ]];

  FSTDocument *doc1a = FSTTestDoc("docs/1", 1, @{@"value" : @1}, FSTDocumentStateSynced);
  auto change1 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{2}, doc1a.key, doc1a);

  FSTDocument *doc1b = FSTTestDoc("docs/1", 1, @{@"value" : @2}, FSTDocumentStateSynced);
  auto change2 = absl::make_unique<DocumentWatchChange>(ids{2}, ids{1}, doc1b.key, doc1b);

  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(change1));
  changes.push_back(std::move(change2));

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:_noOutstandingResponses
                                                existingKeys:DocumentKeySet{doc1a.key}
                                                     changes:changes];
  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  XCTAssertEqual(event.documentUpdates.size(), 1);
  XCTAssertEqualObjects(event.documentUpdates.at(doc1b.key), doc1b);

  XCTAssertEqual(event.targetChanges.size(), 2);

  FSTTargetChange *targetChange1 = FSTTestTargetChange(
      DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{doc1b.key}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(1), targetChange1);

  FSTTargetChange *targetChange2 = FSTTestTargetChange(DocumentKeySet{}, DocumentKeySet{doc1b.key},
                                                       DocumentKeySet{}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(2), targetChange2);
}

- (void)testTargetCurrentChangeWillMarkTheTargetCurrent {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap = [self queryDataForTargets:@[ @1 ]];

  auto change =
      absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Current, ids{1}, _resumeToken1);
  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(change));

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:_noOutstandingResponses
                                                existingKeys:DocumentKeySet {}
                                                     changes:changes];

  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  XCTAssertEqual(event.documentUpdates.size(), 0);
  XCTAssertEqual(event.targetChanges.size(), 1);

  FSTTargetChange *targetChange =
      FSTTestTargetChange(DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{}, _resumeToken1, YES);
  XCTAssertEqualObjects(event.targetChanges.at(1), targetChange);
}

- (void)testTargetAddedChangeWillResetPreviousState {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForTargets:@[ @1, @3 ]];

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, FSTDocumentStateSynced);
  auto change1 = absl::make_unique<DocumentWatchChange>(ids{1, 3}, ids{2}, doc1.key, doc1);
  auto change2 = absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Current, ids{1, 2, 3},
                                                      _resumeToken1);
  auto change3 = absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Removed, ids{1});
  auto change4 = absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Removed, ids{2});
  auto change5 = absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Added, ids{1});
  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{@"value" : @2}, FSTDocumentStateSynced);
  auto change6 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{3}, doc2.key, doc2);

  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(change1));
  changes.push_back(std::move(change2));
  changes.push_back(std::move(change3));
  changes.push_back(std::move(change4));
  changes.push_back(std::move(change5));
  changes.push_back(std::move(change6));

  NSDictionary<NSNumber *, NSNumber *> *outstandingResponses = @{@1 : @2, @2 : @1};

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:outstandingResponses
                                                existingKeys:DocumentKeySet{doc2.key}
                                                     changes:changes];

  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  XCTAssertEqual(event.documentUpdates.size(), 2);
  XCTAssertEqualObjects(event.documentUpdates.at(doc1.key), doc1);
  XCTAssertEqualObjects(event.documentUpdates.at(doc2.key), doc2);

  // target 1 and 3 are affected (1 because of re-add), target 2 is not because of remove
  XCTAssertEqual(event.targetChanges.size(), 2);

  // doc1 was before the remove, so it does not show up in the mapping.
  // Current was before the remove.
  FSTTargetChange *targetChange1 = FSTTestTargetChange(DocumentKeySet{}, DocumentKeySet{doc2.key},
                                                       DocumentKeySet{}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(1), targetChange1);

  // Doc1 was before the remove
  // Current was before the remove
  FSTTargetChange *targetChange3 = FSTTestTargetChange(
      DocumentKeySet{doc1.key}, DocumentKeySet{}, DocumentKeySet{doc2.key}, _resumeToken1, YES);
  XCTAssertEqualObjects(event.targetChanges.at(3), targetChange3);
}

- (void)testNoChangeWillStillMarkTheAffectedTargets {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap = [self queryDataForTargets:@[ @1 ]];

  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargetMap:targetMap
                                                  outstandingResponses:_noOutstandingResponses
                                                          existingKeys:DocumentKeySet {}
                                                               changes:@[]];

  WatchTargetChange change{WatchTargetChangeState::NoChange, {1}, _resumeToken1};
  [aggregator handleTargetChange:change];

  FSTRemoteEvent *event = [aggregator remoteEventAtSnapshotVersion:testutil::Version(3)];

  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  XCTAssertEqual(event.documentUpdates.size(), 0);
  XCTAssertEqual(event.targetChanges.size(), 1);

  FSTTargetChange *targetChange =
      FSTTestTargetChange(DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(1), targetChange);
}

- (void)testExistenceFilterMismatchClearsTarget {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForTargets:@[ @1, @2 ]];

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, FSTDocumentStateSynced);
  auto change1 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, doc1.key, doc1);
  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{@"value" : @2}, FSTDocumentStateSynced);
  auto change2 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, doc2.key, doc2);
  auto change3 =
      absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Current, ids{1}, _resumeToken1);

  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(change1));
  changes.push_back(std::move(change2));
  changes.push_back(std::move(change3));

  FSTWatchChangeAggregator *aggregator =
      [self aggregatorWithTargetMap:targetMap
               outstandingResponses:_noOutstandingResponses
                       existingKeys:DocumentKeySet{doc1.key, doc2.key}
                            changes:changes];

  FSTRemoteEvent *event = [aggregator remoteEventAtSnapshotVersion:testutil::Version(3)];

  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  XCTAssertEqual(event.documentUpdates.size(), 2);
  XCTAssertEqualObjects(event.documentUpdates.at(doc1.key), doc1);
  XCTAssertEqualObjects(event.documentUpdates.at(doc2.key), doc2);

  XCTAssertEqual(event.targetChanges.size(), 2);

  FSTTargetChange *targetChange1 = FSTTestTargetChange(
      DocumentKeySet{}, DocumentKeySet{doc1.key, doc2.key}, DocumentKeySet{}, _resumeToken1, YES);
  XCTAssertEqualObjects(event.targetChanges.at(1), targetChange1);

  FSTTargetChange *targetChange2 =
      FSTTestTargetChange(DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(2), targetChange2);

  // The existence filter mismatch will remove the document from target 1,
  // but not synthesize a document delete.
  ExistenceFilterWatchChange change4{ExistenceFilter{1}, 1};
  [aggregator handleExistenceFilter:change4];

  event = [aggregator remoteEventAtSnapshotVersion:testutil::Version(4)];

  FSTTargetChange *targetChange3 = FSTTestTargetChange(
      DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{doc1.key, doc2.key}, [NSData data], NO);
  XCTAssertEqualObjects(event.targetChanges.at(1), targetChange3);

  XCTAssertEqual(event.targetChanges.size(), 1);
  XCTAssertEqual(event.targetMismatches.size(), 1);
  XCTAssertEqual(event.documentUpdates.size(), 0);
}

- (void)testExistenceFilterMismatchRemovesCurrentChanges {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap = [self queryDataForTargets:@[ @1 ]];

  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargetMap:targetMap
                                                  outstandingResponses:_noOutstandingResponses
                                                          existingKeys:DocumentKeySet {}
                                                               changes:@[]];

  WatchTargetChange markCurrent{WatchTargetChangeState::Current, {1}, _resumeToken1};
  [aggregator handleTargetChange:markCurrent];

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, FSTDocumentStateSynced);
  DocumentWatchChange addDoc{{1}, {}, doc1.key, doc1};
  [aggregator handleDocumentChange:addDoc];

  // The existence filter mismatch will remove the document from target 1, but not synthesize a
  // document delete.
  ExistenceFilterWatchChange existenceFilter{ExistenceFilter{0}, 1};
  [aggregator handleExistenceFilter:existenceFilter];

  FSTRemoteEvent *event = [aggregator remoteEventAtSnapshotVersion:testutil::Version(3)];

  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  XCTAssertEqual(event.documentUpdates.size(), 1);
  XCTAssertEqual(event.targetMismatches.size(), 1);
  XCTAssertEqualObjects(event.documentUpdates.at(doc1.key), doc1);

  XCTAssertEqual(event.targetChanges.size(), 1);

  FSTTargetChange *targetChange1 =
      FSTTestTargetChange(DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{}, [NSData data], NO);
  XCTAssertEqualObjects(event.targetChanges.at(1), targetChange1);
}

- (void)testDocumentUpdate {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap = [self queryDataForTargets:@[ @1 ]];

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"value" : @1}, FSTDocumentStateSynced);
  auto change1 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, doc1.key, doc1);
  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{@"value" : @2}, FSTDocumentStateSynced);
  auto change2 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, doc2.key, doc2);

  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(change1));
  changes.push_back(std::move(change2));

  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargetMap:targetMap
                                                  outstandingResponses:_noOutstandingResponses
                                                          existingKeys:DocumentKeySet {}
                                                               changes:changes];

  FSTRemoteEvent *event = [aggregator remoteEventAtSnapshotVersion:testutil::Version(3)];

  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  XCTAssertEqual(event.documentUpdates.size(), 2);
  XCTAssertEqualObjects(event.documentUpdates.at(doc1.key), doc1);
  XCTAssertEqualObjects(event.documentUpdates.at(doc2.key), doc2);

  [_targetMetadataProvider setSyncedKeys:DocumentKeySet{doc1.key, doc2.key}
                            forQueryData:targetMap[@1]];

  FSTDeletedDocument *deletedDoc1 = [FSTDeletedDocument documentWithKey:doc1.key
                                                                version:testutil::Version(3)
                                                  hasCommittedMutations:NO];
  DocumentWatchChange change3{{}, {1}, deletedDoc1.key, deletedDoc1};
  [aggregator handleDocumentChange:change3];

  FSTDocument *updatedDoc2 = FSTTestDoc("docs/2", 3, @{@"value" : @2}, FSTDocumentStateSynced);
  DocumentWatchChange change4{{1}, {}, updatedDoc2.key, updatedDoc2};
  [aggregator handleDocumentChange:change4];

  FSTDocument *doc3 = FSTTestDoc("docs/3", 3, @{@"value" : @3}, FSTDocumentStateSynced);
  DocumentWatchChange change5{{1}, {}, doc3.key, doc3};
  [aggregator handleDocumentChange:change5];

  event = [aggregator remoteEventAtSnapshotVersion:testutil::Version(3)];

  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  XCTAssertEqual(event.documentUpdates.size(), 3);
  // doc1 is replaced
  XCTAssertEqualObjects(event.documentUpdates.at(doc1.key), deletedDoc1);
  // doc2 is updated
  XCTAssertEqualObjects(event.documentUpdates.at(doc2.key), updatedDoc2);
  // doc3 is new
  XCTAssertEqualObjects(event.documentUpdates.at(doc3.key), doc3);

  // Target is unchanged
  XCTAssertEqual(event.targetChanges.size(), 1);

  FSTTargetChange *targetChange =
      FSTTestTargetChange(DocumentKeySet{doc3.key}, DocumentKeySet{updatedDoc2.key},
                          DocumentKeySet{deletedDoc1.key}, _resumeToken1, NO);
  XCTAssertEqualObjects(event.targetChanges.at(1), targetChange);
}

- (void)testResumeTokensHandledPerTarget {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForTargets:@[ @1, @2 ]];

  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargetMap:targetMap
                                                  outstandingResponses:_noOutstandingResponses
                                                          existingKeys:DocumentKeySet {}
                                                               changes:@[]];

  WatchTargetChange change1{WatchTargetChangeState::Current, {1}, _resumeToken1};
  [aggregator handleTargetChange:change1];

  NSData *resumeToken2 = [@"resume2" dataUsingEncoding:NSUTF8StringEncoding];
  WatchTargetChange change2{WatchTargetChangeState::Current, {2}, resumeToken2};
  [aggregator handleTargetChange:change2];

  FSTRemoteEvent *event = [aggregator remoteEventAtSnapshotVersion:testutil::Version(3)];
  XCTAssertEqual(event.targetChanges.size(), 2);

  FSTTargetChange *targetChange1 =
      FSTTestTargetChange(DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{}, _resumeToken1, YES);
  XCTAssertEqualObjects(event.targetChanges.at(1), targetChange1);

  FSTTargetChange *targetChange2 =
      FSTTestTargetChange(DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{}, resumeToken2, YES);
  XCTAssertEqualObjects(event.targetChanges.at(2), targetChange2);
}

- (void)testLastResumeTokenWins {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForTargets:@[ @1, @2 ]];

  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargetMap:targetMap
                                                  outstandingResponses:_noOutstandingResponses
                                                          existingKeys:DocumentKeySet {}
                                                               changes:@[]];

  WatchTargetChange change1{WatchTargetChangeState::Current, {1}, _resumeToken1};
  [aggregator handleTargetChange:change1];

  NSData *resumeToken2 = [@"resume2" dataUsingEncoding:NSUTF8StringEncoding];
  WatchTargetChange change2{WatchTargetChangeState::NoChange, {1}, resumeToken2};
  [aggregator handleTargetChange:change2];

  NSData *resumeToken3 = [@"resume3" dataUsingEncoding:NSUTF8StringEncoding];
  WatchTargetChange change3{WatchTargetChangeState::NoChange, {2}, resumeToken3};
  [aggregator handleTargetChange:change3];

  FSTRemoteEvent *event = [aggregator remoteEventAtSnapshotVersion:testutil::Version(3)];
  XCTAssertEqual(event.targetChanges.size(), 2);

  FSTTargetChange *targetChange1 =
      FSTTestTargetChange(DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{}, resumeToken2, YES);
  XCTAssertEqualObjects(event.targetChanges.at(1), targetChange1);

  FSTTargetChange *targetChange2 =
      FSTTestTargetChange(DocumentKeySet{}, DocumentKeySet{}, DocumentKeySet{}, resumeToken3, NO);
  XCTAssertEqualObjects(event.targetChanges.at(2), targetChange2);
}

- (void)testSynthesizeDeletes {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForLimboTargets:@[ @1 ]];

  DocumentKey limboKey = testutil::Key("coll/limbo");

  auto resolveLimboTarget =
      absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Current, ids{1});
  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(resolveLimboTarget));

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:_noOutstandingResponses
                                                existingKeys:DocumentKeySet {}
                                                     changes:changes];

  FSTDeletedDocument *expected = [FSTDeletedDocument documentWithKey:limboKey
                                                             version:event.snapshotVersion
                                               hasCommittedMutations:NO];
  XCTAssertEqualObjects(event.documentUpdates.at(limboKey), expected);
  XCTAssertTrue(event.limboDocumentChanges.contains(limboKey));
}

- (void)testDoesntSynthesizeDeletesForWrongState {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForLimboTargets:@[ @1 ]];

  auto wrongState = absl::make_unique<WatchTargetChange>(WatchTargetChangeState::NoChange, ids{1});
  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(wrongState));

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:_noOutstandingResponses
                                                existingKeys:DocumentKeySet {}
                                                     changes:changes];

  XCTAssertEqual(event.documentUpdates.size(), 0);
  XCTAssertEqual(event.limboDocumentChanges.size(), 0);
}

- (void)testDoesntSynthesizeDeletesForExistingDoc {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForLimboTargets:@[ @3 ]];

  auto hasDocument = absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Current, ids{3});
  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(hasDocument));

  FSTRemoteEvent *event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:_noOutstandingResponses
                            existingKeys:DocumentKeySet{FSTTestDocKey(@"coll/limbo")}
                                 changes:changes];

  XCTAssertEqual(event.documentUpdates.size(), 0);
  XCTAssertEqual(event.limboDocumentChanges.size(), 0);
}

- (void)testSeparatesDocumentUpdates {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForLimboTargets:@[ @1 ]];

  FSTDocument *newDoc = FSTTestDoc("docs/new", 1, @{@"key" : @"value"}, FSTDocumentStateSynced);
  auto newDocChange = absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, newDoc.key, newDoc);

  FSTDocument *existingDoc =
      FSTTestDoc("docs/existing", 1, @{@"some" : @"data"}, FSTDocumentStateSynced);
  auto existingDocChange =
      absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, existingDoc.key, existingDoc);

  FSTDeletedDocument *deletedDoc = FSTTestDeletedDoc("docs/deleted", 1, NO);
  auto deletedDocChange =
      absl::make_unique<DocumentWatchChange>(ids{}, ids{1}, deletedDoc.key, deletedDoc);

  FSTDeletedDocument *missingDoc = FSTTestDeletedDoc("docs/missing", 1, NO);
  auto missingDocChange =
      absl::make_unique<DocumentWatchChange>(ids{}, ids{1}, missingDoc.key, missingDoc);

  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(newDocChange));
  changes.push_back(std::move(existingDocChange));
  changes.push_back(std::move(deletedDocChange));
  changes.push_back(std::move(missingDocChange));

  FSTRemoteEvent *event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:_noOutstandingResponses
                            existingKeys:DocumentKeySet{existingDoc.key, deletedDoc.key}
                                 changes:changes];

  FSTTargetChange *targetChange =
      FSTTestTargetChange(DocumentKeySet{newDoc.key}, DocumentKeySet{existingDoc.key},
                          DocumentKeySet{deletedDoc.key}, _resumeToken1, NO);

  XCTAssertEqualObjects(event.targetChanges.at(1), targetChange);
}

- (void)testTracksLimboDocuments {
  NSMutableDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [NSMutableDictionary dictionary];
  [targetMap addEntriesFromDictionary:[self queryDataForTargets:@[ @1 ]]];
  [targetMap addEntriesFromDictionary:[self queryDataForLimboTargets:@[ @2 ]]];

  // Add 3 docs: 1 is limbo and non-limbo, 2 is limbo-only, 3 is non-limbo
  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"key" : @"value"}, FSTDocumentStateSynced);
  FSTDocument *doc2 = FSTTestDoc("docs/2", 1, @{@"key" : @"value"}, FSTDocumentStateSynced);
  FSTDocument *doc3 = FSTTestDoc("docs/3", 1, @{@"key" : @"value"}, FSTDocumentStateSynced);

  // Target 2 is a limbo target
  auto docChange1 = absl::make_unique<DocumentWatchChange>(ids{1, 2}, ids{}, doc1.key, doc1);
  auto docChange2 = absl::make_unique<DocumentWatchChange>(ids{2}, ids{}, doc2.key, doc2);
  auto docChange3 = absl::make_unique<DocumentWatchChange>(ids{1}, ids{}, doc3.key, doc3);
  auto targetsChange =
      absl::make_unique<WatchTargetChange>(WatchTargetChangeState::Current, ids{1, 2});

  std::vector<std::unique_ptr<WatchChange>> changes;
  changes.push_back(std::move(docChange1));
  changes.push_back(std::move(docChange2));
  changes.push_back(std::move(docChange3));
  changes.push_back(std::move(targetsChange));

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:_noOutstandingResponses
                                                existingKeys:DocumentKeySet {}
                                                     changes:changes];

  DocumentKeySet limboDocChanges = event.limboDocumentChanges;
  // Doc1 is in both limbo and non-limbo targets, therefore not tracked as limbo
  XCTAssertFalse(limboDocChanges.contains(doc1.key));
  // Doc2 is only in the limbo target, so is tracked as a limbo document
  XCTAssertTrue(limboDocChanges.contains(doc2.key));
  // Doc3 is only in the non-limbo target, therefore not tracked as limbo
  XCTAssertFalse(limboDocChanges.contains(doc3.key));
}

@end

NS_ASSUME_NONNULL_END
