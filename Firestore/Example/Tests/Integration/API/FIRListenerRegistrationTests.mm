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

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"

@interface FIRListenerRegistrationTests : FSTIntegrationTestCase
@end

@implementation FIRListenerRegistrationTests

- (void)testCanBeRemoved {
  FIRCollectionReference *collectionRef = [self collectionRef];
  FIRDocumentReference *docRef = [collectionRef documentWithAutoID];

  __block int callbacks = 0;
  id<FIRListenerRegistration> one =
      [collectionRef addSnapshotListener:^(FIRQuerySnapshot *, NSError *_Nullable error) {
        XCTAssertNil(error);
        callbacks++;
      }];

  id<FIRListenerRegistration> two =
      [collectionRef addSnapshotListener:^(FIRQuerySnapshot *, NSError *_Nullable error) {
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

  id<FIRListenerRegistration> one =
      [collectionRef addSnapshotListener:^(FIRQuerySnapshot *, NSError *){
      }];
  id<FIRListenerRegistration> two = [docRef addSnapshotListener:^(FIRDocumentSnapshot *, NSError *){
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
  id<FIRListenerRegistration> one =
      [collectionRef addSnapshotListener:^(FIRQuerySnapshot *, NSError *_Nullable error) {
        XCTAssertNil(error);
        @synchronized(self) {
          callbacksOne++;
        }
      }];

  id<FIRListenerRegistration> two =
      [collectionRef addSnapshotListener:^(FIRQuerySnapshot *, NSError *_Nullable error) {
        XCTAssertNil(error);
        @synchronized(self) {
          callbacksTwo++;
        }
      }];

  // Wait for initial events
  [self waitUntil:^BOOL {
    @synchronized(self) {
      return callbacksOne == 1 && callbacksTwo == 1;
    }
  }];

  // Trigger new events
  [self writeDocumentRef:docRef data:@{@"foo" : @"bar"}];

  // Write events should have triggered
  @synchronized(self) {
    XCTAssertEqual(2, callbacksOne);
    XCTAssertEqual(2, callbacksTwo);
  }

  // Should leave "two" unaffected
  [one remove];

  [self writeDocumentRef:docRef data:@{@"foo" : @"new-bar"}];

  // Assert only events for "two" actually occurred
  @synchronized(self) {
    XCTAssertEqual(2, callbacksOne);
    XCTAssertEqual(3, callbacksTwo);
  }

  [self writeDocumentRef:docRef data:@{@"foo" : @"new-bar"}];

  // No more events should occur
  [two remove];
}

- (void)testCanOutliveDocumentReference {
  FIRCollectionReference *collectionRef = [self collectionRef];

  XCTestExpectation *seen = [self expectationWithDescription:@"seen document"];

  __block id<FIRListenerRegistration> registration;
  NSString *documentID;
  @autoreleasepool {
    FIRDocumentReference *docRef = [collectionRef documentWithAutoID];
    documentID = docRef.documentID;
    registration = [docRef addSnapshotListener:^(FIRDocumentSnapshot *snapshot, NSError *) {
      if (snapshot.exists) {
        [seen fulfill];
      }
    }];
    docRef = nil;
  }

  XCTAssertNotNil(registration);

  FIRDocumentReference *docRef2 = [collectionRef documentWithPath:documentID];
  [self writeDocumentRef:docRef2 data:@{@"foo" : @"bar"}];
  [self awaitExpectation:seen];

  [registration remove];
}

@end
