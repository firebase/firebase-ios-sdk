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
#include <libkern/OSAtomic.h>

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

@interface FSTTransactionTests : FSTIntegrationTestCase
@end

@implementation FSTTransactionTests

// We currently require every document read to also be written.
// TODO(b/34879758): Re-enable this test once we fix it.
- (void)xtestGetDocuments {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"spaces"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{ @"foo" : @1, @"desc" : @"Stuff", @"owner" : @"Jonny" }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
    [transaction getDocument:doc error:error];
    XCTAssertNil(*error);
    return @YES;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertNil(result);
        // We currently require every document read to also be written.
        // TODO(b/34879758): Fix this check once we drop that requirement.
        XCTAssertNotNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testDeleteDocument {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"towns"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(@"bar", snapshot[@"foo"]);

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
    [transaction deleteDocument:doc];
    return @YES;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertEqualObjects(@YES, result);
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];

  snapshot = [self readDocumentForRef:doc];
  XCTAssertFalse(snapshot.exists);
}

- (void)testGetNonexistentDocumentThenCreate {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"towns"] documentWithAutoID];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
    FIRDocumentSnapshot *snapshot = [transaction getDocument:doc error:error];
    XCTAssertNil(*error);
    XCTAssertFalse(snapshot.exists);
    [transaction setData:@{@"foo" : @"bar"} forDocument:doc];
    return @YES;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertEqualObjects(@YES, result);
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];

  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertTrue(snapshot.exists);
  XCTAssertEqualObjects(@"bar", snapshot[@"foo"]);
}

- (void)testGetNonexistentDocumentThenFailPatch {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"towns"] documentWithAutoID];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
    FIRDocumentSnapshot *snapshot = [transaction getDocument:doc error:error];
    XCTAssertNil(*error);
    XCTAssertFalse(snapshot.exists);
    [transaction updateData:@{@"foo" : @"bar"} forDocument:doc];
    return @YES;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
        // TODO(dimond): This is probably the wrong error code, but it's what we use today. We
        // should update the code once the underlying error was fixed.
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeFailedPrecondition);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testDeleteDocumentAndPatch {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"towns"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **error) {
    FIRDocumentSnapshot *snapshot = [transaction getDocument:doc error:error];
    XCTAssertNil(*error);
    XCTAssertTrue(snapshot.exists);
    [transaction deleteDocument:doc];
    // Since we deleted the doc, the update will fail
    [transaction updateData:@{@"foo" : @"bar"} forDocument:doc];
    return @YES;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
        // TODO(dimond): This is probably the wrong error code, but it's what we use today. We
        // should update the code once the underlying error was fixed.
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeFailedPrecondition);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testDeleteDocumentAndSet {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"towns"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **error) {
    FIRDocumentSnapshot *snapshot = [transaction getDocument:doc error:error];
    XCTAssertNil(*error);
    XCTAssertTrue(snapshot.exists);
    [transaction deleteDocument:doc];
    // TODO(dimond): In theory this should work, but it's complex to make it work, so instead we
    // just let the transaction fail and verify it's unsupported for now
    [transaction setData:@{@"foo" : @"new-bar"} forDocument:doc];
    return @YES;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
        // TODO(dimond): This is probably the wrong error code, but it's what we use today. We
        // should update the code once the underlying error was fixed.
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeFailedPrecondition);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testWriteDocumentTwice {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"towns"] documentWithAutoID];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **error) {
    [transaction setData:@{@"a" : @"b"} forDocument:doc];
    [transaction setData:@{@"c" : @"d"} forDocument:doc];
    return @YES;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertEqualObjects(@YES, result);
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];

  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(snapshot.data, @{@"c" : @"d"});
}

- (void)testSetDocumentWithMerge {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"towns"] documentWithAutoID];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
    [transaction setData:@{ @"a" : @"b", @"nested" : @{@"a" : @"b"} } forDocument:doc];
    [transaction setData:@{ @"c" : @"d", @"nested" : @{@"c" : @"d"} } forDocument:doc merge:YES];
    return @YES;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertEqualObjects(@YES, result);
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];

  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(
      snapshot.data, (
                         @{ @"a" : @"b",
                            @"c" : @"d",
                            @"nested" : @{@"a" : @"b", @"c" : @"d"} }));
}

- (void)testCannotUpdateNonExistentDocument {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"towns"] documentWithAutoID];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
    [transaction updateData:@{@"foo" : @"bar"} forDocument:doc];
    return nil;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertNotNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];

  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertFalse(result.exists);
}

- (void)testIncrementTransactionally {
  // A barrier to make sure every transaction reaches the same spot.
  dispatch_semaphore_t writeBarrier = dispatch_semaphore_create(0);
  __block volatile int32_t started = 0;

  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{ @"count" : @(5.0) }];

  // Make 3 transactions that will all increment.
  int total = 3;
  for (int i = 0; i < total; i++) {
    XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
    [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
      FIRDocumentSnapshot *snapshot = [transaction getDocument:doc error:error];
      XCTAssertNil(*error);
      int32_t nowStarted = OSAtomicIncrement32(&started);
      // Once all of the transactions have read, allow the first write.
      if (nowStarted == total) {
        dispatch_semaphore_signal(writeBarrier);
      }

      dispatch_semaphore_wait(writeBarrier, DISPATCH_TIME_FOREVER);
      // Refill the barrier so that the other transactions and retries succeed.
      dispatch_semaphore_signal(writeBarrier);

      double newCount = ((NSNumber *)snapshot[@"count"]).doubleValue + 1.0;
      [transaction setData:@{ @"count" : @(newCount) } forDocument:doc];
      return @YES;
    }
        completion:^(id _Nullable result, NSError *_Nullable error) {
          [expectation fulfill];
        }];
  }

  [self awaitExpectations];
  // Now all transaction should be completed, so check the result.
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(@(5.0 + total), snapshot[@"count"]);
}

- (void)testUpdateTransactionally {
  // A barrier to make sure every transaction reaches the same spot.
  dispatch_semaphore_t writeBarrier = dispatch_semaphore_create(0);
  __block volatile int32_t started = 0;

  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{ @"count" : @(5.0), @"other" : @"yes" }];

  // Make 3 transactions that will all increment.
  int total = 3;
  for (int i = 0; i < total; i++) {
    XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
    [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
      FIRDocumentSnapshot *snapshot = [transaction getDocument:doc error:error];
      XCTAssertNil(*error);
      int32_t nowStarted = OSAtomicIncrement32(&started);
      // Once all of the transactions have read, allow the first write.
      if (nowStarted == total) {
        dispatch_semaphore_signal(writeBarrier);
      }

      dispatch_semaphore_wait(writeBarrier, DISPATCH_TIME_FOREVER);
      // Refill the barrier so that the other transactions and retries succeed.
      dispatch_semaphore_signal(writeBarrier);

      double newCount = ((NSNumber *)snapshot[@"count"]).doubleValue + 1.0;
      [transaction updateData:@{ @"count" : @(newCount) } forDocument:doc];
      return @YES;
    }
        completion:^(id _Nullable result, NSError *_Nullable error) {
          [expectation fulfill];
        }];
  }

  [self awaitExpectations];
  // Now all transaction should be completed, so check the result.
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(@(5.0 + total), snapshot[@"count"]);
  XCTAssertEqualObjects(@"yes", snapshot[@"other"]);
}

// We currently require every document read to also be written.
// TODO(b/34879758): Re-enable this test once we fix it.
- (void)xtestHandleReadingOneDocAndWritingAnother {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc1 = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  FIRDocumentReference *doc2 = [[firestore collectionWithPath:@"counters"] documentWithAutoID];

  [self writeDocumentRef:doc1 data:@{ @"count" : @(15.0) }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
    // Get the first doc.
    [transaction getDocument:doc1 error:error];
    XCTAssertNil(*error);
    // Do a write outside of the transaction. The first time the
    // transaction is tried, this will bump the version, which
    // will cause the write to doc2 to fail. The second time, it
    // will be a no-op and not bump the version.
    dispatch_semaphore_t writeSemaphore = dispatch_semaphore_create(0);
    [doc1 setData:@{
      @"count" : @(1234)
    }
        completion:^(NSError *_Nullable error) {
          dispatch_semaphore_signal(writeSemaphore);
        }];
    // We can block on it, because transactions run on a background queue.
    dispatch_semaphore_wait(writeSemaphore, DISPATCH_TIME_FOREVER);
    // Now try to update the other doc from within the transaction.
    // This should fail once, because we read 15 earlier.
    [transaction setData:@{ @"count" : @(16) } forDocument:doc2];
    return nil;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        // We currently require every document read to also be written.
        // TODO(b/34879758): Add this check back once we drop that.
        // NSError *error = nil;
        // FIRDocument *snapshot = [transaction getDocument:doc1 error:&error];
        // XCTAssertNil(error);
        // XCTAssertEquals(0, tries);
        // XCTAssertEqualObjects(@(1234), snapshot[@"count"]);
        // snapshot = [transaction getDocument:doc2 error:&error];
        // XCTAssertNil(error);
        // XCTAssertEqualObjects(@(16), snapshot[@"count"]);
        XCTAssertNotNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testReadingADocTwiceWithDifferentVersions {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{ @"count" : @(15.0) }];
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
    // Get the doc once.
    FIRDocumentSnapshot *snapshot = [transaction getDocument:doc error:error];
    XCTAssertNil(*error);
    XCTAssertEqualObjects(@(15), snapshot[@"count"]);
    // Do a write outside of the transaction.
    dispatch_semaphore_t writeSemaphore = dispatch_semaphore_create(0);
    [doc setData:@{
      @"count" : @(1234)
    }
        completion:^(NSError *_Nullable error) {
          dispatch_semaphore_signal(writeSemaphore);
        }];
    // We can block on it, because transactions run on a background queue.
    dispatch_semaphore_wait(writeSemaphore, DISPATCH_TIME_FOREVER);
    // Get the doc again in the transaction with the new version.
    snapshot = [transaction getDocument:doc error:error];
    // The get itself will fail, because we already read an earlier version of this document.
    // TODO(klimt): Perhaps we shouldn't fail reads for this, but should wait and fail the
    // whole transaction? It's an edge-case anyway, as developers shouldn't be reading the same
    // do multiple times. But they need to handle read errors anyway.
    XCTAssertNotNil(*error);
    return nil;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        [expectation fulfill];
      }];
  [self awaitExpectations];

  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(@(1234.0), snapshot[@"count"]);
}

// We currently require every document read to also be written.
// TODO(b/34879758): Add this test back once we fix that.
- (void)xtestCannotHaveAGetWithoutMutations {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"foo"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
    FIRDocumentSnapshot *snapshot = [transaction getDocument:doc error:error];
    XCTAssertTrue(snapshot.exists);
    XCTAssertNil(*error);
    return nil;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertNotNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testSuccessWithNoTransactionOperations {
  FIRFirestore *firestore = [self firestore];
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
    return @"yes";
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertEqualObjects(@"yes", result);
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testCancellationOnError {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"towns"] documentWithAutoID];
  __block volatile int32_t count = 0;
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
    OSAtomicIncrement32(&count);
    [transaction setData:@{@"foo" : @"bar"} forDocument:doc];
    *error = [NSError errorWithDomain:NSCocoaErrorDomain code:35 userInfo:@{}];
    return nil;
  }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(35, error.code);
        [expectation fulfill];
      }];
  [self awaitExpectations];
  XCTAssertEqual(1, (int)count);
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertFalse(snapshot.exists);
}

- (void)testUpdateFieldsWithDotsTransactionally {
  FIRDocumentReference *doc = [self documentRef];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUpdateFieldsWithDotsTransactionally"];

  [doc.firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        XCTAssertNil(*error);
        [transaction setData:@{@"a.b" : @"old", @"c.d" : @"old"} forDocument:doc];
        [transaction updateData:@{
          [[FIRFieldPath alloc] initWithFields:@[ @"a.b" ]] : @"new"
        }
                    forDocument:doc];
        return nil;
      }
      completion:^(id result, NSError *error) {
        XCTAssertNil(error);
        [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
          XCTAssertNil(error);
          XCTAssertEqualObjects(snapshot.data, (@{@"a.b" : @"new", @"c.d" : @"old"}));
        }];
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testUpdateNestedFieldsTransactionally {
  FIRDocumentReference *doc = [self documentRef];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUpdateNestedFieldsTransactionally"];

  [doc.firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        XCTAssertNil(*error);
        [transaction setData:@{
          @"a" : @{@"b" : @"old"},
          @"c" : @{@"d" : @"old"},
          @"e" : @{@"f" : @"old"}
        }
                 forDocument:doc];
        [transaction updateData:@{
          @"a.b" : @"new",
          [[FIRFieldPath alloc] initWithFields:@[ @"c", @"d" ]] : @"new"
        }
                    forDocument:doc];
        return nil;
      }
      completion:^(id result, NSError *error) {
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

@end
