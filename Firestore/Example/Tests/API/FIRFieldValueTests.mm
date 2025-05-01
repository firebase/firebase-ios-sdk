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

#import <FirebaseFirestore/FIRBsonBinaryData.h>
#import <FirebaseFirestore/FIRBsonObjectId.h>
#import <FirebaseFirestore/FIRBsonTimestamp.h>
#import <FirebaseFirestore/FIRFieldValue.h>
#import <FirebaseFirestore/FIRInt32Value.h>
#import <FirebaseFirestore/FIRRegexValue.h>
#import <FirebaseFirestore/FIRVectorValue.h>
#import "Firestore/Example/Tests/Util/FSTHelpers.h"

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

- (void)testCanCreateRegexValue {
  FIRRegexValue *regex = [FIRFieldValue regexWithPattern:@"^foo" options:@"x"];
  XCTAssertEqual(regex.pattern, @"^foo");
  XCTAssertEqual(regex.options, @"x");
}

- (void)testCanCreateInt32Value {
  FIRInt32Value *int1 = [FIRFieldValue int32WithValue:1234];
  XCTAssertEqual(int1.value, 1234);

  FIRInt32Value *int2 = [FIRFieldValue int32WithValue:-1234];
  XCTAssertEqual(int2.value, -1234);
}

- (void)testCanCreateBsonObjectId {
  FIRBsonObjectId *objectId = [FIRFieldValue bsonObjectIdWithValue:@"foo"];
  XCTAssertEqual(objectId.value, @"foo");
}

- (void)testCanCreateBsonTimestamp {
  FIRBsonTimestamp *timestamp = [FIRFieldValue bsonTimestampWithSeconds:123 increment:456];
  XCTAssertEqual(timestamp.seconds, 123U);
  XCTAssertEqual(timestamp.increment, 456U);
}

- (void)testCanCreateBsonBinaryData {
  FIRBsonBinaryData *binData = [FIRFieldValue bsonBinaryDataWithSubtype:128
                                                                   data:FSTTestData(1, 2, 3, -1)];
  XCTAssertEqual(binData.subtype, 128);
  XCTAssertTrue([binData.data isEqualToData:FSTTestData(1, 2, 3, -1)]);
}

@end

NS_ASSUME_NONNULL_END
