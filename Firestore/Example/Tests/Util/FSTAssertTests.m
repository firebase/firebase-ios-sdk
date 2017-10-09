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

#import "Util/FSTAssert.h"

#import <XCTest/XCTest.h>

@interface FSTAssertTests : XCTestCase
@end

@implementation FSTAssertTests

- (void)testFail {
  @try {
    [self failingMethod];
    XCTFail("Should not have succeeded");
  } @catch (NSException *ex) {
    XCTAssertEqualObjects(ex.name, NSInternalInconsistencyException);
    XCTAssertEqualObjects(ex.reason, @"FIRESTORE INTERNAL ASSERTION FAILED: 0:foo:bar");
  }
}

// A method guaranteed to fail. Note that the return type is intentionally something that is
// not actually returned in the body to ensure that the function attribute declarations in the
// macro properly mark this macro invocation as never returning.
- (int)failingMethod {
  FSTFail(@"%d:%s:%@", 0, "foo", @"bar");
}

- (void)testCFail {
  @try {
    failingFunction();
    XCTFail("Should not have succeeded");
  } @catch (NSException *ex) {
    XCTAssertEqualObjects(ex.name, NSInternalInconsistencyException);
    XCTAssertEqualObjects(ex.reason, @"FIRESTORE INTERNAL ASSERTION FAILED: 0:foo:bar");
  }
}

// A function guaranteed to fail. Note that the return type is intentionally something that is
// not actually returned in the body to ensure that the function attribute declarations in the
// macro properly mark this macro invocation as never returning.
int failingFunction() {
  FSTCFail(@"%d:%s:%@", 0, "foo", @"bar");
}

- (void)testAssertNonFailing {
  @try {
    FSTAssert(YES, @"shouldn't fail");
  } @catch (NSException *ex) {
    XCTFail("Should not have failed, but got %@", ex);
  }
}

- (void)testAssertFailing {
  @try {
    FSTAssert(NO, @"should fail");
    XCTFail("Should not have succeeded");
  } @catch (NSException *ex) {
    XCTAssertEqualObjects(ex.name, NSInternalInconsistencyException);
    XCTAssertEqualObjects(ex.reason, @"FIRESTORE INTERNAL ASSERTION FAILED: should fail");
  }
}

- (void)testCAssertNonFailing {
  @try {
    nonAssertingFunction();
  } @catch (NSException *ex) {
    XCTFail("Should not have failed, but got %@", ex);
  }
}

int nonAssertingFunction() {
  FSTCAssert(YES, @"shouldn't fail");
  return 0;
}

- (void)testCAssertFailing {
  @try {
    assertingFunction();
    XCTFail("Should not have succeeded");
  } @catch (NSException *ex) {
    XCTAssertEqualObjects(ex.name, NSInternalInconsistencyException);
    XCTAssertEqualObjects(ex.reason, @"FIRESTORE INTERNAL ASSERTION FAILED: should fail");
  }
}

int assertingFunction() {
  FSTCAssert(NO, @"should fail");
}

@end
