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

#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTFieldValue.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::model::ArrayTransform;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::TransformOperation;

@interface FSTMutationTests : XCTestCase
@end

@implementation FSTMutationTests {
  FIRTimestamp *_timestamp;
}

- (void)setUp {
  _timestamp = [FIRTimestamp timestamp];
}

- (void)testAppliesSetsToDocuments {
  NSDictionary *docData = @{@"foo" : @"foo-value", @"baz" : @"baz-value"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, NO);

  FSTMutation *set = FSTTestSetMutation(@"collection/key", @{@"bar" : @"bar-value"});
  FSTMaybeDocument *setDoc = [set applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  NSDictionary *expectedData = @{@"bar" : @"bar-value"};
  XCTAssertEqualObjects(setDoc, FSTTestDoc("collection/key", 0, expectedData, YES));
}

- (void)testAppliesPatchesToDocuments {
  NSDictionary *docData = @{ @"foo" : @{@"bar" : @"bar-value"}, @"baz" : @"baz-value" };
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, NO);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo.bar" : @"new-bar-value"}, {});
  FSTMaybeDocument *patchedDoc =
      [patch applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  NSDictionary *expectedData = @{ @"foo" : @{@"bar" : @"new-bar-value"}, @"baz" : @"baz-value" };
  XCTAssertEqualObjects(patchedDoc, FSTTestDoc("collection/key", 0, expectedData, YES));
}

- (void)testDeletesValuesFromTheFieldMask {
  NSDictionary *docData = @{ @"foo" : @{@"bar" : @"bar-value", @"baz" : @"baz-value"} };
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, NO);

  DocumentKey key = testutil::Key("collection/key");
  FSTMutation *patch = [[FSTPatchMutation alloc] initWithKey:key
                                                   fieldMask:{testutil::Field("foo.bar")}
                                                       value:[FSTObjectValue objectValue]
                                                precondition:Precondition::None()];
  FSTMaybeDocument *patchedDoc =
      [patch applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  NSDictionary *expectedData = @{ @"foo" : @{@"baz" : @"baz-value"} };
  XCTAssertEqualObjects(patchedDoc, FSTTestDoc("collection/key", 0, expectedData, YES));
}

- (void)testPatchesPrimitiveValue {
  NSDictionary *docData = @{@"foo" : @"foo-value", @"baz" : @"baz-value"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, NO);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo.bar" : @"new-bar-value"}, {});
  FSTMaybeDocument *patchedDoc =
      [patch applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  NSDictionary *expectedData = @{ @"foo" : @{@"bar" : @"new-bar-value"}, @"baz" : @"baz-value" };
  XCTAssertEqualObjects(patchedDoc, FSTTestDoc("collection/key", 0, expectedData, YES));
}

- (void)testPatchingDeletedDocumentsDoesNothing {
  FSTMaybeDocument *baseDoc = FSTTestDeletedDoc("collection/key", 0);
  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo" : @"bar"}, {});
  FSTMaybeDocument *patchedDoc =
      [patch applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];
  XCTAssertEqualObjects(patchedDoc, baseDoc);
}

- (void)testAppliesLocalServerTimestampTransformToDocuments {
  NSDictionary *docData = @{ @"foo" : @{@"bar" : @"bar-value"}, @"baz" : @"baz-value" };
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, NO);

  FSTMutation *transform = FSTTestTransformMutation(
      @"collection/key", @{@"foo.bar" : [FIRFieldValue fieldValueForServerTimestamp]});
  FSTMaybeDocument *transformedDoc =
      [transform applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  // Server timestamps aren't parsed, so we manually insert it.
  FSTObjectValue *expectedData = FSTTestObjectValue(
      @{ @"foo" : @{@"bar" : @"<server-timestamp>"},
         @"baz" : @"baz-value" });
  expectedData =
      [expectedData objectBySettingValue:[FSTServerTimestampValue
                                             serverTimestampValueWithLocalWriteTime:_timestamp
                                                                      previousValue:nil]
                                 forPath:testutil::Field("foo.bar")];

  FSTDocument *expectedDoc = [FSTDocument documentWithData:expectedData
                                                       key:FSTTestDocKey(@"collection/key")
                                                   version:FSTTestVersion(0)
                                         hasLocalMutations:YES];

  XCTAssertEqualObjects(transformedDoc, expectedDoc);
}

// NOTE: This is more a test of FSTUserDataConverter code than FSTMutation code but we don't have
// unit tests for it currently. We could consider removing this test once we have integration tests.
- (void)testCreateArrayUnionTransform {
  FSTTransformMutation *transform = FSTTestTransformMutation(@"collection/key", @{
    @"foo" : [FIRFieldValue fieldValueForArrayUnion:@[ @"tag" ]],
    @"bar.baz" : [FIRFieldValue fieldValueForArrayUnion:@[ @YES, @[ @1, @2 ], @{@"a" : @"b"} ]]
  });
  XCTAssertEqual(transform.fieldTransforms.size(), 2);

  const FieldTransform &first = transform.fieldTransforms[0];
  XCTAssertEqual(first.path(), FieldPath({"foo"}));
  {
    std::vector<FSTFieldValue *> expectedElements{FSTTestFieldValue(@"tag")};
    ArrayTransform expected(TransformOperation::Type::ArrayUnion, expectedElements);
    XCTAssertEqual(static_cast<const ArrayTransform &>(first.transformation()), expected);
  }

  const FieldTransform &second = transform.fieldTransforms[1];
  XCTAssertEqual(second.path(), FieldPath({"bar", "baz"}));
  {
    std::vector<FSTFieldValue *> expectedElements {
      FSTTestFieldValue(@YES), FSTTestFieldValue(@[ @1, @2 ]), FSTTestFieldValue(@{@"a" : @"b"})
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
    std::vector<FSTFieldValue *> expectedElements{FSTTestFieldValue(@"tag")};
    const ArrayTransform expected(TransformOperation::Type::ArrayRemove, expectedElements);
    XCTAssertEqual(static_cast<const ArrayTransform &>(first.transformation()), expected);
  }
}

- (void)testAppliesLocalArrayUnionTransformToMissingField {
  auto baseDoc = @{};
  auto transform = @{ @"missing" : [FIRFieldValue fieldValueForArrayUnion:@[ @1, @2 ]] };
  auto expected = @{ @"missing" : @[ @1, @2 ] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformToNonArrayField {
  auto baseDoc = @{ @"non-array" : @42 };
  auto transform = @{ @"non-array" : [FIRFieldValue fieldValueForArrayUnion:@[ @1, @2 ]] };
  auto expected = @{ @"non-array" : @[ @1, @2 ] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithNonExistingElements {
  auto baseDoc = @{ @"array" : @[ @1, @3 ] };
  auto transform = @{ @"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @2, @4 ]] };
  auto expected = @{ @"array" : @[ @1, @3, @2, @4 ] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithExistingElements {
  auto baseDoc = @{ @"array" : @[ @1, @3 ] };
  auto transform = @{ @"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @1, @3 ]] };
  auto expected = @{ @"array" : @[ @1, @3 ] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithDuplicateExistingElements {
  // Duplicate entries in your existing array should be preserved.
  auto baseDoc = @{ @"array" : @[ @1, @2, @2, @3 ] };
  auto transform = @{ @"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @2 ]] };
  auto expected = @{ @"array" : @[ @1, @2, @2, @3 ] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithDuplicateUnionElements {
  // Duplicate entries in your union array should only be added once.
  auto baseDoc = @{ @"array" : @[ @1, @3 ] };
  auto transform = @{ @"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @2, @2 ]] };
  auto expected = @{ @"array" : @[ @1, @3, @2 ] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithNonPrimitiveElements {
  // Union nested object values (one existing, one not).
  auto baseDoc = @{ @"array" : @[ @1, @{@"a" : @"b"} ] };
  auto transform =
      @{ @"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @{@"a" : @"b"}, @{@"c" : @"d"} ]] };
  auto expected = @{ @"array" : @[ @1, @{@"a" : @"b"}, @{@"c" : @"d"} ] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

- (void)testAppliesLocalArrayUnionTransformWithPartiallyOverlappingElements {
  // Union objects that partially overlap an existing object.
  auto baseDoc = @{ @"array" : @[ @1, @{@"a" : @"b", @"c" : @"d"} ] };
  auto transform =
      @{ @"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @{@"a" : @"b"}, @{@"c" : @"d"} ]] };
  auto expected =
      @{ @"array" : @[ @1, @{@"a" : @"b", @"c" : @"d"}, @{@"a" : @"b"}, @{@"c" : @"d"} ] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformToMissingField {
  auto baseDoc = @{};
  auto transform = @{ @"missing" : [FIRFieldValue fieldValueForArrayRemove:@[ @1, @2 ]] };
  auto expected = @{ @"missing" : @[] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformToNonArrayField {
  auto baseDoc = @{ @"non-array" : @42 };
  auto transform = @{ @"non-array" : [FIRFieldValue fieldValueForArrayRemove:@[ @1, @2 ]] };
  auto expected = @{ @"non-array" : @[] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformWithNonExistingElements {
  auto baseDoc = @{ @"array" : @[ @1, @3 ] };
  auto transform = @{ @"array" : [FIRFieldValue fieldValueForArrayRemove:@[ @2, @4 ]] };
  auto expected = @{ @"array" : @[ @1, @3 ] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformWithExistingElements {
  auto baseDoc = @{ @"array" : @[ @1, @2, @3, @4 ] };
  auto transform = @{ @"array" : [FIRFieldValue fieldValueForArrayRemove:@[ @1, @3 ]] };
  auto expected = @{ @"array" : @[ @2, @4 ] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

- (void)testAppliesLocalArrayRemoveTransformWithNonPrimitiveElements {
  // Remove nested object values (one existing, one not).
  auto baseDoc = @{ @"array" : @[ @1, @{@"a" : @"b"} ] };
  auto transform =
      @{ @"array" : [FIRFieldValue fieldValueForArrayRemove:@[ @{@"a" : @"b"}, @{@"c" : @"d"} ]] };
  auto expected = @{ @"array" : @[ @1 ] };
  [self transformBaseDoc:baseDoc with:transform expecting:expected];
}

// Helper to test a particular transform scenario.
- (void)transformBaseDoc:(NSDictionary<NSString *, id> *)baseData
                    with:(NSDictionary<NSString *, id> *)transformData
               expecting:(NSDictionary<NSString *, id> *)expectedData {
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, baseData, NO);

  FSTMutation *transform = FSTTestTransformMutation(@"collection/key", transformData);

  FSTMaybeDocument *transformedDoc =
      [transform applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  FSTDocument *expectedDoc = [FSTDocument documentWithData:FSTTestObjectValue(expectedData)
                                                       key:FSTTestDocKey(@"collection/key")
                                                   version:FSTTestVersion(0)
                                         hasLocalMutations:YES];

  XCTAssertEqualObjects(transformedDoc, expectedDoc);
}

- (void)testAppliesServerAckedServerTimestampTransformToDocuments {
  NSDictionary *docData = @{ @"foo" : @{@"bar" : @"bar-value"}, @"baz" : @"baz-value" };
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, NO);

  FSTMutation *transform = FSTTestTransformMutation(
      @"collection/key", @{@"foo.bar" : [FIRFieldValue fieldValueForServerTimestamp]});

  FSTMutationResult *mutationResult = [[FSTMutationResult alloc]
       initWithVersion:FSTTestVersion(1)
      transformResults:@[ [FSTTimestampValue timestampValue:_timestamp] ]];

  FSTMaybeDocument *transformedDoc = [transform applyTo:baseDoc
                                           baseDocument:baseDoc
                                         localWriteTime:_timestamp
                                         mutationResult:mutationResult];

  NSDictionary *expectedData =
      @{ @"foo" : @{@"bar" : _timestamp.dateValue},
         @"baz" : @"baz-value" };
  XCTAssertEqualObjects(transformedDoc, FSTTestDoc("collection/key", 0, expectedData, NO));
}

- (void)testAppliesServerAckedArrayTransformsToDocuments {
  NSDictionary *docData = @{ @"array_1" : @[ @1, @2 ], @"array_2" : @[ @"a", @"b" ] };
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, NO);

  FSTMutation *transform = FSTTestTransformMutation(@"collection/key", @{
    @"array_1" : [FIRFieldValue fieldValueForArrayUnion:@[ @2, @3 ]],
    @"array_2" : [FIRFieldValue fieldValueForArrayRemove:@[ @"a", @"c" ]]
  });

  // Server just sends null transform results for array operations.
  FSTMutationResult *mutationResult = [[FSTMutationResult alloc]
       initWithVersion:FSTTestVersion(1)
      transformResults:@[ [FSTNullValue nullValue], [FSTNullValue nullValue] ]];

  FSTMaybeDocument *transformedDoc = [transform applyTo:baseDoc
                                           baseDocument:baseDoc
                                         localWriteTime:_timestamp
                                         mutationResult:mutationResult];

  NSDictionary *expectedData = @{ @"array_1" : @[ @1, @2, @3 ], @"array_2" : @[ @"b" ] };
  XCTAssertEqualObjects(transformedDoc, FSTTestDoc("collection/key", 0, expectedData, NO));
}

- (void)testDeleteDeletes {
  NSDictionary *docData = @{@"foo" : @"bar"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, NO);

  FSTMutation *mutation = FSTTestDeleteMutation(@"collection/key");
  FSTMaybeDocument *result =
      [mutation applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];
  XCTAssertEqualObjects(result, FSTTestDeletedDoc("collection/key", 0));
}

- (void)testSetWithMutationResult {
  NSDictionary *docData = @{@"foo" : @"bar"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, NO);

  FSTMutation *set = FSTTestSetMutation(@"collection/key", @{@"foo" : @"new-bar"});
  FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:FSTTestVersion(4) transformResults:nil];
  FSTMaybeDocument *setDoc = [set applyTo:baseDoc
                             baseDocument:baseDoc
                           localWriteTime:_timestamp
                           mutationResult:mutationResult];

  NSDictionary *expectedData = @{@"foo" : @"new-bar"};
  XCTAssertEqualObjects(setDoc, FSTTestDoc("collection/key", 0, expectedData, NO));
}

- (void)testPatchWithMutationResult {
  NSDictionary *docData = @{@"foo" : @"bar"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, NO);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo" : @"new-bar"}, {});
  FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:FSTTestVersion(4) transformResults:nil];
  FSTMaybeDocument *patchedDoc = [patch applyTo:baseDoc
                                   baseDocument:baseDoc
                                 localWriteTime:_timestamp
                                 mutationResult:mutationResult];

  NSDictionary *expectedData = @{@"foo" : @"new-bar"};
  XCTAssertEqualObjects(patchedDoc, FSTTestDoc("collection/key", 0, expectedData, NO));
}

#define ASSERT_VERSION_TRANSITION(mutation, base, expected)                                 \
  do {                                                                                      \
    FSTMutationResult *mutationResult =                                                     \
        [[FSTMutationResult alloc] initWithVersion:FSTTestVersion(0) transformResults:nil]; \
    FSTMaybeDocument *actual = [mutation applyTo:base                                       \
                                    baseDocument:base                                       \
                                  localWriteTime:_timestamp                                 \
                                  mutationResult:mutationResult];                           \
    XCTAssertEqualObjects(actual, expected);                                                \
  } while (0);

/**
 * Tests the transition table documented in FSTMutation.h.
 */
- (void)testTransitions {
  FSTDocument *docV0 = FSTTestDoc("collection/key", 0, @{}, NO);
  FSTDeletedDocument *deletedV0 = FSTTestDeletedDoc("collection/key", 0);

  FSTDocument *docV3 = FSTTestDoc("collection/key", 3, @{}, NO);
  FSTDeletedDocument *deletedV3 = FSTTestDeletedDoc("collection/key", 3);

  FSTMutation *setMutation = FSTTestSetMutation(@"collection/key", @{});
  FSTMutation *patchMutation = FSTTestPatchMutation("collection/key", {}, {});
  FSTMutation *deleteMutation = FSTTestDeleteMutation(@"collection/key");

  ASSERT_VERSION_TRANSITION(setMutation, docV3, docV3);
  ASSERT_VERSION_TRANSITION(setMutation, deletedV3, docV0);
  ASSERT_VERSION_TRANSITION(setMutation, nil, docV0);

  ASSERT_VERSION_TRANSITION(patchMutation, docV3, docV3);
  ASSERT_VERSION_TRANSITION(patchMutation, deletedV3, deletedV3);
  ASSERT_VERSION_TRANSITION(patchMutation, nil, nil);

  ASSERT_VERSION_TRANSITION(deleteMutation, docV3, deletedV0);
  ASSERT_VERSION_TRANSITION(deleteMutation, deletedV3, deletedV0);
  ASSERT_VERSION_TRANSITION(deleteMutation, nil, deletedV0);
}

#undef ASSERT_TRANSITION

@end
