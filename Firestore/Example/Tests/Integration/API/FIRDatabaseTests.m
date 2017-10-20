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

@import Firestore;

#import <XCTest/XCTest.h>

#import "Core/FSTFirestoreClient.h"
#import "FIRFirestore+Internal.h"
#import "FSTIntegrationTestCase.h"

@interface FIRDatabaseTests : FSTIntegrationTestCase
@end

@implementation FIRDatabaseTests

- (void)testCanUpdateAnExistingDocument {
  FIRDocumentReference *doc = [self.db documentWithPath:@"rooms/eros"];
  NSDictionary<NSString *, id> *initialData =
      @{ @"desc" : @"Description",
         @"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"} };
  NSDictionary<NSString *, id> *updateData =
      @{@"desc" : @"NewDescription", @"owner.email" : @"new@xyz.com"};
  NSDictionary<NSString *, id> *finalData =
      @{ @"desc" : @"NewDescription",
         @"owner" : @{@"name" : @"Jonny", @"email" : @"new@xyz.com"} };

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

- (void)testCanDeleteAFieldWithAnUpdate {
  FIRDocumentReference *doc = [self.db documentWithPath:@"rooms/eros"];
  NSDictionary<NSString *, id> *initialData =
      @{ @"desc" : @"Description",
         @"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"} };
  NSDictionary<NSString *, id> *updateData =
      @{@"owner.email" : [FIRFieldValue fieldValueForDelete]};
  NSDictionary<NSString *, id> *finalData =
      @{ @"desc" : @"Description",
         @"owner" : @{@"name" : @"Jonny"} };

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
      @{ @"desc" : @"Description",
         @"owner" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"} };
  NSDictionary<NSString *, id> *udpateData = @{@"desc" : @"NewDescription"};

  [self writeDocumentRef:doc data:initialData];
  [self writeDocumentRef:doc data:udpateData];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(document.data, udpateData);
}

- (void)testCanMergeDataWithAnExistingDocumentUsingSet {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData = @{
    @"desc" : @"Description",
    @"owner.data" : @{@"name" : @"Jonny", @"email" : @"abc@xyz.com"}
  };
  NSDictionary<NSString *, id> *mergeData =
      @{ @"updated" : @YES,
         @"owner.data" : @{@"name" : @"Sebastian"} };
  NSDictionary<NSString *, id> *finalData = @{
    @"desc" : @"Description",
    @"updated" : @YES,
    @"owner.data" : @{@"name" : @"Sebastian", @"email" : @"abc@xyz.com"}
  };

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanMergeDataWithAnExistingDocumentUsingSet"];

  [doc setData:mergeData
         options:[FIRSetOptions merge]
      completion:^(NSError *error) {
        XCTAssertNil(error);
        [completed fulfill];
      }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(document.data, finalData);
}

- (void)testCanMergeServerTimestamps {
  FIRDocumentReference *doc = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData = @{
    @"updated" : @NO,
  };
  NSDictionary<NSString *, id> *mergeData =
      @{@"time" : [FIRFieldValue fieldValueForServerTimestamp]};

  [self writeDocumentRef:doc data:initialData];

  XCTestExpectation *completed =
      [self expectationWithDescription:@"testCanMergeDataWithAnExistingDocumentUsingSet"];

  [doc setData:mergeData
         options:[FIRSetOptions merge]
      completion:^(NSError *error) {
        XCTAssertNil(error);
        [completed fulfill];
      }];

  [self awaitExpectations];

  FIRDocumentSnapshot *document = [self readDocumentForRef:doc];
  XCTAssertEqual(document[@"updated"], @NO);
  XCTAssertTrue([document[@"time"] isKindOfClass:[NSDate class]]);
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
      @{ @"data" : @"new",
         @"topLevel" : @[ @"new" ],
         @"mapInArray" : @[ @{@"data" : @"new"} ] };
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
         options:[FIRSetOptions merge]
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
  FIRDocumentReference *ref = [coll addDocumentWithData:@{ @"foo" : @1 }];

  XCTestExpectation *getCompletion = [self expectationWithDescription:@"getData"];
  [ref getDocumentWithCompletion:^(FIRDocumentSnapshot *_Nullable document,
                                   NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(document.data, (@{ @"foo" : @1 }));

    [getCompletion fulfill];
  }];
  [self awaitExpectations];
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

        [strongDoc addSnapshotListener:^(FIRDocumentSnapshot *snapshot2, NSError *error2) {
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
      [docRef addSnapshotListener:^(FIRDocumentSnapshot *_Nullable doc, NSError *error) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertNotNil(doc);
          XCTAssertFalse(doc.exists);
          [snapshotCompletion fulfill];

        } else if (callbacks == 2) {
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
      [docRef addSnapshotListener:^(FIRDocumentSnapshot *_Nullable doc, NSError *error) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertNotNil(doc);
          XCTAssertFalse(doc.exists);
          [emptyCompletion fulfill];

        } else if (callbacks == 2) {
          XCTAssertEqualObjects(doc.data, (@{ @"a" : @1 }));
          XCTAssertEqual(doc.metadata.hasPendingWrites, YES);
          [dataCompletion fulfill];

        } else if (callbacks == 3) {
          XCTFail("Should not have received this callback");
        }
      }];

  [self awaitExpectations];
  dataCompletion = [self expectationWithDescription:@"data snapshot"];

  [docRef setData:@{ @"a" : @1 }];
  [self awaitExpectations];

  [listenerRegistration remove];
}

- (void)testDocumentSnapshotEvents_forAddIncludingMetadata {
  FIRDocumentReference *docRef = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  XCTestExpectation *emptyCompletion = [self expectationWithDescription:@"empty snapshot"];
  __block XCTestExpectation *dataCompletion;
  __block int callbacks = 0;

  FIRDocumentListenOptions *options =
      [[FIRDocumentListenOptions options] includeMetadataChanges:YES];

  id<FIRListenerRegistration> listenerRegistration =
      [docRef addSnapshotListenerWithOptions:options
                                    listener:^(FIRDocumentSnapshot *_Nullable doc, NSError *error) {
                                      callbacks++;

                                      if (callbacks == 1) {
                                        XCTAssertNotNil(doc);
                                        XCTAssertFalse(doc.exists);
                                        [emptyCompletion fulfill];

                                      } else if (callbacks == 2) {
                                        XCTAssertEqualObjects(doc.data, (@{ @"a" : @1 }));
                                        XCTAssertEqual(doc.metadata.hasPendingWrites, YES);

                                      } else if (callbacks == 3) {
                                        XCTAssertEqualObjects(doc.data, (@{ @"a" : @1 }));
                                        XCTAssertEqual(doc.metadata.hasPendingWrites, NO);
                                        [dataCompletion fulfill];

                                      } else if (callbacks == 4) {
                                        XCTFail("Should not have received this callback");
                                      }
                                    }];

  [self awaitExpectations];
  dataCompletion = [self expectationWithDescription:@"data snapshot"];

  [docRef setData:@{ @"a" : @1 }];
  [self awaitExpectations];

  [listenerRegistration remove];
}

- (void)testDocumentSnapshotEvents_forChange {
  FIRDocumentReference *docRef = [[self.db collectionWithPath:@"rooms"] documentWithAutoID];

  NSDictionary<NSString *, id> *initialData = @{ @"a" : @1 };
  NSDictionary<NSString *, id> *changedData = @{ @"b" : @2 };

  [self writeDocumentRef:docRef data:initialData];

  XCTestExpectation *initialCompletion = [self expectationWithDescription:@"initial data"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [docRef addSnapshotListener:^(FIRDocumentSnapshot *_Nullable doc, NSError *error) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertEqualObjects(doc.data, initialData);
          XCTAssertEqual(doc.metadata.hasPendingWrites, NO);
          [initialCompletion fulfill];

        } else if (callbacks == 2) {
          XCTAssertEqualObjects(doc.data, changedData);
          XCTAssertEqual(doc.metadata.hasPendingWrites, YES);
          [changeCompletion fulfill];

        } else if (callbacks == 3) {
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

  NSDictionary<NSString *, id> *initialData = @{ @"a" : @1 };
  NSDictionary<NSString *, id> *changedData = @{ @"b" : @2 };

  [self writeDocumentRef:docRef data:initialData];

  XCTestExpectation *initialCompletion = [self expectationWithDescription:@"initial data"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  FIRDocumentListenOptions *options =
      [[FIRDocumentListenOptions options] includeMetadataChanges:YES];

  id<FIRListenerRegistration> listenerRegistration =
      [docRef addSnapshotListenerWithOptions:options
                                    listener:^(FIRDocumentSnapshot *_Nullable doc, NSError *error) {
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

                                      } else if (callbacks == 5) {
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

  NSDictionary<NSString *, id> *initialData = @{ @"a" : @1 };

  [self writeDocumentRef:docRef data:initialData];

  XCTestExpectation *initialCompletion = [self expectationWithDescription:@"initial data"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [docRef addSnapshotListener:^(FIRDocumentSnapshot *_Nullable doc, NSError *error) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertEqualObjects(doc.data, initialData);
          XCTAssertEqual(doc.metadata.hasPendingWrites, NO);
          XCTAssertEqual(doc.metadata.isFromCache, YES);
          [initialCompletion fulfill];

        } else if (callbacks == 2) {
          XCTAssertFalse(doc.exists);
          [changeCompletion fulfill];

        } else if (callbacks == 3) {
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

  NSDictionary<NSString *, id> *initialData = @{ @"a" : @1 };

  [self writeDocumentRef:docRef data:initialData];

  FIRDocumentListenOptions *options =
      [[FIRDocumentListenOptions options] includeMetadataChanges:YES];

  XCTestExpectation *initialCompletion = [self expectationWithDescription:@"initial data"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [docRef addSnapshotListenerWithOptions:options
                                    listener:^(FIRDocumentSnapshot *_Nullable doc, NSError *error) {
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

                                      } else if (callbacks == 4) {
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

  NSDictionary<NSString *, id> *newData = @{ @"a" : @1 };

  XCTestExpectation *emptyCompletion = [self expectationWithDescription:@"empty snapshot"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [roomsRef addSnapshotListener:^(FIRQuerySnapshot *_Nullable docSet, NSError *error) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertEqual(docSet.count, 0);
          [emptyCompletion fulfill];

        } else if (callbacks == 2) {
          XCTAssertEqual(docSet.count, 1);
          XCTAssertEqualObjects(docSet.documents[0].data, newData);
          XCTAssertEqual(docSet.documents[0].metadata.hasPendingWrites, YES);
          [changeCompletion fulfill];

        } else if (callbacks == 3) {
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

  NSDictionary<NSString *, id> *initialData = @{ @"a" : @1 };
  NSDictionary<NSString *, id> *changedData = @{ @"b" : @2 };

  [self writeDocumentRef:docRef data:initialData];

  XCTestExpectation *initialCompletion = [self expectationWithDescription:@"initial data"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [roomsRef addSnapshotListener:^(FIRQuerySnapshot *_Nullable docSet, NSError *error) {
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

        } else if (callbacks == 3) {
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

  NSDictionary<NSString *, id> *initialData = @{ @"a" : @1 };

  [self writeDocumentRef:docRef data:initialData];

  XCTestExpectation *initialCompletion = [self expectationWithDescription:@"initial data"];
  __block XCTestExpectation *changeCompletion;
  __block int callbacks = 0;

  id<FIRListenerRegistration> listenerRegistration =
      [roomsRef addSnapshotListener:^(FIRQuerySnapshot *_Nullable docSet, NSError *error) {
        callbacks++;

        if (callbacks == 1) {
          XCTAssertEqual(docSet.count, 1);
          XCTAssertEqualObjects(docSet.documents[0].data, initialData);
          XCTAssertEqual(docSet.documents[0].metadata.hasPendingWrites, NO);
          [initialCompletion fulfill];

        } else if (callbacks == 2) {
          XCTAssertEqual(docSet.count, 0);
          [changeCompletion fulfill];

        } else if (callbacks == 4) {
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

  [self updateDocumentRef:doc data:@{ [[FIRFieldPath alloc] initWithFields:@[ @"a.b" ]] : @"new" }];

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
                       @"a.b" : @"new",
                       [[FIRFieldPath alloc] initWithFields:@[ @"c", @"d" ]] : @"new"
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

  [firestore.client disableNetworkWithCompletion:^(NSError *error) {
    XCTAssertNil(error);

    [doc setData:data
        completion:^(NSError *error) {
          XCTAssertNil(error);
          [writeEpectation fulfill];
        }];

    [firestore.client enableNetworkWithCompletion:^(NSError *error) {
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

- (void)testCantGetDocumentsWhileOffline {
  FIRDocumentReference *doc = [self documentRef];
  FIRFirestore *firestore = doc.firestore;
  NSDictionary<NSString *, id> *data = @{@"a" : @"b"};

  XCTestExpectation *onlineExpectation = [self expectationWithDescription:@"online read"];
  XCTestExpectation *networkExpectation = [self expectationWithDescription:@"network online"];

  __weak FIRDocumentReference *weakDoc = doc;

  [firestore.client disableNetworkWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
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
      [firestore.client enableNetworkWithCompletion:^(NSError *error) {
        [networkExpectation fulfill];
      }];
    }];
  }];

  [self awaitExpectations];
}

@end
