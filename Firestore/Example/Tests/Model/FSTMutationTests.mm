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
#import "Firestore/Source/Model/FSTDocument.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace api = firebase::firestore::api;
namespace testutil = firebase::firestore::testutil;
using firebase::Timestamp;
using firebase::firestore::model::ArrayTransform;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::TransformOperation;
using firebase::firestore::testutil::Array;
using firebase::firestore::testutil::Field;
using firebase::firestore::testutil::Key;
using firebase::firestore::testutil::Version;

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
  NSDictionary *docData = @{@"foo" : @"foo-value", @"baz" : @"baz-value"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  FSTMutation *set = FSTTestSetMutation(@"collection/key", @{@"bar" : @"bar-value"});
  FSTMaybeDocument *setDoc = [set applyToLocalDocument:baseDoc
                                          baseDocument:baseDoc
                                        localWriteTime:_timestamp];

  NSDictionary *expectedData = @{@"bar" : @"bar-value"};
  XCTAssertEqualObjects(
      setDoc, FSTTestDoc("collection/key", 0, expectedData, DocumentState::kLocalMutations));
}

- (void)testAppliesPatchesToDocuments {
  NSDictionary *docData = @{@"foo" : @{@"bar" : @"bar-value"}, @"baz" : @"baz-value"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo.bar" : @"new-bar-value"}, {});
  FSTMaybeDocument *patchedDoc = [patch applyToLocalDocument:baseDoc
                                                baseDocument:baseDoc
                                              localWriteTime:_timestamp];

  NSDictionary *expectedData = @{@"foo" : @{@"bar" : @"new-bar-value"}, @"baz" : @"baz-value"};
  XCTAssertEqualObjects(
      patchedDoc, FSTTestDoc("collection/key", 0, expectedData, DocumentState::kLocalMutations));
}

- (void)testDeletesValuesFromTheFieldMask {
  NSDictionary *docData = @{@"foo" : @{@"bar" : @"bar-value", @"baz" : @"baz-value"}};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  DocumentKey key = Key("collection/key");
  FSTMutation *patch = [[FSTPatchMutation alloc] initWithKey:key
                                                   fieldMask:{Field("foo.bar")}
                                                       value:ObjectValue::Empty()
                                                precondition:Precondition::None()];
  FSTMaybeDocument *patchedDoc = [patch applyToLocalDocument:baseDoc
                                                baseDocument:baseDoc
                                              localWriteTime:_timestamp];

  NSDictionary *expectedData = @{@"foo" : @{@"baz" : @"baz-value"}};
  XCTAssertEqualObjects(
      patchedDoc, FSTTestDoc("collection/key", 0, expectedData, DocumentState::kLocalMutations));
}

- (void)testPatchesPrimitiveValue {
  NSDictionary *docData = @{@"foo" : @"foo-value", @"baz" : @"baz-value"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo.bar" : @"new-bar-value"}, {});
  FSTMaybeDocument *patchedDoc = [patch applyToLocalDocument:baseDoc
                                                baseDocument:baseDoc
                                              localWriteTime:_timestamp];

  NSDictionary *expectedData = @{@"foo" : @{@"bar" : @"new-bar-value"}, @"baz" : @"baz-value"};
  XCTAssertEqualObjects(
      patchedDoc, FSTTestDoc("collection/key", 0, expectedData, DocumentState::kLocalMutations));
}

- (void)testPatchingDeletedDocumentsDoesNothing {
  FSTMaybeDocument *baseDoc = FSTTestDeletedDoc("collection/key", 0, NO);
  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo" : @"bar"}, {});
  FSTMaybeDocument *patchedDoc = [patch applyToLocalDocument:baseDoc
                                                baseDocument:baseDoc
                                              localWriteTime:_timestamp];
  XCTAssertEqualObjects(patchedDoc, baseDoc);
}

- (void)testAppliesLocalServerTimestampTransformToDocuments {
  NSDictionary *docData = @{@"foo" : @{@"bar" : @"bar-value"}, @"baz" : @"baz-value"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  FSTMutation *transform = FSTTestTransformMutation(
      @"collection/key", @{@"foo.bar" : [FIRFieldValue fieldValueForServerTimestamp]});
  FSTMaybeDocument *transformedDoc = [transform applyToLocalDocument:baseDoc
                                                        baseDocument:baseDoc
                                                      localWriteTime:_timestamp];

  // Server timestamps aren't parsed, so we manually insert it.
  ObjectValue expectedData =
      FSTTestObjectValue(@{@"foo" : @{@"bar" : @"<server-timestamp>"}, @"baz" : @"baz-value"});
  expectedData = expectedData.Set(Field("foo.bar"), FieldValue::FromServerTimestamp(_timestamp));

  FSTDocument *expectedDoc = [FSTDocument documentWithData:expectedData
                                                       key:FSTTestDocKey(@"collection/key")
                                                   version:Version(0)
                                                     state:DocumentState::kLocalMutations];

  XCTAssertEqualObjects(transformedDoc, expectedDoc);
}

- (void)testAppliesIncrementTransformToDocument {
  NSDictionary *baseDoc = @{
    @"longPlusLong" : @1,
    @"longPlusDouble" : @2,
    @"doublePlusLong" : @3.3,
    @"doublePlusDouble" : @4.0,
    @"longPlusNan" : @5,
    @"doublePlusNan" : @6.6,
    @"longPlusInfinity" : @7,
    @"doublePlusInfinity" : @8.8
  };
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
  NSDictionary *expected = @{
    @"longPlusLong" : @2L,
    @"longPlusDouble" : @4.2,
    @"doublePlusLong" : @6.3,
    @"doublePlusDouble" : @8.4,
    @"longPlusNan" : @(NAN),
    @"doublePlusNan" : @(NAN),
    @"longPlusInfinity" : @(INFINITY),
    @"doublePlusInfinity" : @(INFINITY)
  };
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesIncrementTransformToUnexpectedType {
  NSDictionary *baseDoc = @{@"string" : @"zero"};
  NSDictionary *transform = @{@"string" : [FIRFieldValue fieldValueForIntegerIncrement:1]};
  NSDictionary *expected = @{@"string" : @1};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesIncrementTransformToMissingField {
  NSDictionary *baseDoc = @{};
  NSDictionary *transform = @{@"missing" : [FIRFieldValue fieldValueForIntegerIncrement:1]};
  NSDictionary *expected = @{@"missing" : @1};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesIncrementTransformsConsecutively {
  NSDictionary *baseDoc = @{@"number" : @1};
  NSDictionary *transform1 = @{@"number" : [FIRFieldValue fieldValueForIntegerIncrement:2]};
  NSDictionary *transform2 = @{@"number" : [FIRFieldValue fieldValueForIntegerIncrement:3]};
  NSDictionary *transform3 = @{@"number" : [FIRFieldValue fieldValueForIntegerIncrement:4]};
  NSDictionary *expected = @{@"number" : @10};
  [self transformBaseDoc:baseDoc
         applyTransforms:@[ transform1, transform2, transform3 ]
               expecting:expected];
}

- (void)testAppliesIncrementWithoutOverflow {
  NSDictionary *baseDoc =
      @{@"a" : @(LONG_MAX - 1), @"b" : @(LONG_MAX - 1), @"c" : @(LONG_MAX), @"d" : @(LONG_MAX)};
  NSDictionary *transform = @{
    @"a" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"b" : [FIRFieldValue fieldValueForIntegerIncrement:LONG_MAX],
    @"c" : [FIRFieldValue fieldValueForIntegerIncrement:1],
    @"d" : [FIRFieldValue fieldValueForIntegerIncrement:LONG_MAX]
  };
  NSDictionary *expected =
      @{@"a" : @LONG_MAX, @"b" : @LONG_MAX, @"c" : @LONG_MAX, @"d" : @LONG_MAX};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesIncrementWithoutUnderflow {
  NSDictionary *baseDoc =
      @{@"a" : @(LONG_MIN + 1), @"b" : @(LONG_MIN + 1), @"c" : @(LONG_MIN), @"d" : @(LONG_MIN)};
  NSDictionary *transform = @{
    @"a" : [FIRFieldValue fieldValueForIntegerIncrement:-1],
    @"b" : [FIRFieldValue fieldValueForIntegerIncrement:LONG_MIN],
    @"c" : [FIRFieldValue fieldValueForIntegerIncrement:-1],
    @"d" : [FIRFieldValue fieldValueForIntegerIncrement:LONG_MIN]
  };
  NSDictionary *expected =
      @{@"a" : @(LONG_MIN), @"b" : @(LONG_MIN), @"c" : @(LONG_MIN), @"d" : @(LONG_MIN)};
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
  auto baseDoc = @{};
  auto transform = @{@"missing" : [FIRFieldValue fieldValueForArrayUnion:@[ @1, @2 ]]};
  auto expected = @{@"missing" : @[ @1, @2 ]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformToNonArrayField {
  auto baseDoc = @{@"non-array" : @42};
  auto transform = @{@"non-array" : [FIRFieldValue fieldValueForArrayUnion:@[ @1, @2 ]]};
  auto expected = @{@"non-array" : @[ @1, @2 ]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithNonExistingElements {
  auto baseDoc = @{@"array" : @[ @1, @3 ]};
  auto transform = @{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @2, @4 ]]};
  auto expected = @{@"array" : @[ @1, @3, @2, @4 ]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithExistingElements {
  auto baseDoc = @{@"array" : @[ @1, @3 ]};
  auto transform = @{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @1, @3 ]]};
  auto expected = @{@"array" : @[ @1, @3 ]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithDuplicateExistingElements {
  // Duplicate entries in your existing array should be preserved.
  auto baseDoc = @{@"array" : @[ @1, @2, @2, @3 ]};
  auto transform = @{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @2 ]]};
  auto expected = @{@"array" : @[ @1, @2, @2, @3 ]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithDuplicateUnionElements {
  // Duplicate entries in your union array should only be added once.
  auto baseDoc = @{@"array" : @[ @1, @3 ]};
  auto transform = @{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @2, @2 ]]};
  auto expected = @{@"array" : @[ @1, @3, @2 ]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithNonPrimitiveElements {
  // Union nested object values (one existing, one not).
  auto baseDoc = @{@"array" : @[ @1, @{@"a" : @"b"} ]};
  auto transform =
      @{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @{@"a" : @"b"}, @{@"c" : @"d"} ]]};
  auto expected = @{@"array" : @[ @1, @{@"a" : @"b"}, @{@"c" : @"d"} ]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithPartiallyOverlappingElements {
  // Union objects that partially overlap an existing object.
  auto baseDoc = @{@"array" : @[ @1, @{@"a" : @"b", @"c" : @"d"} ]};
  auto transform =
      @{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @{@"a" : @"b"}, @{@"c" : @"d"} ]]};
  auto expected =
      @{@"array" : @[ @1, @{@"a" : @"b", @"c" : @"d"}, @{@"a" : @"b"}, @{@"c" : @"d"} ]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformToMissingField {
  auto baseDoc = @{};
  auto transform = @{@"missing" : [FIRFieldValue fieldValueForArrayRemove:@[ @1, @2 ]]};
  auto expected = @{@"missing" : @[]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformToNonArrayField {
  auto baseDoc = @{@"non-array" : @42};
  auto transform = @{@"non-array" : [FIRFieldValue fieldValueForArrayRemove:@[ @1, @2 ]]};
  auto expected = @{@"non-array" : @[]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformWithNonExistingElements {
  auto baseDoc = @{@"array" : @[ @1, @3 ]};
  auto transform = @{@"array" : [FIRFieldValue fieldValueForArrayRemove:@[ @2, @4 ]]};
  auto expected = @{@"array" : @[ @1, @3 ]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformWithExistingElements {
  auto baseDoc = @{@"array" : @[ @1, @2, @3, @4 ]};
  auto transform = @{@"array" : [FIRFieldValue fieldValueForArrayRemove:@[ @1, @3 ]]};
  auto expected = @{@"array" : @[ @2, @4 ]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformWithNonPrimitiveElements {
  // Remove nested object values (one existing, one not).
  auto baseDoc = @{@"array" : @[ @1, @{@"a" : @"b"} ]};
  auto transform =
      @{@"array" : [FIRFieldValue fieldValueForArrayRemove:@[ @{@"a" : @"b"}, @{@"c" : @"d"} ]]};
  auto expected = @{@"array" : @[ @1 ]};
  [self transformBaseDoc:baseDoc applyTransform:transform expecting:expected];
}

// Helper to test a particular transform scenario.
- (void)transformBaseDoc:(NSDictionary<NSString *, id> *)baseData
         applyTransforms:(NSArray<NSDictionary<NSString *, id> *> *)transforms
               expecting:(NSDictionary<NSString *, id> *)expectedData {
  FSTMaybeDocument *currentDoc = FSTTestDoc("collection/key", 0, baseData, DocumentState::kSynced);

  for (NSDictionary<NSString *, id> *transformData in transforms) {
    FSTMutation *transform = FSTTestTransformMutation(@"collection/key", transformData);
    currentDoc = [transform applyToLocalDocument:currentDoc
                                    baseDocument:currentDoc
                                  localWriteTime:_timestamp];
  }

  FSTDocument *expectedDoc = [FSTDocument documentWithData:FSTTestObjectValue(expectedData)
                                                       key:FSTTestDocKey(@"collection/key")
                                                   version:Version(0)
                                                     state:DocumentState::kLocalMutations];

  XCTAssertEqualObjects(currentDoc, expectedDoc);
}

- (void)transformBaseDoc:(NSDictionary<NSString *, id> *)baseData
          applyTransform:(NSDictionary<NSString *, id> *)transformData
               expecting:(NSDictionary<NSString *, id> *)expectedData {
  [self transformBaseDoc:baseData applyTransforms:@[ transformData ] expecting:expectedData];
}

- (void)testAppliesServerAckedIncrementTransformToDocuments {
  NSDictionary *docData = @{@"sum" : @1};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  FSTMutation *transform = FSTTestTransformMutation(
      @"collection/key", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:2]});

  FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:Version(1) transformResults:FieldValueVector(3)];

  FSTMaybeDocument *transformedDoc = [transform applyToRemoteDocument:baseDoc
                                                       mutationResult:mutationResult];

  NSDictionary *expectedData = @{@"sum" : @3};
  XCTAssertEqualObjects(transformedDoc, FSTTestDoc("collection/key", 1, expectedData,
                                                   DocumentState::kCommittedMutations));
}

- (void)testAppliesServerAckedServerTimestampTransformToDocuments {
  NSDictionary *docData = @{@"foo" : @{@"bar" : @"bar-value"}, @"baz" : @"baz-value"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  FSTMutation *transform = FSTTestTransformMutation(
      @"collection/key", @{@"foo.bar" : [FIRFieldValue fieldValueForServerTimestamp]});

  FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:Version(1)
                                transformResults:FieldValueVector(_timestamp)];

  FIRTimestamp *publicTimestamp = api::MakeFIRTimestamp(_timestamp);
  FSTMaybeDocument *transformedDoc = [transform applyToRemoteDocument:baseDoc
                                                       mutationResult:mutationResult];

  NSDictionary *expectedData =
      @{@"foo" : @{@"bar" : publicTimestamp.dateValue}, @"baz" : @"baz-value"};
  FSTDocument *expectedDoc =
      FSTTestDoc("collection/key", 1, expectedData, DocumentState::kCommittedMutations);
  XCTAssertEqualObjects(transformedDoc, expectedDoc);
}

- (void)testAppliesServerAckedArrayTransformsToDocuments {
  NSDictionary *docData = @{@"array_1" : @[ @1, @2 ], @"array_2" : @[ @"a", @"b" ]};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  FSTMutation *transform = FSTTestTransformMutation(@"collection/key", @{
    @"array_1" : [FIRFieldValue fieldValueForArrayUnion:@[ @2, @3 ]],
    @"array_2" : [FIRFieldValue fieldValueForArrayRemove:@[ @"a", @"c" ]]
  });

  // Server just sends null transform results for array operations.
  FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:Version(1)
                                transformResults:FieldValueVector(nullptr, nullptr)];

  FSTMaybeDocument *transformedDoc = [transform applyToRemoteDocument:baseDoc
                                                       mutationResult:mutationResult];

  NSDictionary *expectedData = @{@"array_1" : @[ @1, @2, @3 ], @"array_2" : @[ @"b" ]};
  XCTAssertEqualObjects(transformedDoc, FSTTestDoc("collection/key", 1, expectedData,
                                                   DocumentState::kCommittedMutations));
}

- (void)testDeleteDeletes {
  NSDictionary *docData = @{@"foo" : @"bar"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  FSTMutation *mutation = FSTTestDeleteMutation(@"collection/key");
  FSTMaybeDocument *result = [mutation applyToLocalDocument:baseDoc
                                               baseDocument:baseDoc
                                             localWriteTime:_timestamp];
  XCTAssertEqualObjects(result, FSTTestDeletedDoc("collection/key", 0, NO));
}

- (void)testSetWithMutationResult {
  NSDictionary *docData = @{@"foo" : @"bar"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  FSTMutation *set = FSTTestSetMutation(@"collection/key", @{@"foo" : @"new-bar"});
  FSTMutationResult *mutationResult = [[FSTMutationResult alloc] initWithVersion:Version(4)
                                                                transformResults:absl::nullopt];
  FSTMaybeDocument *setDoc = [set applyToRemoteDocument:baseDoc mutationResult:mutationResult];

  NSDictionary *expectedData = @{@"foo" : @"new-bar"};
  XCTAssertEqualObjects(
      setDoc, FSTTestDoc("collection/key", 4, expectedData, DocumentState::kCommittedMutations));
}

- (void)testPatchWithMutationResult {
  NSDictionary *docData = @{@"foo" : @"bar"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo" : @"new-bar"}, {});
  FSTMutationResult *mutationResult = [[FSTMutationResult alloc] initWithVersion:Version(4)
                                                                transformResults:absl::nullopt];
  FSTMaybeDocument *patchedDoc = [patch applyToRemoteDocument:baseDoc
                                               mutationResult:mutationResult];

  NSDictionary *expectedData = @{@"foo" : @"new-bar"};
  XCTAssertEqualObjects(patchedDoc, FSTTestDoc("collection/key", 4, expectedData,
                                               DocumentState::kCommittedMutations));
}

- (void)testNonTransformMutationBaseValue {
  NSDictionary *docData = @{@"foo" : @"foo"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  FSTMutation *set = FSTTestSetMutation(@"collection/key", @{@"foo" : @"bar"});
  XCTAssertFalse([set extractBaseValue:baseDoc]);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo" : @"bar"}, {});
  XCTAssertFalse([patch extractBaseValue:baseDoc]);

  FSTMutation *deleter = FSTTestDeleteMutation(@"collection/key");
  XCTAssertFalse([deleter extractBaseValue:baseDoc]);
}

- (void)testServerTimestampBaseValue {
  NSDictionary *docData = @{@"time" : @"foo", @"nested" : @{@"time" : @"foo"}};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

  FSTMutation *transform = FSTTestTransformMutation(@"collection/key", @{
    @"time" : [FIRFieldValue fieldValueForServerTimestamp],
    @"nested.time" : [FIRFieldValue fieldValueForServerTimestamp]
  });

  // Server timestamps are idempotent and don't require base values.
  XCTAssertFalse([transform extractBaseValue:baseDoc]);
}

- (void)testNumericIncrementBaseValue {
  NSDictionary *docData = @{
    @"ignore" : @"foo",
    @"double" : @42.0,
    @"long" : @42,
    @"string" : @"foo",
    @"map" : @{},
    @"nested" :
        @{@"ignore" : @"foo", @"double" : @42.0, @"long" : @42, @"string" : @"foo", @"map" : @{}}
  };
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, DocumentState::kSynced);

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

  ObjectValue expectedBaseValue = FSTTestObjectValue(@{
    @"double" : @42.0,
    @"long" : @42,
    @"string" : @0,
    @"map" : @0,
    @"missing" : @0,
    @"nested" : @{@"double" : @42.0, @"long" : @42, @"string" : @0, @"map" : @0, @"missing" : @0}
  });

  // Server timestamps are idempotent and don't require base values.
  absl::optional<ObjectValue> actualBaseValue = [transform extractBaseValue:baseDoc];
  XCTAssertTrue([transform extractBaseValue:baseDoc]);
  XCTAssertEqual(expectedBaseValue, *actualBaseValue);
}

#define ASSERT_VERSION_TRANSITION(mutation, base, result, expected)                         \
  do {                                                                                      \
    FSTMaybeDocument *actual = [mutation applyToRemoteDocument:base mutationResult:result]; \
    XCTAssertEqualObjects(actual, expected);                                                \
  } while (0);

/**
 * Tests the transition table documented in FSTMutation.h.
 */
- (void)testTransitions {
  FSTDocument *docV3 = FSTTestDoc("collection/key", 3, @{}, DocumentState::kSynced);
  FSTDeletedDocument *deletedV3 = FSTTestDeletedDoc("collection/key", 3, NO);

  FSTMutation *setMutation = FSTTestSetMutation(@"collection/key", @{});
  FSTMutation *patchMutation = FSTTestPatchMutation("collection/key", @{}, {});
  FSTMutation *transformMutation = FSTTestTransformMutation(@"collection/key", @{});
  FSTMutation *deleteMutation = FSTTestDeleteMutation(@"collection/key");

  FSTDeletedDocument *docV7Deleted = FSTTestDeletedDoc("collection/key", 7, YES);
  FSTDocument *docV7Committed =
      FSTTestDoc("collection/key", 7, @{}, DocumentState::kCommittedMutations);
  FSTUnknownDocument *docV7Unknown = FSTTestUnknownDoc("collection/key", 7);

  FSTMutationResult *mutationResult = [[FSTMutationResult alloc] initWithVersion:Version(7)
                                                                transformResults:absl::nullopt];
  FSTMutationResult *transformResult =
      [[FSTMutationResult alloc] initWithVersion:Version(7) transformResults:FieldValueVector()];

  ASSERT_VERSION_TRANSITION(setMutation, docV3, mutationResult, docV7Committed);
  ASSERT_VERSION_TRANSITION(setMutation, deletedV3, mutationResult, docV7Committed);
  ASSERT_VERSION_TRANSITION(setMutation, nil, mutationResult, docV7Committed);

  ASSERT_VERSION_TRANSITION(patchMutation, docV3, mutationResult, docV7Committed);
  ASSERT_VERSION_TRANSITION(patchMutation, deletedV3, mutationResult, docV7Unknown);
  ASSERT_VERSION_TRANSITION(patchMutation, nil, mutationResult, docV7Unknown);

  ASSERT_VERSION_TRANSITION(transformMutation, docV3, transformResult, docV7Committed);
  ASSERT_VERSION_TRANSITION(transformMutation, deletedV3, transformResult, docV7Unknown);
  ASSERT_VERSION_TRANSITION(transformMutation, nil, transformResult, docV7Unknown);

  ASSERT_VERSION_TRANSITION(deleteMutation, docV3, mutationResult, docV7Deleted);
  ASSERT_VERSION_TRANSITION(deleteMutation, deletedV3, mutationResult, docV7Deleted);
  ASSERT_VERSION_TRANSITION(deleteMutation, nil, mutationResult, docV7Deleted);
}

#undef ASSERT_TRANSITION

@end
