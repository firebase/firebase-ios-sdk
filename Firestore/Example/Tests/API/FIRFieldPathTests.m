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

#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Model/FSTPath.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRFieldPathTests : XCTestCase
@end

@implementation FIRFieldPathTests

- (void)testEquals {
  FSTFieldPath *pathFoo = [FSTFieldPath pathWithServerFormat:@"foo.ooo.oooo"];
  FSTFieldPath *pathFooDup = [FSTFieldPath pathWithServerFormat:@"foo.ooo.oooo"];
  FSTFieldPath *pathBar = [FSTFieldPath pathWithServerFormat:@"baa.aaa.aaar"];
  FIRFieldPath *foo = [[FIRFieldPath alloc] initPrivate:pathFoo];
  FIRFieldPath *fooDup = [[FIRFieldPath alloc] initPrivate:pathFooDup];
  FIRFieldPath *bar = [[FIRFieldPath alloc] initPrivate:pathBar];
  XCTAssertEqualObjects(foo, fooDup);
  XCTAssertNotEqualObjects(foo, bar);
}

@end

NS_ASSUME_NONNULL_END
