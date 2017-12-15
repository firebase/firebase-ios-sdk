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

#import "Firestore/Source/API/FIRCollectionReference+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Model/FSTPath.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRCollectionReferenceTests : XCTestCase
@end

@implementation FIRCollectionReferenceTests

- (void)testEquals {
  // Everything is dummy for unit test here. Filtering does not require any app
  // specific setting as far as we do not fetch data.
  FIRFirestore *firestore = [[FIRFirestore alloc] initWithProjectID:@"abc"
                                                           database:@"abc"
                                                     persistenceKey:@"db123"
                                                credentialsProvider:nil
                                                workerDispatchQueue:nil
                                                        firebaseApp:nil];
  FSTResourcePath *pathFoo = [FSTResourcePath pathWithString:@"foo"];
  FSTResourcePath *pathBar = [FSTResourcePath pathWithString:@"bar"];
  FIRCollectionReference *referenceFoo =
      [FIRCollectionReference referenceWithPath:pathFoo firestore:firestore];
  FIRCollectionReference *referenceFooDup =
      [FIRCollectionReference referenceWithPath:pathFoo firestore:firestore];
  FIRCollectionReference *referenceBar =
      [FIRCollectionReference referenceWithPath:pathBar firestore:firestore];
  XCTAssertEqualObjects(referenceFoo, referenceFooDup);
  XCTAssertNotEqualObjects(referenceFoo, referenceBar);

  XCTAssertEqual([referenceFoo hash], [referenceFooDup hash]);
  XCTAssertNotEqual([referenceFoo hash], [referenceBar hash]);
}

@end

NS_ASSUME_NONNULL_END
