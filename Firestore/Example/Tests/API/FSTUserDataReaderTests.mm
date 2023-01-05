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

#import "Firestore/Source/API/FSTUserDataReader.h"

#import <FirebaseFirestore/FIRFieldValue.h>
#import <FirebaseFirestore/FIRGeoPoint.h>
#import <FirebaseFirestore/FIRTimestamp.h>
#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/API/converters.h"

#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/src/model/transform_operation.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"

namespace nanopb = firebase::firestore::nanopb;
using firebase::Timestamp;
using firebase::firestore::GeoPoint;
using firebase::firestore::google_firestore_v1_ArrayValue;
using firebase::firestore::google_firestore_v1_Value;
using firebase::firestore::api::MakeGeoPoint;
using firebase::firestore::api::MakeTimestamp;
using firebase::firestore::model::ArrayTransform;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::GetTypeOrder;
using firebase::firestore::model::IsArray;
using firebase::firestore::model::IsNullValue;
using firebase::firestore::model::IsNumber;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::PatchMutation;
using firebase::firestore::model::RefValue;
using firebase::firestore::model::SetMutation;
using firebase::firestore::model::TransformOperation;
using firebase::firestore::model::TypeOrder;
using firebase::firestore::nanopb::MakeNSData;
using firebase::firestore::nanopb::Message;
using firebase::firestore::testutil::Array;
using firebase::firestore::testutil::Field;
using firebase::firestore::testutil::Map;
using firebase::firestore::testutil::Value;
using firebase::firestore::testutil::WrapObject;
using firebase::firestore::util::MakeString;

@interface FSTUserDataReaderTests : XCTestCase
@end

@implementation FSTUserDataReaderTests

- (void)testConvertsIntegers {
  NSArray<NSNumber *> *values = @[
    @(INT_MIN), @(-1), @0, @1, @2, @(UCHAR_MAX), @(INT_MAX),  // Standard integers
    @(LONG_MIN), @(LONG_MAX), @(LLONG_MIN), @(LLONG_MAX)      // Larger values
  ];
  for (NSNumber *value in values) {
    Message<google_firestore_v1_Value> wrapped = FSTTestFieldValue(value);
    XCTAssertTrue(IsNumber(*wrapped));
    XCTAssertEqual(wrapped->integer_value, [value longLongValue]);
  }
}

- (void)testConvertsDoubles {
  // Note that 0x1.0p-1074 is a hex floating point literal representing the minimum subnormal
  // number: <https://en.wikipedia.org/wiki/Denormal_number>.
  NSArray<NSNumber *> *values = @[
    @(-INFINITY), @(-DBL_MAX), @(LLONG_MIN * -1.0), @(-1.1), @(-0x1.0p-1074), @(-0.0), @(0.0),
    @(0x1.0p-1074), @(DBL_MIN), @(1.1), @(LLONG_MAX * 1.0), @(DBL_MAX), @(INFINITY)
  ];
  for (NSNumber *value in values) {
    Message<google_firestore_v1_Value> wrapped = FSTTestFieldValue(value);
    XCTAssertTrue(IsNumber(*wrapped));
    XCTAssertEqual(wrapped->double_value, [value doubleValue]);
  }
}

- (void)testConvertsNilAndNSNull {
  Message<google_firestore_v1_Value> nullValue = Value(nullptr);
  XCTAssertTrue(IsNullValue(*nullValue));
  XCTAssertEqual(*FSTTestFieldValue(nil), *nullValue);
  XCTAssertEqual(*FSTTestFieldValue([NSNull null]), *nullValue);
}

- (void)testConvertsBooleans {
  NSArray<NSNumber *> *values = @[ @YES, @NO ];
  for (NSNumber *value in values) {
    Message<google_firestore_v1_Value> wrapped = FSTTestFieldValue(value);
    XCTAssertEqual(GetTypeOrder(*wrapped), TypeOrder::kBoolean);
    XCTAssertEqual(wrapped->boolean_value, [value boolValue]);
  }
}

- (void)testConvertsUnsignedCharToInteger {
  // See comments in FSTUserDataReader regarding handling of signed char. Essentially, signed
  // char has to be treated as boolean. Unsigned chars could conceivably be handled consistently
  // with signed chars but on arm64 these end up being stored as signed shorts. This forces us to
  // choose, and it's more useful to support shorts as Integers than it is to treat unsigned char as
  // Boolean.
  Message<google_firestore_v1_Value> wrapped =
      FSTTestFieldValue([NSNumber numberWithUnsignedChar:1]);
  XCTAssertEqual(*wrapped, *Value(1));
}

union DoubleBits {
  double d;
  uint64_t bits;
};

- (void)testConvertsStrings {
  NSArray<NSString *> *values = @[ @"", @"abc" ];
  for (id value in values) {
    Message<google_firestore_v1_Value> wrapped = FSTTestFieldValue(value);
    XCTAssertEqual(GetTypeOrder(*wrapped), TypeOrder::kString);
    XCTAssertEqual(nanopb::MakeString(wrapped->string_value), MakeString(value));
  }
}

- (void)testConvertsDates {
  NSArray<NSDate *> *values =
      @[ FSTTestDate(1900, 12, 1, 1, 20, 30), FSTTestDate(2017, 4, 24, 13, 20, 30) ];
  for (NSDate *value in values) {
    Message<google_firestore_v1_Value> wrapped = FSTTestFieldValue(value);
    XCTAssertEqual(GetTypeOrder(*wrapped), TypeOrder::kTimestamp);
    Timestamp timestamp = MakeTimestamp(value);
    XCTAssertEqual(wrapped->timestamp_value.nanos, timestamp.nanoseconds());
    XCTAssertEqual(wrapped->timestamp_value.seconds, timestamp.seconds());
  }
}

- (void)testConvertsGeoPoints {
  NSArray<FIRGeoPoint *> *values = @[ FSTTestGeoPoint(1.24, 4.56), FSTTestGeoPoint(-20, 100) ];

  for (FIRGeoPoint *value in values) {
    Message<google_firestore_v1_Value> wrapped = FSTTestFieldValue(value);
    XCTAssertEqual(GetTypeOrder(*wrapped), TypeOrder::kGeoPoint);
    GeoPoint geo_point = MakeGeoPoint(value);
    XCTAssertEqual(wrapped->geo_point_value.longitude, geo_point.longitude());
    XCTAssertEqual(wrapped->geo_point_value.latitude, geo_point.latitude());
  }
}

- (void)testConvertsBlobs {
  NSArray<NSData *> *values = @[ FSTTestData(1, 2, 3, -1), FSTTestData(1, 2, -1) ];
  for (NSData *value in values) {
    Message<google_firestore_v1_Value> wrapped = FSTTestFieldValue(value);
    XCTAssertEqual(GetTypeOrder(*wrapped), TypeOrder::kBlob);
    XCTAssertEqualObjects(MakeNSData(wrapped->bytes_value), value);
  }
}

- (void)testConvertsResourceNames {
  NSArray<FSTDocumentKeyReference *> *values = @[
    FSTTestRef("project", DatabaseId::kDefault, @"foo/bar"),
    FSTTestRef("project", DatabaseId::kDefault, @"foo/baz")
  ];
  for (FSTDocumentKeyReference *value in values) {
    Message<google_firestore_v1_Value> wrapped = FSTTestFieldValue(value);
    XCTAssertEqual(GetTypeOrder(*wrapped), TypeOrder::kReference);
    Message<google_firestore_v1_Value> expected = RefValue(value.databaseID, value.key);
    XCTAssertEqual(*wrapped, *expected);
  }
}

- (void)testConvertsEmptyObjects {
  XCTAssertTrue(ObjectValue(FSTTestFieldValue(@{})) == ObjectValue{});
  XCTAssertEqual(GetTypeOrder(*FSTTestFieldValue(@{})), TypeOrder::kMap);
}

- (void)testConvertsSimpleObjects {
  ObjectValue actual =
      FSTTestObjectValue(@{@"a" : @"foo", @"b" : @(1L), @"c" : @YES, @"d" : [NSNull null]});
  ObjectValue expected = WrapObject("a", "foo", "b", 1, "c", true, "d", nullptr);
  XCTAssertEqual(actual, expected);
}

- (void)testConvertsNestedObjects {
  ObjectValue actual = FSTTestObjectValue(@{@"a" : @{@"b" : @{@"c" : @"foo"}, @"d" : @YES}});
  ObjectValue expected = WrapObject("a", Map("b", Map("c", "foo"), "d", true));
  XCTAssertEqual(actual, expected);
}

- (void)testConvertsArrays {
  Message<google_firestore_v1_Value> expected = Value(Array("value", true));

  Message<google_firestore_v1_Value> actual = FSTTestFieldValue(@[ @"value", @YES ]);
  XCTAssertEqual(*actual, *expected);
  XCTAssertTrue(IsArray(*actual));
}

- (void)testNSDatesAreConvertedToTimestamps {
  NSDate *date = [NSDate date];
  Timestamp timestamp = MakeTimestamp(date);
  id input = @{@"array" : @[ @1, date ], @"obj" : @{@"date" : date, @"string" : @"hi"}};
  ObjectValue value = FSTTestObjectValue(input);
  {
    auto array = value.Get(Field("array"));
    XCTAssertTrue(array.has_value());
    XCTAssertEqual(GetTypeOrder(*array), TypeOrder::kArray);

    const google_firestore_v1_Value &actual = array->array_value.values[1];
    XCTAssertEqual(GetTypeOrder(actual), TypeOrder::kTimestamp);
    XCTAssertEqual(actual.timestamp_value.seconds, timestamp.seconds());
    XCTAssertEqual(actual.timestamp_value.nanos, timestamp.nanoseconds());
  }
  {
    auto found = value.Get(Field("obj.date"));
    XCTAssertTrue(found.has_value());
    XCTAssertEqual(GetTypeOrder(*found), TypeOrder::kTimestamp);
    XCTAssertEqual(found->timestamp_value.seconds, timestamp.seconds());
    XCTAssertEqual(found->timestamp_value.nanos, timestamp.nanoseconds());
  }
}

- (void)testCreatesArrayUnionTransforms {
  PatchMutation patchMutation = FSTTestPatchMutation(@"collection/key", @{
    @"foo" : [FIRFieldValue fieldValueForArrayUnion:@[ @"tag" ]],
    @"bar.baz" :
        [FIRFieldValue fieldValueForArrayUnion:@[ @YES, @{@"nested" : @{@"a" : @[ @1, @2 ]}} ]]
  },
                                                     {});
  XCTAssertEqual(patchMutation.field_transforms().size(), 2u);

  SetMutation setMutation = FSTTestSetMutation(@"collection/key", @{
    @"foo" : [FIRFieldValue fieldValueForArrayUnion:@[ @"tag" ]],
    @"bar" : [FIRFieldValue fieldValueForArrayUnion:@[ @YES, @{@"nested" : @{@"a" : @[ @1, @2 ]}} ]]
  });
  XCTAssertEqual(setMutation.field_transforms().size(), 2u);

  const FieldTransform &patchFirst = patchMutation.field_transforms()[0];
  XCTAssertEqual(patchFirst.path(), FieldPath({"foo"}));
  const FieldTransform &setFirst = setMutation.field_transforms()[0];
  XCTAssertEqual(setFirst.path(), FieldPath({"foo"}));
  {
    Message<google_firestore_v1_ArrayValue> expectedElements = Array(FSTTestFieldValue(@"tag"));
    ArrayTransform expected(TransformOperation::Type::ArrayUnion, std::move(expectedElements));
    XCTAssertEqual(static_cast<const ArrayTransform &>(patchFirst.transformation()), expected);
    XCTAssertEqual(static_cast<const ArrayTransform &>(setFirst.transformation()), expected);
  }

  const FieldTransform &patchSecond = patchMutation.field_transforms()[1];
  XCTAssertEqual(patchSecond.path(), FieldPath({"bar", "baz"}));
  const FieldTransform &setSecond = setMutation.field_transforms()[1];
  XCTAssertEqual(setSecond.path(), FieldPath({"bar"}));
  {
    Message<google_firestore_v1_ArrayValue> expectedElements =
        Array(FSTTestFieldValue(@YES), FSTTestFieldValue(
                                           @{@"nested" : @{@"a" : @[ @1, @2 ]}}));
    ArrayTransform expected(TransformOperation::Type::ArrayUnion, std::move(expectedElements));
    XCTAssertEqual(static_cast<const ArrayTransform &>(patchSecond.transformation()), expected);
    XCTAssertEqual(static_cast<const ArrayTransform &>(setSecond.transformation()), expected);
  }
}

- (void)testCreatesArrayRemoveTransforms {
  PatchMutation patchMutation = FSTTestPatchMutation(@"collection/key", @{
    @"foo" : [FIRFieldValue fieldValueForArrayRemove:@[ @"tag" ]],
  },
                                                     {});
  XCTAssertEqual(patchMutation.field_transforms().size(), 1u);

  SetMutation setMutation = FSTTestSetMutation(@"collection/key", @{
    @"foo" : [FIRFieldValue fieldValueForArrayRemove:@[ @"tag" ]],
  });
  XCTAssertEqual(patchMutation.field_transforms().size(), 1u);

  const FieldTransform &patchFirst = patchMutation.field_transforms()[0];
  XCTAssertEqual(patchFirst.path(), FieldPath({"foo"}));
  const FieldTransform &setFirst = setMutation.field_transforms()[0];
  XCTAssertEqual(setFirst.path(), FieldPath({"foo"}));
  {
    Message<google_firestore_v1_ArrayValue> expectedElements = Array(FSTTestFieldValue(@"tag"));
    const ArrayTransform expected(TransformOperation::Type::ArrayRemove,
                                  std::move(expectedElements));
    XCTAssertEqual(static_cast<const ArrayTransform &>(patchFirst.transformation()), expected);
    XCTAssertEqual(static_cast<const ArrayTransform &>(setFirst.transformation()), expected);
  }
}

@end
