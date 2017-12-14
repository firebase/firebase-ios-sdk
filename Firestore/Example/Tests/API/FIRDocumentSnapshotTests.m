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

#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
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
  FIRFirestore *firestore = [[FIRFirestore alloc] initWithProjectID:@"abc"
                                                           database:@"abc"
                                                     persistenceKey:@"db123"
                                                credentialsProvider:nil
                                                workerDispatchQueue:nil
                                                        firebaseApp:nil];
  FSTDocumentKey *keyFoo = [FSTDocumentKey keyWithPathString:@"rooms/foo"];
  FSTDocumentKey *keyBar = [FSTDocumentKey keyWithPathString:@"rooms/bar"];
  FSTObjectValue *dateFoo = FSTTestObjectValue(@{ @"a" : @1 });
  FSTObjectValue *dateBar = FSTTestObjectValue(@{ @"b" : @1 });
  FSTSnapshotVersion *version = FSTTestVersion(1);
  FSTDocument *docFoo = [FSTDocument documentWithData:dateFoo
                                                  key:keyFoo
                                              version:version
                                    hasLocalMutations:NO];
  FSTDocument *docBar = [FSTDocument documentWithData:dateBar
                                                  key:keyBar
                                              version:version
                                    hasLocalMutations:NO];
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
}

@end

NS_ASSUME_NONNULL_END
