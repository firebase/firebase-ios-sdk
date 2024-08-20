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

#import <FirebaseFirestore/FIRFieldValue.h>
#import <FirebaseFirestore/FIRVectorValue.h>

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRFieldValueTests : XCTestCase
@end

@implementation FIRFieldValueTests

- (void)testEquals {
  FIRFieldValue *deleted = [FIRFieldValue fieldValueForDelete];
  FIRFieldValue *deleteDup = [FIRFieldValue fieldValueForDelete];
  FIRFieldValue *serverTimestamp = [FIRFieldValue fieldValueForServerTimestamp];
  FIRFieldValue *serverTimestampDup = [FIRFieldValue fieldValueForServerTimestamp];
  XCTAssertEqualObjects(deleted, deleteDup);
  XCTAssertNotEqualObjects(deleted, nil);
  XCTAssertEqualObjects(serverTimestamp, serverTimestampDup);
  XCTAssertNotEqualObjects(serverTimestamp, nil);
  XCTAssertNotEqualObjects(deleted, serverTimestamp);

  XCTAssertEqual([deleted hash], [deleteDup hash]);
  XCTAssertEqual([serverTimestamp hash], [serverTimestamp hash]);
  XCTAssertNotEqual([deleted hash], [serverTimestamp hash]);
}

@end

NS_ASSUME_NONNULL_END
