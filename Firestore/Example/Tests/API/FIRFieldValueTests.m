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

#import "Firestore/Source/API/FIRFieldValue+Internal.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRFieldValueTests : XCTestCase
@end

@implementation FIRFieldValueTests

- (void)testEquals {
  XCTAssertEqualObjects([FIRFieldValue fieldValueForDelete], [FIRFieldValue fieldValueForDelete]);
  XCTAssertNotEqualObjects([FIRFieldValue fieldValueForDelete], nil);
  XCTAssertEqualObjects([FIRFieldValue fieldValueForServerTimestamp],
                        [FIRFieldValue fieldValueForServerTimestamp]);
  XCTAssertNotEqualObjects([FIRFieldValue fieldValueForServerTimestamp], nil);
  XCTAssertNotEqualObjects([FIRFieldValue fieldValueForDelete],
                           [FIRFieldValue fieldValueForServerTimestamp]);
}

@end

NS_ASSUME_NONNULL_END
