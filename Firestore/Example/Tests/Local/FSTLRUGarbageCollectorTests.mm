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
#import <absl/strings/str_cat.h>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"
#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Local/FSTQueryCache.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Util/FSTClasses.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

using firebase::firestore::auth::User;
using firebase::firestore::model::Precondition;
namespace testutil = firebase::firestore::testutil;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTLRUGarbageCollectorTests {
  FSTListenSequenceNumber _previousSequenceNumber;
  FSTTargetID _previousTargetID;
  NSUInteger _previousDocNum;
  FSTObjectValue *_testValue;
  FSTObjectValue *_bigObjectValue;
}

- (id<FSTPersistence>)newPersistence {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (long)compactedSize:(id<FSTPersistence>)persistence {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (FSTLRUGarbageCollector *)gcForPersistence:(id<FSTPersistence>)persistence {
  id<FSTLRUDelegate> delegate = (id<FSTLRUDelegate>)persistence.referenceDelegate;
  return delegate.gc;
}

- (void)setUp {
  [super setUp];

  _previousSequenceNumber = 1000;
  _previousTargetID = 500;
  _previousDocNum = 10;
  _testValue = FSTTestObjectValue(@{ @"baz" : @YES, @"ok" : @"fine" });
  NSString *bigString = [@"" stringByPaddingToLength:4096 withString:@"a" startingAtIndex:0];
  _bigObjectValue = FSTTestObjectValue(@{
          @"BigProperty": bigString
  });
}

- (BOOL)isTestBaseClass {
  return ([self class] == [FSTLRUGarbageCollectorTests class]);
}

- (FSTListenSequenceNumber)nextSequenceNumber {
  return ++_previousSequenceNumber;
}

- (FSTQueryData *)nextTestQuery {
  FSTTargetID targetID = ++_previousTargetID;
  FSTListenSequenceNumber listenSequenceNumber = [self nextSequenceNumber];
  FSTQuery *query = FSTTestQuery(absl::StrCat("path", targetID));
  return [[FSTQueryData alloc] initWithQuery:query
                                    targetID:targetID
                        listenSequenceNumber:listenSequenceNumber
                                     purpose:FSTQueryPurposeListen];
}

- (FSTDocumentKey *)nextTestDocKey {
  NSString *path = [NSString stringWithFormat:@"docs/doc_%lu", (unsigned long)++_previousDocNum];
  return FSTTestDocKey(path);
}

- (FSTDocument *)nextTestDocumentWithValue:(FSTObjectValue *)value {
  FSTDocumentKey *key = [self nextTestDocKey];
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
    id<FSTPersistence> persistence = [self newPersistence];
    persistence.run("testPickSequenceNumberPercentile" + std::to_string(i), [&]() {
      id<FSTQueryCache> queryCache = [persistence queryCache];
      [queryCache start];
      for (int j = 0; j < numQueries; j++) {
        [queryCache addQueryData:[self nextTestQuery]];
      }
      FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
      FSTListenSequenceNumber tenth = [gc queryCountForPercentile:10];
      XCTAssertEqual(expectedTenthPercentile, tenth, @"Total query count: %i", numQueries);
    });

    // TODO(gsoltis): technically should shutdown query cache, but it doesn't do anything anymore.
    [persistence shutdown];
  }
}

- (void)testSequenceNumberForQueryCount {
  if ([self isTestBaseClass]) return;

  // Sequence numbers in this test start at 1001 and are incremented by one.

  // No queries... should get invalid sequence number (-1)
  {
    id<FSTPersistence> persistence = [self newPersistence];
    persistence.run("no queries", [&]() {
      id<FSTQueryCache> queryCache = [persistence queryCache];
      [queryCache start];
      FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
      FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:0];
      XCTAssertEqual(kFSTListenSequenceNumberInvalid, highestToCollect);
    });
    [persistence shutdown];
  }

  // 50 queries, want 10. Should get 1010.
  {
    _previousSequenceNumber = 1000;
    id<FSTPersistence> persistence = [self newPersistence];
    persistence.run("50 queries, want 10. Should get 1010.", [&]() {
      id<FSTQueryCache> queryCache = [persistence queryCache];
      [queryCache start];
      FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
      for (int i = 0; i < 50; i++) {
        [queryCache addQueryData:[self nextTestQuery]];
      }
      FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
      XCTAssertEqual(1010, highestToCollect);
    });
    [persistence shutdown];
  }

  // 50 queries, 9 with 1001, incrementing from there. Should get 1002.
  {
    _previousSequenceNumber = 1000;
    id<FSTPersistence> persistence = [self newPersistence];
    persistence.run("50 queries, 9 with 1001, incrementing from there. Should get 1002.", [&]() {
      id<FSTQueryCache> queryCache = [persistence queryCache];
      [queryCache start];
      FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
      for (int i = 0; i < 9; i++) {
        [queryCache addQueryData:[self nextTestQuery]];
        _previousSequenceNumber = 1000;
      }
      _previousSequenceNumber = 1001;
      for (int i = 9; i < 50; i++) {
        [queryCache addQueryData:[self nextTestQuery]];
      }
      FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
      XCTAssertEqual(1002, highestToCollect);
    });
    [persistence shutdown];
  }

  // 50 queries, 11 with 1001, incrementing from there. Should get 1001.
  {
    _previousSequenceNumber = 1000;
    id<FSTPersistence> persistence = [self newPersistence];
    persistence.run("50 queries, 11 with 1001, incrementing from there. Should get 1001.", [&]() {
      id<FSTQueryCache> queryCache = [persistence queryCache];
      [queryCache start];
      FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
      for (int i = 0; i < 11; i++) {
        [queryCache addQueryData:[self nextTestQuery]];
        _previousSequenceNumber = 1000;
      }
      _previousSequenceNumber = 1001;
      for (int i = 11; i < 50; i++) {
        [queryCache addQueryData:[self nextTestQuery]];
      }
      FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
      XCTAssertEqual(1001, highestToCollect);
    });
    [persistence shutdown];
  }

  // A mutated doc at 1000, 50 queries 1001-1050. Should get 1009.
  {
    _previousSequenceNumber = 1000;
    id<FSTPersistence> persistence = [self newPersistence];
    persistence.run("A mutated doc at 1000, 50 queries 1001-1050. Should get 1009.", [&]() {
      id<FSTQueryCache> queryCache = [persistence queryCache];
      [queryCache start];
      FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
      FSTDocumentKey *key = [self nextTestDocKey];
      [persistence.referenceDelegate removeMutationReference:key sequenceNumber:1000];
      for (int i = 0; i < 50; i++) {
        [queryCache addQueryData:[self nextTestQuery]];
      }
      FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
      XCTAssertEqual(1009, highestToCollect);
    });
    [persistence shutdown];
  }

  // Add mutated docs, then add one of them to a query target so it doesn't get GC'd.
  // Expect 1002.
  {
    _previousSequenceNumber = 1000;
    id<FSTPersistence> persistence = [self newPersistence];
    persistence.run(
        "Add mutated docs, then add one of them to a query target so it doesn't get GC'd. Expect "
        "1002",
        [&]() {
          id<FSTQueryCache> queryCache = [persistence queryCache];
          [queryCache start];
          FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
          FSTDocument *docInQuery = [self nextTestDocument];
          FSTDocumentKeySet *docInQuerySet = [[FSTDocumentKeySet keySet] setByAddingObject:docInQuery.key];
          [persistence.referenceDelegate removeMutationReference:docInQuery.key sequenceNumber:1000];
          for (int i = 0; i < 8; i++) {
            [persistence.referenceDelegate removeMutationReference:[self nextTestDocKey] sequenceNumber:1000];
          }
          // Adding 9 doc keys at 1000. If we remove one of them, we'll have room for two actual
          // queries.
          for (int i = 0; i < 49; i++) {
            [queryCache addQueryData:[self nextTestQuery]];
          }
          FSTQueryData *queryData = [self nextTestQuery];
          [queryCache addQueryData:queryData];
          // This should bump one document out of the mutated documents cache.
          [queryCache addMatchingKeys:docInQuerySet
                          forTargetID:queryData.targetID
                     atSequenceNumber:queryData.sequenceNumber];
          // This should catch the remaining 8 documents, plus the first two queries we added.
          FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
          XCTAssertEqual(1002, highestToCollect);
        });
    [persistence shutdown];
  }
}

- (void)testRemoveQueriesUpThroughSequenceNumber {
  if ([self isTestBaseClass]) return;

  id<FSTPersistence> persistence = [self newPersistence];
  persistence.run("testRemoveQueriesUpThroughSequenceNumber", [&]() {
    id<FSTQueryCache> queryCache = [persistence queryCache];
    [queryCache start];
    FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
    NSMutableDictionary<NSNumber *, FSTQueryData *> *liveQueries =
        [[NSMutableDictionary alloc] init];
    for (int i = 0; i < 100; i++) {
      FSTQueryData *queryData = [self nextTestQuery];
      // Mark odd queries as live so we can test filtering out live queries.
      if (queryData.targetID % 2 == 1) {
        liveQueries[@(queryData.targetID)] = queryData;
      }
      [queryCache addQueryData:queryData];
    }

    // GC up through 1015, which is 15%.
    // Expect to have GC'd 7 targets (even values of 1001-1015).
    NSUInteger removed = [gc removeQueriesUpThroughSequenceNumber:1015 liveQueries:liveQueries];
    XCTAssertEqual(7, removed);
  });
  [persistence shutdown];
}

- (void)testRemoveOrphanedDocuments {
  if ([self isTestBaseClass]) return;

  id<FSTPersistence> persistence = [self newPersistence];
  persistence.run("testRemoveOrphanedDocuments", [&]() {
    id<FSTQueryCache> queryCache = [persistence queryCache];
    [queryCache start];
    id<FSTRemoteDocumentCache> documentCache = [persistence remoteDocumentCache];
    User user("user");
    id<FSTMutationQueue> mutationQueue = [persistence mutationQueueForUser:user];
    FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
    [mutationQueue start];

    // Add docs to mutation queue, as well as keep some queries. verify that correct documents are
    // removed.
    NSMutableSet<FSTDocumentKey *> *toBeRetained = [NSMutableSet set];

    NSMutableArray *mutations = [NSMutableArray arrayWithCapacity:2];
    // Add two documents to first target, and register a mutation on the second one
    {
      FSTQueryData *queryData = [self nextTestQuery];
      [queryCache addQueryData:queryData];
      FSTDocumentKeySet *keySet = [FSTImmutableSortedSet keySet];
      FSTDocument *doc1 = [self nextTestDocument];
      [documentCache addEntry:doc1];
      keySet = [keySet setByAddingObject:doc1.key];
      [toBeRetained addObject:doc1.key];
      FSTDocument *doc2 = [self nextTestDocument];
      [documentCache addEntry:doc2];
      keySet = [keySet setByAddingObject:doc2.key];
      [toBeRetained addObject:doc2.key];
      [queryCache addMatchingKeys:keySet
                      forTargetID:queryData.targetID
                 atSequenceNumber:queryData.sequenceNumber];

      FSTObjectValue *newValue = [[FSTObjectValue alloc]
          initWithDictionary:@{@"foo" : [FSTStringValue stringValue:@"bar"]}];
      [mutations addObject:[[FSTSetMutation alloc] initWithKey:doc2.key
                                                         value:newValue
                                                  precondition:Precondition::None()]];
    }

    // Add one document to the second target
    {
      FSTQueryData *queryData = [self nextTestQuery];
      [queryCache addQueryData:queryData];
      FSTDocumentKeySet *keySet = [FSTImmutableSortedSet keySet];
      FSTDocument *doc1 = [self nextTestDocument];
      [documentCache addEntry:doc1];
      keySet = [keySet setByAddingObject:doc1.key];
      [toBeRetained addObject:doc1.key];
      [queryCache addMatchingKeys:keySet
                      forTargetID:queryData.targetID
                 atSequenceNumber:queryData.sequenceNumber];
    }

    {
      FSTDocument *doc1 = [self nextTestDocument];
      [mutations addObject:[[FSTSetMutation alloc] initWithKey:doc1.key
                                                         value:doc1.data
                                                  precondition:Precondition::None()]];
      [documentCache addEntry:doc1];
      [toBeRetained addObject:doc1.key];
    }

    FIRTimestamp *writeTime = [FIRTimestamp timestamp];
    [mutationQueue addMutationBatchWithWriteTime:writeTime mutations:mutations];

    // Now add the docs we expect to get resolved.
    NSUInteger expectedRemoveCount = 5;
    NSMutableSet<FSTDocumentKey *> *toBeRemoved =
        [NSMutableSet setWithCapacity:expectedRemoveCount];
    FSTDocumentKeySet *removedSet = [FSTDocumentKeySet keySet];
    for (int i = 0; i < expectedRemoveCount; i++) {
      FSTDocument *doc = [self nextTestDocument];
      [toBeRemoved addObject:doc.key];
      [documentCache addEntry:doc];
      removedSet = [removedSet setByAddingObject:doc.key];
      [persistence.referenceDelegate removeMutationReference:doc.key
                                              sequenceNumber:1000];
    }
    //[queryCache addPotentiallyOrphanedDocuments:removedSet atSequenceNumber:1000];
    NSUInteger removed = [gc removeOrphanedDocuments:documentCache
                               throughSequenceNumber:1000
                                       mutationQueue:mutationQueue];

    XCTAssertEqual(expectedRemoveCount, removed);
    for (FSTDocumentKey *key in toBeRemoved) {
      XCTAssertNil([documentCache entryForKey:key]);
      XCTAssertFalse([queryCache containsKey:key]);
    }
    for (FSTDocumentKey *key in toBeRetained) {
      XCTAssertNotNil([documentCache entryForKey:key], @"Missing document %@", key);
    }
  });
  [persistence shutdown];
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

  id<FSTPersistence> persistence = [self newPersistence];
  User user("user");
  id<FSTMutationQueue> mutationQueue = [persistence mutationQueueForUser:user];
  id<FSTQueryCache> queryCache = [persistence queryCache];
  id<FSTRemoteDocumentCache> documentCache = [persistence remoteDocumentCache];

  NSMutableSet<FSTDocumentKey *> *expectedRetained = [NSMutableSet set];
  NSMutableSet<FSTDocumentKey *> *expectedRemoved = [NSMutableSet set];

  // Add oldest target and docs
  FSTQueryData *oldestTarget = [self nextTestQuery];
  persistence.run("Add oldest target and docs", [&]() {
    FSTDocumentKeySet *oldestDocs = [FSTDocumentKeySet keySet];

    for (int i = 0; i < 5; i++) {
      FSTDocument *doc = [self nextTestDocument];
      [expectedRetained addObject:doc.key];
      oldestDocs = [oldestDocs setByAddingObject:doc.key];
      [documentCache addEntry:doc];
    }

    [queryCache addQueryData:oldestTarget];
    [queryCache addMatchingKeys:oldestDocs
                    forTargetID:oldestTarget.targetID
               atSequenceNumber:oldestTarget.sequenceNumber];
  });

  // Add middle target and docs. Some docs will be removed from this target later.
  FSTQueryData *middleTarget = [self nextTestQuery];
  FSTDocumentKeySet *middleDocsToRemove = [FSTDocumentKeySet keySet];
  FSTDocumentKey *middleDocToUpdate = nil;
  persistence.run("Add middle target and docs", [&]() {
    [queryCache addQueryData:middleTarget];
    FSTDocumentKeySet *middleDocs = [FSTDocumentKeySet keySet];
    // these docs will be removed from this target later
    for (int i = 0; i < 2; i++) {
      FSTDocument *doc = [self nextTestDocument];
      [expectedRemoved addObject:doc.key];
      middleDocs = [middleDocs setByAddingObject:doc.key];
      [documentCache addEntry:doc];
      middleDocsToRemove = [middleDocsToRemove setByAddingObject:doc.key];
    }
    // these docs stay in this target and only this target
    for (int i = 2; i < 4; i++) {
      FSTDocument *doc = [self nextTestDocument];
      [expectedRetained addObject:doc.key];
      middleDocs = [middleDocs setByAddingObject:doc.key];
      [documentCache addEntry:doc];
    }
    // This doc stays in this target, but gets updated
    {
      FSTDocument *doc = [self nextTestDocument];
      [expectedRetained addObject:doc.key];
      middleDocs = [middleDocs setByAddingObject:doc.key];
      [documentCache addEntry:doc];
      middleDocToUpdate = doc.key;
    }
    [queryCache addMatchingKeys:middleDocs
                    forTargetID:middleTarget.targetID
               atSequenceNumber:middleTarget.sequenceNumber];

  });

  // Add newest target and docs.
  FSTQueryData *newestTarget = [self nextTestQuery];
  FSTDocumentKeySet *newestDocsToAddToOldest = [FSTDocumentKeySet keySet];
  persistence.run("Add newest target and docs", [&]() {
    [queryCache addQueryData:newestTarget];
    FSTDocumentKeySet *newestDocs = [FSTDocumentKeySet keySet];
    for (int i = 0; i < 3; i++) {
      FSTDocument *doc = [self nextBigTestDocument];
      [expectedRemoved addObject:doc.key];
      newestDocs = [newestDocs setByAddingObject:doc.key];
      [documentCache addEntry:doc];
    }
    // docs to add to the oldest target, will be retained
    for (int i = 3; i < 5; i++) {
      FSTDocument *doc = [self nextBigTestDocument];
      [expectedRetained addObject:doc.key];
      newestDocs = [newestDocs setByAddingObject:doc.key];
      newestDocsToAddToOldest = [newestDocsToAddToOldest setByAddingObject:doc.key];
      [documentCache addEntry:doc];
    }
    [queryCache addMatchingKeys:newestDocs
                    forTargetID:newestTarget.targetID
               atSequenceNumber:newestTarget.sequenceNumber];
  });

  // newestTarget removed here, this should bump sequence number? maybe?
  // we don't really need the sequence number for anything, we just don't include it
  // in live queries.
  [self nextSequenceNumber];

  // 2 doc writes, add one of them to the oldest target.
  persistence.run("2 doc writes, add one of them to the oldest target", [&]() {
    // write two docs and have them ack'd by the server. can skip mutation queue
    // and set them in document cache. Add potentially orphaned first, also add one
    // doc to a target.
    FSTDocumentKeySet *docKeys = [FSTDocumentKeySet keySet];

    FSTDocument *doc1 = [self nextTestDocument];
    [documentCache addEntry:doc1];
    docKeys = [docKeys setByAddingObject:doc1.key];
    FSTDocumentKeySet *firstKey = docKeys;

    FSTDocument *doc2 = [self nextTestDocument];
    [documentCache addEntry:doc2];
    docKeys = [docKeys setByAddingObject:doc2.key];

    FSTListenSequenceNumber sequenceNumber = [self nextSequenceNumber];
    [docKeys enumerateObjectsUsingBlock:^(FSTDocumentKey *key, BOOL *stop) {
      [persistence.referenceDelegate removeMutationReference:key sequenceNumber:sequenceNumber];
    }];
    //[queryCache addPotentiallyOrphanedDocuments:docKeys atSequenceNumber:[self nextSequenceNumber]];

    NSData *token = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
    sequenceNumber = [self nextSequenceNumber];
    oldestTarget = [oldestTarget queryDataByReplacingSnapshotVersion:oldestTarget.snapshotVersion
                                                         resumeToken:token
                                                      sequenceNumber:sequenceNumber];
    [queryCache updateQueryData:oldestTarget];
    [queryCache addMatchingKeys:firstKey
                    forTargetID:oldestTarget.targetID
               atSequenceNumber:oldestTarget.sequenceNumber];
    // nothing is keeping doc2 around, it should be removed
    [expectedRemoved addObject:doc2.key];
    // doc1 should be retained by being added to oldestTarget.
    [expectedRetained addObject:doc1.key];
  });

  // Remove some documents from the middle target.
  persistence.run("Remove some documents from the middle target", [&]() {
    FSTListenSequenceNumber sequenceNumber = [self nextSequenceNumber];
    NSData *token = [@"token" dataUsingEncoding:NSUTF8StringEncoding];
    middleTarget = [middleTarget queryDataByReplacingSnapshotVersion:middleTarget.snapshotVersion
                                                         resumeToken:token
                                                      sequenceNumber:sequenceNumber];

    [queryCache updateQueryData:middleTarget];
    [queryCache removeMatchingKeys:middleDocsToRemove
                       forTargetID:middleTarget.targetID
                  atSequenceNumber:sequenceNumber];
  });

  // Add a couple docs from the newest target to the oldest (preserves them past the point where
  // newest was removed)
  persistence.run("Add a couple docs from the newest target to the oldest", [&]() {
    NSData *token = [@"add documents" dataUsingEncoding:NSUTF8StringEncoding];
    FSTListenSequenceNumber sequenceNumber = [self nextSequenceNumber];
    oldestTarget = [oldestTarget queryDataByReplacingSnapshotVersion:oldestTarget.snapshotVersion
                                                         resumeToken:token
                                                      sequenceNumber:sequenceNumber];
    [queryCache updateQueryData:oldestTarget];
    [queryCache addMatchingKeys:newestDocsToAddToOldest
                    forTargetID:oldestTarget.targetID
               atSequenceNumber:oldestTarget.sequenceNumber];
  });

  // the sequence number right before middleTarget is updated, then removed.
  FSTListenSequenceNumber upperBound = [self nextSequenceNumber];

  // Update a doc in the middle target
  persistence.run("Update a doc in the middle target", [&]() {
    FSTTestSnapshotVersion version = 3;
    FSTDocument *doc = [FSTDocument documentWithData:_testValue
                                                 key:middleDocToUpdate
                                             version:testutil::Version(version)
                                   hasLocalMutations:NO];
    [documentCache addEntry:doc];
    NSData *token = [@"updated" dataUsingEncoding:NSUTF8StringEncoding];
    FSTListenSequenceNumber sequenceNumber = [self nextSequenceNumber];
    middleTarget = [middleTarget queryDataByReplacingSnapshotVersion:middleTarget.snapshotVersion
                                                         resumeToken:token
                                                      sequenceNumber:sequenceNumber];
    [queryCache updateQueryData:middleTarget];
  });

  // middleTarget removed here
  [self nextSequenceNumber];

  // Write a doc and get an ack, not part of a target
  persistence.run("Write a doc and get an ack, not part of a target", [&]() {
    FSTDocument *doc = [self nextTestDocument];

    [documentCache addEntry:doc];
    FSTDocumentKeySet *docKey = [[FSTDocumentKeySet keySet] setByAddingObject:doc.key];
    // This should be retained, it's too new to get removed.
    [expectedRetained addObject:doc.key];
    FSTListenSequenceNumber sequenceNumber = [self nextSequenceNumber];
    //[queryCache addPotentiallyOrphanedDocuments:docKey atSequenceNumber:sequenceNumber];
    [persistence.referenceDelegate removeMutationReference:doc.key sequenceNumber:sequenceNumber];
  });

  long sizeBefore = [self compactedSize:persistence];

  // Finally, do the garbage collection, up to but not including the removal of middleTarget
  persistence.run(
      "do the garbage collection, up to but not including the removal of middleTarget", [&]() {
        NSMutableDictionary<NSNumber *, FSTQueryData *> *liveQueries =
            [NSMutableDictionary dictionary];
        liveQueries[@(oldestTarget.targetID)] = oldestTarget;
        FSTLRUGarbageCollector *gc = [self gcForPersistence:persistence];
        NSUInteger queriesRemoved =
            [gc removeQueriesUpThroughSequenceNumber:upperBound liveQueries:liveQueries];
        XCTAssertEqual(1, queriesRemoved, @"Expected to remove newest target");

        NSUInteger docsRemoved = [gc removeOrphanedDocuments:documentCache
                                       throughSequenceNumber:upperBound
                                               mutationQueue:mutationQueue];
        NSLog(@"Expected removed: %@", expectedRemoved);
        NSLog(@"Expected retained: %@", expectedRetained);
        XCTAssertEqual([expectedRemoved count], docsRemoved);

        for (FSTDocumentKey *key in expectedRemoved) {
          XCTAssertNil([documentCache entryForKey:key],
                       @"Did not expect to find %@ in document cache", key);
          XCTAssertFalse([queryCache containsKey:key], @"Did not expect to find %@ in queryCache",
                         key);
        }
        for (FSTDocumentKey *key in expectedRetained) {
          XCTAssertNotNil([documentCache entryForKey:key], @"Expected to find %@ in document cache",
                          key);
        }
      });

  long sizeAfter = [self compactedSize:persistence];
  // Actual size difference will vary by persistence layer. In addtion,
  // we need to compact the leveldb persistence to get a read on size at this small of
  // an amount of data.
  XCTAssertLessThan(sizeAfter, sizeBefore);
  [persistence shutdown];
}
/*
- (void)testShouldGC {
  if ([self isTestBaseClass]) return;

  id<FSTPersistence> persistence = [self newPersistence];
  id<FSTQueryCache> queryCache = [persistence queryCache];
  id<FSTRemoteDocumentCache> docCache = [persistence remoteDocumentCache];
  User user("user");
  id<FSTMutationQueue> mutationQueue = [persistence mutationQueueForUser:user];
  FSTLRUThreshold thresholds{.min_ms_since_start = 1000,
                             .max_bytes_stored = 128,
                             .min_ms_between_attempts = 500,
                             .percentile_to_gc = 10};
  FSTLRUGarbageCollector *gc =
      [[FSTLRUGarbageCollector alloc] initWithQueryCache:queryCache thresholds:thresholds now:0];
  // It's too soon, we should not GC yet.
  XCTAssertFalse([gc shouldGCAt:0 currentSize:1024]);

  XCTAssertTrue([gc shouldGCAt:1001 currentSize:1024]);

  persistence.run("gc 1", [&]() {
    [gc collectGarbageWithLiveQueries:@{} documentCache:docCache mutationQueue:mutationQueue];
  });
  NSDate *now = [NSDate date];
  long nowMs = (long)([now timeIntervalSince1970] * 1000);
  // Too recent compared to the GC we just did.
  XCTAssertFalse([gc shouldGCAt:nowMs currentSize:1024]);

  // Enough time has passed
  XCTAssertTrue([gc shouldGCAt:nowMs + 501 currentSize:1024]);

  // Enough time has passed, but the stored byte size is too small
  XCTAssertFalse([gc shouldGCAt:nowMs + 501 currentSize:10]);
}
*/
@end

NS_ASSUME_NONNULL_END