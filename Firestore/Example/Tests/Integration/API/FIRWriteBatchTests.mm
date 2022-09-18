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

#import <FirebaseFirestore/FirebaseFirestore.h>

#import <XCTest/XCTest.h>
#include <mach/mach.h>

#include <cstdint>

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

#include "Firestore/core/src/util/autoid.h"
#include "Firestore/core/src/util/sanitizers.h"
#include "Firestore/core/src/util/string_apple.h"

using firebase::firestore::util::CreateAutoId;
using firebase::firestore::util::MakeNSString;

NS_ASSUME_NONNULL_BEGIN

@interface FIRWriteBatchTests : FSTIntegrationTestCase
@end

@implementation FIRWriteBatchTests

- (void)testSupportEmptyBatches {
  XCTestExpectation *expectation = [self expectationWithDescription:@"batch written"];
  [[[self firestore] batch] commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectations];
}

- (void)testCommitWithoutCompletionHandler {
  FIRDocumentReference *doc = [self documentRef];
  FIRWriteBatch *batch1 = [doc.firestore batch];
  [batch1 setData:@{@"aa" : @"bb"} forDocument:doc];
  [batch1 commitWithCompletion:nil];
  FIRDocumentSnapshot *snapshot1 = [self readDocumentForRef:doc];
  XCTAssertTrue(snapshot1.exists);
  XCTAssertEqualObjects(snapshot1.data, @{@"aa" : @"bb"});

  FIRWriteBatch *batch2 = [doc.firestore batch];
  [batch2 setData:@{@"cc" : @"dd"} forDocument:doc];
  [batch2 commit];

  // TODO(b/70631617): There's currently a backend bug that prevents us from using a resume token
  // right away (against hexa at least). So we sleep. :-( :-( Anything over ~10ms seems to be
  // sufficient.
  [NSThread sleepForTimeInterval:0.2f];

  FIRDocumentSnapshot *snapshot2 = [self readDocumentForRef:doc];
  XCTAssertTrue(snapshot2.exists);
  XCTAssertEqualObjects(snapshot2.data, @{@"cc" : @"dd"});
}

- (void)testSetDocuments {
  FIRDocumentReference *doc = [self documentRef];
  XCTestExpectation *batchExpectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch setData:@{@"a" : @"b"} forDocument:doc];
  [batch setData:@{@"c" : @"d"} forDocument:doc];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [batchExpectation fulfill];
  }];
  [self awaitExpectations];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertTrue(snapshot.exists);
  XCTAssertEqualObjects(snapshot.data, @{@"c" : @"d"});
}

- (void)testSetDocumentWithMerge {
  FIRDocumentReference *doc = [self documentRef];
  XCTestExpectation *batchExpectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch setData:@{@"a" : @"b", @"nested" : @{@"a" : @"b"}} forDocument:doc];
  [batch setData:@{@"c" : @"d", @"nested" : @{@"c" : @"d"}} forDocument:doc merge:YES];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [batchExpectation fulfill];
  }];
  [self awaitExpectations];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertTrue(snapshot.exists);
  XCTAssertEqualObjects(snapshot.data,
                        (@{@"a" : @"b", @"c" : @"d", @"nested" : @{@"a" : @"b", @"c" : @"d"}}));
}

- (void)testUpdateDocuments {
  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];
  XCTestExpectation *batchExpectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch updateData:@{@"baz" : @42} forDocument:doc];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [batchExpectation fulfill];
  }];
  [self awaitExpectations];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertTrue(snapshot.exists);
  XCTAssertEqualObjects(snapshot.data, (@{@"foo" : @"bar", @"baz" : @42}));
}

- (void)testCannotUpdateNonexistentDocuments {
  FIRDocumentReference *doc = [self documentRef];
  XCTestExpectation *batchExpectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch updateData:@{@"baz" : @42} forDocument:doc];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNotNil(error);
    [batchExpectation fulfill];
  }];
  [self awaitExpectations];
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertFalse(result.exists);
}

- (void)testUpdateFieldsWithDots {
  FIRDocumentReference *doc = [self documentRef];

  XCTestExpectation *expectation = [self expectationWithDescription:@"testUpdateFieldsWithDots"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch setData:@{@"a.b" : @"old", @"c.d" : @"old"} forDocument:doc];
  [batch updateData:@{[[FIRFieldPath alloc] initWithFields:@[ @"a.b" ]] : @"new"} forDocument:doc];

  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects(snapshot.data, (@{@"a.b" : @"new", @"c.d" : @"old"}));
    }];
    [expectation fulfill];
  }];

  [self awaitExpectations];
}

- (void)testUpdateNestedFields {
  FIRDocumentReference *doc = [self documentRef];

  XCTestExpectation *expectation = [self expectationWithDescription:@"testUpdateNestedFields"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch setData:@{@"a" : @{@"b" : @"old"}, @"c" : @{@"d" : @"old"}, @"e" : @{@"f" : @"old"}}
      forDocument:doc];
  [batch
       updateData:@{@"a.b" : @"new", [[FIRFieldPath alloc] initWithFields:@[ @"c", @"d" ]] : @"new"}
      forDocument:doc];
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects(snapshot.data, (@{
                              @"a" : @{@"b" : @"new"},
                              @"c" : @{@"d" : @"new"},
                              @"e" : @{@"f" : @"old"}
                            }));
    }];
    [expectation fulfill];
  }];

  [self awaitExpectations];
}

- (void)testDeleteDocuments {
  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];

  XCTAssertTrue(snapshot.exists);
  XCTestExpectation *batchExpectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch deleteDocument:doc];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [batchExpectation fulfill];
  }];
  [self awaitExpectations];
  snapshot = [self readDocumentForRef:doc];
  XCTAssertFalse(snapshot.exists);
}

- (void)testBatchesCommitAtomicallyRaisingCorrectEvents {
  FIRCollectionReference *collection = [self collectionRef];
  FIRDocumentReference *docA = [collection documentWithPath:@"a"];
  FIRDocumentReference *docB = [collection documentWithPath:@"b"];
  FSTEventAccumulator *accumulator = [FSTEventAccumulator accumulatorForTest:self];
  [collection addSnapshotListenerWithIncludeMetadataChanges:YES
                                                   listener:accumulator.valueEventHandler];
  FIRQuerySnapshot *initialSnap = [accumulator awaitEventWithName:@"initial event"];
  XCTAssertEqual(initialSnap.count, 0);

  // Atomically write two documents.
  XCTestExpectation *expectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [collection.firestore batch];
  [batch setData:@{@"a" : @1} forDocument:docA];
  [batch setData:@{@"b" : @2} forDocument:docB];
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectations];

  FIRQuerySnapshot *localSnap = [accumulator awaitEventWithName:@"local event"];
  XCTAssertTrue(localSnap.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(localSnap), (@[ @{@"a" : @1}, @{@"b" : @2} ]));

  FIRQuerySnapshot *serverSnap = [accumulator awaitEventWithName:@"server event"];
  XCTAssertFalse(serverSnap.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(serverSnap), (@[ @{@"a" : @1}, @{@"b" : @2} ]));
}

- (void)testBatchesFailAtomicallyRaisingCorrectEvents {
  FIRCollectionReference *collection = [self collectionRef];
  FIRDocumentReference *docA = [collection documentWithPath:@"a"];
  FIRDocumentReference *docB = [collection documentWithPath:@"b"];
  FSTEventAccumulator *accumulator = [FSTEventAccumulator accumulatorForTest:self];
  [collection addSnapshotListenerWithIncludeMetadataChanges:YES
                                                   listener:accumulator.valueEventHandler];
  FIRQuerySnapshot *initialSnap = [accumulator awaitEventWithName:@"initial event"];
  XCTAssertEqual(initialSnap.count, 0);

  // Atomically write 1 document and update a nonexistent document.
  XCTestExpectation *expectation = [self expectationWithDescription:@"batch failed"];
  FIRWriteBatch *batch = [collection.firestore batch];
  [batch setData:@{@"a" : @1} forDocument:docA];
  [batch updateData:@{@"b" : @2} forDocument:docB];
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeNotFound);
    [expectation fulfill];
  }];
  [self awaitExpectations];

  // Local event with the set document.
  FIRQuerySnapshot *localSnap = [accumulator awaitEventWithName:@"local event"];
  XCTAssertTrue(localSnap.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(localSnap), (@[ @{@"a" : @1} ]));

  // Server event with the set reverted.
  FIRQuerySnapshot *serverSnap = [accumulator awaitEventWithName:@"server event"];
  XCTAssertFalse(serverSnap.metadata.hasPendingWrites);
  XCTAssertEqual(serverSnap.count, 0);
}

- (void)testWriteTheSameServerTimestampAcrossWrites {
  FIRCollectionReference *collection = [self collectionRef];
  FIRDocumentReference *docA = [collection documentWithPath:@"a"];
  FIRDocumentReference *docB = [collection documentWithPath:@"b"];
  FSTEventAccumulator *accumulator = [FSTEventAccumulator accumulatorForTest:self];
  [collection addSnapshotListenerWithIncludeMetadataChanges:YES
                                                   listener:accumulator.valueEventHandler];
  FIRQuerySnapshot *initialSnap = [accumulator awaitEventWithName:@"initial event"];
  XCTAssertEqual(initialSnap.count, 0);

  // Atomically write 2 documents with server timestamps.
  XCTestExpectation *expectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [collection.firestore batch];
  [batch setData:@{@"when" : [FIRFieldValue fieldValueForServerTimestamp]} forDocument:docA];
  [batch setData:@{@"when" : [FIRFieldValue fieldValueForServerTimestamp]} forDocument:docB];
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectations];

  FIRQuerySnapshot *localSnap = [accumulator awaitEventWithName:@"local event"];
  XCTAssertTrue(localSnap.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(localSnap),
                        (@[ @{@"when" : [NSNull null]}, @{@"when" : [NSNull null]} ]));

  FIRQuerySnapshot *serverSnap = [accumulator awaitEventWithName:@"server event"];
  XCTAssertFalse(serverSnap.metadata.hasPendingWrites);
  XCTAssertEqual(serverSnap.count, 2);
  NSDate *when = serverSnap.documents[0][@"when"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(serverSnap),
                        (@[ @{@"when" : when}, @{@"when" : when} ]));
}

- (void)testCanWriteTheSameDocumentMultipleTimes {
  FIRDocumentReference *doc = [self documentRef];
  FSTEventAccumulator *accumulator = [FSTEventAccumulator accumulatorForTest:self];
  [doc addSnapshotListenerWithIncludeMetadataChanges:YES listener:accumulator.valueEventHandler];
  FIRDocumentSnapshot *initialSnap = [accumulator awaitEventWithName:@"initial event"];
  XCTAssertFalse(initialSnap.exists);

  XCTestExpectation *expectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch deleteDocument:doc];
  [batch setData:@{@"a" : @1, @"b" : @1, @"when" : @"when"} forDocument:doc];
  [batch updateData:@{@"b" : @2, @"when" : [FIRFieldValue fieldValueForServerTimestamp]}
        forDocument:doc];
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectations];

  FIRDocumentSnapshot *localSnap = [accumulator awaitEventWithName:@"local event"];
  XCTAssertTrue(localSnap.metadata.hasPendingWrites);
  XCTAssertEqualObjects(localSnap.data, (@{@"a" : @1, @"b" : @2, @"when" : [NSNull null]}));

  FIRDocumentSnapshot *serverSnap = [accumulator awaitEventWithName:@"server event"];
  XCTAssertFalse(serverSnap.metadata.hasPendingWrites);
  NSDate *when = serverSnap[@"when"];
  XCTAssertEqualObjects(serverSnap.data, (@{@"a" : @1, @"b" : @2, @"when" : when}));
}

- (void)testCanWriteVeryLargeBatches {
  // On Android, SQLite Cursors are limited reading no more than 2 MB per row (despite being able
  // to write very large values). This test verifies that the local MutationQueue is not subject
  // to this limitation.

  // Create a map containing nearly 1 MB of data. Note that if you use 1024 below this will create
  // a document larger than 1 MB, which will be rejected by the backend as too large.
  NSString *kb = [@"" stringByPaddingToLength:1000 withString:@"a" startingAtIndex:0];
  NSMutableDictionary<NSString *, id> *values = [NSMutableDictionary dictionary];
  for (int i = 0; i < 1000; i++) {
    values[MakeNSString(CreateAutoId())] = kb;
  }

  FIRDocumentReference *doc = [self documentRef];
  FIRWriteBatch *batch = [doc.firestore batch];

  // Write a batch containing 3 copies of the data, creating a ~3 MB batch. Writing to the same
  // document in a batch is allowed and so long as the net size of the document is under 1 MB the
  // batch is allowed.
  [batch setData:values forDocument:doc];
  for (int i = 0; i < 2; i++) {
    [batch updateData:values forDocument:doc];
  }

  XCTestExpectation *expectation = [self expectationWithDescription:@"batch written"];
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectations];

  FIRDocumentSnapshot *snap = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(values, snap.data);
}

// Returns how much memory the test application is currently using, in megabytes (fractional part is
// truncated), or -1 if the OS call fails.
// TODO(varconst): move the helper function and the test into a new test target for performance
// testing.
int64_t GetCurrentMemoryUsedInMb() {
  mach_task_basic_info taskInfo;
  mach_msg_type_number_t taskInfoSize = MACH_TASK_BASIC_INFO_COUNT;
  const auto errorCode =
      task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&taskInfo, &taskInfoSize);
  if (errorCode == KERN_SUCCESS) {
    const int bytesInMegabyte = 1024 * 1024;
    return taskInfo.resident_size / bytesInMegabyte;
  }
  return -1;
}

#if !defined(THREAD_SANITIZER) && !defined(ADDRESS_SANITIZER)
- (void)testReasonableMemoryUsageForLotsOfMutations {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testReasonableMemoryUsageForLotsOfMutations"];

  FIRDocumentReference *mainDoc = [self documentRef];
  FIRWriteBatch *batch = [mainDoc.firestore batch];

  // > 500 mutations will be rejected.
  const int maxMutations = 400;
  for (int i = 0; i != maxMutations; ++i) {
    FIRDocumentReference *nestedDoc = [[mainDoc collectionWithPath:@"nested"] documentWithAutoID];
    // The exact data doesn't matter; what is important is the large number of mutations.
    [batch setData:@{
      @"a" : @"foo",
      @"b" : @"bar",
    }
        forDocument:nestedDoc];
  }

  const int64_t memoryUsedBeforeCommitMb = GetCurrentMemoryUsedInMb();
  XCTAssertNotEqual(memoryUsedBeforeCommitMb, -1);
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    const int64_t memoryUsedAfterCommitMb = GetCurrentMemoryUsedInMb();
    XCTAssertNotEqual(memoryUsedAfterCommitMb, -1);

    // This by its nature cannot be a precise value. Runs on simulator seem to give an increase of
    // 10MB in debug mode pretty consistently. A regression would be on the scale of 500Mb.
    //
    // This check is disabled under the thread sanitizer because it introduces an overhead of
    // 5x-10x.
    XCTAssertLessThan(memoryUsedAfterCommitMb - memoryUsedBeforeCommitMb, 20);

    [expectation fulfill];
  }];
  [self awaitExpectations];
}
#endif  // #if !defined(THREAD_SANITIZER) && !defined(ADDRESS_SANITIZER)

@end

NS_ASSUME_NONNULL_END
