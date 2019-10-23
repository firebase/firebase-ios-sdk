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

#import "Firestore/Source/Remote/FSTSerializerBeta.h"

#import <FirebaseFirestore/FIRFieldPath.h>
#import <FirebaseFirestore/FIRFieldValue.h>
#import <FirebaseFirestore/FIRFirestoreErrors.h>
#import <FirebaseFirestore/FIRGeoPoint.h>
#import <FirebaseFirestore/FIRTimestamp.h>
#import <XCTest/XCTest.h>

#include <memory>
#include <vector>

#import "Firestore/Protos/objc/firestore/local/MaybeDocument.pbobjc.h"
#import "Firestore/Protos/objc/firestore/local/Mutation.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1/Common.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1/Document.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1/Firestore.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1/Query.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1/Write.pbobjc.h"
#import "Firestore/Protos/objc/google/rpc/Status.pbobjc.h"
#import "Firestore/Protos/objc/google/type/Latlng.pbobjc.h"
#import "Firestore/Source/API/FIRFieldValue+Internal.h"

#import "Firestore/Example/Tests/API/FSTAPIHelpers.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/core/direction.h"
#include "Firestore/core/src/firebase/firestore/core/field_filter.h"
#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/order_by.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/delete_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/patch_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/set_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/transform_mutation.h"
#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;
using firebase::Timestamp;
using firebase::firestore::Error;
using firebase::firestore::core::Direction;
using firebase::firestore::core::FieldFilter;
using firebase::firestore::core::OrderBy;
using firebase::firestore::local::QueryData;
using firebase::firestore::local::QueryPurpose;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DeleteMutation;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::Mutation;
using firebase::firestore::model::MutationResult;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::PatchMutation;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::SetMutation;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TransformMutation;
using firebase::firestore::nanopb::ByteString;
using firebase::firestore::nanopb::MakeNSData;
using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::ExistenceFilterWatchChange;
using firebase::firestore::remote::WatchChange;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WatchTargetChangeState;
using firebase::firestore::testutil::Array;
using firebase::firestore::util::Status;

using testutil::Bytes;
using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Filter;
using testutil::Key;
using testutil::Map;
using testutil::OrderBy;
using testutil::Query;
using testutil::Ref;
using testutil::Value;
using testutil::Version;
using testutil::WrapObject;

namespace {

template <typename T>
bool Equals(const WatchChange &lhs, const WatchChange &rhs) {
  return static_cast<const T &>(lhs) == static_cast<const T &>(rhs);
}

// Compares two `WatchChange`s taking into account their actual derived type.
bool IsWatchChangeEqual(const WatchChange &lhs, const WatchChange &rhs) {
  if (lhs.type() != rhs.type()) {
    return false;
  }

  switch (lhs.type()) {
    case WatchChange::Type::Document:
      return Equals<DocumentWatchChange>(lhs, rhs);
    case WatchChange::Type::ExistenceFilter:
      return Equals<ExistenceFilterWatchChange>(lhs, rhs);
    case WatchChange::Type::TargetChange:
      return Equals<WatchTargetChange>(lhs, rhs);
  }
  UNREACHABLE();
}

NSString *const kDocumentKeyPath =
    [[NSString alloc] initWithUTF8String:FieldPath::kDocumentKeyPath];

}  // namespace

NS_ASSUME_NONNULL_BEGIN

@interface GCFSStructuredQuery_Order (Test)
+ (instancetype)messageWithProperty:(NSString *)property ascending:(BOOL)ascending;
@end

@implementation GCFSStructuredQuery_Order (Test)

+ (instancetype)messageWithProperty:(NSString *)property ascending:(BOOL)ascending {
  GCFSStructuredQuery_Order *order = [GCFSStructuredQuery_Order message];
  order.field.fieldPath = property;
  order.direction = ascending ? GCFSStructuredQuery_Direction_Ascending
                              : GCFSStructuredQuery_Direction_Descending;
  return order;
}
@end

@interface FSTSerializerBetaTests : XCTestCase

@property(nonatomic, strong) FSTSerializerBeta *serializer;
@end

@implementation FSTSerializerBetaTests

- (void)setUp {
  self.serializer = [[FSTSerializerBeta alloc] initWithDatabaseID:DatabaseId("p", "d")];
}

- (void)testEncodesNull {
  FieldValue model = FieldValue::Null();

  GCFSValue *proto = [GCFSValue message];
  proto.nullValue = GPBNullValue_NullValue;

  [self assertRoundTripForModel:model proto:proto type:GCFSValue_ValueType_OneOfCase_NullValue];
}

- (void)testEncodesBool {
  NSArray<NSNumber *> *examples = @[ @YES, @NO ];
  for (NSNumber *example in examples) {
    FieldValue model = FSTTestFieldValue(example);

    GCFSValue *proto = [GCFSValue message];
    proto.booleanValue = [example boolValue];

    [self assertRoundTripForModel:model
                            proto:proto
                             type:GCFSValue_ValueType_OneOfCase_BooleanValue];
  }
}

- (void)testEncodesIntegers {
  NSArray<NSNumber *> *examples = @[ @(LLONG_MIN), @(-100), @(-1), @0, @1, @100, @(LLONG_MAX) ];
  for (NSNumber *example in examples) {
    FieldValue model = FSTTestFieldValue(example);

    GCFSValue *proto = [GCFSValue message];
    proto.integerValue = [example longLongValue];

    [self assertRoundTripForModel:model
                            proto:proto
                             type:GCFSValue_ValueType_OneOfCase_IntegerValue];
  }
}

- (void)testEncodesDoubles {
  NSArray<NSNumber *> *examples = @[
    // normal negative numbers.
    @(-INFINITY), @(-DBL_MAX), @(LLONG_MIN * 1.0 - 1.0), @(-2.0), @(-1.1), @(-1.0), @(-DBL_MIN),

    // negative smallest subnormal, zeroes, positive smallest subnormal
    @(-0x1.0p-1074), @(-0.0), @(0.0), @(0x1.0p-1074),

    // and the rest
    @(DBL_MIN), @0.1, @1.1, @(LLONG_MAX * 1.0), @(DBL_MAX), @(INFINITY),

    // NaN.
    @(0.0 / 0.0)
  ];
  for (NSNumber *example in examples) {
    FieldValue model = FSTTestFieldValue(example);

    GCFSValue *proto = [GCFSValue message];
    proto.doubleValue = [example doubleValue];

    [self assertRoundTripForModel:model proto:proto type:GCFSValue_ValueType_OneOfCase_DoubleValue];
  }
}

- (void)testEncodesStrings {
  NSArray<NSString *> *examples = @[
    @"",
    @"a",
    @"abc def",
    @"æ",
    @"\0\ud7ff\ue000\uffff",
    @"(╯°□°）╯︵ ┻━┻",
  ];
  for (NSString *example in examples) {
    FieldValue model = FSTTestFieldValue(example);

    GCFSValue *proto = [GCFSValue message];
    proto.stringValue = example;

    [self assertRoundTripForModel:model proto:proto type:GCFSValue_ValueType_OneOfCase_StringValue];
  }
}

- (void)testEncodesDates {
  NSDateComponents *dateWithNanos = FSTTestDateComponents(2016, 1, 2, 10, 20, 50);
  dateWithNanos.nanosecond = 500000000;

  NSArray<NSDate *> *examples = @[
    [[NSCalendar currentCalendar] dateFromComponents:dateWithNanos],
    FSTTestDate(2016, 6, 17, 10, 50, 15)
  ];

  GCFSValue *timestamp1 = [GCFSValue message];
  timestamp1.timestampValue.seconds = 1451730050;
  timestamp1.timestampValue.nanos = 500000000;

  GCFSValue *timestamp2 = [GCFSValue message];
  timestamp2.timestampValue.seconds = 1466160615;
  timestamp2.timestampValue.nanos = 0;
  NSArray<GCFSValue *> *expectedTimestamps = @[ timestamp1, timestamp2 ];

  for (NSUInteger i = 0; i < [examples count]; i++) {
    [self assertRoundTripForModel:FSTTestFieldValue(examples[i])
                            proto:expectedTimestamps[i]
                             type:GCFSValue_ValueType_OneOfCase_TimestampValue];
  }
}

- (void)testEncodesGeoPoints {
  NSArray<FIRGeoPoint *> *examples =
      @[ FSTTestGeoPoint(0, 0), FSTTestGeoPoint(1.24, 4.56), FSTTestGeoPoint(-90, 180) ];
  for (FIRGeoPoint *example in examples) {
    FieldValue model = FSTTestFieldValue(example);

    GCFSValue *proto = [GCFSValue message];
    proto.geoPointValue = [GTPLatLng message];
    proto.geoPointValue.latitude = example.latitude;
    proto.geoPointValue.longitude = example.longitude;

    [self assertRoundTripForModel:model
                            proto:proto
                             type:GCFSValue_ValueType_OneOfCase_GeoPointValue];
  }
}

- (void)testEncodesBlobs {
  NSArray<NSData *> *examples = @[
    FSTTestData(-1),
    FSTTestData(0, -1),
    FSTTestData(0, 1, 2, -1),
    FSTTestData(255, -1),
    FSTTestData(0, 1, 255, -1),
  ];
  for (NSData *example in examples) {
    FieldValue model = FSTTestFieldValue(example);

    GCFSValue *proto = [GCFSValue message];
    proto.bytesValue = example;

    [self assertRoundTripForModel:model proto:proto type:GCFSValue_ValueType_OneOfCase_BytesValue];
  }
}

- (void)testEncodesResourceNames {
  self.serializer = [[FSTSerializerBeta alloc] initWithDatabaseID:DatabaseId("project")];

  FSTDocumentKeyReference *reference = FSTTestRef("project", DatabaseId::kDefault, @"foo/bar");

  GCFSValue *proto = [GCFSValue message];
  proto.referenceValue = @"projects/project/databases/(default)/documents/foo/bar";

  [self assertRoundTripForModel:FSTTestFieldValue(reference)
                          proto:proto
                           type:GCFSValue_ValueType_OneOfCase_ReferenceValue];
}

- (void)testEncodesArrays {
  FieldValue model = FSTTestFieldValue(@[ @YES, @"foo" ]);

  GCFSValue *proto = [GCFSValue message];
  [proto.arrayValue.valuesArray addObjectsFromArray:@[
    [self.serializer encodedBool:true], [self.serializer encodedString:"foo"]
  ]];

  [self assertRoundTripForModel:model proto:proto type:GCFSValue_ValueType_OneOfCase_ArrayValue];
}

- (void)testEncodesEmptyMap {
  FieldValue model = ObjectValue::Empty();

  GCFSValue *proto = [GCFSValue message];
  proto.mapValue = [GCFSMapValue message];

  [self assertRoundTripForModel:model proto:proto type:GCFSValue_ValueType_OneOfCase_MapValue];
}

- (void)testEncodesNestedObjects {
  FieldValue model = FSTTestFieldValue(@{
    @"b" : @YES,
    @"d" : @(DBL_MAX),
    @"i" : @1,
    @"n" : [NSNull null],
    @"s" : @"foo",
    @"a" : @[ @2, @"bar", @{@"b" : @NO} ],
    @"o" : @{
      @"d" : @100,
      @"nested" : @{@"e" : @(LLONG_MIN)},
    },
  });

  GCFSValue *innerObject = [GCFSValue message];
  innerObject.mapValue.fields[@"b"] = [self.serializer encodedBool:false];

  GCFSValue *middleArray = [GCFSValue message];
  [middleArray.arrayValue.valuesArray addObjectsFromArray:@[
    [self.serializer encodedInteger:2], [self.serializer encodedString:"bar"], innerObject
  ]];

  innerObject = [GCFSValue message];
  innerObject.mapValue.fields[@"e"] = [self.serializer encodedInteger:LLONG_MIN];

  GCFSValue *middleObject = [GCFSValue message];
  [middleObject.mapValue.fields addEntriesFromDictionary:@{
    @"d" : [self.serializer encodedInteger:100],
    @"nested" : innerObject
  }];

  GCFSValue *proto = [GCFSValue message];
  [proto.mapValue.fields addEntriesFromDictionary:@{
    @"b" : [self.serializer encodedBool:true],
    @"d" : [self.serializer encodedDouble:DBL_MAX],
    @"i" : [self.serializer encodedInteger:1],
    @"n" : [self.serializer encodedNull],
    @"s" : [self.serializer encodedString:"foo"],
    @"a" : middleArray,
    @"o" : middleObject
  }];

  [self assertRoundTripForModel:model proto:proto type:GCFSValue_ValueType_OneOfCase_MapValue];
}

- (void)assertRoundTripForModel:(const FieldValue &)model
                          proto:(GCFSValue *)value
                           type:(GCFSValue_ValueType_OneOfCase)type {
  GCFSValue *actualProto = [self.serializer encodedFieldValue:model];
  XCTAssertEqual(actualProto.valueTypeOneOfCase, type);
  XCTAssertEqualObjects(actualProto, value);

  FieldValue actualModel = [self.serializer decodedFieldValue:value];
  XCTAssertEqual(actualModel, model);
}

- (void)testEncodesSetMutation {
  SetMutation mutation = FSTTestSetMutation(@"docs/1", @{@"a" : @"b", @"num" : @1});
  GCFSWrite *proto = [GCFSWrite message];
  proto.update = [self.serializer encodedDocumentWithFields:mutation.value() key:mutation.key()];

  [self assertRoundTripForMutation:mutation proto:proto];
}

- (void)testEncodesPatchMutation {
  PatchMutation mutation = FSTTestPatchMutation(
      "docs/1", @{@"a" : @"b", @"num" : @1, @"some.de\\\\ep.th\\ing'" : @2}, {});
  GCFSWrite *proto = [GCFSWrite message];
  proto.update = [self.serializer encodedDocumentWithFields:mutation.value() key:mutation.key()];
  proto.updateMask = [self.serializer encodedFieldMask:mutation.mask()];
  proto.currentDocument.exists = YES;

  [self assertRoundTripForMutation:mutation proto:proto];
}

- (void)testEncodesDeleteMutation {
  DeleteMutation mutation = FSTTestDeleteMutation(@"docs/1");
  GCFSWrite *proto = [GCFSWrite message];
  proto.delete_p = @"projects/p/databases/d/documents/docs/1";

  [self assertRoundTripForMutation:mutation proto:proto];
}

- (void)testEncodesServerTimestampTransformMutation {
  TransformMutation mutation = FSTTestTransformMutation(@"docs/1", @{
    @"a" : [FIRFieldValue fieldValueForServerTimestamp],
    @"bar.baz" : [FIRFieldValue fieldValueForServerTimestamp]
  });
  GCFSWrite *proto = [GCFSWrite message];
  proto.transform = [GCFSDocumentTransform message];
  proto.transform.document = [self.serializer encodedDocumentKey:mutation.key()];
  proto.transform.fieldTransformsArray =
      [self.serializer encodedFieldTransforms:mutation.field_transforms()];
  proto.currentDocument.exists = YES;

  [self assertRoundTripForMutation:mutation proto:proto];
}

- (void)testEncodesArrayTransformMutations {
  TransformMutation mutation = FSTTestTransformMutation(@"docs/1", @{
    @"a" : [FIRFieldValue fieldValueForArrayUnion:@[ @"a", @2 ]],
    @"bar.baz" : [FIRFieldValue fieldValueForArrayRemove:@[ @{@"x" : @1} ]]
  });
  GCFSWrite *proto = [GCFSWrite message];
  proto.transform = [GCFSDocumentTransform message];
  proto.transform.document = [self.serializer encodedDocumentKey:mutation.key()];

  GCFSDocumentTransform_FieldTransform *arrayUnion = [GCFSDocumentTransform_FieldTransform message];
  arrayUnion.fieldPath = @"a";
  arrayUnion.appendMissingElements = [GCFSArrayValue message];
  NSMutableArray *unionElements = arrayUnion.appendMissingElements.valuesArray;
  [unionElements addObject:[self.serializer encodedFieldValue:FSTTestFieldValue(@"a")]];
  [unionElements addObject:[self.serializer encodedFieldValue:FSTTestFieldValue(@2)]];
  [proto.transform.fieldTransformsArray addObject:arrayUnion];

  GCFSDocumentTransform_FieldTransform *arrayRemove =
      [GCFSDocumentTransform_FieldTransform message];
  arrayRemove.fieldPath = @"bar.baz";
  arrayRemove.removeAllFromArray_p = [GCFSArrayValue message];
  NSMutableArray *removeElements = arrayRemove.removeAllFromArray_p.valuesArray;
  [removeElements addObject:[self.serializer encodedFieldValue:FSTTestFieldValue(@{@"x" : @1})]];
  [proto.transform.fieldTransformsArray addObject:arrayRemove];

  proto.currentDocument.exists = YES;

  [self assertRoundTripForMutation:mutation proto:proto];
}

- (void)testEncodesSetMutationWithPrecondition {
  SetMutation mutation(Key("foo/bar"), WrapObject("a", "b", "num", 1),
                       Precondition::UpdateTime(Version(4)));
  GCFSWrite *proto = [GCFSWrite message];
  proto.update = [self.serializer encodedDocumentWithFields:mutation.value() key:mutation.key()];
  proto.currentDocument.updateTime = [self.serializer encodedTimestamp:Timestamp{0, 4000}];

  [self assertRoundTripForMutation:mutation proto:proto];
}

- (void)assertRoundTripForMutation:(const Mutation &)mutation proto:(GCFSWrite *)proto {
  GCFSWrite *actualProto = [self.serializer encodedMutation:mutation];
  XCTAssertEqualObjects(actualProto, proto);

  Mutation actualMutation = [self.serializer decodedMutation:proto];
  XCTAssertEqual(actualMutation, mutation);
}

- (void)testDecodesMutationResult {
  SnapshotVersion commitVersion = testutil::Version(3000);
  SnapshotVersion updateVersion = testutil::Version(4000);
  GCFSWriteResult *proto = [GCFSWriteResult message];
  proto.updateTime = [self.serializer encodedTimestamp:updateVersion.timestamp()];
  [proto.transformResultsArray addObject:[self.serializer encodedString:"result"]];

  MutationResult result = [self.serializer decodedMutationResult:proto commitVersion:commitVersion];

  XCTAssertEqual(result.version(), updateVersion);
  XCTAssertTrue(result.transform_results().has_value());

  XCTAssertEqual(*result.transform_results(), Array("result").array_value());
}

- (void)testDecodesDeleteMutationResult {
  GCFSWriteResult *proto = [GCFSWriteResult message];
  SnapshotVersion commitVersion = testutil::Version(4000);

  MutationResult result = [self.serializer decodedMutationResult:proto commitVersion:commitVersion];

  XCTAssertEqual(result.version(), commitVersion);
  XCTAssertFalse(result.transform_results().has_value());
}

- (void)testRoundTripSpecialFieldNames {
  Mutation set = FSTTestSetMutation(@"collection/key", @{
    @"field" : [NSString stringWithFormat:@"field %d", 1],
    @"field.dot" : @2,
    @"field\\slash" : @3
  });
  GCFSWrite *encoded = [self.serializer encodedMutation:set];
  Mutation decoded = [self.serializer decodedMutation:encoded];
  XCTAssertEqual(set, decoded);
}

- (void)testEncodesListenRequestLabels {
  core::Query query = Query("collection/key");
  QueryData queryData(query, 2, 3, QueryPurpose::Listen);

  NSDictionary<NSString *, NSString *> *result =
      [self.serializer encodedListenRequestLabelsForQueryData:queryData];
  XCTAssertNil(result);

  queryData = QueryData(query, 2, 3, QueryPurpose::LimboResolution);
  result = [self.serializer encodedListenRequestLabelsForQueryData:queryData];
  XCTAssertEqualObjects(result, @{@"goog-listen-tags" : @"limbo-document"});

  queryData = QueryData(query, 2, 3, QueryPurpose::ExistenceFilterMismatch);
  result = [self.serializer encodedListenRequestLabelsForQueryData:queryData];
  XCTAssertEqualObjects(result, @{@"goog-listen-tags" : @"existence-filter-mismatch"});
}

- (void)testEncodesUnaryFilter {
  auto input = Filter("item", "==", nullptr);
  GCFSStructuredQuery_Filter *actual = [self.serializer encodedUnaryOrFieldFilter:input];

  GCFSStructuredQuery_Filter *expected = [GCFSStructuredQuery_Filter message];
  GCFSStructuredQuery_UnaryFilter *prop = expected.unaryFilter;
  prop.field.fieldPath = @"item";
  prop.op = GCFSStructuredQuery_UnaryFilter_Operator_IsNull;
  XCTAssertEqualObjects(actual, expected);

  auto roundTripped = [self.serializer decodedUnaryFilter:prop];
  XCTAssertEqual(input, roundTripped);
}

- (void)testEncodesFieldFilter {
  auto input = Filter("item.part.top", "==", "food");
  GCFSStructuredQuery_Filter *actual = [self.serializer encodedUnaryOrFieldFilter:input];

  GCFSStructuredQuery_Filter *expected = [GCFSStructuredQuery_Filter message];
  GCFSStructuredQuery_FieldFilter *prop = expected.fieldFilter;
  prop.field.fieldPath = @"item.part.top";
  prop.op = GCFSStructuredQuery_FieldFilter_Operator_Equal;
  prop.value.stringValue = @"food";
  XCTAssertEqualObjects(actual, expected);

  auto roundTripped = [self.serializer decodedFieldFilter:prop];
  XCTAssertEqual(input, roundTripped);
}

- (void)testEncodesArrayContainsFilter {
  auto input = Filter("item.tags", "array_contains", "food");
  GCFSStructuredQuery_Filter *actual = [self.serializer encodedUnaryOrFieldFilter:input];

  GCFSStructuredQuery_Filter *expected = [GCFSStructuredQuery_Filter message];
  GCFSStructuredQuery_FieldFilter *prop = expected.fieldFilter;
  prop.field.fieldPath = @"item.tags";
  prop.op = GCFSStructuredQuery_FieldFilter_Operator_ArrayContains;
  prop.value.stringValue = @"food";
  XCTAssertEqualObjects(actual, expected);

  auto roundTripped = [self.serializer decodedFieldFilter:prop];
  XCTAssertEqual(input, roundTripped);
}

- (void)testEncodesArrayContainsAnyFilter {
  auto input = Filter("item.tags", "array-contains-any", Array("food"));
  GCFSStructuredQuery_Filter *actual = [self.serializer encodedUnaryOrFieldFilter:input];

  GCFSStructuredQuery_Filter *expected = [GCFSStructuredQuery_Filter message];
  GCFSStructuredQuery_FieldFilter *prop = expected.fieldFilter;
  prop.field.fieldPath = @"item.tags";
  prop.op = GCFSStructuredQuery_FieldFilter_Operator_ArrayContainsAny;
  [prop.value.arrayValue.valuesArray addObject:[self.serializer encodedString:"food"]];
  XCTAssertEqualObjects(actual, expected);

  auto roundTripped = [self.serializer decodedFieldFilter:prop];
  XCTAssertEqual(input, roundTripped);
}

- (void)testEncodesInFilter {
  auto input = Filter("item.tags", "in", Array("food"));
  GCFSStructuredQuery_Filter *actual = [self.serializer encodedUnaryOrFieldFilter:input];

  GCFSStructuredQuery_Filter *expected = [GCFSStructuredQuery_Filter message];
  GCFSStructuredQuery_FieldFilter *prop = expected.fieldFilter;
  prop.field.fieldPath = @"item.tags";
  prop.op = GCFSStructuredQuery_FieldFilter_Operator_In;
  [prop.value.arrayValue.valuesArray addObject:[self.serializer encodedString:"food"]];
  XCTAssertEqualObjects(actual, expected);

  auto roundTripped = [self.serializer decodedFieldFilter:prop];
  XCTAssertEqual(input, roundTripped);
}

- (void)testEncodesKeyFieldFilter {
  auto input = Filter("__name__", "==", Ref("p/d", "coll/doc"));
  GCFSStructuredQuery_Filter *actual = [self.serializer encodedUnaryOrFieldFilter:input];

  GCFSStructuredQuery_Filter *expected = [GCFSStructuredQuery_Filter message];
  GCFSStructuredQuery_FieldFilter *prop = expected.fieldFilter;
  prop.field.fieldPath = @"__name__";
  prop.op = GCFSStructuredQuery_FieldFilter_Operator_Equal;
  prop.value.referenceValue = @"projects/p/databases/d/documents/coll/doc";
  XCTAssertEqualObjects(actual, expected);

  auto roundTripped = [self.serializer decodedFieldFilter:prop];
  XCTAssertEqual(input, roundTripped);
}

#pragma mark - encodedQuery

- (void)testEncodesFirstLevelKeyQueries {
  core::Query query = Query("docs/1");
  QueryData model = [self queryDataForQuery:std::move(query)];

  GCFSTarget *expected = [GCFSTarget message];
  [expected.documents.documentsArray addObject:@"projects/p/databases/d/documents/docs/1"];
  expected.targetId = 1;

  [self assertRoundTripForQueryData:model proto:expected];
}

- (void)testEncodesFirstLevelAncestorQueries {
  core::Query q = Query("messages");
  QueryData model = [self queryDataForQuery:std::move(q)];

  GCFSTarget *expected = [GCFSTarget message];
  expected.query.parent = @"projects/p/databases/d/documents";
  GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
  from.collectionId = @"messages";
  [expected.query.structuredQuery.fromArray addObject:from];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:kDocumentKeyPath ascending:YES]];
  expected.targetId = 1;

  [self assertRoundTripForQueryData:model proto:expected];
}

- (void)testEncodesNestedAncestorQueries {
  core::Query q = Query("rooms/1/messages/10/attachments");
  QueryData model = [self queryDataForQuery:std::move(q)];

  GCFSTarget *expected = [GCFSTarget message];
  expected.query.parent = @"projects/p/databases/d/documents/rooms/1/messages/10";
  GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
  from.collectionId = @"attachments";
  [expected.query.structuredQuery.fromArray addObject:from];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:kDocumentKeyPath ascending:YES]];
  expected.targetId = 1;

  [self assertRoundTripForQueryData:model proto:expected];
}

- (void)testEncodesSingleFiltersAtFirstLevelCollections {
  core::Query q = Query("docs").AddingFilter(Filter("prop", "<", 42));
  QueryData model = [self queryDataForQuery:std::move(q)];

  GCFSTarget *expected = [GCFSTarget message];
  expected.query.parent = @"projects/p/databases/d/documents";
  GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
  from.collectionId = @"docs";
  [expected.query.structuredQuery.fromArray addObject:from];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:@"prop" ascending:YES]];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:kDocumentKeyPath ascending:YES]];

  GCFSStructuredQuery_FieldFilter *filter = expected.query.structuredQuery.where.fieldFilter;
  filter.field.fieldPath = @"prop";
  filter.op = GCFSStructuredQuery_FieldFilter_Operator_LessThan;
  filter.value.integerValue = 42;
  expected.targetId = 1;

  [self assertRoundTripForQueryData:model proto:expected];
}

- (void)testEncodesMultipleFiltersOnDeeperCollections {
  core::Query q = Query("rooms/1/messages/10/attachments")
                      .AddingFilter(Filter("prop", ">=", 42))
                      .AddingFilter(Filter("author", "==", "dimond"))
                      .AddingFilter(Filter("tags", "array_contains", "pending"));
  QueryData model = [self queryDataForQuery:std::move(q)];

  GCFSTarget *expected = [GCFSTarget message];
  expected.query.parent = @"projects/p/databases/d/documents/rooms/1/messages/10";
  GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
  from.collectionId = @"attachments";
  [expected.query.structuredQuery.fromArray addObject:from];

  GCFSStructuredQuery_Filter *filter1 = [GCFSStructuredQuery_Filter message];
  GCFSStructuredQuery_FieldFilter *field1 = filter1.fieldFilter;
  field1.field.fieldPath = @"prop";
  field1.op = GCFSStructuredQuery_FieldFilter_Operator_GreaterThanOrEqual;
  field1.value.integerValue = 42;

  GCFSStructuredQuery_Filter *filter2 = [GCFSStructuredQuery_Filter message];
  GCFSStructuredQuery_FieldFilter *field2 = filter2.fieldFilter;
  field2.field.fieldPath = @"author";
  field2.op = GCFSStructuredQuery_FieldFilter_Operator_Equal;
  field2.value.stringValue = @"dimond";

  GCFSStructuredQuery_Filter *filter3 = [GCFSStructuredQuery_Filter message];
  GCFSStructuredQuery_FieldFilter *field3 = filter3.fieldFilter;
  field3.field.fieldPath = @"tags";
  field3.op = GCFSStructuredQuery_FieldFilter_Operator_ArrayContains;
  field3.value.stringValue = @"pending";

  GCFSStructuredQuery_CompositeFilter *composite =
      expected.query.structuredQuery.where.compositeFilter;
  composite.op = GCFSStructuredQuery_CompositeFilter_Operator_And;
  [composite.filtersArray addObject:filter1];
  [composite.filtersArray addObject:filter2];
  [composite.filtersArray addObject:filter3];

  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:@"prop" ascending:YES]];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:kDocumentKeyPath ascending:YES]];
  expected.targetId = 1;

  [self assertRoundTripForQueryData:model proto:expected];
}

- (void)testEncodesNullFilter {
  [self unaryFilterTestWithValue:Value(nullptr)
           expectedUnaryOperator:GCFSStructuredQuery_UnaryFilter_Operator_IsNull];
}

- (void)testEncodesNanFilter {
  [self unaryFilterTestWithValue:Value(NAN)
           expectedUnaryOperator:GCFSStructuredQuery_UnaryFilter_Operator_IsNan];
}

- (void)unaryFilterTestWithValue:(FieldValue)value
           expectedUnaryOperator:(GCFSStructuredQuery_UnaryFilter_Operator)op {
  core::Query q = Query("docs").AddingFilter(Filter("prop", "==", value));
  QueryData model = [self queryDataForQuery:std::move(q)];

  GCFSTarget *expected = [GCFSTarget message];
  expected.query.parent = @"projects/p/databases/d/documents";
  GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
  from.collectionId = @"docs";
  [expected.query.structuredQuery.fromArray addObject:from];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:kDocumentKeyPath ascending:YES]];

  GCFSStructuredQuery_UnaryFilter *filter = expected.query.structuredQuery.where.unaryFilter;
  filter.field.fieldPath = @"prop";
  filter.op = op;
  expected.targetId = 1;

  [self assertRoundTripForQueryData:model proto:expected];
}

- (void)testEncodesSortOrders {
  core::Query query = Query("docs").AddingOrderBy(OrderBy("prop", "asc"));
  QueryData model = [self queryDataForQuery:std::move(query)];

  GCFSTarget *expected = [GCFSTarget message];
  expected.query.parent = @"projects/p/databases/d/documents";
  GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
  from.collectionId = @"docs";
  [expected.query.structuredQuery.fromArray addObject:from];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:@"prop" ascending:YES]];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:kDocumentKeyPath ascending:YES]];
  expected.targetId = 1;

  [self assertRoundTripForQueryData:model proto:expected];
}

- (void)testEncodesSortOrdersDescending {
  core::Query query =
      Query("rooms/1/messages/10/attachments").AddingOrderBy(OrderBy("prop", "desc"));
  QueryData model = [self queryDataForQuery:std::move(query)];

  GCFSTarget *expected = [GCFSTarget message];
  expected.query.parent = @"projects/p/databases/d/documents/rooms/1/messages/10";
  GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
  from.collectionId = @"attachments";
  [expected.query.structuredQuery.fromArray addObject:from];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:@"prop" ascending:NO]];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:kDocumentKeyPath ascending:NO]];
  expected.targetId = 1;

  [self assertRoundTripForQueryData:model proto:expected];
}

- (void)testEncodesLimits {
  core::Query query = Query("docs").WithLimit(26);
  QueryData model = [self queryDataForQuery:std::move(query)];

  GCFSTarget *expected = [GCFSTarget message];
  expected.query.parent = @"projects/p/databases/d/documents";
  GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
  from.collectionId = @"docs";
  [expected.query.structuredQuery.fromArray addObject:from];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:kDocumentKeyPath ascending:YES]];
  expected.query.structuredQuery.limit.value = 26;
  expected.targetId = 1;

  [self assertRoundTripForQueryData:model proto:expected];
}

- (void)testEncodesResumeTokens {
  core::Query q = Query("docs");
  QueryData model(std::move(q), 1, 0, QueryPurpose::Listen, SnapshotVersion::None(),
                  testutil::Bytes(1, 2, 3));

  GCFSTarget *expected = [GCFSTarget message];
  expected.query.parent = @"projects/p/databases/d/documents";
  GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
  from.collectionId = @"docs";
  [expected.query.structuredQuery.fromArray addObject:from];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:kDocumentKeyPath ascending:YES]];
  expected.targetId = 1;
  expected.resumeToken = MakeNSData(testutil::Bytes(1, 2, 3));

  [self assertRoundTripForQueryData:model proto:expected];
}

- (QueryData)queryDataForQuery:(core::Query)query {
  return QueryData(std::move(query), 1, 0, QueryPurpose::Listen);
}

- (void)assertRoundTripForQueryData:(const QueryData &)queryData proto:(GCFSTarget *)proto {
  // Verify that the encoded QueryData matches the target.
  GCFSTarget *actualProto = [self.serializer encodedTarget:queryData];
  XCTAssertEqualObjects(actualProto, proto);

  // We don't have deserialization logic for full targets since they're not used for RPC
  // interaction, but the query deserialization only *is* used for the local store.
  core::Query actualModel;
  if (proto.targetTypeOneOfCase == GCFSTarget_TargetType_OneOfCase_Query) {
    actualModel = [self.serializer decodedQueryFromQueryTarget:proto.query];
  } else {
    actualModel = [self.serializer decodedQueryFromDocumentsTarget:proto.documents];
  }
  XCTAssertEqual(actualModel, queryData.query());
}

- (void)testConvertsTargetChangeWithAdded {
  WatchTargetChange expected{WatchTargetChangeState::Added, {1, 4}};
  GCFSListenResponse *listenResponse = [GCFSListenResponse message];
  listenResponse.targetChange.targetChangeType = GCFSTargetChange_TargetChangeType_Add;
  [listenResponse.targetChange.targetIdsArray addValue:1];
  [listenResponse.targetChange.targetIdsArray addValue:4];

  std::unique_ptr<WatchChange> actual = [self.serializer decodedWatchChange:listenResponse];
  XCTAssertTrue(IsWatchChangeEqual(*actual, expected));
}

- (void)testConvertsTargetChangeWithRemoved {
  WatchTargetChange expected{WatchTargetChangeState::Removed,
                             {1, 4},
                             Bytes(0, 1, 2),
                             Status{Error::PermissionDenied, "Error message"}};

  GCFSListenResponse *listenResponse = [GCFSListenResponse message];
  listenResponse.targetChange.targetChangeType = GCFSTargetChange_TargetChangeType_Remove;
  listenResponse.targetChange.cause.code = FIRFirestoreErrorCodePermissionDenied;
  listenResponse.targetChange.cause.message = @"Error message";
  listenResponse.targetChange.resumeToken = MakeNSData(Bytes(0, 1, 2));
  [listenResponse.targetChange.targetIdsArray addValue:1];
  [listenResponse.targetChange.targetIdsArray addValue:4];

  std::unique_ptr<WatchChange> actual = [self.serializer decodedWatchChange:listenResponse];
  XCTAssertTrue(IsWatchChangeEqual(*actual, expected));
}

- (void)testConvertsTargetChangeWithNoChange {
  WatchTargetChange expected{WatchTargetChangeState::NoChange, {1, 4}};
  GCFSListenResponse *listenResponse = [GCFSListenResponse message];
  listenResponse.targetChange.targetChangeType = GCFSTargetChange_TargetChangeType_NoChange;
  [listenResponse.targetChange.targetIdsArray addValue:1];
  [listenResponse.targetChange.targetIdsArray addValue:4];

  std::unique_ptr<WatchChange> actual = [self.serializer decodedWatchChange:listenResponse];
  XCTAssertTrue(IsWatchChangeEqual(*actual, expected));
}

- (void)testConvertsDocumentChangeWithTargetIds {
  DocumentWatchChange expected{
      {1, 2}, {}, FSTTestDocKey(@"coll/1"), Doc("coll/1", 5, Map("foo", "bar"))};
  GCFSListenResponse *listenResponse = [GCFSListenResponse message];
  listenResponse.documentChange.document.name = @"projects/p/databases/d/documents/coll/1";
  listenResponse.documentChange.document.updateTime.nanos = 5000;
  GCFSValue *fooValue = [GCFSValue message];
  fooValue.stringValue = @"bar";
  [listenResponse.documentChange.document.fields setObject:fooValue forKey:@"foo"];
  [listenResponse.documentChange.targetIdsArray addValue:1];
  [listenResponse.documentChange.targetIdsArray addValue:2];

  std::unique_ptr<WatchChange> actual = [self.serializer decodedWatchChange:listenResponse];
  XCTAssertTrue(IsWatchChangeEqual(*actual, expected));
}

- (void)testConvertsDocumentChangeWithRemovedTargetIds {
  DocumentWatchChange expected{
      {2}, {1}, FSTTestDocKey(@"coll/1"), Doc("coll/1", 5, Map("foo", "bar"))};

  GCFSListenResponse *listenResponse = [GCFSListenResponse message];
  listenResponse.documentChange.document.name = @"projects/p/databases/d/documents/coll/1";
  listenResponse.documentChange.document.updateTime.nanos = 5000;
  GCFSValue *fooValue = [GCFSValue message];
  fooValue.stringValue = @"bar";
  [listenResponse.documentChange.document.fields setObject:fooValue forKey:@"foo"];
  [listenResponse.documentChange.removedTargetIdsArray addValue:1];
  [listenResponse.documentChange.targetIdsArray addValue:2];

  std::unique_ptr<WatchChange> actual = [self.serializer decodedWatchChange:listenResponse];
  XCTAssertTrue(IsWatchChangeEqual(*actual, expected));
}

- (void)testConvertsDocumentChangeWithDeletions {
  DocumentWatchChange expected{{}, {1, 2}, FSTTestDocKey(@"coll/1"), DeletedDoc("coll/1", 5)};

  GCFSListenResponse *listenResponse = [GCFSListenResponse message];
  listenResponse.documentDelete.document = @"projects/p/databases/d/documents/coll/1";
  listenResponse.documentDelete.readTime.nanos = 5000;
  [listenResponse.documentDelete.removedTargetIdsArray addValue:1];
  [listenResponse.documentDelete.removedTargetIdsArray addValue:2];

  std::unique_ptr<WatchChange> actual = [self.serializer decodedWatchChange:listenResponse];
  XCTAssertTrue(IsWatchChangeEqual(*actual, expected));
}

- (void)testConvertsDocumentChangeWithRemoves {
  DocumentWatchChange expected{{}, {1, 2}, Key("coll/1"), absl::nullopt};

  GCFSListenResponse *listenResponse = [GCFSListenResponse message];
  listenResponse.documentRemove.document = @"projects/p/databases/d/documents/coll/1";
  [listenResponse.documentRemove.removedTargetIdsArray addValue:1];
  [listenResponse.documentRemove.removedTargetIdsArray addValue:2];

  std::unique_ptr<WatchChange> actual = [self.serializer decodedWatchChange:listenResponse];
  XCTAssertTrue(IsWatchChangeEqual(*actual, expected));
}

@end

NS_ASSUME_NONNULL_END
