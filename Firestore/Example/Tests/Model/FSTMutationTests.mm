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

#import "Firestore/Source/Model/FSTMutation.h"

#import <FirebaseFirestore/FIRFieldValue.h>
#import <FirebaseFirestore/FIRTimestamp.h>
#import <XCTest/XCTest.h>

#include <vector>

#import "Firestore/Source/API/FIRFieldValue+Internal.h"
#import "Firestore/Source/API/converters.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"
#include "Firestore/core/src/firebase/firestore/model/unknown_document.h"
#include "Firestore/core/src/firebase/firestore/timestamp_internal.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace api = firebase::firestore::api;
namespace testutil = firebase::firestore::testutil;
using firebase::Timestamp;
using firebase::TimestampInternal;
using firebase::firestore::model::ArrayTransform;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::MaybeDocument;
using firebase::firestore::model::NoDocument;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::TransformOperation;
using firebase::firestore::model::UnknownDocument;
using firebase::firestore::testutil::Array;
using firebase::firestore::testutil::Field;
using firebase::firestore::testutil::Key;
using firebase::firestore::testutil::Version;

using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Map;
using testutil::WrapObject;

/**
 * Converts the input arguments to a vector of FieldValues wrapping the input
 * types.
 */
template <typename... Args>
static std::vector<FieldValue> FieldValueVector(Args... values) {
  return Array(values...).array_value();
}

@interface FSTMutationTests : XCTestCase
@end

@implementation FSTMutationTests {
  Timestamp _timestamp;
}

- (void)setUp {
  _timestamp = Timestamp::Now();
}

- (void)testAppliesSetsToDocuments {
  auto docData = Map("foo", "foo-value", "baz", "baz-value");
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *set = FSTTestSetMutation(@"collection/key", @{@"bar" : @"bar-value"});
  auto setDoc = [set applyToLocalDocument:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  auto expectedData = Map("bar", "bar-value");
  XCTAssertEqual(setDoc, Doc("collection/key", 0, expectedData, DocumentState::kLocalMutations));
}

- (void)testAppliesPatchesToDocuments {
  auto docData = Map("foo", Map("bar", "bar-value"), "baz", "baz-value");
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo.bar" : @"new-bar-value"}, {});
  auto patchedDoc = [patch applyToLocalDocument:baseDoc
                                   baseDocument:baseDoc
                                 localWriteTime:_timestamp];

  auto expectedData = Map("foo", Map("bar", "new-bar-value"), "baz", "baz-value");
  XCTAssertEqual(patchedDoc,
                 Doc("collection/key", 0, expectedData, DocumentState::kLocalMutations));
}

- (void)testDeletesValuesFromTheFieldMask {
  auto docData = Map("foo", Map("bar", "bar-value", "baz", "baz-value"));
  Document baseDoc = Doc("collection/key", 0, docData);

  DocumentKey key = Key("collection/key");
  FSTMutation *patch = [[FSTPatchMutation alloc] initWithKey:key
                                                   fieldMask:{Field("foo.bar")}
                                                       value:ObjectValue::Empty()
                                                precondition:Precondition::None()];
  auto patchedDoc = [patch applyToLocalDocument:baseDoc
                                   baseDocument:baseDoc
                                 localWriteTime:_timestamp];

  auto expectedData = Map("foo", Map("baz", "baz-value"));
  XCTAssertEqual(patchedDoc,
                 Doc("collection/key", 0, expectedData, DocumentState::kLocalMutations));
}

- (void)testPatchesPrimitiveValue {
  auto docData = Map("foo", "foo-value", "baz", "baz-value");
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo.bar" : @"new-bar-value"}, {});
  auto patchedDoc = [patch applyToLocalDocument:baseDoc
                                   baseDocument:baseDoc
                                 localWriteTime:_timestamp];

  auto expectedData = Map("foo", Map("bar", "new-bar-value"), "baz", "baz-value");
  XCTAssertEqual(patchedDoc,
                 Doc("collection/key", 0, expectedData, DocumentState::kLocalMutations));
}

- (void)testPatchingDeletedDocumentsDoesNothing {
  MaybeDocument baseDoc = DeletedDoc("collection/key");
  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo" : @"bar"}, {});
  auto patchedDoc = [patch applyToLocalDocument:baseDoc
                                   baseDocument:baseDoc
                                 localWriteTime:_timestamp];
  XCTAssertEqual(patchedDoc, baseDoc);
}

- (void)testAppliesLocalServerTimestampTransformToDocuments {
  auto docData = Map("foo", Map("bar", "bar-value"), "baz", "baz-value");
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *transform = FSTTestTransformMutation(
      @"collection/key", @{@"foo.bar" : [FIRFieldValue fieldValueForServerTimestamp]});
  auto transformedDoc = [transform applyToLocalDocument:baseDoc
                                           baseDocument:baseDoc
                                         localWriteTime:_timestamp];

  // Server timestamps aren't parsed, so we manually insert it.
  ObjectValue expectedData =
      WrapObject("foo", Map("bar", "<server-timestamp>"), "baz", "baz-value");
  expectedData = expectedData.Set(Field("foo.bar"), FieldValue::FromServerTimestamp(_timestamp));

  Document expectedDoc = Doc("collection/key", 0, expectedData, DocumentState::kLocalMutations);

  XCTAssertEqual(transformedDoc, expectedDoc);
}

- (void)testAppliesIncrementTransformToDocument {
  auto baseDoc =
      Map("longPlusLong", 1, "longPlusDouble", 2, "doublePlusLong", 3.3, "doublePlusDouble", 4.0,
          "longPlusNan", 5, "doublePlusNan", 6.6, "longPlusInfinity", 7, "doublePlusInfinity", 8.8);
  NSDictionary *transform = @{
    @"longPlusLong" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"longPlusDouble" : [FIRFieldValue fieldValueForDoubleIncrement:2.2],
    @"doublePlusLong" : [FIRFieldValue fieldValueForIntegerIncrement:3],
    @"doublePlusDouble" : [FIRFieldValue fieldValueForDoubleIncrement:4.4],
    @"longPlusNan" : [FIRFieldValue fieldValueForDoubleIncrement:NAN],
    @"doublePlusNan" : [FIRFieldValue fieldValueForDoubleIncrement:NAN],
    @"longPlusInfinity" : [FIRFieldValue fieldValueForDoubleIncrement:INFINITY],
    @"doublePlusInfinity" : [FIRFieldValue fieldValueForDoubleIncrement:INFINITY]
  };
  auto expected = Map("longPlusLong", 2L, "longPlusDouble", 4.2, "doublePlusLong", 6.3,
                      "doublePlusDouble", 8.4, "longPlusNan", NAN, "doublePlusNan", NAN,
                      "longPlusInfinity", INFINITY, "doublePlusInfinity", INFINITY);
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesIncrementTransformToUnexpectedType {
  auto baseDoc = Map("string", "zero");
  NSDictionary *transform = @{@"string" : [FIRFieldValue fieldValueForIntegerIncrement:1]};
  auto expected = Map("string", 1);
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesIncrementTransformToMissingField {
  auto baseDoc = Map();
  NSDictionary *transform = @{@"missing" : [FIRFieldValue fieldValueForIntegerIncrement:1]};
  auto expected = Map("missing", 1);
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesIncrementTransformsConsecutively {
  auto baseDoc = Map("number", 1);
  NSDictionary *transform1 = @{@"number" : [FIRFieldValue fieldValueForIntegerIncrement:2]};
  NSDictionary *transform2 = @{@"number" : [FIRFieldValue fieldValueForIntegerIncrement:3]};
  NSDictionary *transform3 = @{@"number" : [FIRFieldValue fieldValueForIntegerIncrement:4]};
  auto expected = Map("number", 10);
  [self transformBaseDoc:baseDoc
         applyTransforms:@[ transform1, transform2, transform3 ]
               expecting:expected];
}

- (void)testAppliesIncrementWithoutOverflow {
  auto baseDoc = Map("a", LONG_MAX - 1, "b", LONG_MAX - 1, "c", LONG_MAX, "d", LONG_MAX);
  NSDictionary *transform = @{
    @"a" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"b" : [FIRFieldValue fieldValueForIntegerIncrement:LONG_MAX],
    @"c" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"d" : [FIRFieldValue fieldValueForIntegerIncrement:LONG_MAX]
  };
  auto expected = Map("a", LONG_MAX, "b", LONG_MAX, "c", LONG_MAX, "d", LONG_MAX);
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesIncrementWithoutUnderflow {
  auto baseDoc = Map("a", LONG_MIN + 1, "b", LONG_MIN + 1, "c", LONG_MIN, "d", LONG_MIN);
  NSDictionary *transform = @{
    @"a" : [FIRFieldValue fieldValueForIntegerIncrement:-1],
    @"b" : [FIRFieldValue fieldValueForIntegerIncrement:LONG_MIN],
    @"c" : [FIRFieldValue fieldValueForIntegerIncrement:-1],
    @"d" : [FIRFieldValue fieldValueForIntegerIncrement:LONG_MIN]
  };
  auto expected = Map("a", LONG_MIN, "b", LONG_MIN, "c", LONG_MIN, "d", LONG_MIN);
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

// NOTE: This is more a test of FSTUserDataConverter code than FSTMutation code but we don't have
// unit tests for it currently. We could consider removing this test once we have integration tests.
- (void)testCreateArrayUnionTransform {
  FSTTransformMutation *transform = FSTTestTransformMutation(@"collection/key", @{
    @"foo" : [FIRFieldValue fieldValueForArrayUnion:@[ @"tag" ]],
    @"bar.baz" :
        [FIRFieldValue fieldValueForArrayUnion:@[ @YES, @{@"nested" : @{@"a" : @[ @1, @2 ]}} ]]
  });
  XCTAssertEqual(transform.fieldTransforms.size(), 2);

  const FieldTransform &first = transform.fieldTransforms[0];
  XCTAssertEqual(first.path(), FieldPath({"foo"}));
  {
    std::vector<FieldValue> expectedElements{FSTTestFieldValue(@"tag")};
    ArrayTransform expected(TransformOperation::Type::ArrayUnion, expectedElements);
    XCTAssertEqual(static_cast<const ArrayTransform &>(first.transformation()), expected);
  }

  const FieldTransform &second = transform.fieldTransforms[1];
  XCTAssertEqual(second.path(), FieldPath({"bar", "baz"}));
  {
    std::vector<FieldValue> expectedElements {
      FSTTestFieldValue(@YES), FSTTestFieldValue(@{@"nested" : @{@"a" : @[ @1, @2 ]}})
    };
    ArrayTransform expected(TransformOperation::Type::ArrayUnion, expectedElements);
    XCTAssertEqual(static_cast<const ArrayTransform &>(second.transformation()), expected);
  }
}

// NOTE: This is more a test of FSTUserDataConverter code than FSTMutation code but we don't have
// unit tests for it currently. We could consider removing this test once we have integration tests.
- (void)testCreateArrayRemoveTransform {
  FSTTransformMutation *transform = FSTTestTransformMutation(@"collection/key", @{
    @"foo" : [FIRFieldValue fieldValueForArrayRemove:@[ @"tag" ]],
  });
  XCTAssertEqual(transform.fieldTransforms.size(), 1);

  const FieldTransform &first = transform.fieldTransforms[0];
  XCTAssertEqual(first.path(), FieldPath({"foo"}));
  {
    std::vector<FieldValue> expectedElements{FSTTestFieldValue(@"tag")};
    const ArrayTransform expected(TransformOperation::Type::ArrayRemove, expectedElements);
    XCTAssertEqual(static_cast<const ArrayTransform &>(first.transformation()), expected);
  }
}

- (void)testAppliesLocalArrayUnionTransformToMissingField {
  auto baseDoc = Map();
  auto transform = @{@"missing" : [FIRFieldValue fieldValueForArrayUnion:@[ @1, @2 ]]};
  auto expected = Map("missing", Array(1, 2));
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformToNonArrayField {
  auto baseDoc = Map("non-array", 42);
  auto transform = @{@"non-array" : [FIRFieldValue fieldValueForArrayUnion:@[ @1, @2 ]]};
  auto expected = Map("non-array", Array(1, 2));
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithNonExistingElements {
  auto baseDoc = Map("array", Array(1, 3));
  auto transform = @{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @2, @4 ]]};
  auto expected = Map("array", Array(1, 3, 2, 4));
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithExistingElements {
  auto baseDoc = Map("array", Array(1, 3));
  auto transform = @{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @1, @3 ]]};
  auto expected = Map("array", Array(1, 3));
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithDuplicateExistingElements {
  // Duplicate entries in your existing array should be preserved.
  auto baseDoc = Map("array", Array(1, 2, 2, 3));
  auto transform = @{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @2 ]]};
  auto expected = Map("array", Array(1, 2, 2, 3));
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithDuplicateUnionElements {
  // Duplicate entries in your union array should only be added once.
  auto baseDoc = Map("array", Array(1, 3));
  auto transform = @{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @2, @2 ]]};
  auto expected = Map("array", Array(1, 3, 2));
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithNonPrimitiveElements {
  // Union nested object values (one existing, one not).
  auto baseDoc = Map("array", Array(1, Map("a", "b")));
  auto transform =
      @{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @{@"a" : @"b"}, @{@"c" : @"d"} ]]};
  auto expected = Map("array", Array(1, Map("a", "b"), Map("c", "d")));
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithPartiallyOverlappingElements {
  // Union objects that partially overlap an existing object.
  auto baseDoc = Map("array", Array(1, Map("a", "b", "c", "d")));
  auto transform =
      @{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @{@"a" : @"b"}, @{@"c" : @"d"} ]]};
  auto expected = Map("array", Array(1, Map("a", "b", "c", "d"), Map("a", "b"), Map("c", "d")));
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformToMissingField {
  auto baseDoc = Map();
  auto transform = @{@"missing" : [FIRFieldValue fieldValueForArrayRemove:@[ @1, @2 ]]};
  auto expected = Map("missing", Array());
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformToNonArrayField {
  auto baseDoc = Map("non-array", 42);
  auto transform = @{@"non-array" : [FIRFieldValue fieldValueForArrayRemove:@[ @1, @2 ]]};
  auto expected = Map("non-array", Array());
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformWithNonExistingElements {
  auto baseDoc = Map("array", Array(1, 3));
  auto transform = @{@"array" : [FIRFieldValue fieldValueForArrayRemove:@[ @2, @4 ]]};
  auto expected = Map("array", Array(1, 3));
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformWithExistingElements {
  auto baseDoc = Map("array", Array(1, 2, 3, 4));
  auto transform = @{@"array" : [FIRFieldValue fieldValueForArrayRemove:@[ @1, @3 ]]};
  auto expected = Map("array", Array(2, 4));
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformWithNonPrimitiveElements {
  // Remove nested object values (one existing, one not).
  auto baseDoc = Map("array", Array(1, Map("a", "b")));
  auto transform =
      @{@"array" : [FIRFieldValue fieldValueForArrayRemove:@[ @{@"a" : @"b"}, @{@"c" : @"d"} ]]};
  auto expected = Map("array", Array(1));
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

// Helper to test a particular transform scenario.
- (void)transformBaseDoc:(const FieldValue::Map &)baseData
         applyTransforms:(NSArray<NSDictionary<NSString *, id> *> *)transforms
               expecting:(const FieldValue::Map &)expectedData {
  absl::optional<MaybeDocument> currentDoc = Doc("collection/key", 0, baseData);

  for (NSDictionary<NSString *, id> *transformData in transforms) {
    FSTMutation *transform = FSTTestTransformMutation(@"collection/key", transformData);
    currentDoc = [transform applyToLocalDocument:currentDoc
                                    baseDocument:currentDoc
                                  localWriteTime:_timestamp];
  }

  Document expectedDoc = Doc("collection/key", 0, expectedData, DocumentState::kLocalMutations);

  XCTAssertEqual(currentDoc, expectedDoc);
}

- (void)transformBaseDoc:(const FieldValue::Map &)baseData
          applyTransform:(NSDictionary<NSString *, id> *)transformData
               expecting:(const FieldValue::Map &)expectedData {
  [self transformBaseDoc:baseData applyTransforms:@[ transformData ] expecting:expectedData];
}

- (void)testAppliesServerAckedIncrementTransformToDocuments {
  auto docData = Map("sum", 1);
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *transform = FSTTestTransformMutation(
      @"collection/key", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:2]});

  FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:Version(1) transformResults:FieldValueVector(3)];

  MaybeDocument transformedDoc = [transform applyToRemoteDocument:baseDoc
                                                   mutationResult:mutationResult];

  auto expectedData = Map("sum", 3);
  XCTAssertEqual(transformedDoc,
                 Doc("collection/key", 1, expectedData, DocumentState::kCommittedMutations));
}

- (void)testAppliesServerAckedServerTimestampTransformToDocuments {
  auto docData = Map("foo", Map("bar", "bar-value"), "baz", "baz-value");
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *transform = FSTTestTransformMutation(
      @"collection/key", @{@"foo.bar" : [FIRFieldValue fieldValueForServerTimestamp]});

  FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:Version(1)
                                transformResults:FieldValueVector(_timestamp)];

  MaybeDocument transformedDoc = [transform applyToRemoteDocument:baseDoc
                                                   mutationResult:mutationResult];

  auto expectedData = Map("foo", Map("bar", _timestamp), "baz", "baz-value");
  Document expectedDoc = Doc("collection/key", 1, expectedData, DocumentState::kCommittedMutations);

  XCTAssertEqual(transformedDoc, expectedDoc);
}

- (void)testAppliesServerAckedArrayTransformsToDocuments {
  auto docData = Map("array_1", Array(1, 2), "array_2", Array("a", "b"));
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *transform = FSTTestTransformMutation(@"collection/key", @{
    @"array_1" : [FIRFieldValue fieldValueForArrayUnion:@[ @2, @3 ]],
    @"array_2" : [FIRFieldValue fieldValueForArrayRemove:@[ @"a", @"c" ]]
  });

  // Server just sends null transform results for array operations.
  FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:Version(1)
                                transformResults:FieldValueVector(nullptr, nullptr)];

  MaybeDocument transformedDoc = [transform applyToRemoteDocument:baseDoc
                                                   mutationResult:mutationResult];

  auto expectedData = Map("array_1", Array(1, 2, 3), "array_2", Array("b"));
  XCTAssertEqual(transformedDoc,
                 Doc("collection/key", 1, expectedData, DocumentState::kCommittedMutations));
}

- (void)testDeleteDeletes {
  auto docData = Map("foo", "bar");
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *mutation = FSTTestDeleteMutation(@"collection/key");
  auto result = [mutation applyToLocalDocument:baseDoc
                                  baseDocument:baseDoc
                                localWriteTime:_timestamp];
  XCTAssertEqual(result, DeletedDoc("collection/key"));
}

- (void)testSetWithMutationResult {
  auto docData = Map("foo", "bar");
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *set = FSTTestSetMutation(@"collection/key", @{@"foo" : @"new-bar"});
  FSTMutationResult *mutationResult = [[FSTMutationResult alloc] initWithVersion:Version(4)
                                                                transformResults:absl::nullopt];
  MaybeDocument setDoc = [set applyToRemoteDocument:baseDoc mutationResult:mutationResult];

  auto expectedData = Map("foo", "new-bar");
  XCTAssertEqual(setDoc,
                 Doc("collection/key", 4, expectedData, DocumentState::kCommittedMutations));
}

- (void)testPatchWithMutationResult {
  auto docData = Map("foo", "bar");
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo" : @"new-bar"}, {});
  FSTMutationResult *mutationResult = [[FSTMutationResult alloc] initWithVersion:Version(4)
                                                                transformResults:absl::nullopt];
  MaybeDocument patchedDoc = [patch applyToRemoteDocument:baseDoc mutationResult:mutationResult];

  auto expectedData = Map("foo", "new-bar");
  XCTAssertEqual(patchedDoc,
                 Doc("collection/key", 4, expectedData, DocumentState::kCommittedMutations));
}

- (void)testNonTransformMutationBaseValue {
  auto docData = Map("foo", "foo");
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *set = FSTTestSetMutation(@"collection/key", @{@"foo" : @"bar"});
  XCTAssertFalse([set extractBaseValue:baseDoc]);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo" : @"bar"}, {});
  XCTAssertFalse([patch extractBaseValue:baseDoc]);

  FSTMutation *deleter = FSTTestDeleteMutation(@"collection/key");
  XCTAssertFalse([deleter extractBaseValue:baseDoc]);
}

- (void)testServerTimestampBaseValue {
  auto docData = Map("time", "foo", "nested", Map("time", "foo"));
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *transform = FSTTestTransformMutation(@"collection/key", @{
    @"time" : [FIRFieldValue fieldValueForServerTimestamp],
    @"nested.time" : [FIRFieldValue fieldValueForServerTimestamp]
  });

  // Server timestamps are idempotent and don't require base values.
  XCTAssertFalse([transform extractBaseValue:baseDoc]);
}

- (void)testNumericIncrementBaseValue {
  auto docData =
      Map("ignore", "foo", "double", 42.0, "long", 42, "string", "foo", "map", Map(), "nested",
          Map("ignore", "foo", "double", 42.0, "long", 42, "string", "foo", "map", Map()));
  Document baseDoc = Doc("collection/key", 0, docData);

  FSTMutation *transform = FSTTestTransformMutation(@"collection/key", @{
    @"double" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"long" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"string" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"map" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"missing" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"nested.double" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"nested.long" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"nested.string" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"nested.map" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"nested.missing" : [FIRFieldValue fieldValueForIntegerIncrement:1]
  });

  ObjectValue expectedBaseValue =
      WrapObject("double", 42.0, "long", 42, "string", 0, "map", 0, "missing", 0, "nested",
                 Map("double", 42.0, "long", 42, "string", 0, "map", 0, "missing", 0));

  // Server timestamps are idempotent and don't require base values.
  absl::optional<ObjectValue> actualBaseValue = [transform extractBaseValue:baseDoc];
  XCTAssertTrue([transform extractBaseValue:baseDoc]);
  XCTAssertEqual(expectedBaseValue, *actualBaseValue);
}

#define ASSERT_VERSION_TRANSITION(mutation, base, result, expected)            \
  do {                                                                         \
    auto actual = [mutation applyToRemoteDocument:base mutationResult:result]; \
    XCTAssertEqual(actual, expected);                                          \
  } while (0);

/**
 * Tests the transition table documented in FSTMutation.h.
 */
- (void)testTransitions {
  Document docV3 = Doc("collection/key", 3, Map());
  NoDocument deletedV3 = DeletedDoc("collection/key", 3);

  FSTMutation *setMutation = FSTTestSetMutation(@"collection/key", @{});
  FSTMutation *patchMutation = FSTTestPatchMutation("collection/key", @{}, {});
  FSTMutation *transformMutation = FSTTestTransformMutation(@"collection/key", @{});
  FSTMutation *deleteMutation = FSTTestDeleteMutation(@"collection/key");

  NoDocument docV7Deleted = DeletedDoc("collection/key", 7, /* has_committed_mutations= */ true);
  Document docV7Committed = Doc("collection/key", 7, Map(), DocumentState::kCommittedMutations);
  UnknownDocument docV7Unknown = FSTTestUnknownDoc("collection/key", 7);

  FSTMutationResult *mutationResult = [[FSTMutationResult alloc] initWithVersion:Version(7)
                                                                transformResults:absl::nullopt];
  FSTMutationResult *transformResult =
      [[FSTMutationResult alloc] initWithVersion:Version(7) transformResults:FieldValueVector()];

  ASSERT_VERSION_TRANSITION(setMutation, docV3, mutationResult, docV7Committed);
  ASSERT_VERSION_TRANSITION(setMutation, deletedV3, mutationResult, docV7Committed);
  ASSERT_VERSION_TRANSITION(setMutation, absl::nullopt, mutationResult, docV7Committed);

  ASSERT_VERSION_TRANSITION(patchMutation, docV3, mutationResult, docV7Committed);
  ASSERT_VERSION_TRANSITION(patchMutation, deletedV3, mutationResult, docV7Unknown);
  ASSERT_VERSION_TRANSITION(patchMutation, absl::nullopt, mutationResult, docV7Unknown);

  ASSERT_VERSION_TRANSITION(transformMutation, docV3, transformResult, docV7Committed);
  ASSERT_VERSION_TRANSITION(transformMutation, deletedV3, transformResult, docV7Unknown);
  ASSERT_VERSION_TRANSITION(transformMutation, absl::nullopt, transformResult, docV7Unknown);

  ASSERT_VERSION_TRANSITION(deleteMutation, docV3, mutationResult, docV7Deleted);
  ASSERT_VERSION_TRANSITION(deleteMutation, deletedV3, mutationResult, docV7Deleted);
  ASSERT_VERSION_TRANSITION(deleteMutation, absl::nullopt, mutationResult, docV7Deleted);
}

#undef ASSERT_TRANSITION

@end
