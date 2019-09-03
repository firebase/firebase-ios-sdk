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

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/mutation.h"
#include "Firestore/core/src/firebase/firestore/model/mutation_batch.h"
#include "Firestore/core/src/firebase/firestore/model/set_mutation.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace core = firebase::firestore::core;
namespace testutil = firebase::firestore::testutil;
using firebase::Timestamp;
using firebase::firestore::auth::User;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::kBatchIdUnknown;
using firebase::firestore::model::Mutation;
using firebase::firestore::model::MutationBatch;
using firebase::firestore::model::SetMutation;
using firebase::firestore::nanopb::ByteString;
using firebase::firestore::testutil::Key;
using firebase::firestore::testutil::Query;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTMutationQueueTests

- (void)tearDown {
  if (self.persistence) {
    self.persistence->Shutdown();
  }
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

  self.persistence->Run("testCountBatches", [&]() {
    XCTAssertEqual(0, [self batchCount]);
    XCTAssertTrue(self.mutationQueue->IsEmpty());

    MutationBatch batch1 = [self addMutationBatch];
    XCTAssertEqual(1, [self batchCount]);
    XCTAssertFalse(self.mutationQueue->IsEmpty());

    MutationBatch batch2 = [self addMutationBatch];
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

  self.persistence->Run("testAcknowledgeBatchID", [&]() {
    XCTAssertEqual([self batchCount], 0);

    MutationBatch batch1 = [self addMutationBatch];
    MutationBatch batch2 = [self addMutationBatch];
    MutationBatch batch3 = [self addMutationBatch];
    XCTAssertGreaterThan(batch1.batch_id(), kBatchIdUnknown);
    XCTAssertGreaterThan(batch2.batch_id(), batch1.batch_id());
    XCTAssertGreaterThan(batch3.batch_id(), batch2.batch_id());

    XCTAssertEqual([self batchCount], 3);

    self.mutationQueue->AcknowledgeBatch(batch1, {});
    self.mutationQueue->RemoveMutationBatch(batch1);
    XCTAssertEqual([self batchCount], 2);

    self.mutationQueue->AcknowledgeBatch(batch2, {});
    XCTAssertEqual([self batchCount], 2);

    self.mutationQueue->RemoveMutationBatch(batch2);
    XCTAssertEqual([self batchCount], 1);

    self.mutationQueue->RemoveMutationBatch(batch3);
    XCTAssertEqual([self batchCount], 0);
  });
}

- (void)testAcknowledgeThenRemove {
  if ([self isTestBaseClass]) return;

  self.persistence->Run("testAcknowledgeThenRemove", [&]() {
    MutationBatch batch1 = [self addMutationBatch];

    self.mutationQueue->AcknowledgeBatch(batch1, {});
    self.mutationQueue->RemoveMutationBatch(batch1);

    XCTAssertEqual([self batchCount], 0);
  });
}

- (void)testLookupMutationBatch {
  if ([self isTestBaseClass]) return;

  // Searching on an empty queue should not find a non-existent batch
  self.persistence->Run("testLookupMutationBatch", [&]() {
    absl::optional<MutationBatch> notFound = self.mutationQueue->LookupMutationBatch(42);
    XCTAssertEqual(notFound, absl::nullopt);

    std::vector<MutationBatch> batches = [self createBatches:10];
    std::vector<MutationBatch> removed = [self removeFirstBatches:3 inBatches:&batches];

    // After removing, a batch should not be found
    for (size_t i = 0; i < removed.size(); i++) {
      notFound = self.mutationQueue->LookupMutationBatch(removed[i].batch_id());
      XCTAssertEqual(notFound, absl::nullopt);
    }

    // Remaining entries should still be found
    for (const MutationBatch& batch : batches) {
      absl::optional<MutationBatch> found =
          self.mutationQueue->LookupMutationBatch(batch.batch_id());
      XCTAssertEqual(found->batch_id(), batch.batch_id());
    }

    // Even on a nonempty queue searching should not find a non-existent batch
    notFound = self.mutationQueue->LookupMutationBatch(42);
    XCTAssertEqual(notFound, absl::nullopt);
  });
}

- (void)testNextMutationBatchAfterBatchID {
  if ([self isTestBaseClass]) return;

  self.persistence->Run("testNextMutationBatchAfterBatchID", [&]() {
    std::vector<MutationBatch> batches = [self createBatches:10];
    std::vector<MutationBatch> removed = [self removeFirstBatches:3 inBatches:&batches];

    for (size_t i = 0; i < batches.size() - 1; i++) {
      const MutationBatch& current = batches[i];
      const MutationBatch& next = batches[i + 1];
      absl::optional<MutationBatch> found =
          self.mutationQueue->NextMutationBatchAfterBatchId(current.batch_id());
      XCTAssertEqual(found->batch_id(), next.batch_id());
    }

    for (size_t i = 0; i < removed.size(); i++) {
      const MutationBatch& current = removed[i];
      const MutationBatch& next = batches[0];
      absl::optional<MutationBatch> found =
          self.mutationQueue->NextMutationBatchAfterBatchId(current.batch_id());
      XCTAssertEqual(found->batch_id(), next.batch_id());
    }

    const MutationBatch& first = batches[0];
    absl::optional<MutationBatch> found =
        self.mutationQueue->NextMutationBatchAfterBatchId(first.batch_id() - 42);
    XCTAssertEqual(found->batch_id(), first.batch_id());

    const MutationBatch& last = batches[batches.size() - 1];
    absl::optional<MutationBatch> notFound =
        self.mutationQueue->NextMutationBatchAfterBatchId(last.batch_id());
    XCTAssertEqual(notFound, absl::nullopt);
  });
}

- (void)testAllMutationBatchesAffectingDocumentKey {
  if ([self isTestBaseClass]) return;

  self.persistence->Run("testAllMutationBatchesAffectingDocumentKey", [&]() {
    std::vector<Mutation> mutations = {
        FSTTestSetMutation(@"foi/bar", @{@"a" : @1}),
        FSTTestSetMutation(@"foo/bar", @{@"a" : @1}),
        FSTTestPatchMutation("foo/bar", @{@"b" : @1}, {}),
        FSTTestSetMutation(@"foo/bar/suffix/key", @{@"a" : @1}),
        FSTTestSetMutation(@"foo/baz", @{@"a" : @1}),
        FSTTestSetMutation(@"food/bar", @{@"a" : @1}),
    };

    // Store all the mutations.
    std::vector<MutationBatch> batches;
    for (const Mutation& mutation : mutations) {
      MutationBatch batch = self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, {mutation});
      batches.push_back(batch);
    }

    std::vector<MutationBatch> expected{batches[1], batches[2]};
    std::vector<MutationBatch> matches =
        self.mutationQueue->AllMutationBatchesAffectingDocumentKey(testutil::Key("foo/bar"));

    XCTAssertEqual(matches, expected);
  });
}

- (void)testAllMutationBatchesAffectingDocumentKeys {
  if ([self isTestBaseClass]) return;

  self.persistence->Run("testAllMutationBatchesAffectingDocumentKey", [&]() {
    std::vector<Mutation> mutations = {
        FSTTestSetMutation(@"fob/bar", @{@"a" : @1}),
        FSTTestSetMutation(@"foo/bar", @{@"a" : @1}),
        FSTTestPatchMutation("foo/bar", @{@"b" : @1}, {}),
        FSTTestSetMutation(@"foo/bar/suffix/key", @{@"a" : @1}),
        FSTTestSetMutation(@"foo/baz", @{@"a" : @1}),
        FSTTestSetMutation(@"food/bar", @{@"a" : @1}),
    };

    // Store all the mutations.
    std::vector<MutationBatch> batches;
    for (const Mutation& mutation : mutations) {
      MutationBatch batch = self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, {mutation});
      batches.push_back(batch);
    }

    DocumentKeySet keys{
        Key("foo/bar"),
        Key("foo/baz"),
    };

    std::vector<MutationBatch> expected{batches[1], batches[2], batches[4]};
    std::vector<MutationBatch> matches =
        self.mutationQueue->AllMutationBatchesAffectingDocumentKeys(keys);

    XCTAssertEqual(matches, expected);
  });
}

- (void)testAllMutationBatchesAffectingDocumentKeys_handlesOverlap {
  if ([self isTestBaseClass]) return;

  self.persistence->Run("testAllMutationBatchesAffectingDocumentKeys_handlesOverlap", [&]() {
    std::vector<Mutation> group1 = {
        FSTTestSetMutation(@"foo/bar", @{@"a" : @1}),
        FSTTestSetMutation(@"foo/baz", @{@"a" : @1}),
    };
    MutationBatch batch1 =
        self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, std::move(group1));

    std::vector<Mutation> group2 = {FSTTestSetMutation(@"food/bar", @{@"a" : @1})};
    self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, std::move(group2));

    std::vector<Mutation> group3 = {
        FSTTestSetMutation(@"foo/bar", @{@"b" : @1}),
    };
    MutationBatch batch3 =
        self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, std::move(group3));

    DocumentKeySet keys{
        Key("foo/bar"),
        Key("foo/baz"),
    };

    std::vector<MutationBatch> expected{batch1, batch3};
    std::vector<MutationBatch> matches =
        self.mutationQueue->AllMutationBatchesAffectingDocumentKeys(keys);

    XCTAssertEqual(matches, expected);
  });
}

- (void)testAllMutationBatchesAffectingQuery {
  if ([self isTestBaseClass]) return;

  self.persistence->Run("testAllMutationBatchesAffectingQuery", [&]() {
    std::vector<Mutation> mutations = {
        FSTTestSetMutation(@"fob/bar", @{@"a" : @1}),
        FSTTestSetMutation(@"foo/bar", @{@"a" : @1}),
        FSTTestPatchMutation("foo/bar", @{@"b" : @1}, {}),
        FSTTestSetMutation(@"foo/bar/suffix/key", @{@"a" : @1}),
        FSTTestSetMutation(@"foo/baz", @{@"a" : @1}),
        FSTTestSetMutation(@"food/bar", @{@"a" : @1}),
    };

    // Store all the mutations.
    std::vector<MutationBatch> batches;
    for (const Mutation& mutation : mutations) {
      MutationBatch batch = self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, {mutation});
      batches.push_back(batch);
    }

    std::vector<MutationBatch> expected = {batches[1], batches[2], batches[4]};
    core::Query query = Query("foo");
    std::vector<MutationBatch> matches =
        self.mutationQueue->AllMutationBatchesAffectingQuery(query);

    XCTAssertEqual(matches, expected);
  });
}

- (void)testRemoveMutationBatches {
  if ([self isTestBaseClass]) return;

  self.persistence->Run("testRemoveMutationBatches", [&]() {
    std::vector<MutationBatch> batches = [self createBatches:10];

    self.mutationQueue->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());

    XCTAssertEqual([self batchCount], 9);

    std::vector<MutationBatch> found;

    found = self.mutationQueue->AllMutationBatches();
    XCTAssertEqual(found, batches);
    XCTAssertEqual(found.size(), 9);

    self.mutationQueue->RemoveMutationBatch(batches[0]);
    self.mutationQueue->RemoveMutationBatch(batches[1]);
    self.mutationQueue->RemoveMutationBatch(batches[2]);
    batches.erase(batches.begin(), batches.begin() + 3);
    XCTAssertEqual([self batchCount], 6);

    found = self.mutationQueue->AllMutationBatches();
    XCTAssertEqual(found, batches);
    XCTAssertEqual(found.size(), 6);

    self.mutationQueue->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());
    XCTAssertEqual([self batchCount], 5);

    found = self.mutationQueue->AllMutationBatches();
    XCTAssertEqual(found, batches);
    XCTAssertEqual(found.size(), 5);

    self.mutationQueue->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());
    XCTAssertEqual([self batchCount], 4);

    self.mutationQueue->RemoveMutationBatch(batches[0]);
    batches.erase(batches.begin());
    XCTAssertEqual([self batchCount], 3);

    found = self.mutationQueue->AllMutationBatches();
    XCTAssertEqual(found, batches);
    XCTAssertEqual(found.size(), 3);
    XCTAssertFalse(self.mutationQueue->IsEmpty());

    for (const MutationBatch& batch : batches) {
      self.mutationQueue->RemoveMutationBatch(batch);
    }
    found = self.mutationQueue->AllMutationBatches();
    XCTAssertEqual(found.size(), 0);
    XCTAssertTrue(self.mutationQueue->IsEmpty());
  });
}

- (void)testStreamToken {
  if ([self isTestBaseClass]) return;

  ByteString streamToken1("token1");
  ByteString streamToken2("token2");

  self.persistence->Run("testStreamToken", [&]() {
    self.mutationQueue->SetLastStreamToken(streamToken1);

    MutationBatch batch1 = [self addMutationBatch];
    [self addMutationBatch];

    XCTAssertEqual(self.mutationQueue->GetLastStreamToken(), streamToken1);

    self.mutationQueue->AcknowledgeBatch(batch1, streamToken2);
    XCTAssertEqual(self.mutationQueue->GetLastStreamToken(), streamToken2);
  });
}

#pragma mark - Helpers

/** Creates a new MutationBatch with the next batch ID and a set of dummy mutations. */
- (MutationBatch)addMutationBatch {
  return [self addMutationBatchWithKey:@"foo/bar"];
}

/**
 * Creates a new MutationBatch with the given key, the next batch ID and a set of dummy
 * mutations.
 */
- (MutationBatch)addMutationBatchWithKey:(NSString*)key {
  SetMutation mutation = FSTTestSetMutation(key, @{@"a" : @1});

  MutationBatch batch = self.mutationQueue->AddMutationBatch(Timestamp::Now(), {}, {mutation});
  return batch;
}

/**
 * Creates an array of batches containing @a number dummy MutationBatches. Each has a different
 * batchID.
 */
- (std::vector<MutationBatch>)createBatches:(int)number {
  std::vector<MutationBatch> batches;

  for (int i = 0; i < number; i++) {
    MutationBatch batch = [self addMutationBatch];
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
- (std::vector<MutationBatch>)removeFirstBatches:(size_t)n
                                       inBatches:(std::vector<MutationBatch>*)batches {
  std::vector<MutationBatch> removed(batches->begin(), batches->begin() + n);
  batches->erase(batches->begin(), batches->begin() + n);

  for (const MutationBatch& batch : removed) {
    self.mutationQueue->RemoveMutationBatch(batch);
  }
  return removed;
}

@end

NS_ASSUME_NONNULL_END
