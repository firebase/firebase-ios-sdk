/*
 * Copyright 2019 Google
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

#import "Firestore/Source/API/FSTUserDataConverter.h"

#import <FirebaseFirestore/FIRGeoPoint.h>
#import <FirebaseFirestore/FIRTimestamp.h>
#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"

namespace util = firebase::firestore::util;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::FieldValue;

@interface FSTUserDataConverterTests : XCTestCase
@end

@implementation FSTUserDataConverterTests

- (void)testConvertsIntegers {
  NSArray *values = @[
    @(INT_MIN), @(-1), @0, @1, @2, @(UCHAR_MAX), @(INT_MAX),  // Standard integers
    @(LONG_MIN), @(LONG_MAX), @(LLONG_MIN), @(LLONG_MAX)      // Larger values
  ];
  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTIntegerValue class]);
    XCTAssertEqualObjects([wrapped value], @([value longLongValue]));
    XCTAssertEqual(wrapped.type, FieldValue::Type::Integer);
  }
}

- (void)testConvertsDoubles {
  // Note that 0x1.0p-1074 is a hex floating point literal representing the minimum subnormal
  // number: <https://en.wikipedia.org/wiki/Denormal_number>.
  NSArray *values = @[
    @(-INFINITY), @(-DBL_MAX), @(LLONG_MIN * -1.0), @(-1.1), @(-0x1.0p-1074), @(-0.0), @(0.0),
    @(0x1.0p-1074), @(DBL_MIN), @(1.1), @(LLONG_MAX * 1.0), @(DBL_MAX), @(INFINITY)
  ];
  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTDoubleValue class]);
    XCTAssertEqualObjects([wrapped value], value);
    XCTAssertEqual(wrapped.type, FieldValue::Type::Double);
  }
}

- (void)testConvertsNilAndNSNull {
  FSTNullValue *nullValue = [FSTNullValue nullValue];
  XCTAssertEqual(FSTTestFieldValue(nil), nullValue);
  XCTAssertEqual(FSTTestFieldValue([NSNull null]), nullValue);
  XCTAssertEqual([nullValue value], [NSNull null]);
  XCTAssertEqual(nullValue.type, FieldValue::Type::Null);
}

- (void)testConvertsBooleans {
  NSArray *values = @[ @YES, @NO ];
  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTDelegateValue class]);
    XCTAssertEqualObjects([wrapped value], value);
    XCTAssertEqual(wrapped.type, FieldValue::Type::Boolean);
  }
}

- (void)testConvertsUnsignedCharToInteger {
  // See comments in FSTUserDataConverter regarding handling of signed char. Essentially, signed
  // char has to be treated as boolean. Unsigned chars could conceivably be handled consistently
  // with signed chars but on arm64 these end up being stored as signed shorts. This forces us to
  // choose, and it's more useful to support shorts as Integers than it is to treat unsigned char as
  // Boolean.
  FSTFieldValue *wrapped = FSTTestFieldValue([NSNumber numberWithUnsignedChar:1]);
  XCTAssertEqualObjects(wrapped, [FSTIntegerValue integerValue:1]);
}

union DoubleBits {
  double d;
  uint64_t bits;
};

- (void)testConvertsStrings {
  NSArray *values = @[ @"", @"abc" ];
  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTDelegateValue class]);
    XCTAssertEqualObjects([wrapped value], value);
    XCTAssertEqual(wrapped.type, FieldValue::Type::String);
  }
}

- (void)testConvertsDates {
  NSArray *values = @[ FSTTestDate(1900, 12, 1, 1, 20, 30), FSTTestDate(2017, 4, 24, 13, 20, 30) ];
  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTTimestampValue class]);
    XCTAssertEqualObjects([[wrapped value] class], [FIRTimestamp class]);
    XCTAssertEqualObjects([wrapped value], [FIRTimestamp timestampWithDate:value]);
    XCTAssertEqual(wrapped.type, FieldValue::Type::Timestamp);
  }
}

- (void)testConvertsGeoPoints {
  NSArray *values = @[ FSTTestGeoPoint(1.24, 4.56), FSTTestGeoPoint(-20, 100) ];

  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTGeoPointValue class]);
    XCTAssertEqualObjects([wrapped value], value);
    XCTAssertEqual(wrapped.type, FieldValue::Type::GeoPoint);
  }
}

- (void)testConvertsBlobs {
  NSArray *values = @[ FSTTestData(1, 2, 3), FSTTestData(1, 2) ];
  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTBlobValue class]);
    XCTAssertEqualObjects([wrapped value], value);
    XCTAssertEqual(wrapped.type, FieldValue::Type::Blob);
  }
}

- (void)testConvertsResourceNames {
  NSArray *values = @[
    FSTTestRef("project", DatabaseId::kDefault, @"foo/bar"),
    FSTTestRef("project", DatabaseId::kDefault, @"foo/baz")
  ];
  for (FSTDocumentKeyReference *value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTReferenceValue class]);
    XCTAssertEqualObjects([wrapped value], [FSTDocumentKey keyWithDocumentKey:value.key]);
    XCTAssertTrue(((FSTReferenceValue *)wrapped).databaseID == value.databaseID);
    XCTAssertEqual(wrapped.type, FieldValue::Type::Reference);
  }
}

- (void)testConvertsEmptyObjects {
  XCTAssertEqualObjects(FSTTestFieldValue(@{}), [FSTObjectValue objectValue]);
  XCTAssertEqual(FSTTestFieldValue(@{}).type, FieldValue::Type::Object);
}

- (void)testConvertsSimpleObjects {
  FSTObjectValue *actual =
      FSTTestObjectValue(@{@"a" : @"foo", @"b" : @(1L), @"c" : @YES, @"d" : [NSNull null]});
  FSTObjectValue *expected = [[FSTObjectValue alloc] initWithDictionary:@{
    @"a" : FieldValue::FromString("foo").Wrap(),
    @"b" : [FSTIntegerValue integerValue:1LL],
    @"c" : FieldValue::True().Wrap(),
    @"d" : [FSTNullValue nullValue]
  }];
  XCTAssertEqualObjects(actual, expected);
  XCTAssertEqual(actual.type, FieldValue::Type::Object);
}

- (void)testConvertsNestedObjects {
  FSTObjectValue *actual = FSTTestObjectValue(@{@"a" : @{@"b" : @{@"c" : @"foo"}, @"d" : @YES}});
  FSTObjectValue *expected = [[FSTObjectValue alloc] initWithDictionary:@{
    @"a" : [[FSTObjectValue alloc] initWithDictionary:@{
      @"b" : [[FSTObjectValue alloc]
          initWithDictionary:@{@"c" : FieldValue::FromString("foo").Wrap()}],
      @"d" : FieldValue::True().Wrap()
    }]
  }];
  XCTAssertEqualObjects(actual, expected);
  XCTAssertEqual(actual.type, FieldValue::Type::Object);
}

- (void)testConvertsArrays {
  FSTArrayValue *expected = [[FSTArrayValue alloc]
      initWithValueNoCopy:@[ FieldValue::FromString("value").Wrap(), FieldValue::True().Wrap() ]];

  FSTArrayValue *actual = (FSTArrayValue *)FSTTestFieldValue(@[ @"value", @YES ]);
  XCTAssertEqualObjects(actual, expected);
  XCTAssertEqual(actual.type, FieldValue::Type::Array);
}

- (void)testNSDatesAreConvertedToTimestamps {
  NSDate *date = [NSDate date];
  id input = @{@"array" : @[ @1, date ], @"obj" : @{@"date" : date, @"string" : @"hi"}};
  FSTObjectValue *value = FSTTestObjectValue(input);
  id output = [value value];
  {
    XCTAssertTrue([output[@"array"][1] isKindOfClass:[FIRTimestamp class]]);
    FIRTimestamp *actual = output[@"array"][1];
    XCTAssertEqualObjects([FIRTimestamp timestampWithDate:date], actual);
  }
  {
    XCTAssertTrue([output[@"obj"][@"date"] isKindOfClass:[FIRTimestamp class]]);
    FIRTimestamp *actual = output[@"array"][1];
    XCTAssertEqualObjects([FIRTimestamp timestampWithDate:date], actual);
  }
}

@end
