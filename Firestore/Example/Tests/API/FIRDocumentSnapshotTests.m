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
  XCTAssertEqualObjects(FSTTestDocSnapshot(@"rooms/foo", 1, nil, NO, NO),
                        FSTTestDocSnapshot(@"rooms/foo", 1, nil, NO, NO));
  XCTAssertEqualObjects(FSTTestDocSnapshot(@"rooms/bar", 1, @{ @"a" : @1 }, NO, NO),
                        FSTTestDocSnapshot(@"rooms/bar", 1, @{ @"a" : @1 }, NO, NO));
  XCTAssertNotEqualObjects(FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"a" : @1 }, NO, NO),
                           FSTTestDocSnapshot(@"rooms/bar", 1, @{ @"a" : @1 }, NO, NO));
  XCTAssertNotEqualObjects(FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"a" : @1 }, NO, NO),
                           FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"b" : @1 }, NO, NO));
  XCTAssertNotEqualObjects(FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"a" : @1 }, YES, NO),
                           FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"b" : @1 }, NO, NO));
  XCTAssertNotEqualObjects(FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"a" : @1 }, NO, YES),
                           FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"b" : @1 }, NO, NO));

  XCTAssertEqual([FSTTestDocSnapshot(@"rooms/foo", 1, nil, NO, NO) hash],
                 [FSTTestDocSnapshot(@"rooms/foo", 1, nil, NO, NO) hash]);
  XCTAssertEqual([FSTTestDocSnapshot(@"rooms/bar", 1, @{ @"a" : @1 }, NO, NO) hash],
                 [FSTTestDocSnapshot(@"rooms/bar", 1, @{ @"a" : @1 }, NO, NO) hash]);
  XCTAssertNotEqual([FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"a" : @1 }, NO, NO) hash],
                    [FSTTestDocSnapshot(@"rooms/bar", 1, @{ @"a" : @1 }, NO, NO) hash]);
  XCTAssertNotEqual([FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"a" : @1 }, NO, NO) hash],
                    [FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"b" : @1 }, NO, NO) hash]);
  XCTAssertNotEqual([FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"a" : @1 }, YES, NO) hash],
                    [FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"b" : @1 }, NO, NO) hash]);
  XCTAssertNotEqual([FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"a" : @1 }, NO, YES) hash],
                    [FSTTestDocSnapshot(@"rooms/foo", 1, @{ @"b" : @1 }, NO, NO) hash]);
}

@end

NS_ASSUME_NONNULL_END
