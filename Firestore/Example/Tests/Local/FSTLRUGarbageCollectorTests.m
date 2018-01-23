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

#import <XCTest/XCTest.h>
#import "Firestore/Source/Core/FSTTimestamp.h"
#import "Firestore/Source/Local/FSTMemoryMutationQueue.h"
#import "Firestore/Source/Local/FSTMemoryQueryCache.h"
#import "Firestore/Source/Local/FSTMemoryRemoteDocumentCache.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Local/FSTWriteGroup.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTMutation.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTLRUGarbageCollectorTests : XCTestCase
@end

@implementation FSTLRUGarbageCollectorTests {
  FSTListenSequenceNumber _previousSequenceNumber;
  FSTTargetID _previousTargetID;
  NSUInteger _previousDocNum;
  FSTObjectValue* _testValue;
}

- (void)setUp {
  [super setUp];

  _previousSequenceNumber = 1000;
  _previousTargetID = 500;
  _previousDocNum = 10;
  _testValue = FSTTestObjectValue(@{ @"baz" : @YES, @"ok" : @"fine" });
}

- (FSTQueryData *)nextTestQuery {
  FSTTargetID targetID = ++_previousTargetID;
  FSTListenSequenceNumber listenSequenceNumber = ++_previousSequenceNumber;
  FSTQuery *query = FSTTestQuery([NSString stringWithFormat:@"path%i", targetID]);
  return [[FSTQueryData alloc] initWithQuery:query
                                    targetID:targetID
                        listenSequenceNumber:listenSequenceNumber
                                     purpose:FSTQueryPurposeListen];
}

- (FSTDocumentKey *)nextTestDocKey {
  NSString *path = [NSString stringWithFormat:@"docs/doc_%lu", (unsigned long)++_previousDocNum];
  return FSTTestDocKey(path);
}

- (FSTDocument *)nextTestDocument {
  FSTDocumentKey *key = [self nextTestDocKey];
  FSTTestSnapshotVersion version = 2;
  BOOL hasMutations = NO;
  return [FSTDocument documentWithData:_testValue
                                   key:key
                               version:FSTTestVersion(version)
                     hasLocalMutations:hasMutations];
}

- (void)testPickSequenceNumberPercentile {
  const int numTestCases = 5;
  // 0 - number of queries to cache, 1 - number expected to be calculated as 10%
  int testCases[numTestCases][2] = {{0, 0}, {10, 1}, {9, 0}, {50, 5}, {49, 4}};

  for (int i = 0; i < numTestCases; i++) {
    // Fill the query cache.
    FSTWriteGroup *group = [FSTWriteGroup groupWithAction:@"Ignored"];
    int numQueries = testCases[i][0];
    int expectedTenthPercentile = testCases[i][1];
    FSTMemoryQueryCache *queryCache = [[FSTMemoryQueryCache alloc] init];
    for (int j = 0; j < numQueries; j++) {
      [queryCache addQueryData:[self nextTestQuery] group:group];
    }

    FSTLRUGarbageCollector *gc = [[FSTLRUGarbageCollector alloc] initWithQueryCache:queryCache];
    FSTListenSequenceNumber tenth = [gc queryCountForPercentile:10];
    XCTAssertEqual(expectedTenthPercentile, tenth, @"Total query count: %i", numQueries);
  }
}

- (void)testSequenceNumberForQueryCount {
  // Sequence numbers in this test start at 1001 and are incremented by one.

  // No queries... should get invalid sequence number (-1)
  {
    FSTMemoryQueryCache *queryCache = [[FSTMemoryQueryCache alloc] init];
    FSTLRUGarbageCollector *gc = [[FSTLRUGarbageCollector alloc] initWithQueryCache:queryCache];
    FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:0];
    XCTAssertEqual(kFSTListenSequenceNumberInvalid, highestToCollect);
  }

  // 50 queries, want 10. Should get 1010.
  {
    _previousSequenceNumber = 1000;
    FSTMemoryQueryCache *queryCache = [[FSTMemoryQueryCache alloc] init];
    FSTLRUGarbageCollector *gc = [[FSTLRUGarbageCollector alloc] initWithQueryCache:queryCache];
    FSTWriteGroup *group = [FSTWriteGroup groupWithAction:@"Ignored"];
    for (int i = 0; i < 50; i++) {
      [queryCache addQueryData:[self nextTestQuery] group:group];
    }
    FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
    XCTAssertEqual(1010, highestToCollect);
  }

  // 50 queries, 9 with 1001, incrementing from there. Should get 1002.
  {
    _previousSequenceNumber = 1000;
    FSTMemoryQueryCache *queryCache = [[FSTMemoryQueryCache alloc] init];
    FSTLRUGarbageCollector *gc = [[FSTLRUGarbageCollector alloc] initWithQueryCache:queryCache];
    FSTWriteGroup *group = [FSTWriteGroup groupWithAction:@"Ignored"];
    for (int i = 0; i < 9; i++) {
      [queryCache addQueryData:[self nextTestQuery] group:group];
      _previousSequenceNumber = 1000;
    }
    _previousSequenceNumber = 1001;
    for (int i = 9; i < 50; i++) {
      [queryCache addQueryData:[self nextTestQuery] group:group];
    }
    FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
    XCTAssertEqual(1002, highestToCollect);
  }

  // 50 queries, 11 with 1001, incrementing from there. Should get 1001.
  {
    _previousSequenceNumber = 1000;
    FSTMemoryQueryCache *queryCache = [[FSTMemoryQueryCache alloc] init];
    FSTLRUGarbageCollector *gc = [[FSTLRUGarbageCollector alloc] initWithQueryCache:queryCache];
    FSTWriteGroup *group = [FSTWriteGroup groupWithAction:@"Ignored"];
    for (int i = 0; i < 11; i++) {
      [queryCache addQueryData:[self nextTestQuery] group:group];
      _previousSequenceNumber = 1000;
    }
    _previousSequenceNumber = 1001;
    for (int i = 11; i < 50; i++) {
      [queryCache addQueryData:[self nextTestQuery] group:group];
    }
    FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
    XCTAssertEqual(1001, highestToCollect);
  }

  // A mutated doc at 1000, 50 queries 1001-1050. Should get 1009.
  {
    _previousSequenceNumber = 1000;
    FSTMemoryQueryCache *queryCache = [[FSTMemoryQueryCache alloc] init];
    FSTLRUGarbageCollector *gc = [[FSTLRUGarbageCollector alloc] initWithQueryCache:queryCache];
    FSTWriteGroup *group = [FSTWriteGroup groupWithAction:@"Ignored"];
    FSTDocumentKey *key = [self nextTestDocKey];
    FSTDocumentKeySet *set = [[FSTDocumentKeySet keySet] setByAddingObject:key];
    [queryCache addMutatedDocuments:set atSequenceNumber:1000 group:group];
    for (int i = 0; i < 50; i++) {
      [queryCache addQueryData:[self nextTestQuery] group:group];
    }
    FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
    XCTAssertEqual(1009, highestToCollect);
  }

  // Add mutated docs, then add one of them to a query target so it doesn't get GC'd.
  // Expect 1002.
  {
    _previousSequenceNumber = 1000;
    FSTMemoryQueryCache *queryCache = [[FSTMemoryQueryCache alloc] init];
    FSTLRUGarbageCollector *gc = [[FSTLRUGarbageCollector alloc] initWithQueryCache:queryCache];
    FSTWriteGroup *group = [FSTWriteGroup groupWithAction:@"Ignored"];
    FSTDocument *docInQuery = [self nextTestDocument];
    FSTDocumentKeySet *set = [[FSTDocumentKeySet keySet] setByAddingObject:docInQuery.key];
    FSTDocumentKeySet *docInQuerySet = set;
    for (int i = 0; i < 8; i++) {
      set = [set setByAddingObject:[self nextTestDocKey]];
    }
    // Adding 9 doc keys at 1000. If we remove one of them, we'll have room for two actual queries.
    [queryCache addMutatedDocuments:set atSequenceNumber:1000 group:group];
    for (int i = 0; i < 49; i++) {
      [queryCache addQueryData:[self nextTestQuery] group:group];
    }
    FSTQueryData *queryData = [self nextTestQuery];
    [queryCache addQueryData:queryData group:group];
    // This should bump one document out of the mutated documents cache.
    [queryCache addMatchingKeys:docInQuerySet forTargetID:queryData.targetID group:group];

    // This should catch the remaining 8 documents, plus the first two queries we added.
    FSTListenSequenceNumber highestToCollect = [gc sequenceNumberForQueryCount:10];
    XCTAssertEqual(1002, highestToCollect);
  }
}

- (void)testRemoveQueriesUpThroughSequenceNumber {
  FSTMemoryQueryCache *queryCache = [[FSTMemoryQueryCache alloc] init];
  FSTLRUGarbageCollector *gc = [[FSTLRUGarbageCollector alloc] initWithQueryCache:queryCache];
  FSTWriteGroup *group = [FSTWriteGroup groupWithAction:@"Ignored"];
  NSMutableDictionary<NSNumber *, FSTQueryData *> *liveQueries = [[NSMutableDictionary alloc] init];
  for (int i = 0; i < 100; i++) {
    FSTQueryData *queryData = [self nextTestQuery];
    // Mark odd queries as live so we can test filtering out live queries.
    if (queryData.targetID % 2 == 1) {
      liveQueries[@(queryData.targetID)] = queryData;
    }
    [queryCache addQueryData:queryData group:group];
  }

  // GC up through 1015, which is 15%.
  // Expect to have GC'd 7 targets (even values of 1001-1015).
  FSTWriteGroup *gcGroup = [FSTWriteGroup groupWithAction:@"gc"];
  NSUInteger removed =
      [gc removeQueriesUpThroughSequenceNumber:1015 liveQueries:liveQueries group:gcGroup];
  XCTAssertEqual(7, removed);
}

- (void)testRemoveOrphanedDocuments {
  FSTMemoryQueryCache *queryCache = [[FSTMemoryQueryCache alloc] init];
  FSTMemoryRemoteDocumentCache *documentCache = [[FSTMemoryRemoteDocumentCache alloc] init];
  FSTMemoryMutationQueue *mutationQueue = [[FSTMemoryMutationQueue alloc] init];
  FSTLRUGarbageCollector *gc = [[FSTLRUGarbageCollector alloc] initWithQueryCache:queryCache];
  FSTWriteGroup *group = [FSTWriteGroup groupWithAction:@"Ignored"];
  [mutationQueue startWithGroup:group];

  // Add docs to mutation queue, as well as keep some queries. verify that correct documents are
  // removed.
  NSMutableSet<FSTDocumentKey *> *toBeRetained = [NSMutableSet set];

  NSMutableArray *mutations = [NSMutableArray arrayWithCapacity:2];
  // Add two documents to first target, and register a mutation on the second one
  {
    FSTQueryData *queryData = [self nextTestQuery];
    [queryCache addQueryData:queryData group:group];
    FSTDocumentKeySet *keySet = [FSTImmutableSortedSet keySet];
    FSTDocument *doc1 = [self nextTestDocument];
    [documentCache addEntry:doc1 group:group];
    keySet = [keySet setByAddingObject:doc1.key];
    [toBeRetained addObject:doc1.key];
    FSTDocument *doc2 = [self nextTestDocument];
    [documentCache addEntry:doc2 group:group];
    keySet = [keySet setByAddingObject:doc2.key];
    [toBeRetained addObject:doc2.key];
    [queryCache addMatchingKeys:keySet forTargetID:queryData.targetID group:group];

    FSTObjectValue *newValue = [[FSTObjectValue alloc] initWithDictionary:@{@"foo" : @"@bar"}];
    [mutations addObject:[[FSTSetMutation alloc] initWithKey:doc2.key
                                                       value:newValue
                                                precondition:[FSTPrecondition none]]];
  }

  // Add one document to the second target
  {
    FSTQueryData *queryData = [self nextTestQuery];
    [queryCache addQueryData:queryData group:group];
    FSTDocumentKeySet *keySet = [FSTImmutableSortedSet keySet];
    FSTDocument *doc1 = [self nextTestDocument];
    [documentCache addEntry:doc1 group:group];
    keySet = [keySet setByAddingObject:doc1.key];
    [toBeRetained addObject:doc1.key];
    [queryCache addMatchingKeys:keySet forTargetID:queryData.targetID group:group];
  }

  {
    FSTDocument *doc1 = [self nextTestDocument];
    [mutations addObject:[[FSTSetMutation alloc] initWithKey:doc1.key
                                                       value:doc1.data
                                                precondition:[FSTPrecondition none]]];
    [documentCache addEntry:doc1 group:group];
    [toBeRetained addObject:doc1.key];
  }

  FSTTimestamp *writeTime = [FSTTimestamp timestamp];
  [mutationQueue addMutationBatchWithWriteTime:writeTime mutations:mutations group:group];

  // Now add the docs we expect to get resolved.
  NSUInteger expectedRemoveCount = 5;
  NSMutableSet<FSTDocumentKey *> *toBeRemoved = [NSMutableSet setWithCapacity:expectedRemoveCount];
  for (int i = 0; i < expectedRemoveCount; i++) {
    FSTDocument *doc = [self nextTestDocument];
    [toBeRemoved addObject:doc.key];
    [documentCache addEntry:doc group:group];
  }

  FSTWriteGroup *gcGroup = [FSTWriteGroup groupWithAction:@"gc"];
  NSUInteger removed =
      [gc removeOrphanedDocuments:documentCache mutationQueue:mutationQueue group:gcGroup];

  XCTAssertEqual(expectedRemoveCount, removed);
  for (FSTDocumentKey *key in toBeRemoved) {
    XCTAssertNil([documentCache entryForKey:key]);
  }
  for (FSTDocumentKey *key in toBeRetained) {
    XCTAssertNotNil([documentCache entryForKey:key], @"Missing document %@", key);
  }
}

@end

NS_ASSUME_NONNULL_END