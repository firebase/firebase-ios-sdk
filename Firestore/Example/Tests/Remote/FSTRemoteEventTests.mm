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

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Remote/FSTExistenceFilter.h"
#import "Firestore/Source/Remote/FSTWatchChange.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"

#import "Firestore/Example/Tests/Remote/FSTWatchChange+Testing.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::SnapshotVersion;

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
 * Creates an aggregator initialized with the set of provided FSTWatchChanges. Tests can add further
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
 * changes are FSTDocumentWatchChange and FSTWatchTargetChange.
 */
- (FSTWatchChangeAggregator *)
aggregatorWithTargetMap:(NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *)targetMap
   outstandingResponses:
       (nullable NSDictionary<FSTBoxedTargetID *, NSNumber *> *)outstandingResponses
           existingKeys:(DocumentKeySet)existingKeys
                changes:(NSArray<FSTWatchChange *> *)watchChanges {
  FSTWatchChangeAggregator *aggregator =
      [[FSTWatchChangeAggregator alloc] initWithTargetMetadataProvider:_targetMetadataProvider];

  NSMutableArray<FSTBoxedTargetID *> *targetIDs = [NSMutableArray array];
  [targetMap enumerateKeysAndObjectsUsingBlock:^(FSTBoxedTargetID *targetID,
                                                 FSTQueryData *queryData, BOOL *stop) {
    [targetIDs addObject:targetID];
    [_targetMetadataProvider setSyncedKeys:existingKeys forQueryData:queryData];
  }];

  [outstandingResponses
      enumerateKeysAndObjectsUsingBlock:^(FSTBoxedTargetID *targetID, NSNumber *count, BOOL *stop) {
        for (int i = 0; i < count.intValue; ++i) {
          [aggregator recordTargetRequest:targetID];
        }
      }];

  for (FSTWatchChange *change in watchChanges) {
    if ([change isKindOfClass:[FSTDocumentWatchChange class]]) {
      [aggregator handleDocumentChange:(FSTDocumentWatchChange *)change];
    } else if ([change isKindOfClass:[FSTWatchTargetChange class]]) {
      [aggregator handleTargetChange:(FSTWatchTargetChange *)change];
    } else {
      HARD_ASSERT("Encountered unexpected type of FSTWatchChange");
    }
  }

  [aggregator handleTargetChange:[[FSTWatchTargetChange alloc]
                                     initWithState:FSTWatchTargetChangeStateNoChange
                                         targetIDs:targetIDs
                                       resumeToken:_resumeToken1
                                             cause:nil]];

  return aggregator;
}

/**
 * Creates a single remote event that includes target changes for all provided FSTWatchChanges.
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
 * changes are FSTDocumentWatchChange and FSTWatchTargetChange.
 */
- (FSTRemoteEvent *)
remoteEventAtSnapshotVersion:(FSTTestSnapshotVersion)snapshotVersion
                   targetMap:(NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *)targetMap
        outstandingResponses:
            (nullable NSDictionary<FSTBoxedTargetID *, NSNumber *> *)outstandingResponses
                existingKeys:(DocumentKeySet)existingKeys
                     changes:(NSArray<FSTWatchChange *> *)watchChanges {
  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargetMap:targetMap
                                                  outstandingResponses:outstandingResponses
                                                          existingKeys:existingKeys
                                                               changes:watchChanges];
  return [aggregator remoteEventAtSnapshotVersion:testutil::Version(snapshotVersion)];
}

- (void)testWillAccumulateDocumentAddedAndRemovedEvents {
  // The target map that contains an entry for every target in this test. If a target ID is omitted,
  // the target is considered inactive and FSTTestTargetMetadataProvider will fail on access.
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForTargets:@[ @1, @2, @3, @4, @5, @6 ]];

  FSTDocument *existingDoc = FSTTestDoc("docs/1", 1, @{ @"value" : @1 }, NO);
  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1, @2, @3 ]
                                                                    removedTargetIDs:@[ @4, @5, @6 ]
                                                                         documentKey:existingDoc.key
                                                                            document:existingDoc];

  FSTDocument *newDoc = FSTTestDoc("docs/2", 2, @{ @"value" : @2 }, NO);
  FSTWatchChange *change2 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1, @4 ]
                                                                    removedTargetIDs:@[ @2, @6 ]
                                                                         documentKey:newDoc.key
                                                                            document:newDoc];

  // Create a remote event that includes both `change1` and `change2` as well as a NO_CHANGE event
  // with the default resume token (`_resumeToken1`).
  // As `existingDoc` is provided as an existing key, any updates to this document will be treated
  // as modifications rather than adds.
  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:_noOutstandingResponses
                                                existingKeys:DocumentKeySet{existingDoc.key}
                                                     changes:@[ change1, change2 ]];
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

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{ @"value" : @1 }, NO);
  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc1.key
                                                                            document:doc1];

  FSTWatchChange *change2 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateRemoved
                                                        targetIDs:@[ @1 ]
                                                            cause:nil];

  FSTWatchChange *change3 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateAdded
                                                        targetIDs:@[ @1 ]
                                                            cause:nil];

  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{ @"value" : @2 }, NO);
  FSTWatchChange *change4 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc2.key
                                                                            document:doc2];

  // We're waiting for the unwatch and watch ack
  NSDictionary<NSNumber *, NSNumber *> *outstandingResponses = @{ @1 : @2 };

  FSTRemoteEvent *event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:outstandingResponses
                            existingKeys:DocumentKeySet {}
                                 changes:@[ change1, change2, change3, change4 ]];
  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  // doc1 is ignored because it was part of an inactive target, but doc2 is in the changes
  // because it become active.
  XCTAssertEqual(event.documentUpdates.size(), 1);
  XCTAssertEqualObjects(event.documentUpdates.at(doc2.key), doc2);

  XCTAssertEqual(event.targetChanges.size(), 1);
}

- (void)testWillIgnoreEventsForRemovedTargets {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap = [self queryDataForTargets:@[]];

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{ @"value" : @1 }, NO);
  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc1.key
                                                                            document:doc1];

  FSTWatchChange *change2 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateRemoved
                                                        targetIDs:@[ @1 ]
                                                            cause:nil];

  // We're waiting for the unwatch ack
  NSDictionary<NSNumber *, NSNumber *> *outstandingResponses = @{ @1 : @1 };

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:outstandingResponses
                                                existingKeys:DocumentKeySet {}
                                                     changes:@[ change1, change2 ]];
  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  // doc1 is ignored because it was part of an inactive target
  XCTAssertEqual(event.documentUpdates.size(), 0);

  // Target 1 is ignored because it was removed
  XCTAssertEqual(event.targetChanges.size(), 0);
}

- (void)testWillKeepResetMappingEvenWithUpdates {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap = [self queryDataForTargets:@[ @1 ]];

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{ @"value" : @1 }, NO);
  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc1.key
                                                                            document:doc1];
  // Reset stream, ignoring doc1
  FSTWatchChange *change2 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateReset
                                                        targetIDs:@[ @1 ]
                                                            cause:nil];

  // Add doc2, doc3
  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{ @"value" : @2 }, NO);
  FSTWatchChange *change3 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc2.key
                                                                            document:doc2];

  FSTDocument *doc3 = FSTTestDoc("docs/3", 3, @{ @"value" : @3 }, NO);
  FSTWatchChange *change4 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc3.key
                                                                            document:doc3];

  // Remove doc2 again, should not show up in reset mapping
  FSTWatchChange *change5 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[]
                                                                    removedTargetIDs:@[ @1 ]
                                                                         documentKey:doc2.key
                                                                            document:doc2];
  FSTRemoteEvent *event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:_noOutstandingResponses
                            existingKeys:DocumentKeySet{doc1.key}
                                 changes:@[ change1, change2, change3, change4, change5 ]];
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
  FSTWatchTargetChange *change =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateReset
                                  targetIDs:@[ @1 ]
                                      cause:nil];

  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargetMap:targetMap
                                                  outstandingResponses:_noOutstandingResponses
                                                          existingKeys:DocumentKeySet {}
                                                               changes:@[]];
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

  FSTDocument *doc1a = FSTTestDoc("docs/1", 1, @{ @"value" : @1 }, NO);
  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[ @2 ]
                                                                         documentKey:doc1a.key
                                                                            document:doc1a];

  FSTDocument *doc1b = FSTTestDoc("docs/1", 1, @{ @"value" : @2 }, NO);
  FSTWatchChange *change2 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @2 ]
                                                                    removedTargetIDs:@[ @1 ]
                                                                         documentKey:doc1b.key
                                                                            document:doc1b];

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:_noOutstandingResponses
                                                existingKeys:DocumentKeySet{doc1a.key}
                                                     changes:@[ change1, change2 ]];
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

  FSTWatchChange *change = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                                       targetIDs:@[ @1 ]
                                                     resumeToken:_resumeToken1];
  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:_noOutstandingResponses
                                                existingKeys:DocumentKeySet {}
                                                     changes:@[ change ]];

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

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{ @"value" : @1 }, NO);
  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1, @3 ]
                                                                    removedTargetIDs:@[ @2 ]
                                                                         documentKey:doc1.key
                                                                            document:doc1];

  FSTWatchChange *change2 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                                        targetIDs:@[ @1, @2, @3 ]
                                                      resumeToken:_resumeToken1];

  FSTWatchChange *change3 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateRemoved
                                                        targetIDs:@[ @1 ]
                                                            cause:nil];

  FSTWatchChange *change4 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateRemoved
                                                        targetIDs:@[ @2 ]
                                                            cause:nil];

  FSTWatchChange *change5 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateAdded
                                                        targetIDs:@[ @1 ]
                                                            cause:nil];

  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{ @"value" : @2 }, NO);
  FSTWatchChange *change6 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[ @3 ]
                                                                         documentKey:doc2.key
                                                                            document:doc2];

  NSDictionary<NSNumber *, NSNumber *> *outstandingResponses = @{ @1 : @2, @2 : @1 };

  FSTRemoteEvent *event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:outstandingResponses
                            existingKeys:DocumentKeySet{doc2.key}
                                 changes:@[ change1, change2, change3, change4, change5, change6 ]];

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

  FSTWatchTargetChange *change =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateNoChange
                                  targetIDs:@[ @1 ]
                                resumeToken:_resumeToken1];
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

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{ @"value" : @1 }, NO);
  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc1.key
                                                                            document:doc1];

  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{ @"value" : @2 }, NO);
  FSTWatchChange *change2 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc2.key
                                                                            document:doc2];

  FSTWatchChange *change3 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                                        targetIDs:@[ @1 ]
                                                      resumeToken:_resumeToken1];

  FSTWatchChangeAggregator *aggregator =
      [self aggregatorWithTargetMap:targetMap
               outstandingResponses:_noOutstandingResponses
                       existingKeys:DocumentKeySet{doc1.key, doc2.key}
                            changes:@[ change1, change2, change3 ]];

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
  FSTExistenceFilterWatchChange *change4 =
      [FSTExistenceFilterWatchChange changeWithFilter:[FSTExistenceFilter filterWithCount:1]
                                             targetID:1];
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

  FSTWatchTargetChange *markCurrent =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                  targetIDs:@[ @1 ]
                                resumeToken:_resumeToken1];
  [aggregator handleTargetChange:markCurrent];

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{ @"value" : @1 }, NO);
  FSTDocumentWatchChange *addDoc = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                           removedTargetIDs:@[]
                                                                                documentKey:doc1.key
                                                                                   document:doc1];
  [aggregator handleDocumentChange:addDoc];

  // The existence filter mismatch will remove the document from target 1, but not synthesize a
  // document delete.
  FSTExistenceFilterWatchChange *existenceFilter =
      [FSTExistenceFilterWatchChange changeWithFilter:[FSTExistenceFilter filterWithCount:0]
                                             targetID:1];
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

  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{ @"value" : @1 }, NO);
  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc1.key
                                                                            document:doc1];

  FSTDocument *doc2 = FSTTestDoc("docs/2", 2, @{ @"value" : @2 }, NO);
  FSTWatchChange *change2 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc2.key
                                                                            document:doc2];

  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargetMap:targetMap
                                                  outstandingResponses:_noOutstandingResponses
                                                          existingKeys:DocumentKeySet {}
                                                               changes:@[ change1, change2 ]];

  FSTRemoteEvent *event = [aggregator remoteEventAtSnapshotVersion:testutil::Version(3)];

  XCTAssertEqual(event.snapshotVersion, testutil::Version(3));
  XCTAssertEqual(event.documentUpdates.size(), 2);
  XCTAssertEqualObjects(event.documentUpdates.at(doc1.key), doc1);
  XCTAssertEqualObjects(event.documentUpdates.at(doc2.key), doc2);

  [_targetMetadataProvider setSyncedKeys:DocumentKeySet{doc1.key, doc2.key}
                            forQueryData:targetMap[@1]];

  FSTDeletedDocument *deletedDoc1 =
      [FSTDeletedDocument documentWithKey:doc1.key version:testutil::Version(3)];
  FSTDocumentWatchChange *change3 =
      [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[]
                                              removedTargetIDs:@[ @1 ]
                                                   documentKey:deletedDoc1.key
                                                      document:deletedDoc1];
  [aggregator handleDocumentChange:change3];

  FSTDocument *updatedDoc2 = FSTTestDoc("docs/2", 3, @{ @"value" : @2 }, NO);
  FSTDocumentWatchChange *change4 =
      [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                              removedTargetIDs:@[]
                                                   documentKey:updatedDoc2.key
                                                      document:updatedDoc2];
  [aggregator handleDocumentChange:change4];

  FSTDocument *doc3 = FSTTestDoc("docs/3", 3, @{ @"value" : @3 }, NO);
  FSTDocumentWatchChange *change5 =
      [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                              removedTargetIDs:@[]
                                                   documentKey:doc3.key
                                                      document:doc3];
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

  FSTWatchTargetChange *change1 =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                  targetIDs:@[ @1 ]
                                resumeToken:_resumeToken1];
  [aggregator handleTargetChange:change1];

  NSData *resumeToken2 = [@"resume2" dataUsingEncoding:NSUTF8StringEncoding];
  FSTWatchTargetChange *change2 =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                  targetIDs:@[ @2 ]
                                resumeToken:resumeToken2];
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

  FSTWatchTargetChange *change1 =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                  targetIDs:@[ @1 ]
                                resumeToken:_resumeToken1];
  [aggregator handleTargetChange:change1];

  NSData *resumeToken2 = [@"resume2" dataUsingEncoding:NSUTF8StringEncoding];
  FSTWatchTargetChange *change2 =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateNoChange
                                  targetIDs:@[ @1 ]
                                resumeToken:resumeToken2];
  [aggregator handleTargetChange:change2];

  NSData *resumeToken3 = [@"resume3" dataUsingEncoding:NSUTF8StringEncoding];
  FSTWatchTargetChange *change3 =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateNoChange
                                  targetIDs:@[ @2 ]
                                resumeToken:resumeToken3];
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

  FSTWatchChange *resolveLimboTarget =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent targetIDs:@[ @1 ]];

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:_noOutstandingResponses
                                                existingKeys:DocumentKeySet {}
                                                     changes:@[ resolveLimboTarget ]];

  FSTDeletedDocument *expected =
      [FSTDeletedDocument documentWithKey:limboKey version:event.snapshotVersion];
  XCTAssertEqualObjects(event.documentUpdates.at(limboKey), expected);
  XCTAssertTrue(event.limboDocumentChanges.contains(limboKey));
}

- (void)testDoesntSynthesizeDeletesForWrongState {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForLimboTargets:@[ @1 ]];

  FSTWatchChange *wrongState =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateNoChange targetIDs:@[ @1 ]];

  FSTRemoteEvent *event = [self remoteEventAtSnapshotVersion:3
                                                   targetMap:targetMap
                                        outstandingResponses:_noOutstandingResponses
                                                existingKeys:DocumentKeySet {}
                                                     changes:@[ wrongState ]];

  XCTAssertEqual(event.documentUpdates.size(), 0);
  XCTAssertEqual(event.limboDocumentChanges.size(), 0);
}

- (void)testDoesntSynthesizeDeletesForExistingDoc {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForLimboTargets:@[ @3 ]];

  FSTWatchChange *hasDocument =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent targetIDs:@[ @3 ]];

  FSTRemoteEvent *event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:_noOutstandingResponses
                            existingKeys:DocumentKeySet{FSTTestDocKey(@"coll/limbo")}
                                 changes:@[ hasDocument ]];

  XCTAssertEqual(event.documentUpdates.size(), 0);
  XCTAssertEqual(event.limboDocumentChanges.size(), 0);
}

- (void)testSeparatesDocumentUpdates {
  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *targetMap =
      [self queryDataForLimboTargets:@[ @1 ]];

  FSTDocument *newDoc = FSTTestDoc("docs/new", 1, @{@"key" : @"value"}, NO);
  FSTWatchChange *newDocChange = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                         removedTargetIDs:@[]
                                                                              documentKey:newDoc.key
                                                                                 document:newDoc];

  FSTDocument *existingDoc = FSTTestDoc("docs/existing", 1, @{@"some" : @"data"}, NO);
  FSTWatchChange *existingDocChange =
      [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                              removedTargetIDs:@[]
                                                   documentKey:existingDoc.key
                                                      document:existingDoc];

  FSTDeletedDocument *deletedDoc = FSTTestDeletedDoc("docs/deleted", 1);
  FSTWatchChange *deletedDocChange =
      [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[]
                                              removedTargetIDs:@[ @1 ]
                                                   documentKey:deletedDoc.key
                                                      document:deletedDoc];

  FSTDeletedDocument *missingDoc = FSTTestDeletedDoc("docs/missing", 1);
  FSTWatchChange *missingDocChange =
      [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[]
                                              removedTargetIDs:@[ @1 ]
                                                   documentKey:missingDoc.key
                                                      document:missingDoc];

  FSTRemoteEvent *event = [self
      remoteEventAtSnapshotVersion:3
                         targetMap:targetMap
              outstandingResponses:_noOutstandingResponses
                      existingKeys:DocumentKeySet{existingDoc.key, deletedDoc.key}
                           changes:@[
                             newDocChange, existingDocChange, deletedDocChange, missingDocChange
                           ]];

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
  FSTDocument *doc1 = FSTTestDoc("docs/1", 1, @{@"key" : @"value"}, NO);
  FSTDocument *doc2 = FSTTestDoc("docs/2", 1, @{@"key" : @"value"}, NO);
  FSTDocument *doc3 = FSTTestDoc("docs/3", 1, @{@"key" : @"value"}, NO);

  // Target 2 is a limbo target
  FSTWatchChange *docChange1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1, @2 ]
                                                                       removedTargetIDs:@[]
                                                                            documentKey:doc1.key
                                                                               document:doc1];

  FSTWatchChange *docChange2 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @2 ]
                                                                       removedTargetIDs:@[]
                                                                            documentKey:doc2.key
                                                                               document:doc2];

  FSTWatchChange *docChange3 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                       removedTargetIDs:@[]
                                                                            documentKey:doc3.key
                                                                               document:doc3];

  FSTWatchChange *targetsChange =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent targetIDs:@[ @1, @2 ]];

  FSTRemoteEvent *event =
      [self remoteEventAtSnapshotVersion:3
                               targetMap:targetMap
                    outstandingResponses:_noOutstandingResponses
                            existingKeys:DocumentKeySet {}
                                 changes:@[ docChange1, docChange2, docChange3, targetsChange ]];

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
