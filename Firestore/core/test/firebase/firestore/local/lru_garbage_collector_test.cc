/*
 * Copyright 2018 Google
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

#import "Firestore/Example/Tests/Local/FSTLRUGarbageCollectorTests.h"

#import <XCTest/XCTest.h>

#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/Util/FSTClasses.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/local/lru_garbage_collector.h"
#include "Firestore/core/src/firebase/firestore/local/mutation_queue.h"
#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/local/query_cache.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/mutation.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/set_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/strings/str_cat.h"

namespace core = firebase::firestore::core;
namespace testutil = firebase::firestore::testutil;
using firebase::Timestamp;
using firebase::firestore::auth::User;
using firebase::firestore::local::LruDelegate;
using firebase::firestore::local::LruGarbageCollector;
using firebase::firestore::local::LruParams;
using firebase::firestore::local::LruResults;
using firebase::firestore::local::MutationQueue;
using firebase::firestore::local::Persistence;
using firebase::firestore::local::QueryCache;
using firebase::firestore::local::QueryData;
using firebase::firestore::local::QueryPurpose;
using firebase::firestore::local::ReferenceSet;
using firebase::firestore::local::RemoteDocumentCache;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeyHash;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::Mutation;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::SetMutation;
using firebase::firestore::model::TargetId;

using testutil::Key;
using testutil::Query;
using testutil::Version;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTLRUGarbageCollectorTests {
  TargetId _previousTargetID;
  int _previousDocNum;
  ObjectValue _testValue;
  ObjectValue _bigObjectValue;
  std::unique_ptr<Persistence> _persistence;
  QueryCache *_queryCache;
  RemoteDocumentCache *_documentCache;
  MutationQueue *_mutationQueue;
  LruDelegate *_lruDelegate;
  LruGarbageCollector *_gc;
  ListenSequenceNumber _initialSequenceNumber;
  User _user;
  ReferenceSet _additionalReferences;
}

- (void)setUp {
  [super setUp];

  _previousTargetID = 500;
  _previousDocNum = 10;
  _testValue = FSTTestObjectValue(@{@"baz" : @YES, @"ok" : @"fine"});
  NSString *bigString = [@"" stringByPaddingToLength:4096 withString:@"a" startingAtIndex:0];
  _bigObjectValue = FSTTestObjectValue(@{@"BigProperty" : bigString});
  _user = User("user");
}

- (BOOL)isTestBaseClass {
  return ([self class] == [FSTLRUGarbageCollectorTests class]);
}

- (Persistence *)persistence {
  return _persistence.get();
}

- (void)newTestResourcesWithLruParams:(LruParams)lruParams {
  HARD_ASSERT(_persistence == nil, "Persistence already created");
  _persistence = [self newPersistenceWithLruParams:lruParams];
  _persistence->reference_delegate()->AddInMemoryPins(&_additionalReferences);
  _queryCache = _persistence->query_cache();
  _documentCache = _persistence->remote_document_cache();
  _mutationQueue = _persistence->GetMutationQueueForUser(_user);
  _lruDelegate = static_cast<LruDelegate *>(_persistence->reference_delegate());
  _initialSequenceNumber = _persistence->Run("start querycache", [&] {
    _mutationQueue->Start();
    _gc = _lruDelegate->garbage_collector();
    return _persistence->current_sequence_number();
  });
}

- (void)newTestResources {
  [self newTestResourcesWithLruParams:LruParams::Default()];
}

- (std::unique_ptr<Persistence>)newPersistenceWithLruParams:(LruParams)lruParams {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (BOOL)sentinelExists:(const DocumentKey &)key {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (void)expectSentinelRemoved:(const DocumentKey &)key {
  XCTAssertFalse([self sentinelExists:key]);
}

#pragma mark - helpers

- (ListenSequenceNumber)sequenceNumberForQueryCount:(int)queryCount {
  return _persistence->Run("gc", [&] { return _gc->SequenceNumberForQueryCount(queryCount); });
}

- (int)queryCountForPercentile:(int)percentile {
  return _persistence->Run("query count", [&] { return _gc->QueryCountForPercentile(percentile); });
}

- (int)removeQueriesThroughSequenceNumber:(ListenSequenceNumber)sequenceNumber
                              liveQueries:
                                  (const std::unordered_map<TargetId, QueryData> &)liveQueries {
  return _persistence->Run("gc", [&] { return _gc->RemoveTargets(sequenceNumber, liveQueries); });
}

// Removes documents that are not part of a target or a mutation and have a sequence number
// less than or equal to the given sequence number.
- (int)removeOrphanedDocumentsThroughSequenceNumber:(ListenSequenceNumber)sequenceNumber {
  return _persistence->Run("gc", [&] { return _gc->RemoveOrphanedDocuments(sequenceNumber); });
}

- (QueryData)nextTestQuery {
  TargetId targetID = ++_previousTargetID;
  ListenSequenceNumber listenSequenceNumber = _persistence->current_sequence_number();
  core::Query query = Query(absl::StrCat("path", targetID));
  return QueryData(std::move(query), targetID, listenSequenceNumber, QueryPurpose::Listen);
}

- (QueryData)addNextQueryInTransaction {
  QueryData queryData = [self nextTestQuery];
  _queryCache->AddTarget(queryData);
  return queryData;
}

- (void)updateTargetInTransaction:(const QueryData &)queryData {
  QueryData updated = queryData.WithSequenceNumber(_persistence->current_sequence_number());
  _queryCache->UpdateTarget(updated);
}

- (QueryData)addNextQuery {
  return _persistence->Run("adding query", [&] { return [self addNextQueryInTransaction]; });
}

// Simulates a document being mutated and then having that mutation ack'd.
// Since the document is not in a mutation queue any more, there is
// potentially nothing keeping it live. We mark it with the current sequence number
// so it can be collected later.
- (DocumentKey)markADocumentEligibleForGC {
  DocumentKey key = [self nextTestDocKey];
  [self markDocumentEligibleForGC:key];
  return key;
}

- (void)markDocumentEligibleForGC:(const DocumentKey &)docKey {
  _persistence->Run("Removing mutation reference",
                    [&] { [self markDocumentEligibleForGCInTransaction:docKey]; });
}

- (DocumentKey)markADocumentEligibleForGCInTransaction {
  DocumentKey key = [self nextTestDocKey];
  [self markDocumentEligibleForGCInTransaction:key];
  return key;
}

- (void)markDocumentEligibleForGCInTransaction:(const DocumentKey &)docKey {
  _persistence->reference_delegate()->RemoveMutationReference(docKey);
}

- (void)addDocument:(const DocumentKey &)docKey toTarget:(TargetId)targetId {
  _queryCache->AddMatchingKeys(DocumentKeySet{docKey}, targetId);
}

- (void)removeDocument:(const DocumentKey &)docKey fromTarget:(TargetId)targetId {
  _queryCache->RemoveMatchingKeys(DocumentKeySet{docKey}, targetId);
}

/**
 * Used to insert a document into the remote document cache. Use of this method should
 * be paired with some explanation for why it is in the cache, for instance:
 * - added to a target
 * - now has or previously had a pending mutation
 */
- (Document)cacheADocumentInTransaction {
  Document doc = [self nextTestDocument];
  _documentCache->Add(doc);
  return doc;
}

- (SetMutation)mutationForDocument:(const DocumentKey &)docKey {
  return SetMutation(docKey, _testValue, Precondition::None());
}

- (DocumentKey)nextTestDocKey {
  return Key("docs/doc_" + std::to_string(++_previousDocNum));
}

- (Document)nextTestDocumentWithValue:(ObjectValue)value {
  DocumentKey key = [self nextTestDocKey];
  FSTTestSnapshotVersion version = 2;
  return Document(std::move(value), std::move(key), Version(version), DocumentState::kSynced);
}

- (Document)nextTestDocument {
  return [self nextTestDocumentWithValue:_testValue];
}

#pragma mark - tests

- (void)testPickSequenceNumberPercentile {
  if ([self isTestBaseClass]) return;

  const int numTestCases = 5;
  struct Case {
    // number of queries to cache
    int queries;
    // number expected to be calculated as 10%
    int expected;
  };
  struct Case testCases[numTestCases] = {{0, 0}, {10, 1}, {9, 0}, {50, 5}, {49, 4}};

  for (int i = 0; i < numTestCases; i++) {
    // Fill the query cache.
    int numQueries = testCases[i].queries;
    int expectedTenthPercentile = testCases[i].expected;
    [self newTestResources];
    for (int j = 0; j < numQueries; j++) {
      [self addNextQuery];
    }
    int tenth = [self queryCountForPercentile:10];
    XCTAssertEqual(expectedTenthPercentile, tenth, @"Total query count: %i", numQueries);
    _persistence->Shutdown();
    _persistence.reset();
  }
}

- (void)testSequenceNumberNoQueries {
  if ([self isTestBaseClass]) return;

  // No queries... should get invalid sequence number (-1)
  [self newTestResources];
  XCTAssertEqual(local::kListenSequenceNumberInvalid, [self sequenceNumberForQueryCount:0]);
  _persistence->Shutdown();
}

- (void)testSequenceNumberForFiftyQueries {
  if ([self isTestBaseClass]) return;
  // Add 50 queries sequentially, aim to collect 10 of them.
  // The sequence number to collect should be 10 past the initial sequence number.
  [self newTestResources];
  for (int i = 0; i < 50; i++) {
    [self addNextQuery];
  }
  XCTAssertEqual(_initialSequenceNumber + 10, [self sequenceNumberForQueryCount:10]);
  _persistence->Shutdown();
}

- (void)testSequenceNumberForMultipleQueriesInATransaction {
  if ([self isTestBaseClass]) return;

  // 50 queries, 9 with one transaction, incrementing from there. Should get second sequence number.
  [self newTestResources];
  _persistence->Run("9 queries in a batch", [&] {
    for (int i = 0; i < 9; i++) {
      [self addNextQueryInTransaction];
    }
  });
  for (int i = 9; i < 50; i++) {
    [self addNextQuery];
  }
  XCTAssertEqual(2 + _initialSequenceNumber, [self sequenceNumberForQueryCount:10]);
  _persistence->Shutdown();
}

// Ensure that even if all of the queries are added in a single transaction, we still
// pick a sequence number and GC. In this case, the initial transaction contains all of the
// targets that will get GC'd, since they account for more than the first 10 targets.
- (void)testAllCollectedQueriesInSingleTransaction {
  if ([self isTestBaseClass]) return;

  // 50 queries, 11 with one transaction, incrementing from there. Should get first sequence number.
  [self newTestResources];
  _persistence->Run("11 queries in a transaction", [&] {
    for (int i = 0; i < 11; i++) {
      [self addNextQueryInTransaction];
    }
  });
  for (int i = 11; i < 50; i++) {
    [self addNextQuery];
  }
  // We expect to GC the targets from the first transaction, since they account for
  // at least the first 10 of the targets.
  XCTAssertEqual(1 + _initialSequenceNumber, [self sequenceNumberForQueryCount:10]);
  _persistence->Shutdown();
}

- (void)testSequenceNumbersWithMutationAndSequentialQueries {
  if ([self isTestBaseClass]) return;

  // Remove a mutated doc reference, marking it as eligible for GC.
  // Then add 50 queries. Should get 10 past initial (9 queries).
  [self newTestResources];
  [self markADocumentEligibleForGC];
  for (int i = 0; i < 50; i++) {
    [self addNextQuery];
  }
  XCTAssertEqual(10 + _initialSequenceNumber, [self sequenceNumberForQueryCount:10]);
  _persistence->Shutdown();
}

- (void)testSequenceNumbersWithMutationsInQueries {
  if ([self isTestBaseClass]) return;

  // Add mutated docs, then add one of them to a query target so it doesn't get GC'd.
  // Expect 3 past the initial value: the mutations not part of a query, and two queries
  [self newTestResources];
  Document docInQuery = [self nextTestDocument];
  _persistence->Run("mark mutations", [&] {
    // Adding 9 doc keys in a transaction. If we remove one of them, we'll have room for two actual
    // queries.
    [self markDocumentEligibleForGCInTransaction:docInQuery.key()];
    for (int i = 0; i < 8; i++) {
      [self markADocumentEligibleForGCInTransaction];
    }
  });
  for (int i = 0; i < 49; i++) {
    [self addNextQuery];
  }
  _persistence->Run("query with mutation", [&] {
    QueryData queryData = [self addNextQueryInTransaction];
    // This should keep the document from getting GC'd, since it is no longer orphaned.
    [self addDocument:docInQuery.key() toTarget:queryData.target_id()];
  });

  // This should catch the remaining 8 documents, plus the first two queries we added.
  XCTAssertEqual(3 + _initialSequenceNumber, [self sequenceNumberForQueryCount:10]);
  _persistence->Shutdown();
}

- (void)testRemoveQueriesUpThroughSequenceNumber {
  if ([self isTestBaseClass]) return;

  [self newTestResources];
  std::unordered_map<TargetId, QueryData> liveQueries;
  for (int i = 0; i < 100; i++) {
    QueryData queryData = [self addNextQuery];
    // Mark odd queries as live so we can test filtering out live queries.
    if (queryData.target_id() % 2 == 1) {
      liveQueries[queryData.target_id()] = queryData;
    }
  }
  // GC up through 20th query, which is 20%.
  // Expect to have GC'd 10 targets, since every other target is live
  int removed = [self removeQueriesThroughSequenceNumber:20 + _initialSequenceNumber
                                             liveQueries:liveQueries];
  XCTAssertEqual(10, removed);
  // Make sure we removed the even targets with targetID <= 20.
  _persistence->Run("verify remaining targets are > 20 or odd", [&] {
    _queryCache->EnumerateTargets([&](const QueryData &queryData) {
      XCTAssertTrue(queryData.target_id() > 20 || queryData.target_id() % 2 == 1);
    });
  });
  _persistence->Shutdown();
}

- (void)testRemoveOrphanedDocuments {
  if ([self isTestBaseClass]) return;

  [self newTestResources];
  // Track documents we expect to be retained so we can verify post-GC.
  // This will contain documents associated with targets that survive GC, as well
  // as any documents with pending mutations.
  std::unordered_set<DocumentKey, DocumentKeyHash> expectedRetained;
  // we add two mutations later, for now track them in an array.
  std::vector<Mutation> mutations;

  // Add a target and add two documents to it. The documents are expected to be
  // retained, since their membership in the target keeps them alive.
  _persistence->Run("add a target and add two documents to it", [&] {
    // Add two documents to first target, queue a mutation on the second document
    QueryData queryData = [self addNextQueryInTransaction];
    Document doc1 = [self cacheADocumentInTransaction];
    [self addDocument:doc1.key() toTarget:queryData.target_id()];
    expectedRetained.insert(doc1.key());

    Document doc2 = [self cacheADocumentInTransaction];
    [self addDocument:doc2.key() toTarget:queryData.target_id()];
    expectedRetained.insert(doc2.key());
    mutations.push_back([self mutationForDocument:doc2.key()]);
  });

  // Add a second query and register a third document on it
  _persistence->Run("second query", [&] {
    QueryData queryData = [self addNextQueryInTransaction];
    Document doc3 = [self cacheADocumentInTransaction];
    expectedRetained.insert(doc3.key());
    [self addDocument:doc3.key() toTarget:queryData.target_id()];
  });

  // cache another document and prepare a mutation on it.
  _persistence->Run("queue a mutation", [&] {
    Document doc4 = [self cacheADocumentInTransaction];
    mutations.push_back([self mutationForDocument:doc4.key()]);
    expectedRetained.insert(doc4.key());
  });

  // Insert the mutations. These operations don't have a sequence number, they just
  // serve to keep the mutated documents from being GC'd while the mutations are outstanding.
  _persistence->Run("actually register the mutations", [&] {
    Timestamp writeTime = Timestamp::Now();
    _mutationQueue->AddMutationBatch(writeTime, {}, std::move(mutations));
  });

  // Mark 5 documents eligible for GC. This simulates documents that were mutated then ack'd.
  // Since they were ack'd, they are no longer in a mutation queue, and there is nothing keeping
  // them alive.
  std::unordered_set<DocumentKey, DocumentKeyHash> toBeRemoved;
  _persistence->Run("add orphaned docs (previously mutated, then ack'd)", [&] {
    for (int i = 0; i < 5; i++) {
      Document doc = [self cacheADocumentInTransaction];
      toBeRemoved.insert(doc.key());
      [self markDocumentEligibleForGCInTransaction:doc.key()];
    }
  });

  // We expect only the orphaned documents, those not in a mutation or a target, to be
  // removed.
  // use a large sequence number to remove as much as possible
  int removed = [self removeOrphanedDocumentsThroughSequenceNumber:1000];
  XCTAssertEqual(toBeRemoved.size(), removed);
  _persistence->Run("verify", [&] {
    for (const DocumentKey &key : toBeRemoved) {
      XCTAssertEqual(_documentCache->Get(key), absl::nullopt);
      XCTAssertFalse(_queryCache->Contains(key));
    }
    for (const DocumentKey &key : expectedRetained) {
      XCTAssertNotEqual(_documentCache->Get(key), absl::nullopt, @"Missing document %s",
                        key.ToString().c_str());
    }
  });
  _persistence->Shutdown();
}

// TODO(gsoltis): write a test that includes limbo documents

- (void)testRemoveTargetsThenGC {
  if ([self isTestBaseClass]) return;

  // Create 3 targets, add docs to all of them
  // Leave oldest target alone, it is still live
  // Remove newest target
  // Blind write 2 documents
  // Add one of the blind write docs to oldest target (preserves it)
  // Remove some documents from middle target (bumps sequence number)
  // Add some documents from newest target to oldest target (preserves them)
  // Update a doc from middle target
  // Remove middle target
  // Do a blind write
  // GC up to but not including the removal of the middle target
  //
  // Expect:
  // All docs in oldest target are still around
  // One blind write is gone, the first one not added to oldest target
  // Documents removed from middle target are gone, except ones added to oldest target
  // Documents from newest target are gone, except

  [self newTestResources];

  // Through the various steps, track which documents we expect to be removed vs
  // documents we expect to be retained.
  std::unordered_set<DocumentKey, DocumentKeyHash> expectedRetained;
  std::unordered_set<DocumentKey, DocumentKeyHash> expectedRemoved;

  // Add oldest target, 5 documents, and add those documents to the target.
  // This target will not be removed, so all documents that are part of it will
  // be retained.
  QueryData oldestTarget = _persistence->Run("Add oldest target and docs", [&] {
    QueryData queryData = [self addNextQueryInTransaction];
    for (int i = 0; i < 5; i++) {
      Document doc = [self cacheADocumentInTransaction];
      expectedRetained.insert(doc.key());
      [self addDocument:doc.key() toTarget:queryData.target_id()];
    }
    return queryData;
  });

  // Add middle target and docs. Some docs will be removed from this target later,
  // which we track here.
  DocumentKeySet middleDocsToRemove;
  // This will be the document in this target that gets an update later
  DocumentKey middleDocToUpdate;
  QueryData middleTarget = _persistence->Run("Add middle target and docs", [&] {
    QueryData middleTarget = [self addNextQueryInTransaction];
    // these docs will be removed from this target later, triggering a bump
    // to their sequence numbers. Since they will not be a part of the target, we
    // expect them to be removed.
    for (int i = 0; i < 2; i++) {
      Document doc = [self cacheADocumentInTransaction];
      expectedRemoved.insert(doc.key());
      [self addDocument:doc.key() toTarget:middleTarget.target_id()];
      middleDocsToRemove = middleDocsToRemove.insert(doc.key());
    }
    // these docs stay in this target and only this target. There presence in this
    // target prevents them from being GC'd, so they are also expected to be retained.
    for (int i = 2; i < 4; i++) {
      Document doc = [self cacheADocumentInTransaction];
      expectedRetained.insert(doc.key());
      [self addDocument:doc.key() toTarget:middleTarget.target_id()];
    }
    // This doc stays in this target, but gets updated.
    {
      Document doc = [self cacheADocumentInTransaction];
      expectedRetained.insert(doc.key());
      [self addDocument:doc.key() toTarget:middleTarget.target_id()];
      middleDocToUpdate = doc.key();
    }
    return middleTarget;
  });

  // Add the newest target and add 5 documents to it. Some of those documents will
  // additionally be added to the oldest target, which will cause those documents to
  // be retained. The remaining documents are expected to be removed, since this target
  // will be removed.
  DocumentKeySet newestDocsToAddToOldest;
  _persistence->Run("Add newest target and docs", [&] {
    QueryData newestTarget = [self addNextQueryInTransaction];
    // These documents are only in this target. They are expected to be removed
    // because this target will also be removed.
    for (int i = 0; i < 3; i++) {
      Document doc = [self cacheADocumentInTransaction];
      expectedRemoved.insert(doc.key());
      [self addDocument:doc.key() toTarget:newestTarget.target_id()];
    }
    // docs to add to the oldest target in addition to this target. They will be retained
    for (int i = 3; i < 5; i++) {
      Document doc = [self cacheADocumentInTransaction];
      expectedRetained.insert(doc.key());
      [self addDocument:doc.key() toTarget:newestTarget.target_id()];
      newestDocsToAddToOldest = newestDocsToAddToOldest.insert(doc.key());
    }
  });

  // 2 doc writes, add one of them to the oldest target.
  _persistence->Run("2 doc writes, add one of them to the oldest target", [&] {
    // write two docs and have them ack'd by the server. can skip mutation queue
    // and set them in document cache. Add potentially orphaned first, also add one
    // doc to a target.
    Document doc1 = [self cacheADocumentInTransaction];
    [self markDocumentEligibleForGCInTransaction:doc1.key()];
    [self updateTargetInTransaction:oldestTarget];
    [self addDocument:doc1.key() toTarget:oldestTarget.target_id()];
    // doc1 should be retained by being added to oldestTarget.
    expectedRetained.insert(doc1.key());

    Document doc2 = [self cacheADocumentInTransaction];
    [self markDocumentEligibleForGCInTransaction:doc2.key()];
    // nothing is keeping doc2 around, it should be removed
    expectedRemoved.insert(doc2.key());
  });

  // Remove some documents from the middle target.
  _persistence->Run("Remove some documents from the middle target", [&] {
    [self updateTargetInTransaction:middleTarget];
    for (const DocumentKey &docKey : middleDocsToRemove) {
      [self removeDocument:docKey fromTarget:middleTarget.target_id()];
    }
  });

  // Add a couple docs from the newest target to the oldest (preserves them past the point where
  // newest was removed)
  // upperBound is the sequence number right before middleTarget is updated, then removed.
  ListenSequenceNumber upperBound =
      _persistence->Run("Add a couple docs from the newest target to the oldest", [&] {
        [self updateTargetInTransaction:oldestTarget];
        for (const DocumentKey &docKey : newestDocsToAddToOldest) {
          [self addDocument:docKey toTarget:oldestTarget.target_id()];
        }
        return _persistence->current_sequence_number();
      });

  // Update a doc in the middle target
  _persistence->Run("Update a doc in the middle target", [&] {
    FSTTestSnapshotVersion version = 3;
    Document doc(ObjectValue(_testValue), middleDocToUpdate, Version(version),
                 DocumentState::kSynced);
    _documentCache->Add(doc);
    [self updateTargetInTransaction:middleTarget];
  });

  // middleTarget removed here, no update needed

  // Write a doc and get an ack, not part of a target.
  _persistence->Run("Write a doc and get an ack, not part of a target", [&] {
    Document doc = [self cacheADocumentInTransaction];
    // Mark it as eligible for GC, but this is after our upper bound for what we will collect.
    [self markDocumentEligibleForGCInTransaction:doc.key()];
    // This should be retained, it's too new to get removed.
    expectedRetained.insert(doc.key());
  });

  // Finally, do the garbage collection, up to but not including the removal of middleTarget
  std::unordered_map<TargetId, QueryData> liveQueries{{oldestTarget.target_id(), oldestTarget}};

  int queriesRemoved = [self removeQueriesThroughSequenceNumber:upperBound liveQueries:liveQueries];
  XCTAssertEqual(1, queriesRemoved, @"Expected to remove newest target");
  int docsRemoved = [self removeOrphanedDocumentsThroughSequenceNumber:upperBound];
  XCTAssertEqual(expectedRemoved.size(), docsRemoved);
  _persistence->Run("verify results", [&] {
    for (const DocumentKey &key : expectedRemoved) {
      XCTAssertEqual(_documentCache->Get(key), absl::nullopt,
                     @"Did not expect to find %s in document cache", key.ToString().c_str());
      XCTAssertFalse(_queryCache->Contains(key), @"Did not expect to find %s in queryCache",
                     key.ToString().c_str());
      [self expectSentinelRemoved:key];
    }
    for (const DocumentKey &key : expectedRetained) {
      XCTAssertNotEqual(_documentCache->Get(key), absl::nullopt,
                        @"Expected to find %s in document cache", key.ToString().c_str());
    }
  });

  _persistence->Shutdown();
}

- (void)testGetsSize {
  if ([self isTestBaseClass]) return;

  [self newTestResources];

  size_t initialSize = _gc->CalculateByteSize();

  _persistence->Run("fill cache", [&] {
    // Simulate a bunch of ack'd mutations
    for (int i = 0; i < 50; i++) {
      Document doc = [self cacheADocumentInTransaction];
      [self markDocumentEligibleForGCInTransaction:doc.key()];
    }
  });

  size_t finalSize = _gc->CalculateByteSize();
  XCTAssertGreaterThan(finalSize, initialSize);

  _persistence->Shutdown();
}

- (void)testDisabled {
  if ([self isTestBaseClass]) return;

  LruParams params = LruParams::Disabled();
  [self newTestResourcesWithLruParams:params];

  _persistence->Run("fill cache", [&] {
    // Simulate a bunch of ack'd mutations
    for (int i = 0; i < 500; i++) {
      Document doc = [self cacheADocumentInTransaction];
      [self markDocumentEligibleForGCInTransaction:doc.key()];
    }
  });

  LruResults results = _persistence->Run("GC", [&] { return _gc->Collect({}); });
  XCTAssertFalse(results.did_run);

  _persistence->Shutdown();
}

- (void)testCacheTooSmall {
  if ([self isTestBaseClass]) return;

  LruParams params = LruParams::Default();
  [self newTestResourcesWithLruParams:params];

  _persistence->Run("fill cache", [&] {
    // Simulate a bunch of ack'd mutations
    for (int i = 0; i < 50; i++) {
      Document doc = [self cacheADocumentInTransaction];
      [self markDocumentEligibleForGCInTransaction:doc.key()];
    }
  });

  int cacheSize = (int)_gc->CalculateByteSize();
  // Verify that we don't have enough in our cache to warrant collection
  XCTAssertLessThan(cacheSize, params.min_bytes_threshold);

  // Try collection and verify that it didn't run
  LruResults results = _persistence->Run("GC", [&] { return _gc->Collect({}); });
  XCTAssertFalse(results.did_run);

  _persistence->Shutdown();
}

- (void)testGCRan {
  if ([self isTestBaseClass]) return;

  LruParams params = LruParams::Default();
  // Set a low threshold so we will definitely run
  params.min_bytes_threshold = 100;
  [self newTestResourcesWithLruParams:params];

  // Add 100 targets and 10 documents to each
  for (int i = 0; i < 100; i++) {
    // Use separate transactions so that each target and associated documents get their own
    // sequence number.
    _persistence->Run("Add a target and some documents", [&] {
      QueryData queryData = [self addNextQueryInTransaction];
      for (int j = 0; j < 10; j++) {
        Document doc = [self cacheADocumentInTransaction];
        [self addDocument:doc.key() toTarget:queryData.target_id()];
      }
    });
  }

  // Mark nothing as live, so everything is eligible.
  LruResults results = _persistence->Run("GC", [&] { return _gc->Collect({}); });

  // By default, we collect 10% of the sequence numbers. Since we added 100 targets,
  // that should be 10 targets with 10 documents each, for a total of 100 documents.
  XCTAssertTrue(results.did_run);
  XCTAssertEqual(10, results.targets_removed);
  XCTAssertEqual(100, results.documents_removed);
  _persistence->Shutdown();
}

@end

NS_ASSUME_NONNULL_END
