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
#import "Firestore/Source/Util/FSTClasses.h"

@interface FSTTransactionTests : FSTIntegrationTestCase
- (void)assertExistsWithSnapshot:(FIRDocumentSnapshot *)snapshot error:(NSError *)error;
- (void)assertDoesNotExistWithSnapshot:(FIRDocumentSnapshot *)snapshot error:(NSError *)error;
- (void)assertNilErrorWithMessage:(NSString *)message error:(NSError *)error;
- (void)assertErrorWithMessage:(NSString *)message error:(NSError *)error;
- (void)assertEqualsObjectWithSnapshot:(FIRDocumentSnapshot *)snapshot
                              expected:(NSObject *)expected
                                 error:(NSError *)error;
@end

typedef void (^TransactionStage)(FIRTransaction *, FIRDocumentReference *);

/**
 * The transaction stages that follow are postfixed by numbers to indicate the
 * calling order. For example, calling set1 followed by set2 should
 * result in the document being set to the value specified by set2.
 */
TransactionStage delete1 = ^(FIRTransaction *transaction, FIRDocumentReference *doc) {
  [transaction deleteDocument:doc];
};

TransactionStage update1 = ^(FIRTransaction *transaction, FIRDocumentReference *doc) {
  [transaction updateData:@{@"foo" : @"bar1"} forDocument:doc];
};

TransactionStage update2 = ^(FIRTransaction *transaction, FIRDocumentReference *doc) {
  [transaction updateData:@{@"foo" : @"bar2"} forDocument:doc];
};

TransactionStage set1 = ^(FIRTransaction *transaction, FIRDocumentReference *doc) {
  [transaction setData:@{@"foo" : @"bar1"} forDocument:doc];
};

TransactionStage set2 = ^(FIRTransaction *transaction, FIRDocumentReference *doc) {
  [transaction setData:@{@"foo" : @"bar2"} forDocument:doc];
};

TransactionStage get = ^(FIRTransaction *transaction, FIRDocumentReference *doc) {
  NSError *error = nil;
  [transaction getDocument:doc error:&error];
};

@interface FSTTransactionTester : NSObject
- (FSTTransactionTester *)withExistingDoc;
- (FSTTransactionTester *)withNonexistentDoc;
- (FSTTransactionTester *)runWithStages:(NSArray<TransactionStage> *)stages;
- (void)expectDoc:(NSObject *)expected;
- (void)expectNoDoc;
- (void)expectError:(FIRFirestoreErrorCode)expected;
@end

/**
 * Used for testing that all possible combinations of executing transactions
 * result in the desired document value or error.
 *
 * run, withExistingDoc, and withNonexistentDoc don't actually do
 * anything except assign variables into the TransactionTester.
 *
 * expectDoc, expectNoDoc, and expectError will trigger the
 * transaction to run and assert that the end result matches the input.
 */
@implementation FSTTransactionTester {
  FIRFirestore *_db;
  FIRDocumentReference *_docRef;
  boolean_t _fromExistingDoc;
  NSArray<TransactionStage> *_stages;
  FSTTransactionTests *_testCase;
  NSMutableArray<XCTestExpectation *> *_testExpectations;
}
- (instancetype)initWithDb:(FIRFirestore *)db testCase:(FSTTransactionTests *)testCase {
  self = [super init];
  if (self) {
    _db = db;
    _stages = [NSArray array];
    _testCase = testCase;
    _testExpectations = [NSMutableArray array];
  }
  return self;
}

- (FSTTransactionTester *)withExistingDoc {
  _fromExistingDoc = true;
  return self;
}

- (FSTTransactionTester *)withNonexistentDoc {
  _fromExistingDoc = false;
  return self;
}

- (FSTTransactionTester *)runWithStages:(NSArray<TransactionStage> *)stages {
  _stages = stages;
  return self;
}

- (void)expectDoc:(NSObject *)expected {
  [self prepareDoc];
  [self runSuccessfulTransaction];

  XCTestExpectation *expectation = [_testCase expectationWithDescription:@"get"];
  [_docRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    [self->_testCase assertEqualsObjectWithSnapshot:snapshot expected:expected error:error];
    [expectation fulfill];
  }];
  [_testCase awaitExpectations];

  [self cleanupTester];
}

- (void)expectNoDoc {
  [self prepareDoc];
  [self runSuccessfulTransaction];

  XCTestExpectation *expectation = [_testCase expectationWithDescription:@"get"];
  [_docRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    [self->_testCase assertDoesNotExistWithSnapshot:snapshot error:error];
    [expectation fulfill];
  }];
  [_testCase awaitExpectations];

  [self cleanupTester];
}

- (void)expectError:(FIRFirestoreErrorCode)expected {
  [self prepareDoc];
  [self runFailingTransaction:expected];

  [self cleanupTester];
}

- (void)prepareDoc {
  _docRef = [[self->_db collectionWithPath:@"nonexistent"] documentWithAutoID];
  if (_fromExistingDoc) {
    [_docRef setData:@{@"foo" : @"bar"}];

    XCTestExpectation *expectation = [_testCase expectationWithDescription:@"get"];

    [_docRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
      [self->_testCase assertExistsWithSnapshot:snapshot error:error];
      [expectation fulfill];
    }];

    [_testCase awaitExpectations];
  }
}

- (void)runSuccessfulTransaction {
  XCTestExpectation *expectation = [_testCase expectationWithDescription:@"runTransaction"];
  [_db
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        for (TransactionStage stage in self->_stages) {
          stage(transaction, self->_docRef);
        }
        return @YES;
      }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        [expectation fulfill];
        NSString *message =
            [NSString stringWithFormat:@"Expected the sequence %@, to succeed, but got %ld.",
                                       [self listStages], [error code]];
        [self->_testCase assertNilErrorWithMessage:message error:error];
      }];

  [_testCase awaitExpectations];
}

- (void)runFailingTransaction:(FIRFirestoreErrorCode)expected {
  XCTestExpectation *expectation = [_testCase expectationWithDescription:@"runTransaction"];
  [_db
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        for (TransactionStage stage in self->_stages) {
          stage(transaction, self->_docRef);
        }
        return @YES;
      }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        [expectation fulfill];
        NSString *message =
            [NSString stringWithFormat:@"Expected the sequence (%@), to fail, but it didn't.",
                                       [self listStages]];
        [self->_testCase assertErrorWithMessage:message error:error];
      }];

  [_testCase awaitExpectations];
}

- (void)cleanupTester {
  _stages = [NSArray array];
  // Set the docRef to something else to lose the original reference.
  _docRef = [[self->_db collectionWithPath:@"reset"] documentWithAutoID];
}

- (NSString *)listStages {
  NSMutableArray<NSString *> *seqList = [NSMutableArray array];
  for (TransactionStage stage in _stages) {
    if (stage == delete1) {
      [seqList addObject:@"delete"];
    } else if (stage == update1 || stage == update2) {
      [seqList addObject:@"update"];
    } else if (stage == set1 || stage == set2) {
      [seqList addObject:@"set"];
    } else if (stage == get) {
      [seqList addObject:@"get"];
    }
  }
  return [seqList description];
}

@end

@implementation FSTTransactionTests
- (void)assertExistsWithSnapshot:(FIRDocumentSnapshot *)snapshot error:(NSError *)error {
  XCTAssertNil(error);
  XCTAssertTrue(snapshot.exists);
}

- (void)assertDoesNotExistWithSnapshot:(FIRDocumentSnapshot *)snapshot error:(NSError *)error {
  XCTAssertNil(error);
  XCTAssertFalse(snapshot.exists);
}

- (void)assertNilErrorWithMessage:(NSString *)message error:(NSError *)error {
  XCTAssertNil(error, @"%@", message);
}

- (void)assertErrorWithMessage:(NSString *)message error:(NSError *)error {
  XCTAssertNotNil(error, @"%@", message);
}

- (void)assertEqualsObjectWithSnapshot:(FIRDocumentSnapshot *)snapshot
                              expected:(NSObject *)expected
                                 error:(NSError *)error {
  XCTAssertNil(error);
  XCTAssertTrue(snapshot.exists);
  XCTAssertEqualObjects(expected, snapshot.data);
}

- (void)testRunsTransactionsAfterGettingExistingDoc {
  FIRFirestore *firestore = [self firestore];
  FSTTransactionTester *tt = [[FSTTransactionTester alloc] initWithDb:firestore testCase:self];

  [[[tt withExistingDoc] runWithStages:@[ get, delete1, delete1 ]] expectNoDoc];
  [[[tt withExistingDoc] runWithStages:@[ get, delete1, update2 ]]
      expectError:FIRFirestoreErrorCodeInvalidArgument];
  [[[tt withExistingDoc] runWithStages:@[ get, delete1, set2 ]] expectDoc:@{@"foo" : @"bar2"}];

  [[[tt withExistingDoc] runWithStages:@[ get, update1, delete1 ]] expectNoDoc];
  [[[tt withExistingDoc] runWithStages:@[ get, update1, update2 ]] expectDoc:@{@"foo" : @"bar2"}];
  [[[tt withExistingDoc] runWithStages:@[ get, update1, set2 ]] expectDoc:@{@"foo" : @"bar2"}];

  [[[tt withExistingDoc] runWithStages:@[ get, set1, delete1 ]] expectNoDoc];
  [[[tt withExistingDoc] runWithStages:@[ get, set1, update2 ]] expectDoc:@{@"foo" : @"bar2"}];
  [[[tt withExistingDoc] runWithStages:@[ get, set1, set2 ]] expectDoc:@{@"foo" : @"bar2"}];
}

- (void)testRunsTransactionsAfterGettingNonexistentDoc {
  FIRFirestore *firestore = [self firestore];
  FSTTransactionTester *tt = [[FSTTransactionTester alloc] initWithDb:firestore testCase:self];

  [[[tt withNonexistentDoc] runWithStages:@[ get, delete1, delete1 ]] expectNoDoc];
  [[[tt withNonexistentDoc] runWithStages:@[ get, delete1, update2 ]]
      expectError:FIRFirestoreErrorCodeInvalidArgument];
  [[[tt withNonexistentDoc] runWithStages:@[ get, delete1, set2 ]] expectDoc:@{@"foo" : @"bar2"}];

  [[[tt withNonexistentDoc] runWithStages:@[ get, update1, delete1 ]]
      expectError:FIRFirestoreErrorCodeInvalidArgument];
  [[[tt withNonexistentDoc] runWithStages:@[ get, update1, update2 ]]
      expectError:FIRFirestoreErrorCodeInvalidArgument];
  [[[tt withNonexistentDoc] runWithStages:@[ get, update1, set2 ]]
      expectError:FIRFirestoreErrorCodeInvalidArgument];

  [[[tt withNonexistentDoc] runWithStages:@[ get, set1, delete1 ]] expectNoDoc];
  [[[tt withNonexistentDoc] runWithStages:@[ get, set1, update2 ]] expectDoc:@{@"foo" : @"bar2"}];
  [[[tt withNonexistentDoc] runWithStages:@[ get, set1, set2 ]] expectDoc:@{@"foo" : @"bar2"}];
}

- (void)testRunsTransactionOnExistingDoc {
  FIRFirestore *firestore = [self firestore];
  FSTTransactionTester *tt = [[FSTTransactionTester alloc] initWithDb:firestore testCase:self];

  [[[tt withExistingDoc] runWithStages:@[ delete1, delete1 ]] expectNoDoc];
  [[[tt withExistingDoc] runWithStages:@[ delete1, update2 ]]
      expectError:FIRFirestoreErrorCodeInvalidArgument];
  [[[tt withExistingDoc] runWithStages:@[ delete1, set2 ]] expectDoc:@{@"foo" : @"bar2"}];

  [[[tt withExistingDoc] runWithStages:@[ update1, delete1 ]] expectNoDoc];
  [[[tt withExistingDoc] runWithStages:@[ update1, update2 ]] expectDoc:@{@"foo" : @"bar2"}];
  [[[tt withExistingDoc] runWithStages:@[ update1, set2 ]] expectDoc:@{@"foo" : @"bar2"}];

  [[[tt withExistingDoc] runWithStages:@[ set1, delete1 ]] expectNoDoc];
  [[[tt withExistingDoc] runWithStages:@[ set1, update2 ]] expectDoc:@{@"foo" : @"bar2"}];
  [[[tt withExistingDoc] runWithStages:@[ set1, set2 ]] expectDoc:@{@"foo" : @"bar2"}];
}

- (void)testRunsTransactionsOnNonexistentDoc {
  FIRFirestore *firestore = [self firestore];
  FSTTransactionTester *tt = [[FSTTransactionTester alloc] initWithDb:firestore testCase:self];

  [[[tt withNonexistentDoc] runWithStages:@[ delete1, delete1 ]] expectNoDoc];
  [[[tt withNonexistentDoc] runWithStages:@[ delete1, update2 ]]
      expectError:FIRFirestoreErrorCodeInvalidArgument];
  [[[tt withNonexistentDoc] runWithStages:@[ delete1, set2 ]] expectDoc:@{@"foo" : @"bar2"}];

  [[[tt withNonexistentDoc] runWithStages:@[ update1, delete1 ]]
      expectError:FIRFirestoreErrorCodeNotFound];
  [[[tt withNonexistentDoc] runWithStages:@[ update1, update2 ]]
      expectError:FIRFirestoreErrorCodeNotFound];
  [[[tt withNonexistentDoc] runWithStages:@[ update1, set2 ]]
      expectError:FIRFirestoreErrorCodeNotFound];

  [[[tt withNonexistentDoc] runWithStages:@[ set1, delete1 ]] expectNoDoc];
  [[[tt withNonexistentDoc] runWithStages:@[ set1, update2 ]] expectDoc:@{@"foo" : @"bar2"}];
  [[[tt withNonexistentDoc] runWithStages:@[ set1, set2 ]] expectDoc:@{@"foo" : @"bar2"}];
}

- (void)testGetDocuments {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"spaces"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{@"foo" : @1, @"desc" : @"Stuff", @"owner" : @"Jonny"}];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        [transaction getDocument:doc error:error];
        XCTAssertNil(*error);
        return @YES;
      }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertNil(result);
        // We currently require every document read to also be written.
        // TODO(b/34879758): Fix this check once we drop that requirement.
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeInvalidArgument);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testSetDocumentWithMerge {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"towns"] documentWithAutoID];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        [transaction setData:@{@"a" : @"b", @"nested" : @{@"a" : @"b"}} forDocument:doc];
        [transaction setData:@{@"c" : @"d", @"nested" : @{@"c" : @"d"}} forDocument:doc merge:YES];
        return @YES;
      }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertEqualObjects(@YES, result);
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];

  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(snapshot.data,
                        (@{@"a" : @"b", @"c" : @"d", @"nested" : @{@"a" : @"b", @"c" : @"d"}}));
}

- (void)testIncrementTransactionally {
  // A barrier to make sure every transaction reaches the same spot.
  dispatch_semaphore_t writeBarrier = dispatch_semaphore_create(0);
  __block volatile int32_t started = 0;

  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{@"count" : @(5.0)}];

  // Make 3 transactions that will all increment.
  int total = 3;
  for (int i = 0; i < total; i++) {
    XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
    [firestore
        runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
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
          [transaction setData:@{@"count" : @(newCount)} forDocument:doc];
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
  [self writeDocumentRef:doc data:@{@"count" : @(5.0), @"other" : @"yes"}];

  // Make 3 transactions that will all increment.
  int total = 3;
  for (int i = 0; i < total; i++) {
    XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
    [firestore
        runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
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
          [transaction updateData:@{@"count" : @(newCount)} forDocument:doc];
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

- (void)testHandleReadingOneDocAndWritingAnother {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc1 = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  FIRDocumentReference *doc2 = [[firestore collectionWithPath:@"counters"] documentWithAutoID];

  [self writeDocumentRef:doc1 data:@{@"count" : @(15.0)}];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
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
        [transaction setData:@{@"count" : @(16)} forDocument:doc2];
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
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeInvalidArgument);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testReadingADocTwiceWithDifferentVersions {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{@"count" : @(15.0)}];
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
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
        // doc multiple times. But they need to handle read errors anyway.
        XCTAssertNotNil(*error);
        return nil;
      }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        [expectation fulfill];
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeAborted);
      }];
  [self awaitExpectations];

  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(@(1234.0), snapshot[@"count"]);
}

- (void)testReadAndUpdateNonExistentDocumentWithExternalWrite {
  FIRFirestore *firestore = [self firestore];
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        // Get and update a document that doesn't exist so that the transaction fails.
        FIRDocumentReference *doc =
            [[firestore collectionWithPath:@"nonexistent"] documentWithAutoID];
        [transaction getDocument:doc error:error];
        XCTAssertNil(*error);
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
        // Now try to update the other doc from within the transaction.
        // This should fail, because the document didn't exist at the
        // start of the transaction.
        [transaction updateData:@{@"count" : @(16)} forDocument:doc];
        return nil;
      }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        [expectation fulfill];
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeInvalidArgument);
      }];
  [self awaitExpectations];
}

- (void)testCannotHaveAGetWithoutMutations {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"foo"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        FIRDocumentSnapshot *snapshot = [transaction getDocument:doc error:error];
        XCTAssertTrue(snapshot.exists);
        XCTAssertNil(*error);
        return nil;
      }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        // We currently require every document read to also be written.
        // TODO(b/34879758): Fix this check once we drop that requirement.
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeInvalidArgument);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testSuccessWithNoTransactionOperations {
  FIRFirestore *firestore = [self firestore];
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
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
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        OSAtomicIncrement32(&count);
        [transaction setData:@{@"foo" : @"bar"} forDocument:doc];
        if (error) {
          *error = [NSError errorWithDomain:NSCocoaErrorDomain code:35 userInfo:@{}];
        }
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
