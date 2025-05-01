/*
 * Copyright 2025 Google LLC
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
#import <FirebaseFirestore/FIRMaxKey.h>
#import <FirebaseFirestore/FIRMinKey.h>
#import <FirebaseFirestore/FIRRegexValue.h>

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRBsonTypesUnitTests : XCTestCase
@end

@implementation FIRBsonTypesUnitTests

- (void)testMinKeySingleton {
  FIRMinKey *minKey1 = [FIRMinKey instance];
  FIRMinKey *minKey2 = [FIRMinKey instance];
  XCTAssertEqual(minKey1, minKey2);
  XCTAssertTrue([minKey1 isEqual:minKey2]);
}

- (void)testMaxKeySingleton {
  FIRMaxKey *maxKey1 = [FIRMaxKey instance];
  FIRMaxKey *maxKey2 = [FIRMaxKey instance];
  XCTAssertEqual(maxKey1, maxKey2);
  XCTAssertTrue([maxKey1 isEqual:maxKey2]);
}

- (void)testCreateAndReadAndCompareRegexValue {
  FIRRegexValue *regex1 = [[FIRRegexValue alloc] initWithPattern:@"^foo" options:@"i"];
  FIRRegexValue *regex2 = [[FIRRegexValue alloc] initWithPattern:@"^foo" options:@"i"];
  FIRRegexValue *regex3 = [[FIRRegexValue alloc] initWithPattern:@"^foo" options:@"x"];
  FIRRegexValue *regex4 = [[FIRRegexValue alloc] initWithPattern:@"^bar" options:@"i"];

  // Test reading the values back.
  XCTAssertEqual(regex1.pattern, @"^foo");
  XCTAssertEqual(regex1.options, @"i");

  // Test isEqual
  XCTAssertTrue([regex1 isEqual:regex2]);
  XCTAssertFalse([regex1 isEqual:regex3]);
  XCTAssertFalse([regex1 isEqual:regex4]);
}

- (void)testCreateAndReadAndCompareInt32Value {
  FIRInt32Value *val1 = [[FIRInt32Value alloc] initWithValue:5];
  FIRInt32Value *val2 = [[FIRInt32Value alloc] initWithValue:5];
  FIRInt32Value *val3 = [[FIRInt32Value alloc] initWithValue:3];

  // Test reading the value back
  XCTAssertEqual(5, val1.value);

  // Test isEqual
  XCTAssertTrue([val1 isEqual:val2]);
  XCTAssertFalse([val1 isEqual:val3]);
}

- (void)testCreateAndReadAndCompareBsonObjectId {
  FIRBsonObjectId *val1 = [[FIRBsonObjectId alloc] initWithValue:@"abcd"];
  FIRBsonObjectId *val2 = [[FIRBsonObjectId alloc] initWithValue:@"abcd"];
  FIRBsonObjectId *val3 = [[FIRBsonObjectId alloc] initWithValue:@"efgh"];

  // Test reading the value back
  XCTAssertEqual(@"abcd", val1.value);

  // Test isEqual
  XCTAssertTrue([val1 isEqual:val2]);
  XCTAssertFalse([val1 isEqual:val3]);
}

- (void)testCreateAndReadAndCompareBsonTimestamp {
  FIRBsonTimestamp *val1 = [[FIRBsonTimestamp alloc] initWithSeconds:1234 increment:100];
  FIRBsonTimestamp *val2 = [[FIRBsonTimestamp alloc] initWithSeconds:1234 increment:100];
  FIRBsonTimestamp *val3 = [[FIRBsonTimestamp alloc] initWithSeconds:4444 increment:100];
  FIRBsonTimestamp *val4 = [[FIRBsonTimestamp alloc] initWithSeconds:1234 increment:444];

  // Test reading the values back.
  XCTAssertEqual(1234U, val1.seconds);
  XCTAssertEqual(100U, val1.increment);

  // Test isEqual
  XCTAssertTrue([val1 isEqual:val2]);
  XCTAssertFalse([val1 isEqual:val3]);
  XCTAssertFalse([val1 isEqual:val4]);
}

- (void)testCreateAndReadAndCompareBsonBinaryData {
  uint8_t byteArray1[] = {0x01, 0x02, 0x03, 0x04, 0x05};
  uint8_t byteArray2[] = {0x01, 0x02, 0x03, 0x04, 0x99};
  NSData *data1 = [NSData dataWithBytes:byteArray1 length:sizeof(byteArray1)];
  NSData *data2 = [NSData dataWithBytes:byteArray1 length:sizeof(byteArray1)];
  NSData *data3 = [NSData dataWithBytes:byteArray2 length:sizeof(byteArray2)];

  FIRBsonBinaryData *val1 = [[FIRBsonBinaryData alloc] initWithSubtype:128 data:data1];
  FIRBsonBinaryData *val2 = [[FIRBsonBinaryData alloc] initWithSubtype:128 data:data2];
  FIRBsonBinaryData *val3 = [[FIRBsonBinaryData alloc] initWithSubtype:128 data:data3];
  FIRBsonBinaryData *val4 = [[FIRBsonBinaryData alloc] initWithSubtype:1 data:data1];

  // Test reading the values back.
  XCTAssertEqual(128, val1.subtype);
  XCTAssertEqual(data1, val1.data);
  XCTAssertTrue([val1.data isEqualToData:data1]);

  // Test isEqual
  XCTAssertTrue([val1 isEqual:val2]);
  XCTAssertFalse([val1 isEqual:val3]);
  XCTAssertFalse([val1 isEqual:val4]);
}

- (void)testFieldValueMinKey {
  FIRMinKey *minKey1 = [FIRMinKey instance];
  FIRMinKey *minKey2 = [FIRMinKey instance];
  XCTAssertEqual(minKey1, minKey2);
  XCTAssertTrue([minKey1 isEqual:minKey2]);
}

- (void)testFieldValueMaxKey {
  FIRMaxKey *maxKey1 = [FIRMaxKey instance];
  FIRMaxKey *maxKey2 = [FIRMaxKey instance];
  XCTAssertEqual(maxKey1, maxKey2);
  XCTAssertTrue([maxKey1 isEqual:maxKey2]);
}

- (void)testFieldValueRegex {
  FIRRegexValue *regex1 = [[FIRRegexValue alloc] initWithPattern:@"^foo" options:@"i"];
  FIRRegexValue *regex2 = [[FIRRegexValue alloc] initWithPattern:@"^foo" options:@"i"];
  XCTAssertTrue([regex1 isEqual:regex2]);
  XCTAssertEqual(@"^foo", regex2.pattern);
  XCTAssertEqual(@"i", regex2.options);
}

- (void)testFieldValueInt32 {
  FIRInt32Value *val1 = [[FIRInt32Value alloc] initWithValue:5];
  FIRInt32Value *val2 = [[FIRInt32Value alloc] initWithValue:5];
  XCTAssertTrue([val1 isEqual:val2]);
  XCTAssertEqual(5, val2.value);
}

- (void)testFieldValueObjectId {
  FIRBsonObjectId *oid1 = [[FIRBsonObjectId alloc] initWithValue:@"abcd"];
  FIRBsonObjectId *oid2 = [[FIRBsonObjectId alloc] initWithValue:@"abcd"];
  XCTAssertTrue([oid1 isEqual:oid2]);
  XCTAssertEqual(@"abcd", oid2.value);
}

- (void)testFieldValueBsonTimestamp {
  FIRBsonTimestamp *val1 = [[FIRBsonTimestamp alloc] initWithSeconds:1234 increment:100];
  FIRBsonTimestamp *val2 = [[FIRBsonTimestamp alloc] initWithSeconds:1234 increment:100];
  XCTAssertTrue([val1 isEqual:val2]);
  XCTAssertEqual(1234U, val2.seconds);
  XCTAssertEqual(100U, val2.increment);
}

- (void)testFieldValueBsonBinaryData {
  uint8_t byteArray[] = {0x01, 0x02, 0x03, 0x04, 0x05};
  NSData *data = [NSData dataWithBytes:byteArray length:sizeof(byteArray)];
  FIRBsonBinaryData *val1 = [[FIRBsonBinaryData alloc] initWithSubtype:128 data:data];
  FIRBsonBinaryData *val2 = [[FIRBsonBinaryData alloc] initWithSubtype:128 data:data];
  XCTAssertTrue([val1 isEqual:val2]);
  XCTAssertEqual(128, val2.subtype);
  XCTAssertEqual(data, val2.data);
}

@end

NS_ASSUME_NONNULL_END
