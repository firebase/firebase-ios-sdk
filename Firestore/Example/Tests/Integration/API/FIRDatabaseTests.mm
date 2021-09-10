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

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"

#include "Firestore/core/src/api/query_snapshot.h"
#include "Firestore/core/src/core/firestore_client.h"
#include "Firestore/core/test/unit/testutil/app_testing.h"

namespace testutil = firebase::firestore::testutil;

using firebase::firestore::util::TimerId;

@interface FIRDatabaseTests : FSTIntegrationTestCase
@end

@implementation FIRDatabaseTests

- (void)testCanUpdateAnExistingDocument {
  FIRDocumentReference *doc = [self.db documentWithPath:@"rooms/eros"];
  NSDictionary<NSString *, id> *initialData =
      @{@"desc" : @"Description", @"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}};
  NSDictionary<NSString *, id> *updateData =
      @{@"desc" : @"NewDescription", @"owner.email" : @"new@xyz.com"};
  NSDictionary<NSString *, id> *finalData =
      @{@"desc" : @"NewDescription", @"owner" : @{@"name" : @"Jonny", @"email" : @"new@xyz.com"}};

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *updateCompletion = [self expectationWithDescription:@"updateData"];
  [doc updateData:updateData
       completion:^(NSError *_Nullable error) {
         XCTAssertNil(error);
         [updateCompletion fulfill];
       }];
  [self awaitExpectations];

  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertTrue(result.exists);
  XCTAssertEqualObjects(result.data, finalData);
}

- (void)testEqualityComparison {
  FIRDocumentReference *doc = [self.db documentWithPath:@"rooms/eros"];
  NSDictionary<NSString *, id> *initialData =
      @{@"desc" : @"Description", @"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}};

  [self writeDocumentRef:doc data:initialData];

  FIRDocumentSnapshot *snap1 = [self readDocumentForRef:doc];
  FIRDocumentSnapshot *snap2 = [self readDocumentForRef:doc];
  FIRDocumentSnapshot *snap3 = [self readDocumentForRef:doc];

  XCTAssertTrue([snap1.metadata isEqual:snap2.metadata]);
  XCTAssertTrue([snap2.metadata isEqual:snap3.metadata]);

  XCTAssertTrue([snap1.documentID isEqual:snap2.documentID]);
  XCTAssertTrue([snap2.documentID isEqual:snap3.documentID]);

  XCTAssertTrue(snap1.exists == snap2.exists);
  XCTAssertTrue(snap2.exists == snap3.exists);

  XCTAssertTrue([snap1.reference isEqual:snap2.reference]);
  XCTAssertTrue([snap2.reference isEqual:snap3.reference]);

  XCTAssertTrue([[snap1 data] isEqual:[snap2 data]]);
  XCTAssertTrue([[snap2 data] isEqual:[snap3 data]]);

  XCTAssertTrue([snap1 isEqual:snap2]);
  XCTAssertTrue([snap2 isEqual:snap3]);
}

- (void)testCanUpdateAnUnknownDocument {
  [self readerAndWriterOnDocumentRef:^(FIRDocumentReference *readerRef,
                                       FIRDocumentReference *writerRef) {
    [self writeDocumentRef:writerRef data:@{@"a" : @"a"}];
    [self updateDocumentRef:readerRef data:@{@"b" : @"b"}];

    FIRDocumentSnapshot *writerSnap = [self readDocumentForRef:writerRef
                                                        source:FIRFirestoreSourceCache];
    XCTAssertTrue(writerSnap.exists);

    XCTestExpectation *expectation =
        [self expectationWithDescription:@"testCanUpdateAnUnknownDocument"];
    [readerRef getDocumentWithSource:FIRFirestoreSourceCache
                          completion:^(FIRDocumentSnapshot *, NSError *_Nullable error) {
                            XCTAssertNotNil(error);
                            [expectation fulfill];
                          }];
    [self awaitExpectations];

    writerSnap = [self readDocumentForRef:writerRef];
    XCTAssertEqualObjects(writerSnap.data, (@{@"a" : @"a", @"b" : @"b"}));
    FIRDocumentSnapshot *readerSnap = [self readDocumentForRef:writerRef];
    XCTAssertEqualObjects(readerSnap.data, (@{@"a" : @"a", @"b" : @"b"}));
  }];
}

- (void)testCanDeleteAFieldWithAnUpdate {
  FIRDocumentReference *doc = [self.db documentWithPath:@"rooms/eros"];
  NSDictionary<NSString *, id> *initialData =
      @{@"desc" : @"Description", @"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}};
  NSDictionary<NSString *, id> *updateData =
      @{@"owner.email" : [FIRFieldValue fieldValueForDelete]};
  NSDictionary<NSString *, id> *finalData =
      @{@"desc" : @"Description", @"owner" : @{@"name" : @"Jonny"}};

  [self writeDocumentRef:doc data:initialData];
  [self updateDocumentRef:doc data:updateData];

  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertTrue(result.exists);
  XCTAssertEqualObjects(result.data, finalData);
}

- (void)testDeleteDocument {
  FIRDocumentReference *doc = [self.db documentWithPath:@"rooms/eros"];
  NSDictionary<NSString *, id> *data = @{@"value" : @"foo"};
  [self writeDocumentRef:doc data:data];
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(result.data, data);
  [self deleteDocumentRef:doc];
  result = [self readDocumentForRef:doc];
  XCTAssertFalse(result.exists);
}

- (void)testCanRetrieveDocumentThatDoesNotExist {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertNil(result.data);
  XCTAssertNil(result[@"foo"]);
}

- (void)testCannotUpdateNonexistentDocument {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  XCTestExpectation *setCompletion = [self expectationWithDescription:@"setData"];
  [doc updateData:@{@"owner" : @"abc"}
       completion:^(NSError *_Nullable error) {
         XCTAssertNotNil(error);
         XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
         XCTAssertEqual(error.code, FIRFirestoreErrorCodeNotFound);
         [setCompletion fulfill];
       }];
  [self awaitExpectations];
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertFalse(result.exists);
}

- (void)testCanOverwriteDataAnExistingDocumentUsingSet {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData =
      @{@"desc" : @"Description", @"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}};
  NSDictionary<NSString *, id> *udpateData = @{@"desc" : @"NewDescription"};

  [self writeDocumentRef:doc data:initialData];
  [self writeDocumentRef:doc data:udpateData];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(document.data, udpateData);
}

- (void)testCanMergeDataWithAnExistingDocumentUsingSet {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData =
      @{@"desc" : @"Description", @"owner.data" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}};
  NSDictionary<NSString *, id> *mergeData =
      @{@"updated" : @YES, @"owner.data" : @{@"name" : @"Sebastian"}};
  NSDictionary<NSString *, id> *finalData = @{
    @"desc" : @"Description",
    @"updated" : @YES,
    @"owner.data" : @{@"name" : @"Sebastian", @"email" : @"abc@xyz.com"}
  };

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanMergeDataWithAnExistingDocumentUsingSet"];

  [doc setData:mergeData
           merge:YES
      completion:^(NSError *error) {
        XCTAssertNil(error);
        [completed fulfill];
      }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(document.data, finalData);
}

- (void)testCanMergeEmptyObject {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  FSTEventAccumulator *accumulator = [FSTEventAccumulator accumulatorForTest:self];
  id<FIRListenerRegistration> listenerRegistration =
      [doc addSnapshotListener:[accumulator valueEventHandler]];

  [self writeDocumentRef:doc data:@{}];
  FIRDocumentSnapshot *snapshot = [accumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(snapshot.data, @{});

  [self mergeDocumentRef:doc data:@{@"a" : @{}} fields:@[ @"a" ]];
  snapshot = [accumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(snapshot.data, @{@"a" : @{}});

  [self mergeDocumentRef:doc data:@{@"b" : @{}}];
  snapshot = [accumulator awaitEventWithName:@"Snapshot"];
  XCTAssertEqualObjects(snapshot.data, (@{@"a" : @{}, @"b" : @{}}));

  snapshot = [self readDocumentForRef:doc source:FIRFirestoreSourceServer];
  XCTAssertEqualObjects(snapshot.data, (@{@"a" : @{}, @"b" : @{}}));

  [listenerRegistration remove];
}

- (void)testCanMergeServerTimestamps {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData = @{
    @"updated" : @NO,
  };
  NSDictionary<NSString *, id> *mergeData = @{
    @"time" : [FIRFieldValue fieldValueForServerTimestamp],
    @"nested" : @{@"time" : [FIRFieldValue fieldValueForServerTimestamp]}
  };

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanMergeDataWithAnExistingDocumentUsingSet"];

  [doc setData:mergeData
           merge:YES
      completion:^(NSError *error) {
        XCTAssertNil(error);
        [completed fulfill];
      }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqual(document[@"updated"], @NO);
  XCTAssertTrue([document[@"time"] isKindOfClass:[FIRTimestamp class]]);
  XCTAssertTrue([document[@"nested.time"] isKindOfClass:[FIRTimestamp class]]);
}

- (void)testCanDeleteFieldUsingMerge {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData =
      @{@"untouched" : @YES, @"foo" : @"bar", @"nested" : @{@"untouched" : @YES, @"foo" : @"bar"}};
  NSDictionary<NSString *, id> *mergeData = @{
    @"foo" : [FIRFieldValue fieldValueForDelete],
    @"nested" : @{@"foo" : [FIRFieldValue fieldValueForDelete]}
  };

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanMergeDataWithAnExistingDocumentUsingSet"];

  [doc setData:mergeData
           merge:YES
      completion:^(NSError *error) {
        XCTAssertNil(error);
        [completed fulfill];
      }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqual(document[@"untouched"], @YES);
  XCTAssertNil(document[@"foo"]);
  XCTAssertEqual(document[@"nested.untouched"], @YES);
  XCTAssertNil(document[@"nested.foo"]);
}

- (void)testCanDeleteFieldUsingMergeFields {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData = @{
    @"untouched" : @YES,
    @"foo" : @"bar",
    @"inner" : @{@"removed" : @YES, @"foo" : @"bar"},
    @"nested" : @{@"untouched" : @YES, @"foo" : @"bar"}
  };
  NSDictionary<NSString *, id> *mergeData = @{
    @"foo" : [FIRFieldValue fieldValueForDelete],
    @"inner" : @{@"foo" : [FIRFieldValue fieldValueForDelete]},
    @"nested" : @{
      @"untouched" : [FIRFieldValue fieldValueForDelete],
      @"foo" : [FIRFieldValue fieldValueForDelete]
    }
  };
  NSDictionary<NSString *, id> *finalData =
      @{@"untouched" : @YES, @"inner" : @{}, @"nested" : @{@"untouched" : @YES}};

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanMergeDataWithAnExistingDocumentUsingSet"];

  [doc setData:mergeData
      mergeFields:@[ @"foo", @"inner", @"nested.foo" ]
       completion:^(NSError *error) {
         XCTAssertNil(error);
         [completed fulfill];
       }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqualObjects([document data], finalData);
}

- (void)testCanSetServerTimestampsUsingMergeFields {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData =
      @{@"untouched" : @YES, @"foo" : @"bar", @"nested" : @{@"untouched" : @YES, @"foo" : @"bar"}};
  NSDictionary<NSString *, id> *mergeData = @{
    @"foo" : [FIRFieldValue fieldValueForServerTimestamp],
    @"inner" : @{@"foo" : [FIRFieldValue fieldValueForServerTimestamp]},
    @"nested" : @{@"foo" : [FIRFieldValue fieldValueForServerTimestamp]}
  };

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanMergeDataWithAnExistingDocumentUsingSet"];

  [doc setData:mergeData
      mergeFields:@[ @"foo", @"inner", @"nested.foo" ]
       completion:^(NSError *error) {
         XCTAssertNil(error);
         [completed fulfill];
       }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertTrue([document exists]);
  XCTAssertTrue([document[@"foo"] isKindOfClass:[FIRTimestamp class]]);
  XCTAssertTrue([document[@"inner.foo"] isKindOfClass:[FIRTimestamp class]]);
  XCTAssertTrue([document[@"nested.foo"] isKindOfClass:[FIRTimestamp class]]);
}

- (void)testMergeReplacesArrays {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData = @{
    @"untouched" : @YES,
    @"data" : @"old",
    @"topLevel" : @[ @"old", @"old" ],
    @"mapInArray" : @[ @{@"data" : @"old"} ]
  };
  NSDictionary<NSString *, id> *mergeData =
      @{@"data" : @"new", @"topLevel" : @[ @"new" ], @"mapInArray" : @[ @{@"data" : @"new"} ]};
  NSDictionary<NSString *, id> *finalData = @{
    @"untouched" : @YES,
    @"data" : @"new",
    @"topLevel" : @[ @"new" ],
    @"mapInArray" : @[ @{@"data" : @"new"} ]
  };

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanMergeDataWithAnExistingDocumentUsingSet"];

  [doc setData:mergeData
           merge:YES
      completion:^(NSError *error) {
        XCTAssertNil(error);
        [completed fulfill];
      }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(document.data, finalData);
}

- (void)testCannotSpecifyFieldMaskForMissingField {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  XCTAssertThrowsSpecific(
      [doc setData:@{} mergeFields:@[ @"foo" ]], NSException,
      @"Field 'foo' is specified in your field mask but missing from your input data.");
}

- (void)testCanSetASubsetOfFieldsUsingMask {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData =
      @{@"desc" : @"Description", @"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}};

  NSDictionary<NSString *, id> *finalData = @{@"desc" : @"Description", @"owner" : @"Sebastian"};

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanSetASubsetOfFieldsUsingMask"];

  [doc setData:@{@"desc" : @"NewDescription", @"owner" : @"Sebastian"}
      mergeFields:@[ @"owner" ]
       completion:^(NSError *error) {
         XCTAssertNil(error);
         [completed fulfill];
       }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(document.data, finalData);
}

- (void)testDoesNotApplyFieldDeleteOutsideOfMask {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData =
      @{@"desc" : @"Description", @"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}};

  NSDictionary<NSString *, id> *finalData = @{@"desc" : @"Description", @"owner" : @"Sebastian"};

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanSetASubsetOfFieldsUsingMask"];

  [doc setData:@{@"desc" : [FIRFieldValue fieldValueForDelete], @"owner" : @"Sebastian"}
      mergeFields:@[ @"owner" ]
       completion:^(NSError *error) {
         XCTAssertNil(error);
         [completed fulfill];
       }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(document.data, finalData);
}

- (void)testDoesNotApplyFieldTransformOutsideOfMask {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData =
      @{@"desc" : @"Description", @"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}};

  NSDictionary<NSString *, id> *finalData = @{@"desc" : @"Description", @"owner" : @"Sebastian"};

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanSetASubsetOfFieldsUsingMask"];

  [doc setData:@{@"desc" : [FIRFieldValue fieldValueForServerTimestamp], @"owner" : @"Sebastian"}
      mergeFields:@[ @"owner" ]
       completion:^(NSError *error) {
         XCTAssertNil(error);
         [completed fulfill];
       }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(document.data, finalData);
}

- (void)testCanSetEmptyFieldMask {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData =
      @{@"desc" : @"Description", @"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}};

  NSDictionary<NSString *, id> *finalData = initialData;

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanSetASubsetOfFieldsUsingMask"];

  [doc setData:@{@"desc" : [FIRFieldValue fieldValueForServerTimestamp], @"owner" : @"Sebastian"}
      mergeFields:@[]
       completion:^(NSError *error) {
         XCTAssertNil(error);
         [completed fulfill];
       }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(document.data, finalData);
}

- (void)testCanSpecifyFieldsMultipleTimesInFieldMask {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData =
      @{@"desc" : @"Description", @"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}};

  NSDictionary<NSString *, id> *finalData =
      @{@"desc" : @"Description", @"owner" : @{@"name" : @"Sebastian", @"email" : @"new@xyz.com"}};

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanSetASubsetOfFieldsUsingMask"];

  [doc setData:@{
    @"desc" : @"NewDescription",
    @"owner" : @{@"name" : @"Sebastian", @"email" : @"new@xyz.com"}
  }
      mergeFields:@[ @"owner.name", @"owner", @"owner" ]
       completion:^(NSError *error) {
         XCTAssertNil(error);
         [completed fulfill];
       }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(document.data, finalData);
}

- (void)testAddingToACollectionYieldsTheCorrectDocumentReference {
  FIRCollectionReference *coll = [self.db collectionWithPath:@"collection"];
  FIRDocumentReference *ref = [coll addDocumentWithData:@{@"foo" : @1}];

  XCTestExpectation *getCompletion = [self expectationWithDescription:@"getData"];
  [ref getDocumentWithCompletion:^(FIRDocumentSnapshot *_Nullable document,
                                   NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(document.data, (@{@"foo" : @1}));

    [getCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testSnapshotsInSyncListenerFiresAfterListenersInSync {
  FIRCollectionReference *coll = [self.db collectionWithPath:@"collection"];
  FIRDocumentReference *ref = [coll addDocumentWithData:@{@"foo" : @1}];
  NSMutableArray<NSString *> *events = [NSMutableArray array];

  XCTestExpectation *gotInitialSnapshot = [self expectationWithDescription:@"gotInitialSnapshot"];
  __block bool setupComplete = false;
  [ref addSnapshotListener:^(FIRDocumentSnapshot *, NSError *error) {
    XCTAssertNil(error);
    [events addObject:@"doc"];
    // Wait for the initial event from the backend so that we know we'll get exactly one snapshot
    // event for our local write below.
    if (!setupComplete) {
      setupComplete = true;
      [gotInitialSnapshot fulfill];
    }
  }];

  [self awaitExpectations];
  [events removeAllObjects];

  XCTestExpectation *done = [self expectationWithDescription:@"SnapshotsInSyncListenerDone"];
  [ref.firestore addSnapshotsInSyncListener:^() {
    [events addObject:@"snapshots-in-sync"];
    if ([events count] == 3) {
      // We should have an initial snapshots-in-sync event, then a snapshot event
      // for set(), then another event to indicate we're in sync again.
      NSArray<NSString *> *expected = @[ @"snapshots-in-sync", @"doc", @"snapshots-in-sync" ];
      XCTAssertEqualObjects(events, expected);
      [done fulfill];
    }
  }];

  [self writeDocumentRef:ref data:@{@"foo" : @3}];
  [self awaitExpectation:done];
}

- (void)testSnapshotsInSyncRemoveIsIdempotent {
  // This test merely verifies that calling remove multiple times doesn't
  // explode.
  auto listener = [self.db addSnapshotsInSyncListener:^(){
  }];
  [listener remove];
  [listener remove];
}

- (void)testListenCanBeCalledMultipleTimes {
  FIRCollectionReference *coll = [self.db collectionWithPath:@"collection"];
  FIRDocumentReference *doc = [coll documentWithAutoID];

  XCTestExpectation *completed = [self expectationWithDescription:@"multiple addSnapshotListeners"];

  __block NSDictionary<NSString *, id> *resultingData;

  // Shut the compiler up about strong references to doc.
  FIRDocumentReference *__weak weakDoc = doc;

  [doc setData:@{@"foo" : @"bar"}
      completion:^(NSError *error1) {
        XCTAssertNil(error1);
        FIRDocumentReference *strongDoc = weakDoc;

        [strongDoc addSnapshotListener:^(FIRDocumentSnapshot *, NSError *error2) {
          XCTAssertNil(error2);

          FIRDocumentReference *strongDoc2 = weakDoc;
          [strongDoc2 addSnapshotListener:^(FIRDocumentSnapshot *snapshot3, NSError *error3) {
            XCTAssertNil(error3);
            resultingData = snapshot3.data;
            [completed fulfill];
          }];
        }];
      }];

  [self awaitExpectations];
  XCTAssertEqualObjects(resultingData, @{@"foo" : @"bar"});
}

- (void)testDocumentSnapshotEvents_nonExistent {
  FIRDocumentReference *docRef = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  XCTestExpectation *snapshotCompletion = [self expectationWithDescription:@"snapshot"];
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [docRef addSnapshotListener:^(FIRDocumentSnapshot *_Nullable doc, NSError *) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertNotNil(doc);
          XCTAssertFalse(doc.exists);
          [snapshotCompletion fulfill];

        } else {
          XCTFail("Should not have received this callback");
        }
      }];

  [self awaitExpectations];

  [listenerRegistration remove];
}

- (void)testDocumentSnapshotEvents_forAdd {
  FIRDocumentReference *docRef = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  XCTestExpectation *emptyCompletion = [self expectationWithDescription:@"empty snapshot"];
  __block XCTestExpectation *dataCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [docRef addSnapshotListener:^(FIRDocumentSnapshot *_Nullable doc, NSError *) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertNotNil(doc);
          XCTAssertFalse(doc.exists);
          [emptyCompletion fulfill];

        } else if (callbacks == 2) {
          XCTAssertEqualObjects(doc.data, (@{@"a" : @1}));
          XCTAssertEqual(doc.metadata.hasPendingWrites, YES);
          [dataCompletion fulfill];

        } else {
          XCTFail("Should not have received this callback");
        }
      }];

  [self awaitExpectations];
  dataCompletion = [self expectationWithDescription:@"data snapshot"];

  [docRef setData:@{@"a" : @1}];
  [self awaitExpectations];

  [listenerRegistration remove];
}

- (void)testDocumentSnapshotEvents_forAddIncludingMetadata {
  FIRDocumentReference *docRef = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  XCTestExpectation *emptyCompletion = [self expectationWithDescription:@"empty snapshot"];
  __block XCTestExpectation *dataCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration = [docRef
      addSnapshotListenerWithIncludeMetadataChanges:YES
                                           listener:^(FIRDocumentSnapshot *_Nullable doc,
                                                      NSError *) {
                                             callbacks++;

                                             if (callbacks == 1) {
                                               XCTAssertNotNil(doc);
                                               XCTAssertFalse(doc.exists);
                                               [emptyCompletion fulfill];

                                             } else if (callbacks == 2) {
                                               XCTAssertEqualObjects(doc.data, (@{@"a" : @1}));
                                               XCTAssertEqual(doc.metadata.hasPendingWrites, YES);

                                             } else if (callbacks == 3) {
                                               XCTAssertEqualObjects(doc.data, (@{@"a" : @1}));
                                               XCTAssertEqual(doc.metadata.hasPendingWrites, NO);
                                               [dataCompletion fulfill];

                                             } else {
                                               XCTFail("Should not have received this callback");
                                             }
                                           }];

  [self awaitExpectations];
  dataCompletion = [self expectationWithDescription:@"data snapshot"];

  [docRef setData:@{@"a" : @1}];
  [self awaitExpectations];

  [listenerRegistration remove];
}

- (void)testDocumentSnapshotEvents_forChange {
  FIRDocumentReference *docRef = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData = @{@"a" : @1};
  NSDictionary<NSString *, id> *changedData = @{@"b" : @2};

  [self writeDocumentRef:docRef data:initialData];

  XCTestExpectation *initialCompletion = [self expectationWithDescription:@"initial data"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [docRef addSnapshotListener:^(FIRDocumentSnapshot *_Nullable doc, NSError *) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertEqualObjects(doc.data, initialData);
          XCTAssertEqual(doc.metadata.hasPendingWrites, NO);
          [initialCompletion fulfill];

        } else if (callbacks == 2) {
          XCTAssertEqualObjects(doc.data, changedData);
          XCTAssertEqual(doc.metadata.hasPendingWrites, YES);
          [changeCompletion fulfill];

        } else {
          XCTFail("Should not have received this callback");
        }
      }];

  [self awaitExpectations];
  changeCompletion = [self expectationWithDescription:@"listen for changed data"];

  [docRef setData:changedData];
  [self awaitExpectations];

  [listenerRegistration remove];
}

- (void)testDocumentSnapshotEvents_forChangeIncludingMetadata {
  FIRDocumentReference *docRef = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData = @{@"a" : @1};
  NSDictionary<NSString *, id> *changedData = @{@"b" : @2};

  [self writeDocumentRef:docRef data:initialData];

  XCTestExpectation *initialCompletion = [self expectationWithDescription:@"initial data"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration = [docRef
      addSnapshotListenerWithIncludeMetadataChanges:YES
                                           listener:^(FIRDocumentSnapshot *_Nullable doc,
                                                      NSError *) {
                                             callbacks++;

                                             if (callbacks == 1) {
                                               XCTAssertEqualObjects(doc.data, initialData);
                                               XCTAssertEqual(doc.metadata.hasPendingWrites, NO);
                                               XCTAssertEqual(doc.metadata.isFromCache, YES);

                                             } else if (callbacks == 2) {
                                               XCTAssertEqualObjects(doc.data, initialData);
                                               XCTAssertEqual(doc.metadata.hasPendingWrites, NO);
                                               XCTAssertEqual(doc.metadata.isFromCache, NO);
                                               [initialCompletion fulfill];

                                             } else if (callbacks == 3) {
                                               XCTAssertEqualObjects(doc.data, changedData);
                                               XCTAssertEqual(doc.metadata.hasPendingWrites, YES);
                                               XCTAssertEqual(doc.metadata.isFromCache, NO);

                                             } else if (callbacks == 4) {
                                               XCTAssertEqualObjects(doc.data, changedData);
                                               XCTAssertEqual(doc.metadata.hasPendingWrites, NO);
                                               XCTAssertEqual(doc.metadata.isFromCache, NO);
                                               [changeCompletion fulfill];

                                             } else {
                                               XCTFail("Should not have received this callback");
                                             }
                                           }];

  [self awaitExpectations];
  changeCompletion = [self expectationWithDescription:@"listen for changed data"];

  [docRef setData:changedData];
  [self awaitExpectations];

  [listenerRegistration remove];
}

- (void)testDocumentSnapshotEvents_forDelete {
  FIRDocumentReference *docRef = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData = @{@"a" : @1};

  [self writeDocumentRef:docRef data:initialData];

  XCTestExpectation *initialCompletion = [self expectationWithDescription:@"initial data"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [docRef addSnapshotListener:^(FIRDocumentSnapshot *_Nullable doc, NSError *) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertEqualObjects(doc.data, initialData);
          XCTAssertEqual(doc.metadata.hasPendingWrites, NO);
          XCTAssertEqual(doc.metadata.isFromCache, YES);
          [initialCompletion fulfill];

        } else if (callbacks == 2) {
          XCTAssertFalse(doc.exists);
          [changeCompletion fulfill];

        } else {
          XCTFail("Should not have received this callback");
        }
      }];

  [self awaitExpectations];
  changeCompletion = [self expectationWithDescription:@"listen for changed data"];

  [docRef deleteDocument];
  [self awaitExpectations];

  [listenerRegistration remove];
}

- (void)testDocumentSnapshotEvents_forDeleteIncludingMetadata {
  FIRDocumentReference *docRef = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData = @{@"a" : @1};

  [self writeDocumentRef:docRef data:initialData];

  XCTestExpectation *initialCompletion = [self expectationWithDescription:@"initial data"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration = [docRef
      addSnapshotListenerWithIncludeMetadataChanges:YES
                                           listener:^(FIRDocumentSnapshot *_Nullable doc,
                                                      NSError *) {
                                             callbacks++;

                                             if (callbacks == 1) {
                                               XCTAssertEqualObjects(doc.data, initialData);
                                               XCTAssertEqual(doc.metadata.hasPendingWrites, NO);
                                               XCTAssertEqual(doc.metadata.isFromCache, YES);

                                             } else if (callbacks == 2) {
                                               XCTAssertEqualObjects(doc.data, initialData);
                                               XCTAssertEqual(doc.metadata.hasPendingWrites, NO);
                                               XCTAssertEqual(doc.metadata.isFromCache, NO);
                                               [initialCompletion fulfill];

                                             } else if (callbacks == 3) {
                                               XCTAssertFalse(doc.exists);
                                               XCTAssertEqual(doc.metadata.hasPendingWrites, NO);
                                               XCTAssertEqual(doc.metadata.isFromCache, NO);
                                               [changeCompletion fulfill];

                                             } else {
                                               XCTFail("Should not have received this callback");
                                             }
                                           }];

  [self awaitExpectations];
  changeCompletion = [self expectationWithDescription:@"listen for changed data"];

  [docRef deleteDocument];
  [self awaitExpectations];

  [listenerRegistration remove];
}

- (void)testQuerySnapshotEvents_forAdd {
  FIRCollectionReference *roomsRef = [self collectionRef];
  FIRDocumentReference *docRef = [roomsRef documentWithAutoID];

  NSDictionary<NSString *, id> *newData = @{@"a" : @1};

  XCTestExpectation *emptyCompletion = [self expectationWithDescription:@"empty snapshot"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [roomsRef addSnapshotListener:^(FIRQuerySnapshot *_Nullable docSet, NSError *) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertEqual(docSet.count, 0);
          [emptyCompletion fulfill];

        } else if (callbacks == 2) {
          XCTAssertEqual(docSet.count, 1);
          XCTAssertTrue([docSet.documents[0] isKindOfClass:[FIRQueryDocumentSnapshot class]]);
          XCTAssertEqualObjects(docSet.documents[0].data, newData);
          XCTAssertEqual(docSet.documents[0].metadata.hasPendingWrites, YES);
          [changeCompletion fulfill];

        } else {
          XCTFail("Should not have received a third callback");
        }
      }];

  [self awaitExpectations];
  changeCompletion = [self expectationWithDescription:@"changed snapshot"];

  [docRef setData:newData];
  [self awaitExpectations];

  [listenerRegistration remove];
}

- (void)testQuerySnapshotEvents_forChange {
  FIRCollectionReference *roomsRef = [self collectionRef];
  FIRDocumentReference *docRef = [roomsRef documentWithAutoID];

  NSDictionary<NSString *, id> *initialData = @{@"a" : @1};
  NSDictionary<NSString *, id> *changedData = @{@"b" : @2};

  [self writeDocumentRef:docRef data:initialData];

  XCTestExpectation *initialCompletion = [self expectationWithDescription:@"initial data"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [roomsRef addSnapshotListener:^(FIRQuerySnapshot *_Nullable docSet, NSError *) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertEqual(docSet.count, 1);
          XCTAssertEqualObjects(docSet.documents[0].data, initialData);
          XCTAssertEqual(docSet.documents[0].metadata.hasPendingWrites, NO);
          [initialCompletion fulfill];

        } else if (callbacks == 2) {
          XCTAssertEqual(docSet.count, 1);
          XCTAssertEqualObjects(docSet.documents[0].data, changedData);
          XCTAssertEqual(docSet.documents[0].metadata.hasPendingWrites, YES);
          [changeCompletion fulfill];

        } else {
          XCTFail("Should not have received a third callback");
        }
      }];

  [self awaitExpectations];
  changeCompletion = [self expectationWithDescription:@"listen for changed data"];

  [docRef setData:changedData];
  [self awaitExpectations];

  [listenerRegistration remove];
}

- (void)testQuerySnapshotEvents_forDelete {
  FIRCollectionReference *roomsRef = [self collectionRef];
  FIRDocumentReference *docRef = [roomsRef documentWithAutoID];

  NSDictionary<NSString *, id> *initialData = @{@"a" : @1};

  [self writeDocumentRef:docRef data:initialData];

  XCTestExpectation *initialCompletion = [self expectationWithDescription:@"initial data"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [roomsRef addSnapshotListener:^(FIRQuerySnapshot *_Nullable docSet, NSError *) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertEqual(docSet.count, 1);
          XCTAssertEqualObjects(docSet.documents[0].data, initialData);
          XCTAssertEqual(docSet.documents[0].metadata.hasPendingWrites, NO);
          [initialCompletion fulfill];

        } else if (callbacks == 2) {
          XCTAssertEqual(docSet.count, 0);
          [changeCompletion fulfill];

        } else {
          XCTFail("Should not have received a third callback");
        }
      }];

  [self awaitExpectations];
  changeCompletion = [self expectationWithDescription:@"listen for changed data"];

  [docRef deleteDocument];
  [self awaitExpectations];

  [listenerRegistration remove];
}

- (void)testExposesFirestoreOnDocumentReferences {
  FIRDocumentReference *doc = [self.db documentWithPath:@"foo/bar"];
  XCTAssertEqual(doc.firestore, self.db);
}

- (void)testExposesFirestoreOnQueries {
  FIRQuery *q = [[self.db collectionWithPath:@"foo"] queryLimitedTo:5];
  XCTAssertEqual(q.firestore, self.db);
}

- (void)testDocumentReferenceEquality {
  FIRFirestore *firestore = self.db;
  FIRDocumentReference *docRef = [firestore documentWithPath:@"foo/bar"];
  XCTAssertEqualObjects([firestore documentWithPath:@"foo/bar"], docRef);
  XCTAssertEqualObjects([docRef collectionWithPath:@"blah"].parent, docRef);

  XCTAssertNotEqualObjects([firestore documentWithPath:@"foo/BAR"], docRef);

  FIRFirestore *otherFirestore = [self firestore];
  XCTAssertNotEqualObjects([otherFirestore documentWithPath:@"foo/bar"], docRef);
}

- (void)testQueryReferenceEquality {
  FIRFirestore *firestore = self.db;
  FIRQuery *query =
      [[[firestore collectionWithPath:@"foo"] queryOrderedByField:@"bar"] queryWhereField:@"baz"
                                                                                isEqualTo:@42];
  FIRQuery *query2 =
      [[[firestore collectionWithPath:@"foo"] queryOrderedByField:@"bar"] queryWhereField:@"baz"
                                                                                isEqualTo:@42];
  XCTAssertEqualObjects(query, query2);

  FIRQuery *query3 =
      [[[firestore collectionWithPath:@"foo"] queryOrderedByField:@"BAR"] queryWhereField:@"baz"
                                                                                isEqualTo:@42];
  XCTAssertNotEqualObjects(query, query3);

  FIRFirestore *otherFirestore = [self firestore];
  FIRQuery *query4 = [[[otherFirestore collectionWithPath:@"foo"] queryOrderedByField:@"bar"]
      queryWhereField:@"baz"
            isEqualTo:@42];
  XCTAssertNotEqualObjects(query, query4);
}

- (void)testCanTraverseCollectionsAndDocuments {
  NSString *expected = @"a/b/c/d";
  // doc path from root Firestore.
  XCTAssertEqualObjects([self.db documentWithPath:@"a/b/c/d"].path, expected);
  // collection path from root Firestore.
  XCTAssertEqualObjects([[self.db collectionWithPath:@"a/b/c"] documentWithPath:@"d"].path,
                        expected);
  // doc path from CollectionReference.
  XCTAssertEqualObjects([[self.db collectionWithPath:@"a"] documentWithPath:@"b/c/d"].path,
                        expected);
  // collection path from DocumentReference.
  XCTAssertEqualObjects([[self.db documentWithPath:@"a/b"] collectionWithPath:@"c/d/e"].path,
                        @"a/b/c/d/e");
}

- (void)testCanTraverseCollectionAndDocumentParents {
  FIRCollectionReference *collection = [self.db collectionWithPath:@"a/b/c"];
  XCTAssertEqualObjects(collection.path, @"a/b/c");

  FIRDocumentReference *doc = collection.parent;
  XCTAssertEqualObjects(doc.path, @"a/b");

  collection = doc.parent;
  XCTAssertEqualObjects(collection.path, @"a");

  FIRDocumentReference *nilDoc = collection.parent;
  XCTAssertNil(nilDoc);
}

- (void)testUpdateFieldsWithDots {
  FIRDocumentReference *doc = [self documentRef];

  [self writeDocumentRef:doc data:@{@"a.b" : @"old", @"c.d" : @"old"}];

  [self updateDocumentRef:doc
                     data:@{(id)[[FIRFieldPath alloc] initWithFields:@[ @"a.b" ]] : @"new"}];

  XCTestExpectation *expectation = [self expectationWithDescription:@"testUpdateFieldsWithDots"];

  [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(snapshot.data, (@{@"a.b" : @"new", @"c.d" : @"old"}));
    [expectation fulfill];
  }];

  [self awaitExpectations];
}

- (void)testUpdateNestedFields {
  FIRDocumentReference *doc = [self documentRef];

  [self writeDocumentRef:doc
                    data:@{
                      @"a" : @{@"b" : @"old"},
                      @"c" : @{@"d" : @"old"},
                      @"e" : @{@"f" : @"old"}
                    }];

  [self updateDocumentRef:doc
                     data:@{
                       (id) @"a.b" : @"new",
                       (id)[[FIRFieldPath alloc] initWithFields:@[ @"c", @"d" ]] : @"new"
                     }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"testUpdateNestedFields"];

  [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(snapshot.data, (@{
                            @"a" : @{@"b" : @"new"},
                            @"c" : @{@"d" : @"new"},
                            @"e" : @{@"f" : @"old"}
                          }));
    [expectation fulfill];
  }];

  [self awaitExpectations];
}

- (void)testCollectionID {
  XCTAssertEqualObjects([self.db collectionWithPath:@"foo"].collectionID, @"foo");
  XCTAssertEqualObjects([self.db collectionWithPath:@"foo/bar/baz"].collectionID, @"baz");
}

- (void)testDocumentID {
  XCTAssertEqualObjects([self.db documentWithPath:@"foo/bar"].documentID, @"bar");
  XCTAssertEqualObjects([self.db documentWithPath:@"foo/bar/baz/qux"].documentID, @"qux");
}

- (void)testCanQueueWritesWhileOffline {
  XCTestExpectation *writeEpectation = [self expectationWithDescription:@"successfull write"];
  XCTestExpectation *networkExpectation = [self expectationWithDescription:@"enable network"];

  FIRDocumentReference *doc = [self documentRef];
  FIRFirestore *firestore = doc.firestore;
  NSDictionary<NSString *, id> *data = @{@"a" : @"b"};

  [firestore disableNetworkWithCompletion:^(NSError *error) {
    XCTAssertNil(error);

    [doc setData:data
        completion:^(NSError *error) {
          XCTAssertNil(error);
          [writeEpectation fulfill];
        }];

    [firestore enableNetworkWithCompletion:^(NSError *error) {
      XCTAssertNil(error);
      [networkExpectation fulfill];
    }];
  }];

  [self awaitExpectations];

  XCTestExpectation *getExpectation = [self expectationWithDescription:@"successfull get"];
  [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(snapshot.data, data);
    XCTAssertFalse(snapshot.metadata.isFromCache);

    [getExpectation fulfill];
  }];

  [self awaitExpectations];
}

- (void)testCanGetDocumentsWhileOffline {
  FIRDocumentReference *doc = [self documentRef];
  FIRFirestore *firestore = doc.firestore;
  NSDictionary<NSString *, id> *data = @{@"a" : @"b"};

  XCTestExpectation *failExpectation =
      [self expectationWithDescription:@"offline read with no cached data"];
  XCTestExpectation *onlineExpectation = [self expectationWithDescription:@"online read"];
  XCTestExpectation *networkExpectation = [self expectationWithDescription:@"network online"];

  __weak FIRDocumentReference *weakDoc = doc;

  [firestore disableNetworkWithCompletion:^(NSError *error) {
    XCTAssertNil(error);

    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *, NSError *error) {
      XCTAssertNotNil(error);
      [failExpectation fulfill];
    }];

    [doc setData:data
        completion:^(NSError *_Nullable error) {
          XCTAssertNil(error);

          [weakDoc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
            XCTAssertNil(error);

            // Verify that we are not reading from cache.
            XCTAssertFalse(snapshot.metadata.isFromCache);
            [onlineExpectation fulfill];
          }];
        }];

    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
      XCTAssertNil(error);

      // Verify that we are reading from cache.
      XCTAssertTrue(snapshot.metadata.fromCache);
      XCTAssertEqualObjects(snapshot.data, data);
      [firestore enableNetworkWithCompletion:^(NSError *) {
        [networkExpectation fulfill];
      }];
    }];
  }];

  [self awaitExpectations];
}

- (void)testWriteStreamReconnectsAfterIdle {
  FIRDocumentReference *doc = [self documentRef];
  FIRFirestore *firestore = doc.firestore;

  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];
  [firestore workerQueue]->RunScheduledOperationsUntil(TimerId::WriteStreamIdle);
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];
}

- (void)testWatchStreamReconnectsAfterIdle {
  FIRDocumentReference *doc = [self documentRef];
  FIRFirestore *firestore = doc.firestore;

  [self readSnapshotForRef:[self documentRef] requireOnline:YES];
  [firestore workerQueue]->RunScheduledOperationsUntil(TimerId::ListenStreamIdle);
  [self readSnapshotForRef:[self documentRef] requireOnline:YES];
}

- (void)testCanDisableNetwork {
  FIRDocumentReference *doc = [self documentRef];
  FIRFirestore *firestore = doc.firestore;

  [firestore enableNetworkWithCompletion:[self completionForExpectationWithName:@"Enable network"]];
  [self awaitExpectations];
  [firestore
      enableNetworkWithCompletion:[self completionForExpectationWithName:@"Enable network again"]];
  [self awaitExpectations];
  [firestore
      disableNetworkWithCompletion:[self completionForExpectationWithName:@"Disable network"]];
  [self awaitExpectations];
  [firestore
      disableNetworkWithCompletion:[self
                                       completionForExpectationWithName:@"Disable network again"]];
  [self awaitExpectations];
  [firestore
      enableNetworkWithCompletion:[self completionForExpectationWithName:@"Final enable network"]];
  [self awaitExpectations];
}

- (void)testClientCallsAfterTerminationFail {
  FIRDocumentReference *doc = [self documentRef];
  FIRFirestore *firestore = doc.firestore;

  [firestore enableNetworkWithCompletion:[self completionForExpectationWithName:@"Enable network"]];
  [self awaitExpectations];
  [firestore terminateWithCompletion:[self completionForExpectationWithName:@"Terminate"]];
  [self awaitExpectations];

  XCTAssertThrowsSpecific([firestore disableNetworkWithCompletion:^(NSError *){
                          }],
                          NSException, @"The client has already been terminated.");
}

- (void)testMaintainsPersistenceAfterRestarting {
  FIRDocumentReference *doc = [self documentRef];
  FIRFirestore *firestore = doc.firestore;
  FIRApp *app = firestore.app;
  NSString *appName = app.name;
  FIROptions *options = app.options;

  NSDictionary<NSString *, id> *initialData = @{@"foo" : @"42"};
  [self writeDocumentRef:doc data:initialData];

  // -clearPersistence() requires Firestore to be terminated. Shutdown FIRApp and remove the
  // firestore instance to emulate the way an end user would do this.
  [self terminateFirestore:firestore];
  [self.firestores removeObject:firestore];
  [self deleteApp:app];

  // We restart the app with the same name and options to check that the previous instance's
  // persistent storage persists its data after restarting. Calling [self firestore] here would
  // create a new instance of firestore, which defeats the purpose of this test.
  [FIRApp configureWithName:appName options:options];
  FIRApp *app2 = [FIRApp appNamed:appName];
  FIRFirestore *firestore2 = [self firestoreWithApp:app2];
  FIRDocumentReference *docRef2 = [firestore2 documentWithPath:doc.path];
  FIRDocumentSnapshot *snap = [self readDocumentForRef:docRef2 source:FIRFirestoreSourceCache];
  XCTAssertTrue(snap.exists);
}

- (void)testCanClearPersistenceAfterRestarting {
  FIRDocumentReference *doc = [self documentRef];
  FIRFirestore *firestore = doc.firestore;
  FIRApp *app = firestore.app;
  NSString *appName = app.name;
  FIROptions *options = app.options;

  NSDictionary<NSString *, id> *initialData = @{@"foo" : @"42"};
  [self writeDocumentRef:doc data:initialData];

  // -clearPersistence() requires Firestore to be terminated. Shutdown FIRApp and remove the
  // firestore instance to emulate the way an end user would do this.
  [self terminateFirestore:firestore];
  [self.firestores removeObject:firestore];
  [firestore
      clearPersistenceWithCompletion:[self completionForExpectationWithName:@"ClearPersistence"]];
  [self awaitExpectations];
  [self deleteApp:app];

  // We restart the app with the same name and options to check that the previous instance's
  // persistent storage is actually cleared after the restart. Calling [self firestore] here would
  // create a new instance of firestore, which defeats the purpose of this test.
  [FIRApp configureWithName:appName options:options];
  FIRApp *app2 = [FIRApp appNamed:appName];
  FIRFirestore *firestore2 = [self firestoreWithApp:app2];
  FIRDocumentReference *docRef2 = [firestore2 documentWithPath:doc.path];
  XCTestExpectation *expectation2 = [self expectationWithDescription:@"getData"];
  [docRef2 getDocumentWithSource:FIRFirestoreSourceCache
                      completion:^(FIRDocumentSnapshot *, NSError *_Nullable error) {
                        XCTAssertNotNil(error);
                        XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                        XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
                        [expectation2 fulfill];
                      }];
  [self awaitExpectations];
}

- (void)testCanClearPersistenceOnANewFirestoreInstance {
  FIRDocumentReference *doc = [self documentRef];
  FIRFirestore *firestore = doc.firestore;
  FIRApp *app = firestore.app;
  NSString *appName = app.name;
  FIROptions *options = app.options;

  NSDictionary<NSString *, id> *initialData = @{@"foo" : @"42"};
  [self writeDocumentRef:doc data:initialData];

  [firestore terminateWithCompletion:[self completionForExpectationWithName:@"Terminate"]];
  [self.firestores removeObject:firestore];
  [self awaitExpectations];
  [self deleteApp:app];

  // We restart the app with the same name and options to check that the previous instance's
  // persistent storage is actually cleared after the restart. Calling [self firestore] here would
  // create a new instance of firestore, which defeats the purpose of this test.
  [FIRApp configureWithName:appName options:options];
  FIRApp *app2 = [FIRApp appNamed:appName];
  FIRFirestore *firestore2 = [self firestoreWithApp:app2];
  [firestore2
      clearPersistenceWithCompletion:[self completionForExpectationWithName:@"ClearPersistence"]];
  [self awaitExpectations];
  FIRDocumentReference *docRef2 = [firestore2 documentWithPath:doc.path];
  XCTestExpectation *expectation2 = [self expectationWithDescription:@"getData"];
  [docRef2 getDocumentWithSource:FIRFirestoreSourceCache
                      completion:^(FIRDocumentSnapshot *, NSError *_Nullable error) {
                        XCTAssertNotNil(error);
                        XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                        XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
                        [expectation2 fulfill];
                      }];
  [self awaitExpectations];
}

- (void)testClearPersistenceWhileRunningFails {
  FIRDocumentReference *doc = [self documentRef];
  FIRFirestore *firestore = doc.firestore;

  [self enableNetwork];
  XCTestExpectation *expectation = [self expectationWithDescription:@"clearPersistence"];
  [firestore clearPersistenceWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeFailedPrecondition);
    [expectation fulfill];
  }];
  [self awaitExpectations];
}

- (void)testRestartFirestoreLeadsToNewInstance {
  FIRApp *app = testutil::AppForUnitTesting(util::MakeString([FSTIntegrationTestCase projectID]));
  FIRFirestore *firestore = [FIRFirestore firestoreForApp:app];
  FIRFirestore *sameInstance = [FIRFirestore firestoreForApp:app];
  firestore.settings = [FSTIntegrationTestCase settings];

  XCTAssertEqual(firestore, sameInstance);

  NSDictionary<NSString *, id> *data =
      @{@"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}};
  [self writeDocumentRef:[firestore documentWithPath:@"abc/123"] data:data];

  [self terminateFirestore:firestore];

  // Create a new instance, check it's a different instance.
  FIRFirestore *newInstance = [FIRFirestore firestoreForApp:app];
  newInstance.settings = [FSTIntegrationTestCase settings];
  XCTAssertNotEqual(firestore, newInstance);

  // New instance still functions.
  FIRDocumentSnapshot *snapshot =
      [self readDocumentForRef:[newInstance documentWithPath:@"abc/123"]];
  XCTAssertTrue([data isEqualToDictionary:[snapshot data]]);
}

- (void)testAppDeleteLeadsToFirestoreTermination {
  FIRApp *app = testutil::AppForUnitTesting(util::MakeString([FSTIntegrationTestCase projectID]));
  FIRFirestore *firestore = [FIRFirestore firestoreForApp:app];
  firestore.settings = [FSTIntegrationTestCase settings];
  NSDictionary<NSString *, id> *data =
      @{@"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}};
  [self writeDocumentRef:[firestore documentWithPath:@"abc/123"] data:data];

  [self deleteApp:app];

  XCTAssertTrue(firestore.wrapped->client()->is_terminated());
}

// Ensures b/172958106 doesn't regress.
- (void)testDeleteAppWorksWhenLastReferenceToFirestoreIsInListener {
  FIRApp *app = testutil::AppForUnitTesting(util::MakeString([FSTIntegrationTestCase projectID]));
  FIRFirestore *firestore = [FIRFirestore firestoreForApp:app];

  FIRDocumentReference *doc = [firestore documentWithPath:@"abc/123"];
  // Make sure there is a listener.
  [doc addSnapshotListener:^(FIRDocumentSnapshot *, NSError *){
  }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"App is deleted"];
  [app deleteApp:^(BOOL) {
    [expectation fulfill];
  }];
  // Let go of the last app reference.
  app = nil;

  [self awaitExpectations];
}

- (void)testTerminateCanBeCalledMultipleTimes {
  FIRApp *app = testutil::AppForUnitTesting(util::MakeString([FSTIntegrationTestCase projectID]));
  FIRFirestore *firestore = [FIRFirestore firestoreForApp:app];

  [firestore terminateWithCompletion:[self completionForExpectationWithName:@"Terminate1"]];
  [self awaitExpectations];
  XCTAssertThrowsSpecific([firestore disableNetworkWithCompletion:^(NSError *){
                          }],
                          NSException, @"The client has already been terminated.");

  [firestore terminateWithCompletion:[self completionForExpectationWithName:@"Terminate2"]];
  [self awaitExpectations];
  XCTAssertThrowsSpecific([firestore enableNetworkWithCompletion:^(NSError *){
                          }],
                          NSException, @"The client has already been terminated.");
}

- (void)testCanRemoveListenerAfterTermination {
  FIRApp *app = testutil::AppForUnitTesting(util::MakeString([FSTIntegrationTestCase projectID]));
  FIRFirestore *firestore = [FIRFirestore firestoreForApp:app];
  firestore.settings = [FSTIntegrationTestCase settings];

  FIRDocumentReference *doc = [[firestore collectionWithPath:@"rooms"] documentWithAutoID];
  FSTEventAccumulator *accumulator = [FSTEventAccumulator accumulatorForTest:self];
  [self writeDocumentRef:doc data:@{}];
  id<FIRListenerRegistration> listenerRegistration =
      [doc addSnapshotListener:[accumulator valueEventHandler]];
  [accumulator awaitEventWithName:@"Snapshot"];

  [firestore terminateWithCompletion:[self completionForExpectationWithName:@"terminate"]];
  [self awaitExpectations];

  // This should proceed without error.
  [listenerRegistration remove];
  // Multiple calls should proceed as well.
  [listenerRegistration remove];
}

- (void)testListenerCallbackBlocksRemove {
  // This tests a guarantee required for C++ that doesn't strictly matter for Objective-C and has no
  // equivalent on other platforms.
  //
  // The problem for C++ is that users can register a listener that refers to some state, then call
  // `ListenerRegistration::Remove()` and expect to be able to immediately delete that state. The
  // trouble is that there may be a callback in progress against that listener so the implementation
  // now blocks the remove call until the callback is complete.
  //
  // To make this work, user callbacks can't be on the main thread because the main thread is
  // blocked waiting for the test to complete (that is, you can't await expectations on the main
  // thread and then have the user callback additionally await expectations).
  dispatch_queue_t userQueue = dispatch_queue_create("firestore.test.user", DISPATCH_QUEUE_SERIAL);
  FIRFirestoreSettings *settings = self.db.settings;
  settings.dispatchQueue = userQueue;
  self.db.settings = settings;

  XCTestExpectation *running = [self expectationWithDescription:@"listener running"];
  XCTestExpectation *allowCompletion =
      [self expectationWithDescription:@"allow listener to complete"];
  XCTestExpectation *removing = [self expectationWithDescription:@"attempting to remove listener"];
  XCTestExpectation *removed = [self expectationWithDescription:@"listener removed"];

  NSMutableString *steps = [NSMutableString string];

  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];

  __block bool firstTime = true;

  id<FIRListenerRegistration> listener =
      [doc addSnapshotListener:^(FIRDocumentSnapshot *, NSError *) {
        @synchronized(self) {
          if (!firstTime) {
            return;
          }
          firstTime = false;
        }

        [steps appendString:@"1"];
        [running fulfill];

        [self awaitExpectation:allowCompletion];
        [steps appendString:@"3"];
      }];

  // Call remove asynchronously to avoid blocking the main test thread.
  dispatch_queue_t async = dispatch_queue_create("firestore.async", DISPATCH_QUEUE_SERIAL);
  dispatch_async(async, ^{
    [self awaitExpectation:running];
    [steps appendString:@"2"];

    [removing fulfill];
    [listener remove];

    [steps appendString:@"4"];
    [removed fulfill];
  });

  // Perform a write to `doc` which will trigger the listener callback. Don't wait for completion
  // though because that completion handler is in line behind the listener callback that the test
  // is blocking.
  XCTestExpectation *setData = [self expectationWithDescription:@"setData"];
  [doc setData:@{@"foo" : @"bar"} completion:[self completionForExpectation:setData]];

  [self awaitExpectation:removing];
  [allowCompletion fulfill];

  [self awaitExpectation:removed];
  XCTAssertEqualObjects(steps, @"1234");

  [self awaitExpectation:setData];
}

- (void)testListenerCallbackCanCallRemoveWithoutBlocking {
  // This tests a guarantee required for C++ that doesn't strictly matter for Objective-C and has no
  // equivalent on other platforms. See `testListenerCallbackBlocksRemove` for background.
  XCTestExpectation *removed = [self expectationWithDescription:@"listener removed"];

  NSMutableString *steps = [NSMutableString string];

  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];

  __block id<FIRListenerRegistration> listener = nil;

  @synchronized(self) {
    listener = [doc addSnapshotListener:^(FIRDocumentSnapshot *, NSError *) {
      [steps appendString:@"1"];

      @synchronized(self) {
        // This test is successful if this method does not block.
        [listener remove];
      }

      [steps appendString:@"2"];
      [removed fulfill];
    }];
  }

  // Perform a write to `doc` which will trigger the listener callback.
  [self writeDocumentRef:doc data:@{@"foo" : @"bar2"}];

  [self awaitExpectation:removed];
  XCTAssertEqualObjects(steps, @"12");
}

- (void)testListenerCallbacksHappenOnMainThread {
  // Verify that callbacks occur on the main thread if settings.dispatchQueue is not specified.
  XCTestExpectation *invoked = [self expectationWithDescription:@"listener invoked"];
  invoked.assertForOverFulfill = false;

  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];

  __block bool callbackThreadIsMainThread;
  __block NSString *callbackThreadDescription;

  [doc addSnapshotListener:^(FIRDocumentSnapshot *, NSError *) {
    callbackThreadIsMainThread = NSThread.isMainThread;
    callbackThreadDescription = [NSString stringWithFormat:@"%@", NSThread.currentThread];
    [invoked fulfill];
  }];

  [self awaitExpectation:invoked];
  XCTAssertTrue(callbackThreadIsMainThread,
                @"The listener callback was expected to occur on the main thread, but instead it "
                @"occurred on the thread %@",
                callbackThreadDescription);
}

- (void)testWaitForPendingWritesCompletes {
  FIRDocumentReference *doc = [self documentRef];
  FIRFirestore *firestore = doc.firestore;

  [self disableNetwork];

  [doc setData:@{@"foo" : @"bar"}];
  [firestore waitForPendingWritesWithCompletion:
                 [self completionForExpectationWithName:@"Wait for pending writes"]];

  [firestore enableNetworkWithCompletion:[self completionForExpectationWithName:@"Enable network"]];
  [self awaitExpectations];
}

- (void)testWaitForPendingWritesFailsWhenUserChanges {
  FIRFirestore *firestore = self.db;

  [self disableNetwork];

  // Writes to local to prevent immediate call to the completion of waitForPendingWrites.
  NSDictionary<NSString *, id> *data =
      @{@"owner" : @{@"name" : @"Andy", @"email" : @"abc@example.com"}};
  [[self documentRef] setData:data];

  XCTestExpectation *expectation = [self expectationWithDescription:@"waitForPendingWrites"];
  [firestore waitForPendingWritesWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeCancelled);
    [expectation fulfill];
  }];

  [self triggerUserChangeWithUid:@"user-to-fail-pending-writes"];
  [self awaitExpectations];
}

- (void)testWaitForPendingWritesCompletesWhenOfflineIfNoPending {
  FIRFirestore *firestore = self.db;

  [self disableNetwork];

  [firestore waitForPendingWritesWithCompletion:
                 [self completionForExpectationWithName:@"Wait for pending writes"]];
  [self awaitExpectations];
}

@end
