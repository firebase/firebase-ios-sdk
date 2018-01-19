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
#import <Firestore/Source/Local/FSTQueryData.h>
#import "Firestore/Source/Local/FSTMemoryQueryCache.h"
#import "Firestore/Source/Local/FSTWriteGroup.h"

#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTLRUGarbageCollectorTests : XCTestCase
@end

@implementation FSTLRUGarbageCollectorTests {
  FSTListenSequenceNumber _previousSequenceNumber;
  FSTTargetID _previousTargetID;
}

- (void)setUp {
  [super setUp];

  _previousSequenceNumber = 1000;
  _previousTargetID = 500;
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

- (void)testPickSequenceNumberPercentile {
  const int numTestCases = 5;
  // 0 - number of queries to cache, 1 - number expected to be calculated as 10%
  int testCases[numTestCases][2] = {
          {0, 0},
          {10, 1},
          {9, 0},
          {50, 5},
          {49, 4}
  };

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
  NSUInteger removed = [gc removeQueriesUpThroughSequenceNumber:1015
                                                    liveQueries:liveQueries
                                                          group:group];
  XCTAssertEqual(7, removed);
  [queryCache enumerateQueryDataUsingBlock:^(FSTQueryData *queryData, BOOL *stop) {
    XCTAssertTrue(queryData.sequenceNumber > 1015 || queryData.targetID % 2 == 1);
  }];
}

@end

NS_ASSUME_NONNULL_END