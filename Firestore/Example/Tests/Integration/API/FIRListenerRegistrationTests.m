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

@import FirebaseFirestore;

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"

@interface FIRListenerRegistrationTests : FSTIntegrationTestCase
@end

@implementation FIRListenerRegistrationTests

- (void)testCanBeRemoved {
  FIRCollectionReference *collectionRef = [self collectionRef];
  FIRDocumentReference *docRef = [collectionRef documentWithAutoID];

  __block int callbacks = 0;
  id<FIRListenerRegistration> one = [collectionRef
      addSnapshotListener:^(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error) {
        XCTAssertNil(error);
        callbacks++;
      }];

  id<FIRListenerRegistration> two = [collectionRef
      addSnapshotListener:^(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error) {
        XCTAssertNil(error);
        callbacks++;
      }];

  // Wait for initial events
  [self waitUntil:^BOOL {
    return callbacks == 2;
  }];

  // Trigger new events
  [self writeDocumentRef:docRef data:@{@"foo" : @"bar"}];

  // Write events should have triggered
  XCTAssertEqual(4, callbacks);

  // No more events should occur
  [one remove];
  [two remove];

  [self writeDocumentRef:docRef data:@{@"foo" : @"new-bar"}];

  // Assert no further events occurred
  XCTAssertEqual(4, callbacks);
}

- (void)testCanBeRemovedTwice {
  FIRCollectionReference *collectionRef = [self collectionRef];
  FIRDocumentReference *docRef = [collectionRef documentWithAutoID];

  id<FIRListenerRegistration> one = [collectionRef
      addSnapshotListener:^(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error){
      }];
  id<FIRListenerRegistration> two = [docRef
      addSnapshotListener:^(FIRDocumentSnapshot *_Nullable snapshot, NSError *_Nullable error){
      }];

  [one remove];
  [one remove];

  [two remove];
  [two remove];
}

- (void)testCanBeRemovedIndependently {
  FIRCollectionReference *collectionRef = [self collectionRef];
  FIRDocumentReference *docRef = [collectionRef documentWithAutoID];

  __block int callbacksOne = 0;
  __block int callbacksTwo = 0;
  id<FIRListenerRegistration> one = [collectionRef
      addSnapshotListener:^(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error) {
        XCTAssertNil(error);
        callbacksOne++;
      }];

  id<FIRListenerRegistration> two = [collectionRef
      addSnapshotListener:^(FIRQuerySnapshot *_Nullable snapshot, NSError *_Nullable error) {
        XCTAssertNil(error);
        callbacksTwo++;
      }];

  // Wait for initial events
  [self waitUntil:^BOOL {
    return callbacksOne == 1 && callbacksTwo == 1;
  }];

  // Trigger new events
  [self writeDocumentRef:docRef data:@{@"foo" : @"bar"}];

  // Write events should have triggered
  XCTAssertEqual(2, callbacksOne);
  XCTAssertEqual(2, callbacksTwo);

  // Should leave "two" unaffected
  [one remove];

  [self writeDocumentRef:docRef data:@{@"foo" : @"new-bar"}];

  // Assert only events for "two" actually occurred
  XCTAssertEqual(2, callbacksOne);
  XCTAssertEqual(3, callbacksTwo);

  [self writeDocumentRef:docRef data:@{@"foo" : @"new-bar"}];

  // No more events should occur
  [two remove];
}

- (void)testWatchSurvivesNetworkDisconnect {
  XCTestExpectation *testExpectiation =
      [self expectationWithDescription:@"testWatchSurvivesNetworkDisconnect"];

  FIRCollectionReference *collectionRef = [self collectionRef];
  FIRDocumentReference *docRef = [collectionRef documentWithAutoID];

  FIRFirestore *firestore = collectionRef.firestore;

  FIRQueryListenOptions *options = [[[FIRQueryListenOptions options]
      includeDocumentMetadataChanges:YES] includeQueryMetadataChanges:YES];

  [collectionRef addSnapshotListenerWithOptions:options
                                       listener:^(FIRQuerySnapshot *snapshot, NSError *error) {
                                         XCTAssertNil(error);
                                         if (!snapshot.empty && !snapshot.metadata.fromCache) {
                                           [testExpectiation fulfill];
                                         }
                                       }];

  [firestore.client disableNetworkWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [docRef setData:@{@"foo" : @"bar"}];
    [firestore.client enableNetworkWithCompletion:^(NSError *error) {
      XCTAssertNil(error);
    }];
  }];

  [self awaitExpectations];
}

@end
