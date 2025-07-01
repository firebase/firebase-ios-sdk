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

#import <FirebaseFirestore/FIRBSONBinaryData.h>
#import <FirebaseFirestore/FIRBSONObjectId.h>
#import <FirebaseFirestore/FIRBSONTimestamp.h>
#import <FirebaseFirestore/FIRDecimal128Value.h>
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
  FIRMinKey *minKey1 = [FIRMinKey shared];
  FIRMinKey *minKey2 = [FIRMinKey shared];
  XCTAssertEqual(minKey1, minKey2);
  XCTAssertTrue([minKey1 isEqual:minKey2]);
}

- (void)testMaxKeySingleton {
  FIRMaxKey *maxKey1 = [FIRMaxKey shared];
  FIRMaxKey *maxKey2 = [FIRMaxKey shared];
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

- (void)testCreateAndReadAndCompareDecimal128Value {
  FIRDecimal128Value *val1 = [[FIRDecimal128Value alloc] initWithValue:@"1.2e3"];
  FIRDecimal128Value *val2 = [[FIRDecimal128Value alloc] initWithValue:@"12e2"];
  FIRDecimal128Value *val3 = [[FIRDecimal128Value alloc] initWithValue:@"0.12e4"];
  FIRDecimal128Value *val4 = [[FIRDecimal128Value alloc] initWithValue:@"12000e-1"];
  FIRDecimal128Value *val5 = [[FIRDecimal128Value alloc] initWithValue:@"1.2"];
  FIRDecimal128Value *val6 = [[FIRDecimal128Value alloc] initWithValue:@"NaN"];
  FIRDecimal128Value *val7 = [[FIRDecimal128Value alloc] initWithValue:@"Infinity"];
  FIRDecimal128Value *val8 = [[FIRDecimal128Value alloc] initWithValue:@"-Infinity"];
  FIRDecimal128Value *val9 = [[FIRDecimal128Value alloc] initWithValue:@"NaN"];
  FIRDecimal128Value *val10 = [[FIRDecimal128Value alloc] initWithValue:@"-0"];
  FIRDecimal128Value *val11 = [[FIRDecimal128Value alloc] initWithValue:@"0"];
  FIRDecimal128Value *val12 = [[FIRDecimal128Value alloc] initWithValue:@"-0.0"];
  FIRDecimal128Value *val13 = [[FIRDecimal128Value alloc] initWithValue:@"0.0"];

  // Test reading the value back
  XCTAssertEqual(@"1.2e3", val1.value);

  // Test isEqual
  XCTAssertTrue([val1 isEqual:val2]);
  XCTAssertTrue([val1 isEqual:val3]);
  XCTAssertTrue([val1 isEqual:val4]);
  XCTAssertFalse([val1 isEqual:val5]);

  // Test isEqual for special values.
  XCTAssertTrue([val6 isEqual:val9]);
  XCTAssertFalse([val7 isEqual:val8]);
  XCTAssertFalse([val7 isEqual:val9]);
  XCTAssertTrue([val10 isEqual:val11]);
  XCTAssertTrue([val10 isEqual:val12]);
  XCTAssertTrue([val10 isEqual:val13]);
}

- (void)testCreateAndReadAndCompareBsonObjectId {
  FIRBSONObjectId *val1 = [[FIRBSONObjectId alloc] initWithValue:@"abcd"];
  FIRBSONObjectId *val2 = [[FIRBSONObjectId alloc] initWithValue:@"abcd"];
  FIRBSONObjectId *val3 = [[FIRBSONObjectId alloc] initWithValue:@"efgh"];

  // Test reading the value back
  XCTAssertEqual(@"abcd", val1.value);

  // Test isEqual
  XCTAssertTrue([val1 isEqual:val2]);
  XCTAssertFalse([val1 isEqual:val3]);
}

- (void)testCreateAndReadAndCompareBsonTimestamp {
  FIRBSONTimestamp *val1 = [[FIRBSONTimestamp alloc] initWithSeconds:1234 increment:100];
  FIRBSONTimestamp *val2 = [[FIRBSONTimestamp alloc] initWithSeconds:1234 increment:100];
  FIRBSONTimestamp *val3 = [[FIRBSONTimestamp alloc] initWithSeconds:4444 increment:100];
  FIRBSONTimestamp *val4 = [[FIRBSONTimestamp alloc] initWithSeconds:1234 increment:444];

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

  FIRBSONBinaryData *val1 = [[FIRBSONBinaryData alloc] initWithSubtype:128 data:data1];
  FIRBSONBinaryData *val2 = [[FIRBSONBinaryData alloc] initWithSubtype:128 data:data2];
  FIRBSONBinaryData *val3 = [[FIRBSONBinaryData alloc] initWithSubtype:128 data:data3];
  FIRBSONBinaryData *val4 = [[FIRBSONBinaryData alloc] initWithSubtype:1 data:data1];

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
  FIRMinKey *minKey1 = [FIRMinKey shared];
  FIRMinKey *minKey2 = [FIRMinKey shared];
  XCTAssertEqual(minKey1, minKey2);
  XCTAssertTrue([minKey1 isEqual:minKey2]);
}

- (void)testFieldValueMaxKey {
  FIRMaxKey *maxKey1 = [FIRMaxKey shared];
  FIRMaxKey *maxKey2 = [FIRMaxKey shared];
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
  FIRBSONObjectId *oid1 = [[FIRBSONObjectId alloc] initWithValue:@"abcd"];
  FIRBSONObjectId *oid2 = [[FIRBSONObjectId alloc] initWithValue:@"abcd"];
  XCTAssertTrue([oid1 isEqual:oid2]);
  XCTAssertEqual(@"abcd", oid2.value);
}

- (void)testFieldValueBsonTimestamp {
  FIRBSONTimestamp *val1 = [[FIRBSONTimestamp alloc] initWithSeconds:1234 increment:100];
  FIRBSONTimestamp *val2 = [[FIRBSONTimestamp alloc] initWithSeconds:1234 increment:100];
  XCTAssertTrue([val1 isEqual:val2]);
  XCTAssertEqual(1234U, val2.seconds);
  XCTAssertEqual(100U, val2.increment);
}

- (void)testFieldValueBsonBinaryData {
  uint8_t byteArray[] = {0x01, 0x02, 0x03, 0x04, 0x05};
  NSData *data = [NSData dataWithBytes:byteArray length:sizeof(byteArray)];
  FIRBSONBinaryData *val1 = [[FIRBSONBinaryData alloc] initWithSubtype:128 data:data];
  FIRBSONBinaryData *val2 = [[FIRBSONBinaryData alloc] initWithSubtype:128 data:data];
  XCTAssertTrue([val1 isEqual:val2]);
  XCTAssertEqual(128, val2.subtype);
  XCTAssertEqual(data, val2.data);
}

@end

NS_ASSUME_NONNULL_END
