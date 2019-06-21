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
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"

#import "Firestore/Example/Tests/API/FSTAPIHelpers.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;
using firebase::Timestamp;
using firebase::firestore::FirestoreErrorCode;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::ExistenceFilterWatchChange;
using firebase::firestore::remote::WatchChange;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WatchTargetChangeState;
using firebase::firestore::testutil::Array;
using firebase::firestore::util::Status;

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
  FSTSetMutation *mutation = FSTTestSetMutation(@"docs/1", @{@"a" : @"b", @"num" : @1});
  GCFSWrite *proto = [GCFSWrite message];
  proto.update = [self.serializer encodedDocumentWithFields:mutation.value key:mutation.key];

  [self assertRoundTripForMutation:mutation proto:proto];
}

- (void)testEncodesPatchMutation {
  FSTPatchMutation *mutation = FSTTestPatchMutation(
      "docs/1", @{@"a" : @"b", @"num" : @1, @"some.de\\\\ep.th\\ing'" : @2}, {});
  GCFSWrite *proto = [GCFSWrite message];
  proto.update = [self.serializer encodedDocumentWithFields:mutation.value key:mutation.key];
  proto.updateMask = [self.serializer encodedFieldMask:*(mutation.fieldMask)];
  proto.currentDocument.exists = YES;

  [self assertRoundTripForMutation:mutation proto:proto];
}

- (void)testEncodesDeleteMutation {
  FSTDeleteMutation *mutation = FSTTestDeleteMutation(@"docs/1");
  GCFSWrite *proto = [GCFSWrite message];
  proto.delete_p = @"projects/p/databases/d/documents/docs/1";

  [self assertRoundTripForMutation:mutation proto:proto];
}

- (void)testEncodesServerTimestampTransformMutation {
  FSTTransformMutation *mutation = FSTTestTransformMutation(@"docs/1", @{
    @"a" : [FIRFieldValue fieldValueForServerTimestamp],
    @"bar.baz" : [FIRFieldValue fieldValueForServerTimestamp]
  });
  GCFSWrite *proto = [GCFSWrite message];
  proto.transform = [GCFSDocumentTransform message];
  proto.transform.document = [self.serializer encodedDocumentKey:mutation.key];
  proto.transform.fieldTransformsArray =
      [self.serializer encodedFieldTransforms:mutation.fieldTransforms];
  proto.currentDocument.exists = YES;

  [self assertRoundTripForMutation:mutation proto:proto];
}

- (void)testEncodesArrayTransformMutations {
  FSTTransformMutation *mutation = FSTTestTransformMutation(@"docs/1", @{
    @"a" : [FIRFieldValue fieldValueForArrayUnion:@[ @"a", @2 ]],
    @"bar.baz" : [FIRFieldValue fieldValueForArrayRemove:@[ @{@"x" : @1} ]]
  });
  GCFSWrite *proto = [GCFSWrite message];
  proto.transform = [GCFSDocumentTransform message];
  proto.transform.document = [self.serializer encodedDocumentKey:mutation.key];

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
  FSTSetMutation *mutation =
      [[FSTSetMutation alloc] initWithKey:FSTTestDocKey(@"foo/bar")
                                    value:FSTTestObjectValue(@{@"a" : @"b", @"num" : @1})
                             precondition:Precondition::UpdateTime(testutil::Version(4))];
  GCFSWrite *proto = [GCFSWrite message];
  proto.update = [self.serializer encodedDocumentWithFields:mutation.value key:mutation.key];
  proto.currentDocument.updateTime = [self.serializer encodedTimestamp:Timestamp{0, 4000}];

  [self assertRoundTripForMutation:mutation proto:proto];
}

- (void)assertRoundTripForMutation:(FSTMutation *)mutation proto:(GCFSWrite *)proto {
  GCFSWrite *actualProto = [self.serializer encodedMutation:mutation];
  XCTAssertEqualObjects(actualProto, proto);

  FSTMutation *actualMutation = [self.serializer decodedMutation:proto];
  XCTAssertEqualObjects(actualMutation, mutation);
}

- (void)testDecodesMutationResult {
  SnapshotVersion commitVersion = testutil::Version(3000);
  SnapshotVersion updateVersion = testutil::Version(4000);
  GCFSWriteResult *proto = [GCFSWriteResult message];
  proto.updateTime = [self.serializer encodedTimestamp:updateVersion.timestamp()];
  [proto.transformResultsArray addObject:[self.serializer encodedString:"result"]];

  FSTMutationResult *result = [self.serializer decodedMutationResult:proto
                                                       commitVersion:commitVersion];

  XCTAssertEqual(result.version, updateVersion);
  XCTAssertTrue(result.transformResults.has_value());

  XCTAssertEqual(*result.transformResults, Array("result").array_value());
}

- (void)testDecodesDeleteMutationResult {
  GCFSWriteResult *proto = [GCFSWriteResult message];
  SnapshotVersion commitVersion = testutil::Version(4000);

  FSTMutationResult *result = [self.serializer decodedMutationResult:proto
                                                       commitVersion:commitVersion];

  XCTAssertEqual(result.version, commitVersion);
  XCTAssertFalse(result.transformResults.has_value());
}

- (void)testRoundTripSpecialFieldNames {
  FSTMutation *set = FSTTestSetMutation(@"collection/key", @{
    @"field" : [NSString stringWithFormat:@"field %d", 1],
    @"field.dot" : @2,
    @"field\\slash" : @3
  });
  GCFSWrite *encoded = [self.serializer encodedMutation:set];
  FSTMutation *decoded = [self.serializer decodedMutation:encoded];
  XCTAssertEqualObjects(set, decoded);
}

- (void)testEncodesListenRequestLabels {
  FSTQuery *query = FSTTestQuery("collection/key");
  FSTQueryData *queryData = [[FSTQueryData alloc] initWithQuery:query
                                                       targetID:2
                                           listenSequenceNumber:3
                                                        purpose:FSTQueryPurposeListen];

  NSDictionary<NSString *, NSString *> *result =
      [self.serializer encodedListenRequestLabelsForQueryData:queryData];
  XCTAssertNil(result);

  queryData = [[FSTQueryData alloc] initWithQuery:query
                                         targetID:2
                             listenSequenceNumber:3
                                          purpose:FSTQueryPurposeLimboResolution];
  result = [self.serializer encodedListenRequestLabelsForQueryData:queryData];
  XCTAssertEqualObjects(result, @{@"goog-listen-tags" : @"limbo-document"});

  queryData = [[FSTQueryData alloc] initWithQuery:query
                                         targetID:2
                             listenSequenceNumber:3
                                          purpose:FSTQueryPurposeExistenceFilterMismatch];
  result = [self.serializer encodedListenRequestLabelsForQueryData:queryData];
  XCTAssertEqualObjects(result, @{@"goog-listen-tags" : @"existence-filter-mismatch"});
}

- (void)testEncodesRelationFilter {
  FSTRelationFilter *input = (FSTRelationFilter *)FSTTestFilter("item.part.top", @"==", @"food");
  GCFSStructuredQuery_Filter *actual = [self.serializer encodedRelationFilter:input];

  GCFSStructuredQuery_Filter *expected = [GCFSStructuredQuery_Filter message];
  GCFSStructuredQuery_FieldFilter *prop = expected.fieldFilter;
  prop.field.fieldPath = @"item.part.top";
  prop.op = GCFSStructuredQuery_FieldFilter_Operator_Equal;
  prop.value.stringValue = @"food";
  XCTAssertEqualObjects(actual, expected);
}

- (void)testEncodesArrayContainsFilter {
  FSTRelationFilter *input =
      (FSTRelationFilter *)FSTTestFilter("item.tags", @"array_contains", @"food");
  GCFSStructuredQuery_Filter *actual = [self.serializer encodedRelationFilter:input];

  GCFSStructuredQuery_Filter *expected = [GCFSStructuredQuery_Filter message];
  GCFSStructuredQuery_FieldFilter *prop = expected.fieldFilter;
  prop.field.fieldPath = @"item.tags";
  prop.op = GCFSStructuredQuery_FieldFilter_Operator_ArrayContains;
  prop.value.stringValue = @"food";
  XCTAssertEqualObjects(actual, expected);
}

#pragma mark - encodedQuery

- (void)testEncodesFirstLevelKeyQueries {
  FSTQuery *q = FSTTestQuery("docs/1");
  FSTQueryData *model = [self queryDataForQuery:q];

  GCFSTarget *expected = [GCFSTarget message];
  [expected.documents.documentsArray addObject:@"projects/p/databases/d/documents/docs/1"];
  expected.targetId = 1;

  [self assertRoundTripForQueryData:model proto:expected];
}

- (void)testEncodesFirstLevelAncestorQueries {
  FSTQuery *q = FSTTestQuery("messages");
  FSTQueryData *model = [self queryDataForQuery:q];

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
  FSTQuery *q = FSTTestQuery("rooms/1/messages/10/attachments");
  FSTQueryData *model = [self queryDataForQuery:q];

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
  FSTQuery *q = [FSTTestQuery("docs") queryByAddingFilter:FSTTestFilter("prop", @"<", @(42))];
  FSTQueryData *model = [self queryDataForQuery:q];

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
  FSTQuery *q = [[[FSTTestQuery("rooms/1/messages/10/attachments")
      queryByAddingFilter:FSTTestFilter("prop", @">=", @(42))]
      queryByAddingFilter:FSTTestFilter("author", @"==", @"dimond")]
      queryByAddingFilter:FSTTestFilter("tags", @"array_contains", @"pending")];
  FSTQueryData *model = [self queryDataForQuery:q];

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
  [self unaryFilterTestWithValue:[NSNull null]
           expectedUnaryOperator:GCFSStructuredQuery_UnaryFilter_Operator_IsNull];
}

- (void)testEncodesNanFilter {
  [self unaryFilterTestWithValue:@(NAN)
           expectedUnaryOperator:GCFSStructuredQuery_UnaryFilter_Operator_IsNan];
}

- (void)unaryFilterTestWithValue:(id)value
           expectedUnaryOperator:(GCFSStructuredQuery_UnaryFilter_Operator)op {
  FSTQuery *q = [FSTTestQuery("docs") queryByAddingFilter:FSTTestFilter("prop", @"==", value)];
  FSTQueryData *model = [self queryDataForQuery:q];

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
  FSTQuery *q = [FSTTestQuery("docs")
      queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("prop")
                                                        ascending:YES]];
  FSTQueryData *model = [self queryDataForQuery:q];

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
  FSTQuery *q = [FSTTestQuery("rooms/1/messages/10/attachments")
      queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("prop")
                                                        ascending:NO]];
  FSTQueryData *model = [self queryDataForQuery:q];

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
  FSTQuery *q = [FSTTestQuery("docs") queryBySettingLimit:26];
  FSTQueryData *model = [self queryDataForQuery:q];

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
  FSTQuery *q = FSTTestQuery("docs");
  FSTQueryData *model = [[FSTQueryData alloc] initWithQuery:q
                                                   targetID:1
                                       listenSequenceNumber:0
                                                    purpose:FSTQueryPurposeListen
                                            snapshotVersion:SnapshotVersion::None()
                                                resumeToken:FSTTestData(1, 2, 3, -1)];

  GCFSTarget *expected = [GCFSTarget message];
  expected.query.parent = @"projects/p/databases/d/documents";
  GCFSStructuredQuery_CollectionSelector *from = [GCFSStructuredQuery_CollectionSelector message];
  from.collectionId = @"docs";
  [expected.query.structuredQuery.fromArray addObject:from];
  [expected.query.structuredQuery.orderByArray
      addObject:[GCFSStructuredQuery_Order messageWithProperty:kDocumentKeyPath ascending:YES]];
  expected.targetId = 1;
  expected.resumeToken = FSTTestData(1, 2, 3, -1);

  [self assertRoundTripForQueryData:model proto:expected];
}

- (FSTQueryData *)queryDataForQuery:(FSTQuery *)query {
  return [[FSTQueryData alloc] initWithQuery:query
                                    targetID:1
                        listenSequenceNumber:0
                                     purpose:FSTQueryPurposeListen
                             snapshotVersion:SnapshotVersion::None()
                                 resumeToken:[NSData data]];
}

- (void)assertRoundTripForQueryData:(FSTQueryData *)queryData proto:(GCFSTarget *)proto {
  // Verify that the encoded FSTQueryData matches the target.
  GCFSTarget *actualProto = [self.serializer encodedTarget:queryData];
  XCTAssertEqualObjects(actualProto, proto);

  // We don't have deserialization logic for full targets since they're not used for RPC
  // interaction, but the query deserialization only *is* used for the local store.
  FSTQuery *actualModel;
  if (proto.targetTypeOneOfCase == GCFSTarget_TargetType_OneOfCase_Query) {
    actualModel = [self.serializer decodedQueryFromQueryTarget:proto.query];
  } else {
    actualModel = [self.serializer decodedQueryFromDocumentsTarget:proto.documents];
  }
  XCTAssertEqualObjects(actualModel, queryData.query);
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
                             FSTTestData(0, 1, 2, -1),
                             Status{FirestoreErrorCode::PermissionDenied, "Error message"}};

  GCFSListenResponse *listenResponse = [GCFSListenResponse message];
  listenResponse.targetChange.targetChangeType = GCFSTargetChange_TargetChangeType_Remove;
  listenResponse.targetChange.cause.code = FIRFirestoreErrorCodePermissionDenied;
  listenResponse.targetChange.cause.message = @"Error message";
  listenResponse.targetChange.resumeToken = FSTTestData(0, 1, 2, -1);
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
  DocumentWatchChange expected {
    {1, 2}, {}, FSTTestDocKey(@"coll/1"),
        FSTTestDoc("coll/1", 5, @{@"foo" : @"bar"}, DocumentState::kSynced)
  };
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
  DocumentWatchChange expected {
    {2}, {1}, FSTTestDocKey(@"coll/1"),
        FSTTestDoc("coll/1", 5, @{@"foo" : @"bar"}, DocumentState::kSynced)
  };

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
  DocumentWatchChange expected{
      {}, {1, 2}, FSTTestDocKey(@"coll/1"), FSTTestDeletedDoc("coll/1", 5, NO)};

  GCFSListenResponse *listenResponse = [GCFSListenResponse message];
  listenResponse.documentDelete.document = @"projects/p/databases/d/documents/coll/1";
  listenResponse.documentDelete.readTime.nanos = 5000;
  [listenResponse.documentDelete.removedTargetIdsArray addValue:1];
  [listenResponse.documentDelete.removedTargetIdsArray addValue:2];

  std::unique_ptr<WatchChange> actual = [self.serializer decodedWatchChange:listenResponse];
  XCTAssertTrue(IsWatchChangeEqual(*actual, expected));
}

- (void)testConvertsDocumentChangeWithRemoves {
  DocumentWatchChange expected{{}, {1, 2}, FSTTestDocKey(@"coll/1"), nil};

  GCFSListenResponse *listenResponse = [GCFSListenResponse message];
  listenResponse.documentRemove.document = @"projects/p/databases/d/documents/coll/1";
  [listenResponse.documentRemove.removedTargetIdsArray addValue:1];
  [listenResponse.documentRemove.removedTargetIdsArray addValue:2];

  std::unique_ptr<WatchChange> actual = [self.serializer decodedWatchChange:listenResponse];
  XCTAssertTrue(IsWatchChangeEqual(*actual, expected));
}

@end

NS_ASSUME_NONNULL_END
