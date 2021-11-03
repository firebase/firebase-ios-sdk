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

#import <FirebaseFirestore/FIRFieldPath.h>

#import <XCTest/XCTest.h>

#import "Firestore/Source/API/FIRFieldPath+Internal.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/test/unit/testutil/testutil.h"

using firebase::firestore::testutil::Field;

NS_ASSUME_NONNULL_BEGIN

@interface FIRFieldPathTests : XCTestCase
@end

@implementation FIRFieldPathTests

- (void)testEquals {
  FIRFieldPath *foo = [[FIRFieldPath alloc] initPrivate:Field("foo.ooo.oooo")];
  FIRFieldPath *fooDup = [[FIRFieldPath alloc] initPrivate:Field("foo.ooo.oooo")];
  FIRFieldPath *bar = [[FIRFieldPath alloc] initPrivate:Field("baa.aaa.aaar")];
  XCTAssertEqualObjects(foo, fooDup);
  XCTAssertNotEqualObjects(foo, bar);

  XCTAssertEqual([foo hash], [fooDup hash]);
  XCTAssertNotEqual([foo hash], [bar hash]);
}

@end

NS_ASSUME_NONNULL_END
