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

#import "Remote/FSTRemoteEvent.h"

#import <XCTest/XCTest.h>

#import "Local/FSTQueryData.h"
#import "Model/FSTDocument.h"
#import "Model/FSTDocumentKey.h"
#import "Remote/FSTExistenceFilter.h"
#import "Remote/FSTWatchChange.h"

#import "FSTHelpers.h"
#import "FSTWatchChange+Testing.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTRemoteEventTests : XCTestCase
@end

@implementation FSTRemoteEventTests {
  NSData *_resumeToken1;
  NSMutableDictionary<NSNumber *, NSNumber *> *_noPendingResponses;
}

- (void)setUp {
  _resumeToken1 = [@"resume1" dataUsingEncoding:NSUTF8StringEncoding];
  _noPendingResponses = [NSMutableDictionary dictionary];
}

- (FSTWatchChangeAggregator *)aggregatorWithTargets:(NSArray<NSNumber *> *)targets
                                        outstanding:
                                            (NSDictionary<NSNumber *, NSNumber *> *)outstanding
                                            changes:(NSArray<FSTWatchChange *> *)watchChanges {
  NSMutableDictionary<NSNumber *, FSTQueryData *> *listens = [NSMutableDictionary dictionary];
  FSTQueryData *dummyQueryData = [FSTQueryData alloc];
  for (NSNumber *targetID in targets) {
    listens[targetID] = dummyQueryData;
  }
  FSTWatchChangeAggregator *aggregator =
      [[FSTWatchChangeAggregator alloc] initWithSnapshotVersion:FSTTestVersion(3)
                                                  listenTargets:listens
                                         pendingTargetResponses:outstanding];
  [aggregator addWatchChanges:watchChanges];
  return aggregator;
}

- (void)testWillAccumulateDocumentAddedAndRemovedEvents {
  FSTDocument *doc1 = FSTTestDoc(@"docs/1", 1, @{ @"value" : @1 }, NO);
  FSTDocument *doc2 = FSTTestDoc(@"docs/2", 2, @{ @"value" : @2 }, NO);

  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1, @2, @3 ]
                                                                    removedTargetIDs:@[ @4, @5, @6 ]
                                                                         documentKey:doc1.key
                                                                            document:doc1];

  FSTWatchChange *change2 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1, @4 ]
                                                                    removedTargetIDs:@[ @2, @6 ]
                                                                         documentKey:doc2.key
                                                                            document:doc2];

  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargets:@[ @1, @2, @3, @4, @5, @6 ]
                                                         outstanding:_noPendingResponses
                                                             changes:@[ change1, change2 ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.documentUpdates.count, 2);
  XCTAssertEqualObjects(event.documentUpdates[doc1.key], doc1);
  XCTAssertEqualObjects(event.documentUpdates[doc2.key], doc2);

  XCTAssertEqual(event.targetChanges.count, 6);

  FSTUpdateMapping *mapping1 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[ doc1, doc2 ] removedDocuments:@[]];
  XCTAssertEqualObjects(event.targetChanges[@1].mapping, mapping1);

  FSTUpdateMapping *mapping2 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[ doc1 ] removedDocuments:@[ doc2 ]];
  XCTAssertEqualObjects(event.targetChanges[@2].mapping, mapping2);

  FSTUpdateMapping *mapping3 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[ doc1 ] removedDocuments:@[]];
  XCTAssertEqualObjects(event.targetChanges[@3].mapping, mapping3);

  FSTUpdateMapping *mapping4 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[ doc2 ] removedDocuments:@[ doc1 ]];
  XCTAssertEqualObjects(event.targetChanges[@4].mapping, mapping4);

  FSTUpdateMapping *mapping5 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[] removedDocuments:@[ doc1 ]];
  XCTAssertEqualObjects(event.targetChanges[@5].mapping, mapping5);

  FSTUpdateMapping *mapping6 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[] removedDocuments:@[ doc1, doc2 ]];
  XCTAssertEqualObjects(event.targetChanges[@6].mapping, mapping6);
}

- (void)testWillIgnoreEventsForPendingTargets {
  FSTDocument *doc1 = FSTTestDoc(@"docs/1", 1, @{ @"value" : @1 }, NO);
  FSTDocument *doc2 = FSTTestDoc(@"docs/2", 2, @{ @"value" : @2 }, NO);

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

  FSTWatchChange *change4 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc2.key
                                                                            document:doc2];

  // We're waiting for the unwatch and watch ack
  NSDictionary<NSNumber *, NSNumber *> *pendingResponses = @{ @1 : @2 };

  FSTWatchChangeAggregator *aggregator =
      [self aggregatorWithTargets:@[ @1 ]
                      outstanding:pendingResponses
                          changes:@[ change1, change2, change3, change4 ]];
  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  // doc1 is ignored because it was part of an inactive target, but doc2 is in the changes
  // because it become active.
  XCTAssertEqual(event.documentUpdates.count, 1);
  XCTAssertEqualObjects(event.documentUpdates[doc2.key], doc2);

  XCTAssertEqual(event.targetChanges.count, 1);
}

- (void)testWillIgnoreEventsForRemovedTargets {
  FSTDocument *doc1 = FSTTestDoc(@"docs/1", 1, @{ @"value" : @1 }, NO);

  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc1.key
                                                                            document:doc1];

  FSTWatchChange *change2 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateRemoved
                                                        targetIDs:@[ @1 ]
                                                            cause:nil];

  // We're waiting for the unwatch ack
  NSDictionary<NSNumber *, NSNumber *> *pendingResponses = @{ @1 : @1 };

  FSTWatchChangeAggregator *aggregator =
      [self aggregatorWithTargets:@[] outstanding:pendingResponses changes:@[ change1, change2 ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  // doc1 is ignored because it was part of an inactive target
  XCTAssertEqual(event.documentUpdates.count, 0);

  // Target 1 is ignored because it was removed
  XCTAssertEqual(event.targetChanges.count, 0);
}

- (void)testWillKeepResetMappingEvenWithUpdates {
  FSTDocument *doc1 = FSTTestDoc(@"docs/1", 1, @{ @"value" : @1 }, NO);
  FSTDocument *doc2 = FSTTestDoc(@"docs/2", 2, @{ @"value" : @2 }, NO);
  FSTDocument *doc3 = FSTTestDoc(@"docs/3", 3, @{ @"value" : @3 }, NO);

  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc1.key
                                                                            document:doc1];
  // Reset stream, ignoring doc1
  FSTWatchChange *change2 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateReset
                                                        targetIDs:@[ @1 ]
                                                            cause:nil];

  // Add doc2, doc3
  FSTWatchChange *change3 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc2.key
                                                                            document:doc2];
  FSTWatchChange *change4 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc3.key
                                                                            document:doc3];

  // Remove doc2 again, should not show up in reset mapping
  FSTWatchChange *change5 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[]
                                                                    removedTargetIDs:@[ @1 ]
                                                                         documentKey:doc2.key
                                                                            document:doc2];

  FSTWatchChangeAggregator *aggregator =
      [self aggregatorWithTargets:@[ @1 ]
                      outstanding:_noPendingResponses
                          changes:@[ change1, change2, change3, change4, change5 ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.documentUpdates.count, 3);
  XCTAssertEqualObjects(event.documentUpdates[doc1.key], doc1);
  XCTAssertEqualObjects(event.documentUpdates[doc2.key], doc2);
  XCTAssertEqualObjects(event.documentUpdates[doc3.key], doc3);

  XCTAssertEqual(event.targetChanges.count, 1);

  // Only doc3 is part of the new mapping
  FSTResetMapping *expectedMapping = [FSTResetMapping mappingWithDocuments:@[ doc3 ]];

  XCTAssertEqualObjects(event.targetChanges[@1].mapping, expectedMapping);
}

- (void)testWillHandleSingleReset {
  // Reset target
  FSTWatchChange *change = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateReset
                                                       targetIDs:@[ @1 ]
                                                           cause:nil];

  FSTWatchChangeAggregator *aggregator =
      [self aggregatorWithTargets:@[ @1 ] outstanding:_noPendingResponses changes:@[ change ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.documentUpdates.count, 0);

  XCTAssertEqual(event.targetChanges.count, 1);

  // Reset mapping is empty
  FSTResetMapping *expectedMapping = [FSTResetMapping mappingWithDocuments:@[]];
  XCTAssertEqualObjects(event.targetChanges[@1].mapping, expectedMapping);
}

- (void)testWillHandleTargetAddAndRemovalInSameBatch {
  FSTDocument *doc1a = FSTTestDoc(@"docs/1", 1, @{ @"value" : @1 }, NO);
  FSTDocument *doc1b = FSTTestDoc(@"docs/1", 1, @{ @"value" : @2 }, NO);

  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[ @2 ]
                                                                         documentKey:doc1a.key
                                                                            document:doc1a];

  FSTWatchChange *change2 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @2 ]
                                                                    removedTargetIDs:@[ @1 ]
                                                                         documentKey:doc1b.key
                                                                            document:doc1b];
  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargets:@[ @1, @2 ]
                                                         outstanding:_noPendingResponses
                                                             changes:@[ change1, change2 ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.documentUpdates.count, 1);
  XCTAssertEqualObjects(event.documentUpdates[doc1b.key], doc1b);

  XCTAssertEqual(event.targetChanges.count, 2);

  FSTUpdateMapping *mapping1 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[] removedDocuments:@[ doc1b ]];
  XCTAssertEqualObjects(event.targetChanges[@1].mapping, mapping1);

  FSTUpdateMapping *mapping2 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[ doc1b ] removedDocuments:@[]];
  XCTAssertEqualObjects(event.targetChanges[@2].mapping, mapping2);
}

- (void)testTargetCurrentChangeWillMarkTheTargetCurrent {
  FSTWatchChange *change = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                                       targetIDs:@[ @1 ]
                                                     resumeToken:_resumeToken1];

  FSTWatchChangeAggregator *aggregator =
      [self aggregatorWithTargets:@[ @1 ] outstanding:_noPendingResponses changes:@[ change ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.documentUpdates.count, 0);
  XCTAssertEqual(event.targetChanges.count, 1);
  FSTTargetChange *targetChange = event.targetChanges[@1];
  XCTAssertEqualObjects(targetChange.mapping, [[FSTUpdateMapping alloc] init]);
  XCTAssertEqual(targetChange.currentStatusUpdate, FSTCurrentStatusUpdateMarkCurrent);
  XCTAssertEqualObjects(targetChange.resumeToken, _resumeToken1);
}

- (void)testTargetAddedChangeWillResetPreviousState {
  FSTDocument *doc1 = FSTTestDoc(@"docs/1", 1, @{ @"value" : @1 }, NO);
  FSTDocument *doc2 = FSTTestDoc(@"docs/2", 2, @{ @"value" : @2 }, NO);

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
  FSTWatchChange *change6 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[ @3 ]
                                                                         documentKey:doc2.key
                                                                            document:doc2];

  NSDictionary<NSNumber *, NSNumber *> *pendingResponses = @{ @1 : @2, @2 : @1 };

  FSTWatchChangeAggregator *aggregator =
      [self aggregatorWithTargets:@[ @1, @3 ]
                      outstanding:pendingResponses
                          changes:@[ change1, change2, change3, change4, change5, change6 ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.documentUpdates.count, 2);
  XCTAssertEqualObjects(event.documentUpdates[doc1.key], doc1);
  XCTAssertEqualObjects(event.documentUpdates[doc2.key], doc2);

  // target 1 and 3 are affected (1 because of re-add), target 2 is not because of remove
  XCTAssertEqual(event.targetChanges.count, 2);

  // doc1 was before the remove, so it does not show up in the mapping
  FSTUpdateMapping *mapping1 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[ doc2 ] removedDocuments:@[]];
  XCTAssertEqualObjects(event.targetChanges[@1].mapping, mapping1);
  // Current was before the remove
  XCTAssertEqual(event.targetChanges[@1].currentStatusUpdate, FSTCurrentStatusUpdateNone);

  // Doc1 was before the remove
  FSTUpdateMapping *mapping3 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[ doc1 ] removedDocuments:@[ doc2 ]];
  XCTAssertEqualObjects(event.targetChanges[@3].mapping, mapping3);
  // Current was before the remove
  XCTAssertEqual(event.targetChanges[@3].currentStatusUpdate, FSTCurrentStatusUpdateMarkCurrent);
  XCTAssertEqualObjects(event.targetChanges[@3].resumeToken, _resumeToken1);
}

- (void)testNoChangeWillStillMarkTheAffectedTargets {
  FSTWatchChange *change = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateNoChange
                                                       targetIDs:@[ @1 ]
                                                     resumeToken:_resumeToken1];

  FSTWatchChangeAggregator *aggregator =
      [self aggregatorWithTargets:@[ @1 ] outstanding:_noPendingResponses changes:@[ change ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.documentUpdates.count, 0);
  XCTAssertEqual(event.targetChanges.count, 1);
  XCTAssertEqualObjects(event.targetChanges[@1].mapping, [[FSTUpdateMapping alloc] init]);
  XCTAssertEqual(event.targetChanges[@1].currentStatusUpdate, FSTCurrentStatusUpdateNone);
  XCTAssertEqualObjects(event.targetChanges[@1].resumeToken, _resumeToken1);
}

- (void)testExistenceFiltersWillReplacePreviousExistenceFilters {
  FSTExistenceFilter *filter1 = [FSTExistenceFilter filterWithCount:1];
  FSTExistenceFilter *filter2 = [FSTExistenceFilter filterWithCount:2];
  FSTWatchChange *change1 = [FSTExistenceFilterWatchChange changeWithFilter:filter1 targetID:1];
  FSTWatchChange *change2 = [FSTExistenceFilterWatchChange changeWithFilter:filter1 targetID:2];
  // replace filter1 for target 2
  FSTWatchChange *change3 = [FSTExistenceFilterWatchChange changeWithFilter:filter2 targetID:2];

  FSTWatchChangeAggregator *aggregator =
      [self aggregatorWithTargets:@[ @1, @2 ]
                      outstanding:_noPendingResponses
                          changes:@[ change1, change2, change3 ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.documentUpdates.count, 0);
  XCTAssertEqual(event.targetChanges.count, 0);
  XCTAssertEqual(aggregator.existenceFilters.count, 2);
  XCTAssertEqual(aggregator.existenceFilters[@1], filter1);
  XCTAssertEqual(aggregator.existenceFilters[@2], filter2);
}

- (void)testExistenceFilterMismatchResetsTarget {
  FSTDocument *doc1 = FSTTestDoc(@"docs/1", 1, @{ @"value" : @1 }, NO);
  FSTDocument *doc2 = FSTTestDoc(@"docs/2", 2, @{ @"value" : @2 }, NO);

  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc1.key
                                                                            document:doc1];

  FSTWatchChange *change2 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc2.key
                                                                            document:doc2];

  FSTWatchChange *change3 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                                        targetIDs:@[ @1 ]
                                                      resumeToken:_resumeToken1];

  FSTWatchChangeAggregator *aggregator =
      [self aggregatorWithTargets:@[ @1 ]
                      outstanding:_noPendingResponses
                          changes:@[ change1, change2, change3 ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.documentUpdates.count, 2);
  XCTAssertEqualObjects(event.documentUpdates[doc1.key], doc1);
  XCTAssertEqualObjects(event.documentUpdates[doc2.key], doc2);

  XCTAssertEqual(event.targetChanges.count, 1);

  FSTUpdateMapping *mapping1 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[ doc1, doc2 ] removedDocuments:@[]];
  XCTAssertEqualObjects(event.targetChanges[@1].mapping, mapping1);
  XCTAssertEqualObjects(event.targetChanges[@1].snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.targetChanges[@1].currentStatusUpdate, FSTCurrentStatusUpdateMarkCurrent);
  XCTAssertEqualObjects(event.targetChanges[@1].resumeToken, _resumeToken1);

  [event handleExistenceFilterMismatchForTargetID:@1];

  // Mapping is reset
  XCTAssertEqualObjects(event.targetChanges[@1].mapping, [[FSTResetMapping alloc] init]);
  // Reset the resume snapshot
  XCTAssertEqualObjects(event.targetChanges[@1].snapshotVersion, FSTTestVersion(0));
  // Target needs to be set to not current
  XCTAssertEqual(event.targetChanges[@1].currentStatusUpdate, FSTCurrentStatusUpdateMarkNotCurrent);
  XCTAssertEqual(event.targetChanges[@1].resumeToken.length, 0);
}

- (void)testDocumentUpdate {
  FSTDocument *doc1 = FSTTestDoc(@"docs/1", 1, @{ @"value" : @1 }, NO);
  FSTDeletedDocument *deletedDoc1 =
      [FSTDeletedDocument documentWithKey:doc1.key version:FSTTestVersion(3)];
  FSTDocument *doc2 = FSTTestDoc(@"docs/2", 2, @{ @"value" : @2 }, NO);
  FSTDocument *doc3 = FSTTestDoc(@"docs/3", 3, @{ @"value" : @3 }, NO);

  FSTWatchChange *change1 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc1.key
                                                                            document:doc1];

  FSTWatchChange *change2 = [[FSTDocumentWatchChange alloc] initWithUpdatedTargetIDs:@[ @1 ]
                                                                    removedTargetIDs:@[]
                                                                         documentKey:doc2.key
                                                                            document:doc2];

  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargets:@[ @1 ]
                                                         outstanding:_noPendingResponses
                                                             changes:@[ change1, change2 ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.documentUpdates.count, 2);
  XCTAssertEqualObjects(event.documentUpdates[doc1.key], doc1);
  XCTAssertEqualObjects(event.documentUpdates[doc2.key], doc2);

  // Update doc1
  [event addDocumentUpdate:deletedDoc1];
  [event addDocumentUpdate:doc3];

  XCTAssertEqualObjects(event.snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.documentUpdates.count, 3);
  // doc1 is replaced
  XCTAssertEqualObjects(event.documentUpdates[doc1.key], deletedDoc1);
  // doc2 is untouched
  XCTAssertEqualObjects(event.documentUpdates[doc2.key], doc2);
  // doc3 is new
  XCTAssertEqualObjects(event.documentUpdates[doc3.key], doc3);

  // Target is unchanged
  XCTAssertEqual(event.targetChanges.count, 1);

  FSTUpdateMapping *mapping1 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[ doc1, doc2 ] removedDocuments:@[]];
  XCTAssertEqualObjects(event.targetChanges[@1].mapping, mapping1);
}

- (void)testResumeTokensHandledPerTarget {
  NSData *resumeToken2 = [@"resume2" dataUsingEncoding:NSUTF8StringEncoding];
  FSTWatchChange *change1 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                                        targetIDs:@[ @1 ]
                                                      resumeToken:_resumeToken1];
  FSTWatchChange *change2 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                                        targetIDs:@[ @2 ]
                                                      resumeToken:resumeToken2];
  FSTWatchChangeAggregator *aggregator = [self aggregatorWithTargets:@[ @1, @2 ]
                                                         outstanding:_noPendingResponses
                                                             changes:@[ change1, change2 ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqual(event.targetChanges.count, 2);

  FSTUpdateMapping *mapping1 =
      [FSTUpdateMapping mappingWithAddedDocuments:@[] removedDocuments:@[]];
  XCTAssertEqualObjects(event.targetChanges[@1].mapping, mapping1);
  XCTAssertEqualObjects(event.targetChanges[@1].snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.targetChanges[@1].currentStatusUpdate, FSTCurrentStatusUpdateMarkCurrent);
  XCTAssertEqualObjects(event.targetChanges[@1].resumeToken, _resumeToken1);

  XCTAssertEqualObjects(event.targetChanges[@2].mapping, mapping1);
  XCTAssertEqualObjects(event.targetChanges[@2].snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.targetChanges[@2].currentStatusUpdate, FSTCurrentStatusUpdateMarkCurrent);
  XCTAssertEqualObjects(event.targetChanges[@2].resumeToken, resumeToken2);
}

- (void)testLastResumeTokenWins {
  NSData *resumeToken2 = [@"resume2" dataUsingEncoding:NSUTF8StringEncoding];
  NSData *resumeToken3 = [@"resume3" dataUsingEncoding:NSUTF8StringEncoding];

  FSTWatchChange *change1 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                                        targetIDs:@[ @1 ]
                                                      resumeToken:_resumeToken1];
  FSTWatchChange *change2 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateReset
                                                        targetIDs:@[ @1 ]
                                                      resumeToken:resumeToken2];
  FSTWatchChange *change3 = [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateReset
                                                        targetIDs:@[ @2 ]
                                                      resumeToken:resumeToken3];
  FSTWatchChangeAggregator *aggregator =
      [self aggregatorWithTargets:@[ @1, @2 ]
                      outstanding:_noPendingResponses
                          changes:@[ change1, change2, change3 ]];

  FSTRemoteEvent *event = [aggregator remoteEvent];
  XCTAssertEqual(event.targetChanges.count, 2);

  FSTResetMapping *mapping1 = [FSTResetMapping mappingWithDocuments:@[]];
  XCTAssertEqualObjects(event.targetChanges[@1].mapping, mapping1);
  XCTAssertEqualObjects(event.targetChanges[@1].snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.targetChanges[@1].currentStatusUpdate, FSTCurrentStatusUpdateMarkCurrent);
  XCTAssertEqualObjects(event.targetChanges[@1].resumeToken, resumeToken2);

  XCTAssertEqualObjects(event.targetChanges[@2].mapping, mapping1);
  XCTAssertEqualObjects(event.targetChanges[@2].snapshotVersion, FSTTestVersion(3));
  XCTAssertEqual(event.targetChanges[@2].currentStatusUpdate, FSTCurrentStatusUpdateNone);
  XCTAssertEqualObjects(event.targetChanges[@2].resumeToken, resumeToken3);
}

@end

NS_ASSUME_NONNULL_END
