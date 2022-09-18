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
#include <atomic>

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"

using firebase::firestore::util::TimerId;

@interface FSTTransactionTests : FSTIntegrationTestCase
- (void)runFailedPreconditionTransactionWithOptions:(FIRTransactionOptions *_Nullable)options
                                  expectNumAttempts:(int)expectedNumAttempts;
@end

/**
 * This category is to handle the use of assertions in `FSTTransactionTester`, since XCTest
 * assertions do not work in classes that don't extend XCTestCase.
 */
@interface FSTTransactionTests (Assertions)
- (void)assertExistsWithSnapshot:(FIRDocumentSnapshot *)snapshot error:(NSError *)error;
- (void)assertDoesNotExistWithSnapshot:(FIRDocumentSnapshot *)snapshot error:(NSError *)error;
- (void)assertNilError:(NSError *)error message:(NSString *)message;
- (void)assertError:(NSError *)error message:(NSString *)message code:(NSInteger)code;
- (void)assertSnapshot:(FIRDocumentSnapshot *)snapshot
          equalsObject:(NSObject *)expected
                 error:(NSError *)error;
@end

@implementation FSTTransactionTests (Assertions)
- (void)assertExistsWithSnapshot:(FIRDocumentSnapshot *)snapshot error:(NSError *)error {
  XCTAssertNil(error);
  XCTAssertTrue(snapshot.exists);
}

- (void)assertDoesNotExistWithSnapshot:(FIRDocumentSnapshot *)snapshot error:(NSError *)error {
  XCTAssertNil(error);
  XCTAssertFalse(snapshot.exists);
}

- (void)assertNilError:(NSError *)error message:(NSString *)message {
  XCTAssertNil(error, @"%@", message);
}

- (void)assertError:(NSError *)error message:(NSString *)message code:(NSInteger)code {
  XCTAssertNotNil(error, @"%@", message);
  XCTAssertEqual(error.code, code, @"%@", message);
}

- (void)assertSnapshot:(FIRDocumentSnapshot *)snapshot
          equalsObject:(NSObject *)expected
                 error:(NSError *)error {
  XCTAssertNil(error);
  XCTAssertTrue(snapshot.exists);
  XCTAssertEqualObjects(expected, snapshot.data);
}
@end

typedef void (^TransactionStage)(FIRTransaction *, FIRDocumentReference *);

/**
 * The transaction stages that follow are postfixed by numbers to indicate the calling order. For
 * example, calling `set1` followed by `set2` should result in the document being set to the value
 * specified by `set2`.
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

/**
 * Used for testing that all possible combinations of executing transactions result in the desired
 * document value or error.
 *
 * `runWithStages`, `withExistingDoc`, and `withNonexistentDoc` don't actually do anything except
 * assign variables into `FSTTransactionTester`.
 *
 * `expectDoc`, `expectNoDoc`, and `expectError` will trigger the transaction to run and assert
 * that the end result matches the input.
 */
@interface FSTTransactionTester : NSObject
- (FSTTransactionTester *)withExistingDoc;
- (FSTTransactionTester *)withNonexistentDoc;
- (FSTTransactionTester *)runWithStages:(NSArray<TransactionStage> *)stages;
- (void)expectDoc:(NSObject *)expected;
- (void)expectNoDoc;
- (void)expectError:(FIRFirestoreErrorCode)expected;

@property(atomic, strong, readwrite) NSArray<TransactionStage> *stages;
@property(atomic, strong, readwrite) FIRDocumentReference *docRef;
@property(atomic, assign, readwrite) BOOL fromExistingDoc;
@end

@implementation FSTTransactionTester {
  FIRFirestore *_db;
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
  self.fromExistingDoc = YES;
  return self;
}

- (FSTTransactionTester *)withNonexistentDoc {
  self.fromExistingDoc = NO;
  return self;
}

- (FSTTransactionTester *)runWithStages:(NSArray<TransactionStage> *)stages {
  self.stages = stages;
  return self;
}

- (void)expectDoc:(NSObject *)expected {
  [self prepareDoc];
  [self runSuccessfulTransaction];

  XCTestExpectation *expectation = [_testCase expectationWithDescription:@"expectDoc"];
  [self.docRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    [self->_testCase assertSnapshot:snapshot equalsObject:expected error:error];
    [expectation fulfill];
  }];
  [_testCase awaitExpectations];

  [self cleanupTester];
}

- (void)expectNoDoc {
  [self prepareDoc];
  [self runSuccessfulTransaction];

  XCTestExpectation *expectation = [_testCase expectationWithDescription:@"expectNoDoc"];
  [self.docRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
    [self->_testCase assertDoesNotExistWithSnapshot:snapshot error:error];
    [expectation fulfill];
  }];
  [_testCase awaitExpectations];

  [self cleanupTester];
}

- (void)expectError:(FIRFirestoreErrorCode)expected {
  [self prepareDoc];
  [self runFailingTransactionWithError:expected];

  [self cleanupTester];
}

- (void)prepareDoc {
  self.docRef = [[_db collectionWithPath:@"nonexistent"] documentWithAutoID];
  if (_fromExistingDoc) {
    NSError *setError = [self writeDocumentRef:self.docRef data:@{@"foo" : @"bar"}];
    NSString *message = [NSString stringWithFormat:@"Failed set at %@", [self stageNames]];
    [_testCase assertNilError:setError message:message];
  }
}

- (NSError *)writeDocumentRef:(FIRDocumentReference *)ref
                         data:(NSDictionary<NSString *, id> *)data {
  __block NSError *errorResult;
  XCTestExpectation *expectation = [_testCase expectationWithDescription:@"prepareDoc:set"];
  [ref setData:data
      completion:^(NSError *error) {
        errorResult = error;
        [expectation fulfill];
      }];
  [_testCase awaitExpectations];
  return errorResult;
}

- (void)runSuccessfulTransaction {
  XCTestExpectation *expectation =
      [_testCase expectationWithDescription:@"runSuccessfulTransaction"];
  [_db
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **) {
        for (TransactionStage stage in self.stages) {
          stage(transaction, self.docRef);
        }
        return @YES;
      }
      completion:^(id, NSError *error) {
        [expectation fulfill];
        NSString *message =
            [NSString stringWithFormat:@"Expected the sequence %@, to succeed, but got %d.",
                                       [self stageNames], (int)[error code]];
        [self->_testCase assertNilError:error message:message];
      }];

  [_testCase awaitExpectations];
}

- (void)runFailingTransactionWithError:(FIRFirestoreErrorCode)expected {
  (void)expected;
  XCTestExpectation *expectation =
      [_testCase expectationWithDescription:@"runFailingTransactionWithError"];
  [_db
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **) {
        for (TransactionStage stage in self.stages) {
          stage(transaction, self.docRef);
        }
        return @YES;
      }
      completion:^(id, NSError *_Nullable error) {
        [expectation fulfill];
        NSString *message =
            [NSString stringWithFormat:@"Expected the sequence (%@), to fail, but it didn't.",
                                       [self stageNames]];
        [self->_testCase assertError:error message:message code:expected];
      }];

  [_testCase awaitExpectations];
}

- (void)cleanupTester {
  self.stages = [NSArray array];
  // Set the docRef to something else to lose the original reference.
  self.docRef = [[self->_db collectionWithPath:@"reset"] documentWithAutoID];
}

- (NSString *)stageNames {
  NSMutableArray<NSString *> *seqList = [NSMutableArray array];
  for (TransactionStage stage in self.stages) {
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

- (void)testSetDocumentWithMerge {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"towns"] documentWithAutoID];

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **) {
        [transaction setData:@{@"a" : @"b", @"nested" : @{@"a" : @"b"}} forDocument:doc];
        [transaction setData:@{@"c" : @"d", @"nested" : @{@"c" : @"d"}} forDocument:doc merge:YES];
        return @YES;
      }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertEqualObjects(result, @YES);
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
  auto counter = std::make_shared<std::atomic_int>(0);

  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{@"count" : @(5.0)}];

  // Skip backoff delays.
  [firestore workerQueue]->SkipDelaysForTimerId(TimerId::RetryTransaction);

  // Make 3 transactions that will all increment.
  int total = 3;
  for (int i = 0; i < total; i++) {
    XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
    [firestore
        runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
          FIRDocumentSnapshot *snapshot = [transaction getDocument:doc error:error];
          XCTAssertNil(*error);
          (*counter)++;
          // Once all of the transactions have read, allow the first write.
          if (*counter == total) {
            dispatch_semaphore_signal(writeBarrier);
          }

          dispatch_semaphore_wait(writeBarrier, DISPATCH_TIME_FOREVER);
          // Refill the barrier so that the other transactions and retries succeed.
          dispatch_semaphore_signal(writeBarrier);

          double newCount = ((NSNumber *)snapshot[@"count"]).doubleValue + 1.0;
          [transaction setData:@{@"count" : @(newCount)} forDocument:doc];
          return @YES;
        }
        completion:^(id, NSError *) {
          [expectation fulfill];
        }];
  }

  [self awaitExpectations];
  // Now all transaction should be completed, so check the result.
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(snapshot[@"count"], @(5.0 + total));
}

- (void)testUpdateTransactionally {
  // A barrier to make sure every transaction reaches the same spot.
  dispatch_semaphore_t writeBarrier = dispatch_semaphore_create(0);
  auto counter = std::make_shared<std::atomic_int>(0);

  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  [self writeDocumentRef:doc data:@{@"count" : @(5.0), @"other" : @"yes"}];

  // Skip backoff delays.
  [firestore workerQueue]->SkipDelaysForTimerId(TimerId::RetryTransaction);

  // Make 3 transactions that will all increment.
  int total = 3;
  for (int i = 0; i < total; i++) {
    XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
    [firestore
        runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
          int32_t nowStarted = ++(*counter);
          FIRDocumentSnapshot *snapshot = [transaction getDocument:doc error:error];
          XCTAssertNil(*error);
          // Once all of the transactions have read, allow the first write. There should be 3
          // initial transaction runs.
          if (nowStarted == total) {
            XCTAssertEqual(counter->load(), 3);
            dispatch_semaphore_signal(writeBarrier);
          }

          dispatch_semaphore_wait(writeBarrier, DISPATCH_TIME_FOREVER);
          // Refill the barrier so that the other transactions and retries succeed.
          dispatch_semaphore_signal(writeBarrier);

          double newCount = ((NSNumber *)snapshot[@"count"]).doubleValue + 1.0;
          [transaction updateData:@{@"count" : @(newCount)} forDocument:doc];
          return @YES;
        }
        completion:^(id, NSError *) {
          [expectation fulfill];
        }];
  }

  [self awaitExpectations];
  // There should be a maximum of 3 retries: once for the 2nd update, and twice for the 3rd update.
  XCTAssertLessThanOrEqual(counter->load(), 6);
  // Now all transaction should be completed, so check the result.
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(snapshot[@"count"], @(5.0 + total));
  XCTAssertEqualObjects(@"yes", snapshot[@"other"]);
}

- (void)testRetriesWhenDocumentThatWasReadWithoutBeingWrittenChanges {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc1 = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  FIRDocumentReference *doc2 = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  auto counter = std::make_shared<std::atomic_int>(0);

  [self writeDocumentRef:doc1 data:@{@"count" : @(15.0)}];

  // Skip backoff delays.
  [firestore workerQueue]->SkipDelaysForTimerId(TimerId::RetryTransaction);

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        ++(*counter);
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
            completion:^(NSError *) {
              dispatch_semaphore_signal(writeSemaphore);
            }];
        // We can block on it, because transactions run on a background queue.
        dispatch_semaphore_wait(writeSemaphore, DISPATCH_TIME_FOREVER);
        // Now try to update the other doc from within the transaction.
        // This should fail once, because we read 15 earlier.
        [transaction setData:@{@"count" : @(16)} forDocument:doc2];
        return nil;
      }
      completion:^(id, NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(counter->load(), 2);
        [expectation fulfill];
      }];
  [self awaitExpectations];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc1];
  XCTAssertEqualObjects(snapshot[@"count"], @(1234));
}

- (void)testReadingADocTwiceWithDifferentVersions {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  auto counter = std::make_shared<std::atomic_int>(0);

  [self writeDocumentRef:doc data:@{@"count" : @(15.0)}];

  // Skip backoff delays.
  [firestore workerQueue]->SkipDelaysForTimerId(TimerId::RetryTransaction);

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        ++(*counter);
        // Get the doc once.
        FIRDocumentSnapshot *snapshot = [transaction getDocument:doc error:error];
        XCTAssertNotNil(snapshot);
        XCTAssertNil(*error);
        // Do a write outside of the transaction. Because the transaction will retry, set the
        // document to a different value each time.
        dispatch_semaphore_t writeSemaphore = dispatch_semaphore_create(0);
        [doc setData:@{
          @"count" : @(1234 + (int)(*counter))
        }
            completion:^(NSError *) {
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
        XCTAssertNil(snapshot);
        XCTAssertNotNil(*error);
        return nil;
      }
      completion:^(id, NSError *_Nullable error) {
        [expectation fulfill];
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeAborted);
      }];
  [self awaitExpectations];
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
            completion:^(NSError *) {
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
      completion:^(id, NSError *_Nullable error) {
        [expectation fulfill];
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeInvalidArgument);
      }];
  [self awaitExpectations];
}

- (void)testCanHaveGetsWithoutMutations {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"foo"] documentWithAutoID];
  FIRDocumentReference *doc2 = [[firestore collectionWithPath:@"foo"] documentWithAutoID];

  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        [transaction getDocument:doc2 error:error];
        [transaction getDocument:doc error:error];
        return nil;
      }
      completion:^(id, NSError *_Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(snapshot[@"foo"], @"bar");
}

- (void)testDoesNotRetryOnPermanentError {
  FIRFirestore *firestore = [self firestore];
  auto counter = std::make_shared<std::atomic_int>(0);

  // Make a transaction that should fail with a permanent error
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        ++(*counter);
        // Get and update a document that doesn't exist so that the transaction fails.
        FIRDocumentReference *doc =
            [[firestore collectionWithPath:@"nonexistent"] documentWithAutoID];
        [transaction getDocument:doc error:error];
        [transaction updateData:@{@"count" : @(16)} forDocument:doc];
        return nil;
      }
      completion:^(id, NSError *_Nullable error) {
        [expectation fulfill];
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeInvalidArgument);
        XCTAssertEqual(counter->load(), 1);
      }];
  [self awaitExpectations];
}

- (void)testMakesDefaultMaxAttempts {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc1 = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  auto counter = std::make_shared<std::atomic_int>(0);

  [self writeDocumentRef:doc1 data:@{@"count" : @(15.0)}];

  // Skip backoff delays.
  [firestore workerQueue]->SkipDelaysForTimerId(TimerId::RetryTransaction);

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        ++(*counter);
        // Get the first doc.
        [transaction getDocument:doc1 error:error];
        XCTAssertNil(*error);
        // Do a write outside of the transaction to cause the transaction to fail.
        dispatch_semaphore_t writeSemaphore = dispatch_semaphore_create(0);
        int newValue = 1234 + counter->load();
        [doc1 setData:@{
          @"count" : @(newValue)
        }
            completion:^(NSError *) {
              dispatch_semaphore_signal(writeSemaphore);
            }];
        // We can block on it, because transactions run on a background queue.
        dispatch_semaphore_wait(writeSemaphore, DISPATCH_TIME_FOREVER);
        return nil;
      }
      completion:^(id, NSError *_Nullable error) {
        [expectation fulfill];
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeFailedPrecondition);
        XCTAssertEqual(counter->load(), 5);
      }];
  [self awaitExpectations];
}

- (void)testSuccessWithNoTransactionOperations {
  FIRFirestore *firestore = [self firestore];
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *, NSError **) {
        return @"yes";
      }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertEqualObjects(result, @"yes");
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testCancellationOnError {
  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"towns"] documentWithAutoID];
  auto counter = std::make_shared<std::atomic_int>(0);
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore
      runTransactionWithBlock:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        ++(*counter);
        [transaction setData:@{@"foo" : @"bar"} forDocument:doc];
        if (error) {
          *error = [NSError errorWithDomain:NSCocoaErrorDomain code:35 userInfo:@{}];
        }
        return nil;
      }
      completion:^(id _Nullable result, NSError *_Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, 35);
        [expectation fulfill];
      }];
  [self awaitExpectations];
  XCTAssertEqual(counter->load(), 1);
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
      completion:^(id, NSError *error) {
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
      completion:^(id, NSError *error) {
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

- (void)runFailedPreconditionTransactionWithOptions:(FIRTransactionOptions *_Nullable)options
                                  expectNumAttempts:(int)expectedNumAttempts {
  // Note: The logic below to force retries is heavily based on
  // testRetriesWhenDocumentThatWasReadWithoutBeingWrittenChanges.

  FIRFirestore *firestore = [self firestore];
  FIRDocumentReference *doc = [[firestore collectionWithPath:@"counters"] documentWithAutoID];
  auto attemptCount = std::make_shared<std::atomic_int>(0);
  attemptCount->store(0);

  [self writeDocumentRef:doc data:@{@"count" : @"initial value"}];

  // Skip backoff delays.
  [firestore workerQueue]->SkipDelaysForTimerId(TimerId::RetryTransaction);

  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction"];
  [firestore runTransactionWithOptions:options
      block:^id _Nullable(FIRTransaction *transaction, NSError **error) {
        ++(*attemptCount);

        [transaction getDocument:doc error:error];
        XCTAssertNil(*error);

        // Do a write outside of the transaction. This will force the transaction to be retried.
        dispatch_semaphore_t writeSemaphore = dispatch_semaphore_create(0);
        [doc setData:@{
          @"count" : @(attemptCount->load())
        }
            completion:^(NSError *) {
              dispatch_semaphore_signal(writeSemaphore);
            }];
        dispatch_semaphore_wait(writeSemaphore, DISPATCH_TIME_FOREVER);

        // Now try to update the doc from within the transaction.
        // This will fail since the document was modified outside of the transaction.
        [transaction setData:@{@"count" : @"this write should fail"} forDocument:doc];
        return nil;
      }
      completion:^(id, NSError *_Nullable error) {
        [self assertError:error
                  message:@"the transaction should fail due to retries exhausted"
                     code:FIRFirestoreErrorCodeFailedPrecondition];
        XCTAssertEqual(attemptCount->load(), expectedNumAttempts);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testTransactionOptionsNil {
  [self runFailedPreconditionTransactionWithOptions:nil expectNumAttempts:5];
}

- (void)testTransactionOptionsMaxAttempts {
  FIRTransactionOptions *options = [[FIRTransactionOptions alloc] init];
  options.maxAttempts = 7;
  [self runFailedPreconditionTransactionWithOptions:options expectNumAttempts:7];
}

@end
