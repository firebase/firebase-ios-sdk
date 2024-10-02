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

#import <FirebaseFirestore/FirebaseFirestore.h>

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"

@interface FIRFirestoreSourceTests : FSTIntegrationTestCase
@end

@implementation FIRFirestoreSourceTests

- (void)testGetDocumentWhileOnlineWithDefaultSource {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key" : @"value"};
  [self writeDocumentRef:doc data:initialData];

  // get doc and ensure that it exists, is *not* from the cache, and matches
  // the initialData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertTrue(result.exists);
  XCTAssertFalse(result.metadata.fromCache);
  XCTAssertFalse(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(result.data, initialData);
}

- (void)testGetCollectionWhileOnlineWithDefaultSource {
  FIRCollectionReference *col = [self collectionRef];

  // set a few documents to known values
  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *initialDocs = @{
    @"doc1" : @{@"key1" : @"value1"},
    @"doc2" : @{@"key2" : @"value2"},
    @"doc3" : @{@"key3" : @"value3"}
  };
  [self writeAllDocuments:initialDocs toCollection:col];

  // get docs and ensure they are *not* from the cache, and match the
  // initialDocs.
  FIRQuerySnapshot *result = [self readDocumentSetForRef:col];
  XCTAssertFalse(result.metadata.fromCache);
  XCTAssertFalse(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(
      FIRQuerySnapshotGetData(result),
      (@[ @{@"key1" : @"value1"}, @{@"key2" : @"value2"}, @{@"key3" : @"value3"} ]));
  XCTAssertEqualObjects(FIRQuerySnapshotGetDocChangesData(result), (@[
                          @[ @(FIRDocumentChangeTypeAdded), @"doc1", @{@"key1" : @"value1"} ],
                          @[ @(FIRDocumentChangeTypeAdded), @"doc2", @{@"key2" : @"value2"} ],
                          @[ @(FIRDocumentChangeTypeAdded), @"doc3", @{@"key3" : @"value3"} ]
                        ]));
}

- (void)testGetDocumentError {
  FIRDocumentReference *doc = [self.db documentWithPath:@"foo/__invalid__"];

  XCTestExpectation *completed = [self expectationWithDescription:@"get completed"];
  [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *, NSError *error) {
    XCTAssertNotNil(error);
    [completed fulfill];
  }];

  [self awaitExpectations];
}

- (void)testGetCollectionError {
  FIRCollectionReference *col = [self.db collectionWithPath:@"__invalid__"];

  XCTestExpectation *completed = [self expectationWithDescription:@"get completed"];
  [col getDocumentsWithCompletion:^(FIRQuerySnapshot *, NSError *error) {
    XCTAssertNotNil(error);
    [completed fulfill];
  }];

  [self awaitExpectations];
}

- (void)testGetDocumentWhileOfflineWithDefaultSource {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key1" : @"value1"};
  [self writeDocumentRef:doc data:initialData];

  // go offline for the rest of this test
  [self disableNetwork];

  // update the doc (though don't wait for a server response. We're offline; so
  // that ain't happening!). This allows us to further distinguished cached vs
  // server responses below.
  NSDictionary<NSString *, id> *newData = @{@"key2" : @"value2"};
  [doc setData:newData
      completion:^(NSError *) {
        XCTAssertTrue(false, "Because we're offline, this should never occur.");
      }];

  // get doc and ensure it exists, *is* from the cache, and matches the
  // newData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertTrue(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(result.data, newData);
}

- (void)testGetCollectionWhileOfflineWithDefaultSource {
  FIRCollectionReference *col = [self collectionRef];

  // set a few documents to known values
  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *initialDocs = @{
    @"doc1" : @{@"key1" : @"value1"},
    @"doc2" : @{@"key2" : @"value2"},
    @"doc3" : @{@"key3" : @"value3"}
  };
  [self writeAllDocuments:initialDocs toCollection:col];

  // go offline for the rest of this test
  [self disableNetwork];

  // update the docs (though don't wait for a server response. We're offline; so
  // that ain't happening!). This allows us to further distinguished cached vs
  // server responses below.
  [[col documentWithPath:@"doc2"] setData:@{@"key2b" : @"value2b"} merge:YES];
  [[col documentWithPath:@"doc3"] setData:@{@"key3b" : @"value3b"}];
  [[col documentWithPath:@"doc4"] setData:@{@"key4" : @"value4"}];

  // get docs and ensure they *are* from the cache, and matches the updated data.
  FIRQuerySnapshot *result = [self readDocumentSetForRef:col];
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertTrue(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), (@[
                          @{@"key1" : @"value1"}, @{@"key2" : @"value2", @"key2b" : @"value2b"},
                          @{@"key3b" : @"value3b"}, @{@"key4" : @"value4"}
                        ]));
  XCTAssertEqualObjects(
      FIRQuerySnapshotGetDocChangesData(result), (@[
        @[ @(FIRDocumentChangeTypeAdded), @"doc1", @{@"key1" : @"value1"} ],
        @[ @(FIRDocumentChangeTypeAdded), @"doc2", @{@"key2" : @"value2", @"key2b" : @"value2b"} ],
        @[ @(FIRDocumentChangeTypeAdded), @"doc3", @{@"key3b" : @"value3b"} ],
        @[ @(FIRDocumentChangeTypeAdded), @"doc4", @{@"key4" : @"value4"} ]
      ]));
}

- (void)testGetDocumentWhileOnlineCacheOnly {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key" : @"value"};
  [self writeDocumentRef:doc data:initialData];

  // get doc and ensure that it exists, *is* from the cache, and matches
  // the initialData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc source:FIRFirestoreSourceCache];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertFalse(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(result.data, initialData);
}

- (void)testGetCollectionWhileOnlineCacheOnly {
  FIRCollectionReference *col = [self collectionRef];

  // set a few documents to a known value
  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *initialDocs = @{
    @"doc1" : @{@"key1" : @"value1"},
    @"doc2" : @{@"key2" : @"value2"},
    @"doc3" : @{@"key3" : @"value3"},
  };
  [self writeAllDocuments:initialDocs toCollection:col];

  // get docs and ensure they *are* from the cache, and matches the
  // initialDocs.
  FIRQuerySnapshot *result = [self readDocumentSetForRef:col source:FIRFirestoreSourceCache];
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertFalse(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), (@[
                          @{@"key1" : @"value1"},
                          @{@"key2" : @"value2"},
                          @{@"key3" : @"value3"},
                        ]));
  XCTAssertEqualObjects(FIRQuerySnapshotGetDocChangesData(result), (@[
                          @[ @(FIRDocumentChangeTypeAdded), @"doc1", @{@"key1" : @"value1"} ],
                          @[ @(FIRDocumentChangeTypeAdded), @"doc2", @{@"key2" : @"value2"} ],
                          @[ @(FIRDocumentChangeTypeAdded), @"doc3", @{@"key3" : @"value3"} ]
                        ]));
}

- (void)testGetDocumentWhileOfflineCacheOnly {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key1" : @"value1"};
  [self writeDocumentRef:doc data:initialData];

  // go offline for the rest of this test
  [self disableNetwork];

  // update the doc (though don't wait for a server response. We're offline; so
  // that ain't happening!). This allows us to further distinguished cached vs
  // server responses below.
  NSDictionary<NSString *, id> *newData = @{@"key2" : @"value2"};
  [doc setData:newData
      completion:^(NSError *) {
        XCTFail("Because we're offline, this should never occur.");
      }];

  // get doc and ensure it exists, *is* from the cache, and matches the
  // newData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc source:FIRFirestoreSourceCache];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertTrue(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(result.data, newData);
}

- (void)testGetCollectionWhileOfflineCacheOnly {
  FIRCollectionReference *col = [self collectionRef];

  // set a few documents to a known value
  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *initialDocs = @{
    @"doc1" : @{@"key1" : @"value1"},
    @"doc2" : @{@"key2" : @"value2"},
    @"doc3" : @{@"key3" : @"value3"},
  };
  [self writeAllDocuments:initialDocs toCollection:col];

  // go offline for the rest of this test
  [self disableNetwork];

  // update the docs (though don't wait for a server response. We're offline; so
  // that ain't happening!). This allows us to further distinguished cached vs
  // server responses below.
  [[col documentWithPath:@"doc2"] setData:@{@"key2b" : @"value2b"} merge:YES];
  [[col documentWithPath:@"doc3"] setData:@{@"key3b" : @"value3b"}];
  [[col documentWithPath:@"doc4"] setData:@{@"key4" : @"value4"}];

  // get docs and ensure they *are* from the cache, and matches the updated
  // data.
  FIRQuerySnapshot *result = [self readDocumentSetForRef:col source:FIRFirestoreSourceCache];
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertTrue(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), (@[
                          @{@"key1" : @"value1"}, @{@"key2" : @"value2", @"key2b" : @"value2b"},
                          @{@"key3b" : @"value3b"}, @{@"key4" : @"value4"}
                        ]));
  XCTAssertEqualObjects(
      FIRQuerySnapshotGetDocChangesData(result), (@[
        @[ @(FIRDocumentChangeTypeAdded), @"doc1", @{@"key1" : @"value1"} ],
        @[ @(FIRDocumentChangeTypeAdded), @"doc2", @{@"key2" : @"value2", @"key2b" : @"value2b"} ],
        @[ @(FIRDocumentChangeTypeAdded), @"doc3", @{@"key3b" : @"value3b"} ],
        @[ @(FIRDocumentChangeTypeAdded), @"doc4", @{@"key4" : @"value4"} ]
      ]));
}

- (void)testGetDocumentWhileOnlineServerOnly {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key" : @"value"};
  [self writeDocumentRef:doc data:initialData];

  // get doc and ensure that it exists, is *not* from the cache, and matches
  // the initialData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc source:FIRFirestoreSourceServer];
  XCTAssertTrue(result.exists);
  XCTAssertFalse(result.metadata.fromCache);
  XCTAssertFalse(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(result.data, initialData);
}

- (void)testGetCollectionWhileOnlineServerOnly {
  FIRCollectionReference *col = [self collectionRef];

  // set a few documents to a known value
  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *initialDocs = @{
    @"doc1" : @{@"key1" : @"value1"},
    @"doc2" : @{@"key2" : @"value2"},
    @"doc3" : @{@"key3" : @"value3"},
  };
  [self writeAllDocuments:initialDocs toCollection:col];

  // get docs and ensure they are *not* from the cache, and matches the
  // initialData.
  FIRQuerySnapshot *result = [self readDocumentSetForRef:col source:FIRFirestoreSourceServer];
  XCTAssertFalse(result.metadata.fromCache);
  XCTAssertFalse(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), (@[
                          @{@"key1" : @"value1"},
                          @{@"key2" : @"value2"},
                          @{@"key3" : @"value3"},
                        ]));
  XCTAssertEqualObjects(FIRQuerySnapshotGetDocChangesData(result), (@[
                          @[ @(FIRDocumentChangeTypeAdded), @"doc1", @{@"key1" : @"value1"} ],
                          @[ @(FIRDocumentChangeTypeAdded), @"doc2", @{@"key2" : @"value2"} ],
                          @[ @(FIRDocumentChangeTypeAdded), @"doc3", @{@"key3" : @"value3"} ]
                        ]));
}

- (void)testGetDocumentWhileOfflineServerOnly {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key1" : @"value1"};
  [self writeDocumentRef:doc data:initialData];

  // go offline for the rest of this test
  [self disableNetwork];

  // attempt to get doc and ensure it cannot be retrieved
  XCTestExpectation *failedGetDocCompletion = [self expectationWithDescription:@"failedGetDoc"];
  [doc getDocumentWithSource:FIRFirestoreSourceServer
                  completion:^(FIRDocumentSnapshot *, NSError *error) {
                    XCTAssertNotNil(error);
                    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
                    [failedGetDocCompletion fulfill];
                  }];
  [self awaitExpectations];
}

- (void)testGetCollectionWhileOfflineServerOnly {
  FIRCollectionReference *col = [self collectionRef];

  // set a few documents to a known value
  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *initialDocs = @{
    @"doc1" : @{@"key1" : @"value1"},
    @"doc2" : @{@"key2" : @"value2"},
    @"doc3" : @{@"key3" : @"value3"},
  };
  [self writeAllDocuments:initialDocs toCollection:col];

  // go offline for the rest of this test
  [self disableNetwork];

  // attempt to get docs and ensure they cannot be retrieved
  XCTestExpectation *failedGetDocsCompletion = [self expectationWithDescription:@"failedGetDocs"];
  [col getDocumentsWithSource:FIRFirestoreSourceServer
                   completion:^(FIRQuerySnapshot *, NSError *error) {
                     XCTAssertNotNil(error);
                     XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                     XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
                     [failedGetDocsCompletion fulfill];
                   }];
  [self awaitExpectations];
}

- (void)testGetDocumentWhileOfflineWithDifferentSource {
  FIRDocumentReference *doc = [self documentRef];

  // set document to a known value
  NSDictionary<NSString *, id> *initialData = @{@"key1" : @"value1"};
  [self writeDocumentRef:doc data:initialData];

  // go offline for the rest of this test
  [self disableNetwork];

  // update the doc (though don't wait for a server response. We're offline; so
  // that ain't happening!). This allows us to further distinguished cached vs
  // server responses below.
  NSDictionary<NSString *, id> *newData = @{@"key2" : @"value2"};
  [doc setData:newData
      completion:^(NSError *) {
        XCTAssertTrue(false, "Because we're offline, this should never occur.");
      }];

  // Create an initial listener for this query (to attempt to disrupt the gets below) and wait for
  // the listener to deliver its initial snapshot before continuing.
  XCTestExpectation *listenerReady = [self expectationWithDescription:@"listenerReady"];
  [doc addSnapshotListener:^(FIRDocumentSnapshot *, NSError *) {
    [listenerReady fulfill];
  }];
  [self awaitExpectations];

  // get doc (from cache) and ensure it exists, *is* from the cache, and
  // matches the newData.
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc source:FIRFirestoreSourceCache];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertTrue(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(result.data, newData);

  // attempt to get doc (with default get source)
  result = [self readDocumentForRef:doc source:FIRFirestoreSourceDefault];
  XCTAssertTrue(result.exists);
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertTrue(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(result.data, newData);

  // attempt to get doc (from the server) and ensure it cannot be retrieved
  XCTestExpectation *failedGetDocCompletion = [self expectationWithDescription:@"failedGetDoc"];
  [doc getDocumentWithSource:FIRFirestoreSourceServer
                  completion:^(FIRDocumentSnapshot *, NSError *error) {
                    XCTAssertNotNil(error);
                    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
                    [failedGetDocCompletion fulfill];
                  }];
  [self awaitExpectations];
}

- (void)testGetCollectionWhileOfflineWithDifferentSource {
  FIRCollectionReference *col = [self collectionRef];

  // set a few documents to a known value
  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *initialDocs = @{
    @"doc1" : @{@"key1" : @"value1"},
    @"doc2" : @{@"key2" : @"value2"},
    @"doc3" : @{@"key3" : @"value3"},
  };
  [self writeAllDocuments:initialDocs toCollection:col];

  // go offline for the rest of this test
  [self disableNetwork];

  // update the docs (though don't wait for a server response. We're offline; so
  // that ain't happening!). This allows us to further distinguished cached vs
  // server responses below.
  [[col documentWithPath:@"doc2"] setData:@{@"key2b" : @"value2b"} merge:YES];
  [[col documentWithPath:@"doc3"] setData:@{@"key3b" : @"value3b"}];
  [[col documentWithPath:@"doc4"] setData:@{@"key4" : @"value4"}];

  // Create an initial listener for this query (to attempt to disrupt the gets
  // below) and wait for the listener to deliver its initial snapshot before
  // continuing.
  XCTestExpectation *listenerReady = [self expectationWithDescription:@"listenerReady"];
  [col addSnapshotListener:^(FIRQuerySnapshot *, NSError *) {
    [listenerReady fulfill];
  }];
  [self awaitExpectations];

  // get docs (from cache) and ensure they *are* from the cache, and
  // matches the updated data.
  FIRQuerySnapshot *result = [self readDocumentSetForRef:col source:FIRFirestoreSourceCache];
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertTrue(result.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), (@[
                          @{@"key1" : @"value1"}, @{@"key2" : @"value2", @"key2b" : @"value2b"},
                          @{@"key3b" : @"value3b"}, @{@"key4" : @"value4"}
                        ]));
  XCTAssertEqualObjects(
      FIRQuerySnapshotGetDocChangesData(result), (@[
        @[ @(FIRDocumentChangeTypeAdded), @"doc1", @{@"key1" : @"value1"} ],
        @[ @(FIRDocumentChangeTypeAdded), @"doc2", @{@"key2" : @"value2", @"key2b" : @"value2b"} ],
        @[ @(FIRDocumentChangeTypeAdded), @"doc3", @{@"key3b" : @"value3b"} ],
        @[ @(FIRDocumentChangeTypeAdded), @"doc4", @{@"key4" : @"value4"} ]
      ]));

  // attempt to get docs (with default get source)
  result = [self readDocumentSetForRef:col source:FIRFirestoreSourceDefault];
  XCTAssertTrue(result.metadata.fromCache);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(result), (@[
                          @{@"key1" : @"value1"}, @{@"key2" : @"value2", @"key2b" : @"value2b"},
                          @{@"key3b" : @"value3b"}, @{@"key4" : @"value4"}
                        ]));
  XCTAssertEqualObjects(
      FIRQuerySnapshotGetDocChangesData(result), (@[
        @[ @(FIRDocumentChangeTypeAdded), @"doc1", @{@"key1" : @"value1"} ],
        @[ @(FIRDocumentChangeTypeAdded), @"doc2", @{@"key2" : @"value2", @"key2b" : @"value2b"} ],
        @[ @(FIRDocumentChangeTypeAdded), @"doc3", @{@"key3b" : @"value3b"} ],
        @[ @(FIRDocumentChangeTypeAdded), @"doc4", @{@"key4" : @"value4"} ]
      ]));

  // attempt to get docs (from the server) and ensure they cannot be retrieved
  XCTestExpectation *failedGetDocsCompletion = [self expectationWithDescription:@"failedGetDocs"];
  [col getDocumentsWithSource:FIRFirestoreSourceServer
                   completion:^(FIRQuerySnapshot *, NSError *error) {
                     XCTAssertNotNil(error);
                     XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                     XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
                     [failedGetDocsCompletion fulfill];
                   }];
  [self awaitExpectations];
}

- (void)testGetNonExistingDocWhileOnlineWithDefaultSource {
  FIRDocumentReference *doc = [self documentRef];

  // get doc and ensure that it does not exist and is *not* from the cache.
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertFalse(snapshot.exists);
  XCTAssertFalse(snapshot.metadata.fromCache);
  XCTAssertFalse(snapshot.metadata.hasPendingWrites);
}

- (void)testGetNonExistingCollectionWhileOnlineWithDefaultSource {
  FIRCollectionReference *col = [self collectionRef];

  // get collection and ensure it's empty and that it's *not* from the cache.
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:col];
  XCTAssertEqual(snapshot.count, 0);
  XCTAssertEqual(snapshot.documentChanges.count, 0ul);
  XCTAssertFalse(snapshot.metadata.fromCache);
  XCTAssertFalse(snapshot.metadata.hasPendingWrites);
}

- (void)testGetNonExistingDocWhileOfflineWithDefaultSource {
  FIRDocumentReference *doc = [self documentRef];

  // go offline for the rest of this test
  [self disableNetwork];

  // Attempt to get doc. This will fail since there's nothing in cache.
  XCTestExpectation *getNonExistingDocCompletion =
      [self expectationWithDescription:@"getNonExistingDoc"];
  [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *, NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
    [getNonExistingDocCompletion fulfill];
  }];
  [self awaitExpectations];
}

// TODO(b/112267729): We should raise a fromCache=true event with a nonexistent snapshot, but
// because the default source goes through a normal listener, we do not.
- (void)xtestGetDeletedDocWhileOfflineWithDefaultSource {
  FIRDocumentReference *doc = [self documentRef];

  // Delete the doc to get a deleted document into our cache.
  [self deleteDocumentRef:doc];

  // Go offline for the rest of this test
  [self disableNetwork];

  // Should get a FIRDocumentSnapshot with exists=false, fromCache=true
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc source:FIRFirestoreSourceDefault];
  XCTAssertNotNil(snapshot);
  XCTAssertFalse(snapshot.exists);
  XCTAssertNil(snapshot.data);
  XCTAssertTrue(snapshot.metadata.fromCache);
  XCTAssertFalse(snapshot.metadata.hasPendingWrites);
}

- (void)testGetNonExistingCollectionWhileOfflineWithDefaultSource {
  FIRCollectionReference *col = [self collectionRef];

  // go offline for the rest of this test
  [self disableNetwork];

  // get collection and ensure it's empty and that it *is* from the cache.
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:col];
  XCTAssertEqual(snapshot.count, 0);
  XCTAssertEqual(snapshot.documentChanges.count, 0ul);
  XCTAssertTrue(snapshot.metadata.fromCache);
  XCTAssertFalse(snapshot.metadata.hasPendingWrites);
}

- (void)testGetNonExistingDocWhileOnlineCacheOnly {
  FIRDocumentReference *doc = [self documentRef];

  // Attempt to get doc. This will fail since there's nothing in cache.
  XCTestExpectation *getNonExistingDocCompletion =
      [self expectationWithDescription:@"getNonExistingDoc"];
  [doc getDocumentWithSource:FIRFirestoreSourceCache
                  completion:^(FIRDocumentSnapshot *, NSError *error) {
                    XCTAssertNotNil(error);
                    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
                    [getNonExistingDocCompletion fulfill];
                  }];
  [self awaitExpectations];
}

- (void)testGetNonExistingCollectionWhileOnlineCacheOnly {
  FIRCollectionReference *col = [self collectionRef];

  // get collection and ensure it's empty and that it *is* from the cache.
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:col source:FIRFirestoreSourceCache];
  XCTAssertEqual(snapshot.count, 0);
  XCTAssertEqual(snapshot.documentChanges.count, 0ul);
  XCTAssertTrue(snapshot.metadata.fromCache);
  XCTAssertFalse(snapshot.metadata.hasPendingWrites);
}

- (void)testGetNonExistingDocWhileOfflineCacheOnly {
  FIRDocumentReference *doc = [self documentRef];

  // go offline for the rest of this test
  [self disableNetwork];

  // Attempt to get doc. This will fail since there's nothing in cache.
  XCTestExpectation *getNonExistingDocCompletion =
      [self expectationWithDescription:@"getNonExistingDoc"];
  [doc getDocumentWithSource:FIRFirestoreSourceCache
                  completion:^(FIRDocumentSnapshot *, NSError *error) {
                    XCTAssertNotNil(error);
                    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
                    [getNonExistingDocCompletion fulfill];
                  }];
  [self awaitExpectations];
}

- (void)testGetDeletedDocWhileOfflineCacheOnly {
  FIRDocumentReference *doc = [self documentRef];

  // Delete the doc to get a deleted document into our cache.
  [self deleteDocumentRef:doc];

  // Go offline for the rest of this test
  [self disableNetwork];

  // Should get a FIRDocumentSnapshot with exists=false, fromCache=true
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc source:FIRFirestoreSourceCache];
  XCTAssertNotNil(snapshot);
  XCTAssertFalse(snapshot.exists);
  XCTAssertNil(snapshot.data);
  XCTAssertTrue(snapshot.metadata.fromCache);
  XCTAssertFalse(snapshot.metadata.hasPendingWrites);
}

- (void)testGetNonExistingCollectionWhileOfflineCacheOnly {
  FIRCollectionReference *col = [self collectionRef];

  // go offline for the rest of this test
  [self disableNetwork];

  // get collection and ensure it's empty and that it *is* from the cache.
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:col source:FIRFirestoreSourceCache];
  XCTAssertEqual(snapshot.count, 0);
  XCTAssertEqual(snapshot.documentChanges.count, 0ul);
  XCTAssertTrue(snapshot.metadata.fromCache);
  XCTAssertFalse(snapshot.metadata.hasPendingWrites);
}

- (void)testGetNonExistingDocWhileOnlineServerOnly {
  FIRDocumentReference *doc = [self documentRef];

  // get doc and ensure that it does not exist and is *not* from the cache.
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc source:FIRFirestoreSourceServer];
  XCTAssertFalse(snapshot.exists);
  XCTAssertFalse(snapshot.metadata.fromCache);
  XCTAssertFalse(snapshot.metadata.hasPendingWrites);
}

- (void)testGetNonExistingCollectionWhileOnlineServerOnly {
  FIRCollectionReference *col = [self collectionRef];

  // get collection and ensure that it's empty and that it's *not* from the cache.
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:col source:FIRFirestoreSourceServer];
  XCTAssertEqual(snapshot.count, 0);
  XCTAssertEqual(snapshot.documentChanges.count, 0ul);
  XCTAssertFalse(snapshot.metadata.fromCache);
  XCTAssertFalse(snapshot.metadata.hasPendingWrites);
}

- (void)testGetNonExistingDocWhileOfflineServerOnly {
  FIRDocumentReference *doc = [self documentRef];

  // go offline for the rest of this test
  [self disableNetwork];

  // attempt to get doc. Currently, this is expected to fail. In the future, we
  // might consider adding support for negative cache hits so that we know
  // certain documents *don't* exist.
  XCTestExpectation *getNonExistingDocCompletion =
      [self expectationWithDescription:@"getNonExistingDoc"];
  [doc getDocumentWithSource:FIRFirestoreSourceServer
                  completion:^(FIRDocumentSnapshot *, NSError *error) {
                    XCTAssertNotNil(error);
                    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                    XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
                    [getNonExistingDocCompletion fulfill];
                  }];
  [self awaitExpectations];
}

- (void)testGetNonExistingCollectionWhileOfflineServerOnly {
  FIRCollectionReference *col = [self collectionRef];

  // go offline for the rest of this test
  [self disableNetwork];

  // attempt to get collection and ensure that it cannot be retrieved
  XCTestExpectation *failedGetDocsCompletion = [self expectationWithDescription:@"failedGetDocs"];
  [col getDocumentsWithSource:FIRFirestoreSourceServer
                   completion:^(FIRQuerySnapshot *, NSError *error) {
                     XCTAssertNotNil(error);
                     XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
                     XCTAssertEqual(error.code, FIRFirestoreErrorCodeUnavailable);
                     [failedGetDocsCompletion fulfill];
                   }];
  [self awaitExpectations];
}

@end
