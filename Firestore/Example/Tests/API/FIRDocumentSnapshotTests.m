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

#import <XCTest/XCTest.h>

#import "FirebaseFirestore/FIRDocumentSnapshot.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTFieldValue.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRDocumentSnapshotTests : XCTestCase
@end

@implementation FIRDocumentSnapshotTests

- (void)testEquals {
  // Everything is dummy for unit test here. Filtering does not require any app
  // specific setting as far as we do not fetch data.
  FIRFirestore *firestore = FSTTestFirestore();
  FSTDocumentKey *keyFoo = FSTTestDocKey(@"rooms/foo");
  FSTDocumentKey *keyBar = FSTTestDocKey(@"rooms/bar");
  FSTObjectValue *dataFoo = FSTTestObjectValue(@{ @"a" : @1 });
  FSTObjectValue *dataBar = FSTTestObjectValue(@{ @"b" : @1 });
  FSTSnapshotVersion *version = FSTTestVersion(1);
  FSTDocument *docFoo = FSTTestDoc(@"rooms/foo", 1, @{ @"a" : @1 }, NO);
  FSTDocument *docBar = FSTTestDoc(@"rooms/bar", 1, @{ @"b" : @1 }, NO);
  XCTAssertEqualObjects([FIRDocumentSnapshot snapshotWithFirestore:firestore
                                                       documentKey:keyFoo
                                                          document:nil
                                                         fromCache:YES],
                        [FIRDocumentSnapshot snapshotWithFirestore:firestore
                                                       documentKey:keyFoo
                                                          document:nil
                                                         fromCache:YES]);
  XCTAssertEqualObjects([FIRDocumentSnapshot snapshotWithFirestore:firestore
                                                       documentKey:keyFoo
                                                          document:docFoo
                                                         fromCache:YES],
                        [FIRDocumentSnapshot snapshotWithFirestore:firestore
                                                       documentKey:keyFoo
                                                          document:docFoo
                                                         fromCache:YES]);
  XCTAssertNotEqualObjects([FIRDocumentSnapshot snapshotWithFirestore:firestore
                                                          documentKey:keyFoo
                                                             document:nil
                                                            fromCache:YES],
                           [FIRDocumentSnapshot snapshotWithFirestore:firestore
                                                          documentKey:keyBar
                                                             document:nil
                                                            fromCache:YES]);
  XCTAssertNotEqualObjects([FIRDocumentSnapshot snapshotWithFirestore:firestore
                                                          documentKey:keyFoo
                                                             document:docFoo
                                                            fromCache:YES],
                           [FIRDocumentSnapshot snapshotWithFirestore:firestore
                                                          documentKey:keyFoo
                                                             document:docBar
                                                            fromCache:YES]);
  XCTAssertNotEqualObjects([FIRDocumentSnapshot snapshotWithFirestore:firestore
                                                          documentKey:keyFoo
                                                             document:nil
                                                            fromCache:YES],
                           [FIRDocumentSnapshot snapshotWithFirestore:firestore
                                                          documentKey:keyFoo
                                                             document:nil
                                                            fromCache:NO]);

  // Test hash (in)equality here as well.
}

@end

NS_ASSUME_NONNULL_END
