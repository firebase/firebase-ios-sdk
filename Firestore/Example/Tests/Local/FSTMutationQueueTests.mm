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
#include <utility>
#include <vector>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/mutation_batch.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::Timestamp;
using firebase::firestore::auth::User;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::kBatchIdUnknown;
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
    XCTAssertTrue(self.mutationQueue->IsEmpty());

    FSTMutationBatch *batch1 = [self addMutationBatch];
    XCTAssertEqual(1, [self batchCount]);
    XCTAssertFalse(self.mutationQueue->IsEmpty());

    FSTMutationBatch *batch2 = [self addMutationBatch];
    XCTAssertEqual(2, [self batchCount]);

    self.mutationQueue->RemoveMutationBatch(batch1);
    XCTAssertEqual(1, [self batchCount]);

    self.mutationQueue->RemoveMutationBatch(batch2);
    XCTAssertEqual(0, [self batchCount]);
    XCTAssertTrue(self.mutationQueue->IsEmpty());
  });
}

- (void)testAcknowledgeBatchID {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testAcknowledgeBatchID", [&]() {
    XCTAssertEqual([self batchCount], 0);

    FSTMutationBatch *batch1 = [self addMutationBatch];
    FSTMutationBatch *batch2 = [self addMutationBatch];
    FSTMutationBatch *batch3 = [self addMutationBatch];
    XCTAssertGreaterThan(batch1.batchID, kBatchIdUnknown);
    XCTAssertGreaterThan(batch2.batchID, batch1.batchID);
    XCTAssertGreaterThan(batch3.batchID, batch2.batchID);

    XCTAssertEqual([self batchCount], 3);

    self.mutationQueue->AcknowledgeBatch(batch1, nil);
    self.mutationQueue->RemoveMutationBatch(batch1);
    XCTAssertEqual([self batchCount], 2);

    self.mutationQueue->AcknowledgeBatch(batch2, nil);
    XCTAssertEqual([self batchCount], 2);

    self.mutationQueue->RemoveMutationBatch(batch2);
    XCTAssertEqual([self batchCount], 1);

    self.mutationQueue->RemoveMutationBatch(batch3);
    XCTAssertEqual([self batchCount], 0);
  });
}

- (void)testAcknowledgeThenRemove {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testAcknowledgeThenRemove", [&]() {
    FSTMutationBatch *batch1 = [self addMutationBatch];

    self.mutationQueue->AcknowledgeBatch(batch1, nil);
    self.mutationQueue->RemoveMutationBatch(batch1);

    XCTAssertEqual([self batchCount], 0);
  });
}

- (void)testLookupMutationBatch {
  if ([self isTestBaseClass]) return;

  // Searching on an empty queue should not find a non-existent batch
  self.persistence.run("testLookupMutationBatch", [&]() {
    FSTMutationBatch *notFound = self.mutationQueue->LookupMutationBatch(42);
    XCTAssertNil(notFound);

    std::vector<FSTMutationBatch *> batches = [self createBatches:10];
    std::vector<FSTMutationBatch *> removed = [self removeFirstBatches:3 inBatches:&batches];

    // After removing, a batch should not be found
    for (size_t i = 0; i < removed.size(); i++) {
      notFound = self.mutationQueue->LookupMutationBatch(removed[i].batchID);
      XCTAssertNil(notFound);
    }

    // Remaining entries should still be found
    for (FSTMutationBatch *batch : batches) {
      FSTMutationBatch *found = self.mutationQueue->LookupMutationBatch(batch.batchID);
      XCTAssertEqual(found.batchID, batch.batchID);
    }

    // Even on a nonempty queue searching should not find a non-existent batch
    notFound = self.mutationQueue->LookupMutationBatch(42);
    XCTAssertNil(notFound);
  });
}

- (void)testNextMutationBatchAfterBatchID {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testNextMutationBatchAfterBatchID", [&]() {
    std::vector<FSTMutationBatch *> batches = [self createBatches:10];
    std::vector<FSTMutationBatch *> removed = [self removeFirstBatches:3 inBatches:&batches];

    for (size_t i = 0; i < batches.size() - 1; i++) {
      FSTMutationBatch *current = batches[i];
      FSTMutationBatch *next = batches[i + 1];
      FSTMutationBatch *found = self.mutationQueue->NextMutationBatchAfterBatchId(current.batchID);
      XCTAssertEqual(found.batchID, next.batchID);
    }

    for (size_t i = 0; i < removed.size(); i++) {
      FSTMutationBatch *current = removed[i];
      FSTMutationBatch *next = batches[0];
      FSTMutationBatch *found = self.mutationQueue->NextMutationBatchAfterBatchId(current.batchID);
      XCTAssertEqual(found.batchID, next.batchID);
    }

    FSTMutationBatch *first = batches[0];
    FSTMutationBatch *found = self.mutationQueue->NextMutationBatchAfterBatchId(first.batchID - 42);
    XCTAssertEqual(found.batchID, first.batchID);

    FSTMutationBatch *last = batches[batches.size() - 1];
    FSTMutationBatch *notFound = self.mutationQueue->NextMutationBatchAfterBatchId(last.batchID);
    XCTAssertNil(notFound);
  });
}

- (void)testAllMutationBatchesAffectingDocumentKey {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testAllMutationBatchesAffectingDocumentKey", [&]() {
    NSArray<FSTMutation *> *mutations = @[
      FSTTestSetMutation(@"foi/bar", @{@"a" : @1}), FSTTestSetMutation(@"foo/bar", @{@"a" : @1}),
      FSTTestPatchMutation("foo/bar", @{@"b" : @1}, {}),
      FSTTestSetMutation(@"foo/bar/suffix/key", @{@"a" : @1}),
      FSTTestSetMutation(@"foo/baz", @{@"a" : @1}), FSTTestSetMutation(@"food/bar", @{@"a" : @1})
    ];

    // Store all the mutations.
    NSMutableArray<FSTMutationBatch *> *batches = [NSMutableArray array];
    for (FSTMutation *mutation in mutations) {
      FSTMutationBatch *batch =
          self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, {mutation});
      [batches addObject:batch];
    }

    std::vector<FSTMutationBatch *> expected{batches[1], batches[2]};
    std::vector<FSTMutationBatch *> matches =
        self.mutationQueue->AllMutationBatchesAffectingDocumentKey(testutil::Key("foo/bar"));

    FSTAssertEqualVectors(matches, expected);
  });
}

- (void)testAllMutationBatchesAffectingDocumentKeys {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testAllMutationBatchesAffectingDocumentKey", [&]() {
    NSArray<FSTMutation *> *mutations = @[
      FSTTestSetMutation(@"fob/bar", @{@"a" : @1}), FSTTestSetMutation(@"foo/bar", @{@"a" : @1}),
      FSTTestPatchMutation("foo/bar", @{@"b" : @1}, {}),
      FSTTestSetMutation(@"foo/bar/suffix/key", @{@"a" : @1}),
      FSTTestSetMutation(@"foo/baz", @{@"a" : @1}), FSTTestSetMutation(@"food/bar", @{@"a" : @1})
    ];

    // Store all the mutations.
    NSMutableArray<FSTMutationBatch *> *batches = [NSMutableArray array];
    for (FSTMutation *mutation in mutations) {
      FSTMutationBatch *batch =
          self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, {mutation});
      [batches addObject:batch];
    }

    DocumentKeySet keys{
        Key("foo/bar"),
        Key("foo/baz"),
    };

    std::vector<FSTMutationBatch *> expected{batches[1], batches[2], batches[4]};
    std::vector<FSTMutationBatch *> matches =
        self.mutationQueue->AllMutationBatchesAffectingDocumentKeys(keys);

    FSTAssertEqualVectors(matches, expected);
  });
}

- (void)testAllMutationBatchesAffectingDocumentKeys_handlesOverlap {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testAllMutationBatchesAffectingDocumentKeys_handlesOverlap", [&]() {
    std::vector<FSTMutation *> group1 = {
        FSTTestSetMutation(@"foo/bar", @{@"a" : @1}),
        FSTTestSetMutation(@"foo/baz", @{@"a" : @1}),
    };
    FSTMutationBatch *batch1 =
        self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, std::move(group1));

    std::vector<FSTMutation *> group2 = {FSTTestSetMutation(@"food/bar", @{@"a" : @1})};
    self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, std::move(group2));

    std::vector<FSTMutation *> group3 = {
        FSTTestSetMutation(@"foo/bar", @{@"b" : @1}),
    };
    FSTMutationBatch *batch3 =
        self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, std::move(group3));

    DocumentKeySet keys{
        Key("foo/bar"),
        Key("foo/baz"),
    };

    std::vector<FSTMutationBatch *> expected{batch1, batch3};
    std::vector<FSTMutationBatch *> matches =
        self.mutationQueue->AllMutationBatchesAffectingDocumentKeys(keys);

    FSTAssertEqualVectors(matches, expected);
  });
}

- (void)testAllMutationBatchesAffectingQuery {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testAllMutationBatchesAffectingQuery", [&]() {
    NSArray<FSTMutation *> *mutations = @[
      FSTTestSetMutation(@"fob/bar", @{@"a" : @1}), FSTTestSetMutation(@"foo/bar", @{@"a" : @1}),
      FSTTestPatchMutation("foo/bar", @{@"b" : @1}, {}),
      FSTTestSetMutation(@"foo/bar/suffix/key", @{@"a" : @1}),
      FSTTestSetMutation(@"foo/baz", @{@"a" : @1}), FSTTestSetMutation(@"food/bar", @{@"a" : @1})
    ];

    // Store all the mutations.
    NSMutableArray<FSTMutationBatch *> *batches = [NSMutableArray array];
    for (FSTMutation *mutation in mutations) {
      FSTMutationBatch *batch =
          self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, {mutation});
      [batches addObject:batch];
    }

    std::vector<FSTMutationBatch *> expected = {batches[1], batches[2], batches[4]};
    FSTQuery *query = FSTTestQuery("foo");
    std::vector<FSTMutationBatch *> matches =
        self.mutationQueue->AllMutationBatchesAffectingQuery(query);

    FSTAssertEqualVectors(matches, expected);
  });
}

- (void)testRemoveMutationBatches {
  if ([self isTestBaseClass]) return;

  self.persistence.run("testRemoveMutationBatches", [&]() {
    std::vector<FSTMutationBatch *> batches = [self createBatches:10];

    self.mutationQueue->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());

    XCTAssertEqual([self batchCount], 9);

    std::vector<FSTMutationBatch *> found;

    found = self.mutationQueue->AllMutationBatches();
    FSTAssertEqualVectors(found, batches);
    XCTAssertEqual(found.size(), 9);

    self.mutationQueue->RemoveMutationBatch(batches[0]);
    self.mutationQueue->RemoveMutationBatch(batches[1]);
    self.mutationQueue->RemoveMutationBatch(batches[2]);
    batches.erase(batches.begin(), batches.begin() + 3);
    XCTAssertEqual([self batchCount], 6);

    found = self.mutationQueue->AllMutationBatches();
    FSTAssertEqualVectors(found, batches);
    XCTAssertEqual(found.size(), 6);

    self.mutationQueue->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());
    XCTAssertEqual([self batchCount], 5);

    found = self.mutationQueue->AllMutationBatches();
    FSTAssertEqualVectors(found, batches);
    XCTAssertEqual(found.size(), 5);

    self.mutationQueue->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());
    XCTAssertEqual([self batchCount], 4);

    self.mutationQueue->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());
    XCTAssertEqual([self batchCount], 3);

    found = self.mutationQueue->AllMutationBatches();
    FSTAssertEqualVectors(found, batches);
    XCTAssertEqual(found.size(), 3);
    XCTAssertFalse(self.mutationQueue->IsEmpty());

    for (FSTMutationBatch *batch : batches) {
      self.mutationQueue->RemoveMutationBatch(batch);
    }
    found = self.mutationQueue->AllMutationBatches();
    XCTAssertEqual(found.size(), 0);
    XCTAssertTrue(self.mutationQueue->IsEmpty());
  });
}

- (void)testStreamToken {
  if ([self isTestBaseClass]) return;

  NSData *streamToken1 = [@"token1" dataUsingEncoding:NSUTF8StringEncoding];
  NSData *streamToken2 = [@"token2" dataUsingEncoding:NSUTF8StringEncoding];

  self.persistence.run("testStreamToken", [&]() {
    self.mutationQueue->SetLastStreamToken(streamToken1);

    FSTMutationBatch *batch1 = [self addMutationBatch];
    [self addMutationBatch];

    XCTAssertEqualObjects(self.mutationQueue->GetLastStreamToken(), streamToken1);

    self.mutationQueue->AcknowledgeBatch(batch1, streamToken2);
    XCTAssertEqualObjects(self.mutationQueue->GetLastStreamToken(), streamToken2);
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

  FSTMutationBatch *batch = self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, {mutation});
  return batch;
}

/**
 * Creates an array of batches containing @a number dummy FSTMutationBatches. Each has a different
 * batchID.
 */
- (std::vector<FSTMutationBatch *>)createBatches:(int)number {
  std::vector<FSTMutationBatch *> batches;

  for (int i = 0; i < number; i++) {
    FSTMutationBatch *batch = [self addMutationBatch];
    batches.push_back(batch);
  }

  return batches;
}

/** Returns the number of mutation batches in the mutation queue. */
- (size_t)batchCount {
  return self.mutationQueue->AllMutationBatches().size();
}

/**
 * Removes the first n entries from the the given batches and returns them.
 *
 * @param n The number of batches to remove.
 * @param batches The array to mutate, removing entries from it.
 * @return A new array containing all the entries that were removed from @a batches.
 */
- (std::vector<FSTMutationBatch *>)removeFirstBatches:(size_t)n
                                            inBatches:(std::vector<FSTMutationBatch *> *)batches {
  std::vector<FSTMutationBatch *> removed(batches->begin(), batches->begin() + n);
  batches->erase(batches->begin(), batches->begin() + n);

  for (FSTMutationBatch *batch : removed) {
    self.mutationQueue->RemoveMutationBatch(batch);
  }
  return removed;
}

@end

NS_ASSUME_NONNULL_END
