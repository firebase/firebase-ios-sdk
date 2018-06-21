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

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"
#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Local/FSTQueryCache.h"
#import "Firestore/Source/Local/FSTRemoteDocumentCache.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Util/FSTClasses.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/strings/str_cat.h"

using firebase::firestore::auth::User;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeyHash;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::Precondition;
namespace testutil = firebase::firestore::testutil;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTLRUGarbageCollectorTests {
  FSTTargetID _previousTargetID;
  int _previousDocNum;
  FSTObjectValue *_testValue;
  FSTObjectValue *_bigObjectValue;
  id<FSTPersistence> _persistence;
  id<FSTQueryCache> _queryCache;
  id<FSTRemoteDocumentCache> _documentCache;
  id<FSTMutationQueue> _mutationQueue;
  FSTLRUGarbageCollector *_gc;
  FSTListenSequenceNumber _initialSequenceNumber;
  User _user;
}

- (void)newTestResources {
  HARD_ASSERT(_persistence == nil, "Persistence already created");
  _persistence = [self newPersistence];
  _queryCache = [_persistence queryCache];
  _documentCache = [_persistence remoteDocumentCache];
  _mutationQueue = [_persistence mutationQueueForUser:_user];
  _initialSequenceNumber = _persistence.run("start querycache", [&]() -> FSTListenSequenceNumber {
    [_queryCache start];
    [_mutationQueue start];
    _gc = ((id<FSTLRUDelegate>)_persistence.referenceDelegate).gc;
    return _persistence.currentSequenceNumber;
  });
}

- (FSTListenSequenceNumber)sequenceNumberForQueryCount:(int)queryCount {
  return _persistence.run("gc", [&]() -> FSTListenSequenceNumber {
    return [_gc sequenceNumberForQueryCount:queryCount];
  });
}

- (id<FSTPersistence>)newPersistence {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (void)setUp {
  [super setUp];

  _previousTargetID = 500;
  _previousDocNum = 10;
  _testValue = FSTTestObjectValue(@{ @"baz" : @YES, @"ok" : @"fine" });
  NSString *bigString = [@"" stringByPaddingToLength:4096 withString:@"a" startingAtIndex:0];
  _bigObjectValue = FSTTestObjectValue(@{@"BigProperty" : bigString});
  _user = User("user");
}

- (BOOL)isTestBaseClass {
  return ([self class] == [FSTLRUGarbageCollectorTests class]);
}

- (FSTQueryData *)nextTestQuery {
  FSTTargetID targetID = ++_previousTargetID;
  FSTListenSequenceNumber listenSequenceNumber = _persistence.currentSequenceNumber;
  FSTQuery *query = FSTTestQuery(absl::StrCat("path", targetID));
  return [[FSTQueryData alloc] initWithQuery:query
                                    targetID:targetID
                        listenSequenceNumber:listenSequenceNumber
                                     purpose:FSTQueryPurposeListen];
}

- (FSTQueryData *)addNextQueryInTransaction {
  FSTQueryData *queryData = [self nextTestQuery];
  [_queryCache addQueryData:queryData];
  return queryData;
}

- (FSTQueryData *)addNextQuery {
  return _persistence.run("adding query",
                          [&]() -> FSTQueryData * { return [self addNextQueryInTransaction]; });
}

- (DocumentKey)removeMutationReference {
  DocumentKey key = [self nextTestDocKey];
  _persistence.run("Removing mutation reference",
                   [&]() { [_persistence.referenceDelegate removeMutationReference:key]; });
  return key;
}

- (DocumentKey)nextTestDocKey {
  return testutil::Key("docs/doc_" + std::to_string(++_previousDocNum));
}

- (FSTDocument *)nextTestDocumentWithValue:(FSTObjectValue *)value {
  DocumentKey key = [self nextTestDocKey];
  FSTTestSnapshotVersion version = 2;
  BOOL hasMutations = NO;
  return [FSTDocument documentWithData:value
                                   key:key
                               version:testutil::Version(version)
                     hasLocalMutations:hasMutations];
}

- (FSTDocument *)nextTestDocument {
  return [self nextTestDocumentWithValue:_testValue];
}

- (FSTDocument *)nextBigTestDocument {
  return [self nextTestDocumentWithValue:_bigObjectValue];
}

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
      _persistence.run("add query", [&]() { [_queryCache addQueryData:[self nextTestQuery]]; });
    }
    _persistence.run("Check GC", [&]() {
      FSTListenSequenceNumber tenth = [_gc queryCountForPercentile:10];
      XCTAssertEqual(expectedTenthPercentile, tenth, @"Total query count: %i", numQueries);
    });
    [_persistence shutdown];
    _persistence = nil;
  }
}

- (void)testSequenceNumberNoQueries {
  if ([self isTestBaseClass]) return;

  // No queries... should get invalid sequence number (-1)
  [self newTestResources];
  XCTAssertEqual(kFSTListenSequenceNumberInvalid, [self sequenceNumberForQueryCount:0]);
  [_persistence shutdown];
}

- (void)testSequenceNumberForFiftyQueries {
  if ([self isTestBaseClass]) return;
  // Add 50 queries sequentially, aim to collect 10 of them.
  // The sequence number to collect should be 10 past the initial sequence number.
  [self newTestResources];
  for (int i = 0; i < 50; i++) {
    _persistence.run("add query", [&]() { [_queryCache addQueryData:[self nextTestQuery]]; });
  }
  XCTAssertEqual(_initialSequenceNumber + 10, [self sequenceNumberForQueryCount:10]);
  [_persistence shutdown];
}

- (void)testSequenceNumberForMultipleQueriesInATransaction {
  if ([self isTestBaseClass]) return;

  // 50 queries, 9 with one transaction, incrementing from there. Should get second sequence number.
  [self newTestResources];
  _persistence.run("9 queries in a batch", [&]() {
    for (int i = 0; i < 9; i++) {
      [_queryCache addQueryData:[self nextTestQuery]];
    }
  });
  for (int i = 9; i < 50; i++) {
    [self addNextQuery];
  }
  XCTAssertEqual(2 + _initialSequenceNumber, [self sequenceNumberForQueryCount:10]);
  [_persistence shutdown];
}

- (void)testAllCollectedQueriesInSingleTransaction {
  if ([self isTestBaseClass]) return;

  // 50 queries, 11 with one transaction, incrementing from there. Should get first sequence number.
  [self newTestResources];
  _persistence.run("11 queries in a batch", [&]() {
    for (int i = 0; i < 11; i++) {
      [_queryCache addQueryData:[self nextTestQuery]];
    }
  });
  for (int i = 11; i < 50; i++) {
    [self addNextQuery];
  }
  XCTAssertEqual(1 + _initialSequenceNumber, [self sequenceNumberForQueryCount:10]);
  [_persistence shutdown];
}

- (void)testSequenceNumbersWithMutationAndSequentialQueries {
  if ([self isTestBaseClass]) return;

  // Remove a mutated doc reference, marking it as eligible for GC.
  // Then add 50 queries. Should get 10 past initial (9 queries).
  [self newTestResources];
  [self removeMutationReference];
  for (int i = 0; i < 50; i++) {
    [self addNextQuery];
  }
  XCTAssertEqual(10 + _initialSequenceNumber, [self sequenceNumberForQueryCount:10]);
  [_persistence shutdown];
}

- (void)testSequenceNumbersWithMutationsInQueries {
  if ([self isTestBaseClass]) return;

  // Add mutated docs, then add one of them to a query target so it doesn't get GC'd.
  // Expect 3 past the initial value: the mutations not part of a query, and two queries
  [self newTestResources];
  FSTDocument *docInQuery = [self nextTestDocument];
  DocumentKeySet docInQuerySet{docInQuery.key};
  _persistence.run("mark mutations", [&]() {
    // Adding 9 doc keys in a transaction. If we remove one of them, we'll have room for two actual
    // queries.
    [_persistence.referenceDelegate removeMutationReference:docInQuery.key];
    for (int i = 0; i < 8; i++) {
      [_persistence.referenceDelegate removeMutationReference:[self nextTestDocKey]];
    }
  });
  for (int i = 0; i < 49; i++) {
    [self addNextQuery];
  }
  _persistence.run("query with mutation", [&]() {
    FSTQueryData *queryData = [self addNextQueryInTransaction];
    // This should bump one document out of the mutated documents cache.
    [_queryCache addMatchingKeys:docInQuerySet forTargetID:queryData.targetID];
  });

  // This should catch the remaining 8 documents, plus the first two queries we added.
  XCTAssertEqual(3 + _initialSequenceNumber, [self sequenceNumberForQueryCount:10]);
  [_persistence shutdown];
}

- (void)testRemoveQueriesUpThroughSequenceNumber {
  if ([self isTestBaseClass]) return;

  [self newTestResources];
  NSMutableDictionary<NSNumber *, FSTQueryData *> *liveQueries = [[NSMutableDictionary alloc] init];
  for (int i = 0; i < 100; i++) {
    _persistence.run("sequential queries", [&]() {
      FSTQueryData *queryData = [self addNextQueryInTransaction];
      // Mark odd queries as live so we can test filtering out live queries.
      if (queryData.targetID % 2 == 1) {
        liveQueries[@(queryData.targetID)] = queryData;
      }
    });
  }
  // GC up through 15th query, which is 15%.
  // Expect to have GC'd 8 targets (even values of 2-16).
  _persistence.run("gc", [&]() {
    NSUInteger removed = [_gc removeQueriesUpThroughSequenceNumber:15 + _initialSequenceNumber
                                                       liveQueries:liveQueries];
    XCTAssertEqual(7, removed);
  });
  [_persistence shutdown];
}

- (void)testRemoveOrphanedDocuments {
  if ([self isTestBaseClass]) return;

  [self newTestResources];
  // Add docs to mutation queue, as well as keep some queries. verify that correct documents are
  // removed.
  std::unordered_set<DocumentKey, DocumentKeyHash> toBeRetained;
  NSMutableArray *mutations = [NSMutableArray arrayWithCapacity:2];
  _persistence.run("add a target and add two documents to it", [&]() {
    // Add two documents to first target, queue a mutation on the second document
    FSTQueryData *queryData = [self addNextQueryInTransaction];
    DocumentKeySet keySet{};
    FSTDocument *doc1 = [self nextTestDocument];
    [_documentCache addEntry:doc1];
    keySet = keySet.insert(doc1.key);
    toBeRetained.insert(doc1.key);
    FSTDocument *doc2 = [self nextTestDocument];
    [_documentCache addEntry:doc2];
    keySet = keySet.insert(doc2.key);
    toBeRetained.insert(doc2.key);
    [_queryCache addMatchingKeys:keySet forTargetID:queryData.targetID];

    FSTObjectValue *newValue =
        [[FSTObjectValue alloc] initWithDictionary:@{@"foo" : [FSTStringValue stringValue:@"bar"]}];
    [mutations addObject:[[FSTSetMutation alloc] initWithKey:doc2.key
                                                       value:newValue
                                                precondition:Precondition::None()]];
  });
  // Add a second query and register a document on it
  _persistence.run("second query", [&]() {
    FSTQueryData *queryData = [self addNextQueryInTransaction];
    DocumentKeySet keySet{};
    FSTDocument *doc3 = [self nextTestDocument];
    [_documentCache addEntry:doc3];
    keySet = keySet.insert(doc3.key);
    toBeRetained.insert(doc3.key);
    [_queryCache addMatchingKeys:keySet forTargetID:queryData.targetID];
  });

  _persistence.run("queue a mutation", [&]() {
    FSTDocument *doc1 = [self nextTestDocument];
    [mutations addObject:[[FSTSetMutation alloc] initWithKey:doc1.key
                                                       value:doc1.data
                                                precondition:Precondition::None()]];
    [_documentCache addEntry:doc1];
    toBeRetained.insert(doc1.key);
  });

  _persistence.run("actually register the mutations", [&]() {
    FIRTimestamp *writeTime = [FIRTimestamp timestamp];
    [_mutationQueue addMutationBatchWithWriteTime:writeTime mutations:mutations];
  });

  NSUInteger expectedRemoveCount = 5;
  std::unordered_set<DocumentKey, DocumentKeyHash> toBeRemoved;
  _persistence.run("add orphaned docs (previously mutated, then ack'd)", [&]() {
    // Now add the docs we expect to get resolved.

    for (int i = 0; i < expectedRemoveCount; i++) {
      FSTDocument *doc = [self nextTestDocument];
      toBeRemoved.insert(doc.key);
      [_documentCache addEntry:doc];
      [_persistence.referenceDelegate removeMutationReference:doc.key];
    }
  });

  _persistence.run("gc and verify", [&]() {
    // remove as much as possible
    int removed = [_gc removeOrphanedDocumentsThroughSequenceNumber:1000];
    XCTAssertEqual(expectedRemoveCount, removed);
    for (const DocumentKey &key : toBeRemoved) {
      XCTAssertNil([_documentCache entryForKey:key]);
      XCTAssertFalse([_queryCache containsKey:key]);
    }
    for (const DocumentKey &key : toBeRetained) {
      XCTAssertNotNil([_documentCache entryForKey:key], @"Missing document %s",
                      key.ToString().c_str());
    }
  });
  [_persistence shutdown];
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

  std::unordered_set<DocumentKey, DocumentKeyHash> expectedRetained;
  std::unordered_set<DocumentKey, DocumentKeyHash> expectedRemoved;

  // Add oldest target and docs

  FSTQueryData *oldestTarget =
      _persistence.run("Add oldest target and docs", [&]() -> FSTQueryData * {
        FSTQueryData *queryData = [self addNextQueryInTransaction];
        DocumentKeySet oldestDocs{};

        for (int i = 0; i < 5; i++) {
          FSTDocument *doc = [self nextTestDocument];
          expectedRetained.insert(doc.key);
          oldestDocs = oldestDocs.insert(doc.key);
          [_documentCache addEntry:doc];
        }
        [_queryCache addMatchingKeys:oldestDocs forTargetID:queryData.targetID];
        return queryData;
      });

  // Add middle target and docs. Some docs will be removed from this target later.
  DocumentKeySet middleDocsToRemove{};
  DocumentKey middleDocToUpdate;
  FSTQueryData *middleTarget =
      _persistence.run("Add middle target and docs", [&]() -> FSTQueryData * {
        FSTQueryData *middleTarget = [self addNextQueryInTransaction];
        DocumentKeySet middleDocs{};
        // these docs will be removed from this target later
        for (int i = 0; i < 2; i++) {
          FSTDocument *doc = [self nextTestDocument];
          expectedRemoved.insert(doc.key);
          middleDocs = middleDocs.insert(doc.key);
          [_documentCache addEntry:doc];
          middleDocsToRemove = middleDocsToRemove.insert(doc.key);
        }
        // these docs stay in this target and only this target
        for (int i = 2; i < 4; i++) {
          FSTDocument *doc = [self nextTestDocument];
          expectedRetained.insert(doc.key);
          middleDocs = middleDocs.insert(doc.key);
          [_documentCache addEntry:doc];
        }
        // This doc stays in this target, but gets updated
        {
          FSTDocument *doc = [self nextTestDocument];
          expectedRetained.insert(doc.key);
          middleDocs = middleDocs.insert(doc.key);
          [_documentCache addEntry:doc];
          middleDocToUpdate = doc.key;
        }
        [_queryCache addMatchingKeys:middleDocs forTargetID:middleTarget.targetID];
        return middleTarget;
      });

  // Add newest target and docs.
  DocumentKeySet newestDocsToAddToOldest{};
  _persistence.run("Add newest target and docs", [&]() {
    FSTQueryData *newestTarget = [self addNextQueryInTransaction];
    DocumentKeySet newestDocs{};
    for (int i = 0; i < 3; i++) {
      FSTDocument *doc = [self nextBigTestDocument];
      expectedRemoved.insert(doc.key);
      newestDocs = newestDocs.insert(doc.key);
      [_documentCache addEntry:doc];
    }
    // docs to add to the oldest target, will be retained
    for (int i = 3; i < 5; i++) {
      FSTDocument *doc = [self nextBigTestDocument];
      expectedRetained.insert(doc.key);
      newestDocs = newestDocs.insert(doc.key);
      newestDocsToAddToOldest = newestDocsToAddToOldest.insert(doc.key);
      [_documentCache addEntry:doc];
    }
    [_queryCache addMatchingKeys:newestDocs forTargetID:newestTarget.targetID];
  });

  // 2 doc writes, add one of them to the oldest target.
  _persistence.run("2 doc writes, add one of them to the oldest target", [&]() {
    // write two docs and have them ack'd by the server. can skip mutation queue
    // and set them in document cache. Add potentially orphaned first, also add one
    // doc to a target.
    DocumentKeySet docKeys{};

    FSTDocument *doc1 = [self nextTestDocument];
    [_documentCache addEntry:doc1];
    docKeys = docKeys.insert(doc1.key);
    DocumentKeySet firstKey = docKeys;

    FSTDocument *doc2 = [self nextTestDocument];
    [_documentCache addEntry:doc2];
    docKeys = docKeys.insert(doc2.key);

    for (const DocumentKey &key : docKeys) {
      [_persistence.referenceDelegate removeMutationReference:key];
    };

    NSData *token = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
    oldestTarget =
        [oldestTarget queryDataByReplacingSnapshotVersion:oldestTarget.snapshotVersion
                                              resumeToken:token
                                           sequenceNumber:_persistence.currentSequenceNumber];
    [_queryCache updateQueryData:oldestTarget];
    [_queryCache addMatchingKeys:firstKey forTargetID:oldestTarget.targetID];
    // nothing is keeping doc2 around, it should be removed
    expectedRemoved.insert(doc2.key);
    // doc1 should be retained by being added to oldestTarget.
    expectedRetained.insert(doc1.key);
  });

  // Remove some documents from the middle target.
  _persistence.run("Remove some documents from the middle target", [&]() {
    NSData *token = [@"token" dataUsingEncoding:NSUTF8StringEncoding];
    middleTarget =
        [middleTarget queryDataByReplacingSnapshotVersion:middleTarget.snapshotVersion
                                              resumeToken:token
                                           sequenceNumber:_persistence.currentSequenceNumber];

    [_queryCache updateQueryData:middleTarget];
    [_queryCache removeMatchingKeys:middleDocsToRemove forTargetID:middleTarget.targetID];
  });

  // Add a couple docs from the newest target to the oldest (preserves them past the point where
  // newest was removed)
  // upperBound is the sequence number right before middleTarget is updated, then removed.
  FSTListenSequenceNumber upperBound = _persistence.run(
      "Add a couple docs from the newest target to the oldest", [&]() -> FSTListenSequenceNumber {
        NSData *token = [@"add documents" dataUsingEncoding:NSUTF8StringEncoding];
        oldestTarget =
            [oldestTarget queryDataByReplacingSnapshotVersion:oldestTarget.snapshotVersion
                                                  resumeToken:token
                                               sequenceNumber:_persistence.currentSequenceNumber];
        [_queryCache updateQueryData:oldestTarget];
        [_queryCache addMatchingKeys:newestDocsToAddToOldest forTargetID:oldestTarget.targetID];
        return _persistence.currentSequenceNumber;
      });

  // Update a doc in the middle target
  _persistence.run("Update a doc in the middle target", [&]() {
    FSTTestSnapshotVersion version = 3;
    FSTDocument *doc = [FSTDocument documentWithData:_testValue
                                                 key:middleDocToUpdate
                                             version:testutil::Version(version)
                                   hasLocalMutations:NO];
    [_documentCache addEntry:doc];
    NSData *token = [@"updated" dataUsingEncoding:NSUTF8StringEncoding];
    middleTarget =
        [middleTarget queryDataByReplacingSnapshotVersion:middleTarget.snapshotVersion
                                              resumeToken:token
                                           sequenceNumber:_persistence.currentSequenceNumber];
    [_queryCache updateQueryData:middleTarget];
  });

  // middleTarget removed here, no update needed

  // Write a doc and get an ack, not part of a target
  _persistence.run("Write a doc and get an ack, not part of a target", [&]() {
    FSTDocument *doc = [self nextTestDocument];

    [_documentCache addEntry:doc];
    // This should be retained, it's too new to get removed.
    expectedRetained.insert(doc.key);
    //[queryCache addPotentiallyOrphanedDocuments:docKey atSequenceNumber:sequenceNumber];
    [_persistence.referenceDelegate removeMutationReference:doc.key];
  });

  // Finally, do the garbage collection, up to but not including the removal of middleTarget
  _persistence.run(
      "do the garbage collection, up to but not including the removal of middleTarget", [&]() {
        NSMutableDictionary<NSNumber *, FSTQueryData *> *liveQueries =
            [NSMutableDictionary dictionary];
        liveQueries[@(oldestTarget.targetID)] = oldestTarget;
        NSUInteger queriesRemoved =
            [_gc removeQueriesUpThroughSequenceNumber:upperBound liveQueries:liveQueries];
        XCTAssertEqual(1, queriesRemoved, @"Expected to remove newest target");

        NSUInteger docsRemoved = [_gc removeOrphanedDocumentsThroughSequenceNumber:upperBound];
        XCTAssertEqual(expectedRemoved.size(), docsRemoved);

        for (const DocumentKey &key : expectedRemoved) {
          XCTAssertNil([_documentCache entryForKey:key],
                       @"Did not expect to find %s in document cache", key.ToString().c_str());
          XCTAssertFalse([_queryCache containsKey:key], @"Did not expect to find %s in queryCache",
                         key.ToString().c_str());
        }
        for (const DocumentKey &key : expectedRetained) {
          XCTAssertNotNil([_documentCache entryForKey:key],
                          @"Expected to find %s in document cache", key.ToString().c_str());
        }
      });
  [_persistence shutdown];
}
@end

NS_ASSUME_NONNULL_END