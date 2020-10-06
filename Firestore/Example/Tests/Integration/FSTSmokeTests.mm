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

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

@interface FSTSmokeTests : FSTIntegrationTestCase
@end

@implementation FSTSmokeTests

- (void)testCanWriteASingleDocument {
  FIRDocumentReference *ref = [self documentRef];
  [self writeDocumentRef:ref data:[self chatMessage]];
}

- (void)testCanReadAWrittenDocument {
  NSDictionary<NSString *, id> *data = [self chatMessage];

  FIRDocumentReference *ref = [self documentRef];
  [self writeDocumentRef:ref data:data];

  FIRDocumentSnapshot *doc = [self readDocumentForRef:ref];
  XCTAssertEqualObjects(doc.data, data);
}

- (void)testObservesExistingDocument {
  [self readerAndWriterOnDocumentRef:^(FIRDocumentReference *readerRef,
                                       FIRDocumentReference *writerRef) {
    NSDictionary<NSString *, id> *data = [self chatMessage];
    [self writeDocumentRef:writerRef data:data];

    id<FIRListenerRegistration> listenerRegistration =
        [readerRef addSnapshotListener:self.eventAccumulator.valueEventHandler];

    FIRDocumentSnapshot *doc = [self.eventAccumulator awaitEventWithName:@"snapshot"];
    XCTAssertEqual([doc class], [FIRDocumentSnapshot class]);
    XCTAssertEqualObjects(doc.data, data);

    [listenerRegistration remove];
  }];
}

- (void)testObservesNewDocument {
  [self readerAndWriterOnDocumentRef:^(FIRDocumentReference *readerRef,
                                       FIRDocumentReference *writerRef) {
    id<FIRListenerRegistration> listenerRegistration =
        [readerRef addSnapshotListener:self.eventAccumulator.valueEventHandler];

    FIRDocumentSnapshot *doc1 = [self.eventAccumulator awaitEventWithName:@"null snapshot"];
    XCTAssertFalse(doc1.exists);
    // TODO(b/36366944): add tests for doc1.path)

    NSDictionary<NSString *, id> *data = [self chatMessage];
    [self writeDocumentRef:writerRef data:data];

    FIRDocumentSnapshot *doc2 = [self.eventAccumulator awaitEventWithName:@"full snapshot"];
    XCTAssertEqual([doc2 class], [FIRDocumentSnapshot class]);
    XCTAssertEqualObjects(doc2.data, data);

    [listenerRegistration remove];
  }];
}

- (void)testWillFireValueEventsForEmptyCollections {
  FIRCollectionReference *collection = [self.db collectionWithPath:@"empty-collection"];
  id<FIRListenerRegistration> listenerRegistration =
      [collection addSnapshotListener:self.eventAccumulator.valueEventHandler];

  FIRQuerySnapshot *snap = [self.eventAccumulator awaitEventWithName:@"empty query snapshot"];
  XCTAssertEqual([snap class], [FIRQuerySnapshot class]);
  XCTAssertEqual(snap.count, 0);

  [listenerRegistration remove];
}

- (void)testGetCollectionQuery {
  NSDictionary<NSString *, id> *testDocs = @{
    @"1" : @{@"name" : @"Patryk", @"message" : @"Real data, yo!"},
    @"2" : @{@"name" : @"Gil", @"message" : @"Yep!"},
    @"3" : @{@"name" : @"Jonny", @"message" : @"Back to work!"},
  };

  FIRCollectionReference *docs = [self collectionRefWithDocuments:testDocs];
  FIRQuerySnapshot *result = [self readDocumentSetForRef:docs];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result),
                        (@[ testDocs[@"1"], testDocs[@"2"], testDocs[@"3"] ]));
}

// TODO(klimt): This test is disabled because we can't create compound indexes programmatically.
- (void)xtestQueryByFieldAndUseOrderBy {
  NSDictionary<NSString *, id> *testDocs = @{
    @"1" : @{@"sort" : @1, @"filter" : @YES, @"key" : @"1"},
    @"2" : @{@"sort" : @2, @"filter" : @YES, @"key" : @"2"},
    @"3" : @{@"sort" : @2, @"filter" : @YES, @"key" : @"3"},
    @"4" : @{@"sort" : @3, @"filter" : @NO, @"key" : @"4"}
  };

  FIRCollectionReference *coll = [self collectionRefWithDocuments:testDocs];

  FIRQuery *query = [[coll queryWhereField:@"filter" isEqualTo:@YES] queryOrderedByField:@"sort"
                                                                              descending:YES];
  FIRQuerySnapshot *result = [self readDocumentSetForRef:query];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result),
                        (@[ testDocs[@"2"], testDocs[@"3"], testDocs[@"1"] ]));
}

- (NSDictionary<NSString *, id> *)chatMessage {
  return @{@"name" : @"Patryk", @"message" : @"We are actually writing data!"};
}

@end
