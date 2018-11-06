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

#import "Firestore/Example/Tests/Local/FSTMutationQueueTests.h"

#import <FirebaseFirestore/FIRTimestamp.h>

#include <set>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::auth::User;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::testutil::Key;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTMutationQueueTests

- (void)tearDown {
  [self.persistence shutdown];
  [super tearDown];
}

/**
 * Xcode will run tests from any class that extends XCTestCase, but this doesn't work for
 * FSTMutationQueueTests since it is incomplete without the implementations supplied by its
 * subclasses.
 */
- (BOOL)isTestBaseClass {
  return [self class] == [FSTMutationQueueTests class];
}

- (void)testCountBatches {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testCountBatches", [&]() {
    XCTAssertEqual(0, [self batchCount]);
    XCTAssertTrue([self.mutationQueue isEmpty]);

    FSTMutationBatch *batch1 = [self addMutationBatch];
    XCTAssertEqual(1, [self batchCount]);
    XCTAssertFalse([self.mutationQueue isEmpty]);

    FSTMutationBatch *batch2 = [self addMutationBatch];
    XCTAssertEqual(2, [self batchCount]);

    [self.mutationQueue removeMutationBatch:batch1];
    XCTAssertEqual(1, [self batchCount]);

    [self.mutationQueue removeMutationBatch:batch2];
    XCTAssertEqual(0, [self batchCount]);
    XCTAssertTrue([self.mutationQueue isEmpty]);
  });
}

- (void)testAcknowledgeBatchID {
  if ([self isTestBaseClass]) return;

  // Initial state of an empty queue
  XCTAssertEqual([self.mutationQueue highestAcknowledgedBatchID], kFSTBatchIDUnknown);

  // Adding mutation batches should not change the highest acked batchID.
  self.persistence.run("testAcknowledgeBatchID", [&]() {
    FSTMutationBatch *batch1 = [self addMutationBatch];
    FSTMutationBatch *batch2 = [self addMutationBatch];
    FSTMutationBatch *batch3 = [self addMutationBatch];
    XCTAssertGreaterThan(batch1.batchID, kFSTBatchIDUnknown);
    XCTAssertGreaterThan(batch2.batchID, batch1.batchID);
    XCTAssertGreaterThan(batch3.batchID, batch2.batchID);

    XCTAssertEqual([self.mutationQueue highestAcknowledgedBatchID], kFSTBatchIDUnknown);

    [self.mutationQueue acknowledgeBatch:batch1 streamToken:nil];
    [self.mutationQueue removeMutationBatch:batch1];

    [self.mutationQueue acknowledgeBatch:batch2 streamToken:nil];
    XCTAssertEqual([self.mutationQueue highestAcknowledgedBatchID], batch2.batchID);

    [self.mutationQueue removeMutationBatch:batch2];
    XCTAssertEqual([self.mutationQueue highestAcknowledgedBatchID], batch2.batchID);

    // Batch 3 never acknowledged.
    [self.mutationQueue removeMutationBatch:batch3];
    XCTAssertEqual([self.mutationQueue highestAcknowledgedBatchID], batch2.batchID);
  });
}

- (void)testAcknowledgeThenRemove {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testAcknowledgeThenRemove", [&]() {
    FSTMutationBatch *batch1 = [self addMutationBatch];

    [self.mutationQueue acknowledgeBatch:batch1 streamToken:nil];
    [self.mutationQueue removeMutationBatch:batch1];

    XCTAssertEqual([self batchCount], 0);
    XCTAssertEqual([self.mutationQueue highestAcknowledgedBatchID], batch1.batchID);
  });
}

- (void)testHighestAcknowledgedBatchIDNeverExceedsNextBatchID {
  if ([self isTestBaseClass]) return;

  FSTMutationBatch *batch1 =
      self.persistence.run("testHighestAcknowledgedBatchIDNeverExceedsNextBatchID batch1",
                           [&]() -> FSTMutationBatch * { return [self addMutationBatch]; });
  FSTMutationBatch *batch2 =
      self.persistence.run("testHighestAcknowledgedBatchIDNeverExceedsNextBatchID batch2",
                           [&]() -> FSTMutationBatch * { return [self addMutationBatch]; });

  self.persistence.run("testHighestAcknowledgedBatchIDNeverExceedsNextBatchID", [&]() {
    [self.mutationQueue acknowledgeBatch:batch1 streamToken:nil];
    [self.mutationQueue removeMutationBatch:batch1];
    [self.mutationQueue acknowledgeBatch:batch2 streamToken:nil];
    XCTAssertEqual([self.mutationQueue highestAcknowledgedBatchID], batch2.batchID);

    [self.mutationQueue removeMutationBatch:batch2];
    XCTAssertEqual([self.mutationQueue highestAcknowledgedBatchID], batch2.batchID);
  });

  // Restart the queue so that nextBatchID will be reset.
  FSTMutationBatch *batch = self.persistence.run(
      "testHighestAcknowledgedBatchIDNeverExceedsNextBatchID restart", [&]() -> FSTMutationBatch * {
        self.mutationQueue = [self.persistence mutationQueueForUser:User("user")];

        [self.mutationQueue start];

        // Verify that on restart with an empty queue, nextBatchID falls to a lower value.
        XCTAssertLessThan(self.mutationQueue.nextBatchID, batch2.batchID);

        // As a result highestAcknowledgedBatchID must also reset lower.
        XCTAssertEqual([self.mutationQueue highestAcknowledgedBatchID], kFSTBatchIDUnknown);

        // The mutation queue will reset the next batchID after all mutations are removed so adding
        // another mutation will cause a collision.
        FSTMutationBatch *newBatch = [self addMutationBatch];
        XCTAssertEqual(newBatch.batchID, batch1.batchID);
        return newBatch;
      });
  self.persistence.run("testHighestAcknowledgedBatchIDNeverExceedsNextBatchID restart2", [&]() {
    // Restart the queue with one unacknowledged batch in it.
    [self.mutationQueue start];

    XCTAssertEqual([self.mutationQueue nextBatchID], batch.batchID + 1);

    // highestAcknowledgedBatchID must still be kFSTBatchIDUnknown.
    XCTAssertEqual([self.mutationQueue highestAcknowledgedBatchID], kFSTBatchIDUnknown);
  });
}

- (void)testLookupMutationBatch {
  if ([self isTestBaseClass]) return;

  // Searching on an empty queue should not find a non-existent batch
  self.persistence.run("testLookupMutationBatch", [&]() {
    FSTMutationBatch *notFound = [self.mutationQueue lookupMutationBatch:42];
    XCTAssertNil(notFound);

    NSMutableArray<FSTMutationBatch *> *batches = [self createBatches:10];
    NSArray<FSTMutationBatch *> *removed = [self removeFirstBatches:3 inBatches:batches];

    // After removing, a batch should not be found
    for (NSUInteger i = 0; i < removed.count; i++) {
      notFound = [self.mutationQueue lookupMutationBatch:removed[i].batchID];
      XCTAssertNil(notFound);
    }

    // Remaining entries should still be found
    for (FSTMutationBatch *batch in batches) {
      FSTMutationBatch *found = [self.mutationQueue lookupMutationBatch:batch.batchID];
      XCTAssertEqual(found.batchID, batch.batchID);
    }

    // Even on a nonempty queue searching should not find a non-existent batch
    notFound = [self.mutationQueue lookupMutationBatch:42];
    XCTAssertNil(notFound);
  });
}

- (void)testNextMutationBatchAfterBatchID {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testNextMutationBatchAfterBatchID", [&]() {
    NSMutableArray<FSTMutationBatch *> *batches = [self createBatches:10];
    NSArray<FSTMutationBatch *> *removed = [self removeFirstBatches:3 inBatches:batches];

    for (NSUInteger i = 0; i < batches.count - 1; i++) {
      FSTMutationBatch *current = batches[i];
      FSTMutationBatch *next = batches[i + 1];
      FSTMutationBatch *found = [self.mutationQueue nextMutationBatchAfterBatchID:current.batchID];
      XCTAssertEqual(found.batchID, next.batchID);
    }

    for (NSUInteger i = 0; i < removed.count; i++) {
      FSTMutationBatch *current = removed[i];
      FSTMutationBatch *next = batches[0];
      FSTMutationBatch *found = [self.mutationQueue nextMutationBatchAfterBatchID:current.batchID];
      XCTAssertEqual(found.batchID, next.batchID);
    }

    FSTMutationBatch *first = batches[0];
    FSTMutationBatch *found = [self.mutationQueue nextMutationBatchAfterBatchID:first.batchID - 42];
    XCTAssertEqual(found.batchID, first.batchID);

    FSTMutationBatch *last = batches[batches.count - 1];
    FSTMutationBatch *notFound = [self.mutationQueue nextMutationBatchAfterBatchID:last.batchID];
    XCTAssertNil(notFound);
  });
}

- (void)testNextMutationBatchAfterBatchIDSkipsAcknowledgedBatches {
  if ([self isTestBaseClass]) return;

  NSMutableArray<FSTMutationBatch *> *batches = self.persistence.run(
      "testNextMutationBatchAfterBatchIDSkipsAcknowledgedBatches newBatches",
      [&]() -> NSMutableArray<FSTMutationBatch *> * {
        NSMutableArray<FSTMutationBatch *> *newBatches = [self createBatches:3];
        XCTAssertEqualObjects([self.mutationQueue nextMutationBatchAfterBatchID:kFSTBatchIDUnknown],
                              newBatches[0]);
        return newBatches;
      });
  self.persistence.run("testNextMutationBatchAfterBatchIDSkipsAcknowledgedBatches", [&]() {
    [self.mutationQueue acknowledgeBatch:batches[0] streamToken:nil];
    XCTAssertEqualObjects([self.mutationQueue nextMutationBatchAfterBatchID:kFSTBatchIDUnknown],
                          batches[1]);
    XCTAssertEqualObjects([self.mutationQueue nextMutationBatchAfterBatchID:batches[0].batchID],
                          batches[1]);
    XCTAssertEqualObjects([self.mutationQueue nextMutationBatchAfterBatchID:batches[1].batchID],
                          batches[2]);
  });
}

- (void)testAllMutationBatchesAffectingDocumentKey {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testAllMutationBatchesAffectingDocumentKey", [&]() {
    NSArray<FSTMutation *> *mutations = @[
      FSTTestSetMutation(@"foi/bar",
                         @{@"a" : @1}),
      FSTTestSetMutation(@"foo/bar",
                         @{@"a" : @1}),
      FSTTestPatchMutation("foo/bar",
                           @{@"b" : @1}, {}),
      FSTTestSetMutation(@"foo/bar/suffix/key",
                         @{@"a" : @1}),
      FSTTestSetMutation(@"foo/baz",
                         @{@"a" : @1}),
      FSTTestSetMutation(@"food/bar",
                         @{@"a" : @1})
    ];

    // Store all the mutations.
    NSMutableArray<FSTMutationBatch *> *batches = [NSMutableArray array];
    for (FSTMutation *mutation in mutations) {
      FSTMutationBatch *batch =
          [self.mutationQueue addMutationBatchWithWriteTime:[FIRTimestamp timestamp]
                                                  mutations:@[ mutation ]];
      [batches addObject:batch];
    }

    NSArray<FSTMutationBatch *> *expected = @[ batches[1], batches[2] ];
    NSArray<FSTMutationBatch *> *matches =
        [self.mutationQueue allMutationBatchesAffectingDocumentKey:testutil::Key("foo/bar")];

    XCTAssertEqualObjects(matches, expected);
  });
}

- (void)testAllMutationBatchesAffectingDocumentKeys {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testAllMutationBatchesAffectingDocumentKey", [&]() {
    NSArray<FSTMutation *> *mutations = @[
      FSTTestSetMutation(@"fob/bar",
                         @{@"a" : @1}),
      FSTTestSetMutation(@"foo/bar",
                         @{@"a" : @1}),
      FSTTestPatchMutation("foo/bar",
                           @{@"b" : @1}, {}),
      FSTTestSetMutation(@"foo/bar/suffix/key",
                         @{@"a" : @1}),
      FSTTestSetMutation(@"foo/baz",
                         @{@"a" : @1}),
      FSTTestSetMutation(@"food/bar",
                         @{@"a" : @1})
    ];

    // Store all the mutations.
    NSMutableArray<FSTMutationBatch *> *batches = [NSMutableArray array];
    for (FSTMutation *mutation in mutations) {
      FSTMutationBatch *batch =
          [self.mutationQueue addMutationBatchWithWriteTime:[FIRTimestamp timestamp]
                                                  mutations:@[ mutation ]];
      [batches addObject:batch];
    }

    DocumentKeySet keys{
        Key("foo/bar"),
        Key("foo/baz"),
    };

    NSArray<FSTMutationBatch *> *expected = @[ batches[1], batches[2], batches[4] ];
    NSArray<FSTMutationBatch *> *matches =
        [self.mutationQueue allMutationBatchesAffectingDocumentKeys:keys];

    XCTAssertEqualObjects(matches, expected);
  });
}

- (void)testAllMutationBatchesAffectingDocumentKeys_handlesOverlap {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testAllMutationBatchesAffectingDocumentKeys_handlesOverlap", [&]() {
    NSArray<FSTMutation *> *group1 = @[
      FSTTestSetMutation(@"foo/bar",
                         @{@"a" : @1}),
      FSTTestSetMutation(@"foo/baz",
                         @{@"a" : @1}),
    ];
    FSTMutationBatch *batch1 =
        [self.mutationQueue addMutationBatchWithWriteTime:[FIRTimestamp timestamp]
                                                mutations:group1];

    NSArray<FSTMutation *> *group2 = @[ FSTTestSetMutation(@"food/bar", @{@"a" : @1}) ];
    [self.mutationQueue addMutationBatchWithWriteTime:[FIRTimestamp timestamp] mutations:group2];

    NSArray<FSTMutation *> *group3 = @[
      FSTTestSetMutation(@"foo/bar",
                         @{@"b" : @1}),
    ];
    FSTMutationBatch *batch3 =
        [self.mutationQueue addMutationBatchWithWriteTime:[FIRTimestamp timestamp]
                                                mutations:group3];

    DocumentKeySet keys{
        Key("foo/bar"),
        Key("foo/baz"),
    };

    NSArray<FSTMutationBatch *> *expected = @[ batch1, batch3 ];
    NSArray<FSTMutationBatch *> *matches =
        [self.mutationQueue allMutationBatchesAffectingDocumentKeys:keys];

    XCTAssertEqualObjects(matches, expected);
  });
}

- (void)testAllMutationBatchesAffectingQuery {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testAllMutationBatchesAffectingQuery", [&]() {
    NSArray<FSTMutation *> *mutations = @[
      FSTTestSetMutation(@"fob/bar",
                         @{@"a" : @1}),
      FSTTestSetMutation(@"foo/bar",
                         @{@"a" : @1}),
      FSTTestPatchMutation("foo/bar",
                           @{@"b" : @1}, {}),
      FSTTestSetMutation(@"foo/bar/suffix/key",
                         @{@"a" : @1}),
      FSTTestSetMutation(@"foo/baz",
                         @{@"a" : @1}),
      FSTTestSetMutation(@"food/bar",
                         @{@"a" : @1})
    ];

    // Store all the mutations.
    NSMutableArray<FSTMutationBatch *> *batches = [NSMutableArray array];
    for (FSTMutation *mutation in mutations) {
      FSTMutationBatch *batch =
          [self.mutationQueue addMutationBatchWithWriteTime:[FIRTimestamp timestamp]
                                                  mutations:@[ mutation ]];
      [batches addObject:batch];
    }

    NSArray<FSTMutationBatch *> *expected = @[ batches[1], batches[2], batches[4] ];
    FSTQuery *query = FSTTestQuery("foo");
    NSArray<FSTMutationBatch *> *matches =
        [self.mutationQueue allMutationBatchesAffectingQuery:query];

    XCTAssertEqualObjects(matches, expected);
  });
}

- (void)testRemoveMutationBatches {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testRemoveMutationBatches", [&]() {
    NSMutableArray<FSTMutationBatch *> *batches = [self createBatches:10];

    [self.mutationQueue removeMutationBatch:batches[0]];
    [batches removeObjectAtIndex:0];

    XCTAssertEqual([self batchCount], 9);

    NSArray<FSTMutationBatch *> *found;

    found = [self.mutationQueue allMutationBatches];
    XCTAssertEqualObjects(found, batches);
    XCTAssertEqual(found.count, 9);

    [self.mutationQueue removeMutationBatch:batches[0]];
    [self.mutationQueue removeMutationBatch:batches[1]];
    [self.mutationQueue removeMutationBatch:batches[2]];
    [batches removeObjectsInRange:NSMakeRange(0, 3)];
    XCTAssertEqual([self batchCount], 6);

    found = [self.mutationQueue allMutationBatches];
    XCTAssertEqualObjects(found, batches);
    XCTAssertEqual(found.count, 6);

    [self.mutationQueue removeMutationBatch:batches[0]];
    [batches removeObjectAtIndex:0];
    XCTAssertEqual([self batchCount], 5);

    found = [self.mutationQueue allMutationBatches];
    XCTAssertEqualObjects(found, batches);
    XCTAssertEqual(found.count, 5);

    [self.mutationQueue removeMutationBatch:batches[0]];
    [batches removeObjectAtIndex:0];
    XCTAssertEqual([self batchCount], 4);

    [self.mutationQueue removeMutationBatch:batches[0]];
    [batches removeObjectAtIndex:0];
    XCTAssertEqual([self batchCount], 3);

    found = [self.mutationQueue allMutationBatches];
    XCTAssertEqualObjects(found, batches);
    XCTAssertEqual(found.count, 3);
    XCTAssertFalse([self.mutationQueue isEmpty]);

    for (FSTMutationBatch *batch in batches) {
      [self.mutationQueue removeMutationBatch:batch];
    }
    found = [self.mutationQueue allMutationBatches];
    XCTAssertEqualObjects(found, @[]);
    XCTAssertEqual(found.count, 0);
    XCTAssertTrue([self.mutationQueue isEmpty]);
  });
}

- (void)testStreamToken {
  if ([self isTestBaseClass]) return;

  NSData *streamToken1 = [@"token1" dataUsingEncoding:NSUTF8StringEncoding];
  NSData *streamToken2 = [@"token2" dataUsingEncoding:NSUTF8StringEncoding];

  self.persistence.run("testStreamToken", [&]() {
    [self.mutationQueue setLastStreamToken:streamToken1];

    FSTMutationBatch *batch1 = [self addMutationBatch];
    [self addMutationBatch];

    XCTAssertEqualObjects([self.mutationQueue lastStreamToken], streamToken1);

    [self.mutationQueue acknowledgeBatch:batch1 streamToken:streamToken2];
    XCTAssertEqual(self.mutationQueue.highestAcknowledgedBatchID, batch1.batchID);
    XCTAssertEqualObjects([self.mutationQueue lastStreamToken], streamToken2);
  });
}

#pragma mark - Helpers

/** Creates a new FSTMutationBatch with the next batch ID and a set of dummy mutations. */
- (FSTMutationBatch *)addMutationBatch {
  return [self addMutationBatchWithKey:@"foo/bar"];
}

/**
 * Creates a new FSTMutationBatch with the given key, the next batch ID and a set of dummy
 * mutations.
 */
- (FSTMutationBatch *)addMutationBatchWithKey:(NSString *)key {
  FSTSetMutation *mutation = FSTTestSetMutation(key, @{@"a" : @1});

  FSTMutationBatch *batch =
      [self.mutationQueue addMutationBatchWithWriteTime:[FIRTimestamp timestamp]
                                              mutations:@[ mutation ]];
  return batch;
}

/**
 * Creates an array of batches containing @a number dummy FSTMutationBatches. Each has a different
 * batchID.
 */
- (NSMutableArray<FSTMutationBatch *> *)createBatches:(int)number {
  NSMutableArray<FSTMutationBatch *> *batches = [NSMutableArray array];

  for (int i = 0; i < number; i++) {
    FSTMutationBatch *batch = [self addMutationBatch];
    [batches addObject:batch];
  }

  return batches;
}

/** Returns the number of mutation batches in the mutation queue. */
- (NSUInteger)batchCount {
  return [self.mutationQueue allMutationBatches].count;
}

/**
 * Removes the first n entries from the the given batches and returns them.
 *
 * @param n The number of batches to remove.
 * @param batches The array to mutate, removing entries from it.
 * @return A new array containing all the entries that were removed from @a batches.
 */
- (NSArray<FSTMutationBatch *> *)removeFirstBatches:(NSUInteger)n
                                          inBatches:(NSMutableArray<FSTMutationBatch *> *)batches {
  NSArray<FSTMutationBatch *> *removed = [batches subarrayWithRange:NSMakeRange(0, n)];
  [batches removeObjectsInRange:NSMakeRange(0, n)];

  [removed enumerateObjectsUsingBlock:^(FSTMutationBatch *batch, NSUInteger idx, BOOL *stop) {
    [self.mutationQueue removeMutationBatch:batch];
  }];

  return removed;
}

@end

NS_ASSUME_NONNULL_END
