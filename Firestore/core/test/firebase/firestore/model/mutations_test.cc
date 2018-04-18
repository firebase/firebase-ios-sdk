/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/model/mutations.h"

#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/types/optional.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(MutationResult, DeletedResult) {
  const MutationResult result;
  EXPECT_EQ(absl::nullopt, result.version());
  EXPECT_EQ(absl::nullopt, result.transform_results());
}

TEST(MutationResult, PatchResult) {
  const MutationResult result{testutil::Version(12345)};
  EXPECT_EQ(testutil::Version(12345), result.version());
  EXPECT_EQ(absl::nullopt, result.transform_results());
}

TEST(MutationResult, TransformResult) {
  const MutationResult result{testutil::Version(12345),
                              std::vector<FieldValue>{FieldValue::TrueValue()}};
  EXPECT_EQ(testutil::Version(12345), result.version());
  EXPECT_EQ(std::vector<FieldValue>{FieldValue::TrueValue()},
            result.transform_results());
}

// The following test cases, Mutation_*, are ported from iOS unit tests.
TEST(Mutation, AppliesSetsToDocument) {
  const MaybeDocumentPointer base_doc =
      testutil::DocPointer("collection/key", 0,
                           {{"foo", FieldValue::StringValue("foo-value")},
                            {"baz", FieldValue::StringValue("baz-value")}});
  const SetMutation set = testutil::TestSetMutation(
      "collection/key", {{"bar", FieldValue::StringValue("bar-value")}});
  const MaybeDocumentPointer set_doc =
      set.Mutation::ApplyTo(base_doc, base_doc, testutil::TestTimestamp());
  EXPECT_TRUE(set_doc);
  EXPECT_EQ(testutil::Doc("collection/key", 0,
                          {{"bar", FieldValue::StringValue("bar-value")}}),
            *set_doc);
}

TEST(Mutation, AppliesPatchesToDocuments) {
  const MaybeDocumentPointer base_doc = testutil::DocPointer(
      "collection/key", 0,
      {{"foo", FieldValue::ObjectValueFromMap(
                   {{"bar", FieldValue::StringValue("bar-value")}})},
       {"baz", FieldValue::StringValue("baz-value")}});
  const PatchMutation patch = testutil::TestPatchMutation(
      "collection/key", {{"foo.bar", FieldValue::StringValue("new-bar-value")}},
      {});
  const MaybeDocumentPointer patched_doc =
      patch.Mutation::ApplyTo(base_doc, base_doc, testutil::TestTimestamp());
  EXPECT_TRUE(patched_doc);
  EXPECT_EQ(
      testutil::Doc(
          "collection/key", 0,
          {{"foo", FieldValue::ObjectValueFromMap(
                       {{"bar", FieldValue::StringValue("new-bar-value")}})},
           {"baz", FieldValue::StringValue("baz-value")}}),
      *patched_doc);
}

/*
- (void)testDeletesValuesFromTheFieldMask {
  NSDictionary *docData = @{ @"foo" : @{@"bar" : @"bar-value", @"baz" :
@"baz-value"} }; FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData,
NO);

  DocumentKey key = testutil::Key("collection/key");
  FSTFieldMask *mask = [[FSTFieldMask alloc]
initWithFields:{testutil::Field("foo.bar")}]; FSTMutation *patch =
[[FSTPatchMutation alloc] initWithKey:key fieldMask:mask value:[FSTObjectValue
objectValue] precondition:[FSTPrecondition none]]; FSTMaybeDocument *patchedDoc
= [patch applyTo:baseDoc baseDocument:baseDoc localWriteTime:_timestamp];

  NSDictionary *expectedData = @{ @"foo" : @{@"baz" : @"baz-value"} };
  XCTAssertEqualObjects(patchedDoc, FSTTestDoc("collection/key", 0,
expectedData, YES));
}

- (void)testPatchesPrimitiveValue {
  NSDictionary *docData = @{@"foo" : @"foo-value", @"baz" : @"baz-value"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, NO);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo.bar" :
@"new-bar-value"}, {}); FSTMaybeDocument *patchedDoc = [patch applyTo:baseDoc
baseDocument:baseDoc localWriteTime:_timestamp];

  NSDictionary *expectedData = @{ @"foo" : @{@"bar" : @"new-bar-value"}, @"baz"
: @"baz-value" }; XCTAssertEqualObjects(patchedDoc, FSTTestDoc("collection/key",
0, expectedData, YES));
}

- (void)testPatchingDeletedDocumentsDoesNothing {
  FSTMaybeDocument *baseDoc = FSTTestDeletedDoc("collection/key", 0);
  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo" :
@"bar"}, {}); FSTMaybeDocument *patchedDoc = [patch applyTo:baseDoc
baseDocument:baseDoc localWriteTime:_timestamp];
  XCTAssertEqualObjects(patchedDoc, baseDoc);
}

- (void)testAppliesLocalTransformsToDocuments {
  NSDictionary *docData = @{ @"foo" : @{@"bar" : @"bar-value"}, @"baz" :
@"baz-value" }; FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData,
NO);

  FSTMutation *transform = FSTTestTransformMutation(@"collection/key", @[
@"foo.bar" ]); FSTMaybeDocument *transformedDoc = [transform applyTo:baseDoc
baseDocument:baseDoc localWriteTime:_timestamp];

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

- (void)testAppliesServerAckedTransformsToDocuments {
  NSDictionary *docData = @{ @"foo" : @{@"bar" : @"bar-value"}, @"baz" :
@"baz-value" }; FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData,
NO);

  FSTMutation *transform = FSTTestTransformMutation(@"collection/key", @[
@"foo.bar" ]);

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
  XCTAssertEqualObjects(transformedDoc, FSTTestDoc("collection/key", 0,
expectedData, NO));
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

  FSTMutation *set = FSTTestSetMutation(@"collection/key", @{@"foo" :
@"new-bar"}); FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:FSTTestVersion(4)
transformResults:nil]; FSTMaybeDocument *setDoc = [set applyTo:baseDoc
                             baseDocument:baseDoc
                           localWriteTime:_timestamp
                           mutationResult:mutationResult];

  NSDictionary *expectedData = @{@"foo" : @"new-bar"};
  XCTAssertEqualObjects(setDoc, FSTTestDoc("collection/key", 0, expectedData,
NO));
}

- (void)testPatchWithMutationResult {
  NSDictionary *docData = @{@"foo" : @"bar"};
  FSTDocument *baseDoc = FSTTestDoc("collection/key", 0, docData, NO);

  FSTMutation *patch = FSTTestPatchMutation("collection/key", @{@"foo" :
@"new-bar"}, {}); FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:FSTTestVersion(4)
transformResults:nil]; FSTMaybeDocument *patchedDoc = [patch applyTo:baseDoc
                                   baseDocument:baseDoc
                                 localWriteTime:_timestamp
                                 mutationResult:mutationResult];

  NSDictionary *expectedData = @{@"foo" : @"new-bar"};
  XCTAssertEqualObjects(patchedDoc, FSTTestDoc("collection/key", 0,
expectedData, NO));
}

#define ASSERT_VERSION_TRANSITION(mutation, base, expected) \
  do { \
    FSTMutationResult *mutationResult = \
        [[FSTMutationResult alloc] initWithVersion:FSTTestVersion(0)
transformResults:nil]; \
    FSTMaybeDocument *actual = [mutation applyTo:base \
                                    baseDocument:base \
                                  localWriteTime:_timestamp \
                                  mutationResult:mutationResult]; \
    XCTAssertEqualObjects(actual, expected); \ } while (0);

 * Tests the transition table documented in FSTMutation.h.
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
*/
}  // namespace model
}  // namespace firestore
}  // namespace firebase
