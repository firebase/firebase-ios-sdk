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
  EXPECT_EQ(
      testutil::Doc("collection/key", 0,
                    {{"bar", FieldValue::StringValue("bar-value")}}, true),
      *set_doc);
}

TEST(Mutation, AppliesPatchesToDocuments) {
  const MaybeDocumentPointer base_doc = testutil::DocPointer(
      "collection/key", 0,
      {{"foo", FieldValue::ObjectValueFromMap(
                   {{"bar", FieldValue::StringValue("bar-value")}})},
       {"baz", FieldValue::StringValue("baz-value")}});
  const PatchMutation patch = testutil::TestPatchMutation(
      "collection/key",
      {{"foo.bar", FieldValue::StringValue("new-bar-value")}});
  const MaybeDocumentPointer patched_doc =
      patch.Mutation::ApplyTo(base_doc, base_doc, testutil::TestTimestamp());
  EXPECT_TRUE(patched_doc);
  EXPECT_EQ(
      testutil::Doc(
          "collection/key", 0,
          {{"foo", FieldValue::ObjectValueFromMap(
                       {{"bar", FieldValue::StringValue("new-bar-value")}})},
           {"baz", FieldValue::StringValue("baz-value")}},
          true),
      *patched_doc);
}

TEST(Mutation, DeletesValuesFromTheFieldMask) {
  const MaybeDocumentPointer base_doc = testutil::DocPointer(
      "collection/key", 0,
      {{"foo", FieldValue::ObjectValueFromMap(
                   {{"bar", FieldValue::StringValue("bar-value")},
                    {"baz", FieldValue::StringValue("baz-value")}})}});
  const PatchMutation patch = testutil::TestPatchMutation(
      "collection/key", {{"foo.bar", FieldValue::StringValue("<DELETE>")}});
  const MaybeDocumentPointer patched_doc =
      patch.Mutation::ApplyTo(base_doc, base_doc, testutil::TestTimestamp());
  EXPECT_TRUE(patched_doc);
  EXPECT_EQ(testutil::Doc(
                "collection/key", 0,
                {{"foo", FieldValue::ObjectValueFromMap(
                             {{"baz", FieldValue::StringValue("baz-value")}})}},
                true),
            *patched_doc);
}

TEST(Mutation, PatchesPrimitiveValue) {
  const MaybeDocumentPointer base_doc =
      testutil::DocPointer("collection/key", 0,
                           {{"foo", FieldValue::StringValue("foo-value")},
                            {"baz", FieldValue::StringValue("baz-value")}});
  const PatchMutation patch = testutil::TestPatchMutation(
      "collection/key",
      {{"foo.bar", FieldValue::StringValue("new-bar-value")}});
  const MaybeDocumentPointer patched_doc =
      patch.Mutation::ApplyTo(base_doc, base_doc, testutil::TestTimestamp());
  EXPECT_TRUE(patched_doc);
  EXPECT_EQ(
      testutil::Doc(
          "collection/key", 0,
          {{"foo", FieldValue::ObjectValueFromMap(
                       {{"bar", FieldValue::StringValue("new-bar-value")}})},
           {"baz", FieldValue::StringValue("baz-value")}},
          true),
      *patched_doc);
}

TEST(Mutation, PatchingDeletedDocumentsDoesNothing) {
  const MaybeDocumentPointer base_doc =
      testutil::DeletedDocPointer("collection/key", 0);
  const PatchMutation patch = testutil::TestPatchMutation(
      "collection/key", {{"foo", FieldValue::StringValue("bar")}});
  const MaybeDocumentPointer patched_doc =
      patch.Mutation::ApplyTo(base_doc, base_doc, testutil::TestTimestamp());
  EXPECT_TRUE(patched_doc);
  EXPECT_EQ(*base_doc, *patched_doc);
}

TEST(Mutation, AppliesLocalTransformsToDocuments) {
  const MaybeDocumentPointer base_doc = testutil::DocPointer(
      "collection/key", 0,
      {{"foo", FieldValue::ObjectValueFromMap(
                   {{"bar", FieldValue::StringValue("bar-value")}})},
       {"baz", FieldValue::StringValue("baz-value")}});
  const TransformMutation transform =
      testutil::ServerTimestampMutation("collection/key", {"foo.bar"});
  const MaybeDocumentPointer transformed_doc = transform.Mutation::ApplyTo(
      base_doc, base_doc, testutil::TestTimestamp());
  EXPECT_TRUE(transformed_doc);
  EXPECT_EQ(
      testutil::Doc("collection/key", 0,
                    {{"foo", FieldValue::ObjectValueFromMap(
                                 {{"bar", FieldValue::ServerTimestampValue(
                                              testutil::TestTimestamp())}})},
                     {"baz", FieldValue::StringValue("baz-value")}},
                    true),
      *transformed_doc);
}

TEST(Mutation, AppliesServerAckedTransformsToDocuments) {
  const MaybeDocumentPointer base_doc = testutil::DocPointer(
      "collection/key", 0,
      {{"foo", FieldValue::ObjectValueFromMap(
                   {{"bar", FieldValue::StringValue("bar-value")}})},
       {"baz", FieldValue::StringValue("baz-value")}});
  const TransformMutation transform =
      testutil::ServerTimestampMutation("collection/key", {"foo.bar"});
  const MutationResult mutation_result{
      testutil::Version(1), std::vector<FieldValue>{FieldValue::TimestampValue(
                                testutil::TestTimestamp())}};
  const MaybeDocumentPointer transformed_doc = transform.ApplyTo(
      base_doc, base_doc, testutil::TestTimestamp(), mutation_result);
  EXPECT_TRUE(transformed_doc);
  EXPECT_EQ(
      testutil::Doc("collection/key", 0,
                    {{"foo", FieldValue::ObjectValueFromMap(
                                 {{"bar", FieldValue::TimestampValue(
                                              testutil::TestTimestamp())}})},
                     {"baz", FieldValue::StringValue("baz-value")}}),
      *transformed_doc);
}

TEST(Mutation, DeleteDeletes) {  // This name is consistent with the Firestore
                                 // test in other platforms.
  const MaybeDocumentPointer base_doc = testutil::DocPointer(
      "collection/key", 0, {{"foo", FieldValue::StringValue("bar")}});
  const DeleteMutation mutation =
      testutil::TestDeleteMutation("collection/key");
  const MaybeDocumentPointer deleted_doc =
      mutation.Mutation::ApplyTo(base_doc, base_doc, testutil::TestTimestamp());
  EXPECT_TRUE(deleted_doc);
  EXPECT_EQ(testutil::DeletedDoc("collection/key", 0), *deleted_doc);
}

TEST(Mutation, SetWithMutationResult) {
  const MaybeDocumentPointer base_doc = testutil::DocPointer(
      "collection/key", 0, {{"foo", FieldValue::StringValue("bar")}});
  const SetMutation set = testutil::TestSetMutation(
      "collection/key", {{"foo", FieldValue::StringValue("new-bar")}});
  const MutationResult mutation_result{testutil::Version(4)};
  const MaybeDocumentPointer set_doc = set.ApplyTo(
      base_doc, base_doc, testutil::TestTimestamp(), mutation_result);
  EXPECT_TRUE(set_doc);
  EXPECT_EQ(testutil::Doc("collection/key", 0,
                          {{"foo", FieldValue::StringValue("new-bar")}}),
            *set_doc);
}

TEST(Mutation, PatchWithMutationResult) {
  const MaybeDocumentPointer base_doc = testutil::DocPointer(
      "collection/key", 0, {{"foo", FieldValue::StringValue("bar")}});
  const PatchMutation patch = testutil::TestPatchMutation(
      "collection/key", {{"foo", FieldValue::StringValue("new-bar")}});
  const MutationResult mutation_result{testutil::Version(4)};
  const MaybeDocumentPointer patched_doc = patch.ApplyTo(
      base_doc, base_doc, testutil::TestTimestamp(), mutation_result);
  EXPECT_TRUE(patched_doc);
  EXPECT_EQ(testutil::Doc("collection/key", 0,
                          {{"foo", FieldValue::StringValue("new-bar")}}),
            *patched_doc);
}

void AssertVersionTransition(const Mutation& mutation,
                             MaybeDocumentPointer base,
                             MaybeDocumentPointer expected) {
  const MutationResult mutation_result{testutil::Version(0)};
  const MaybeDocumentPointer mutated_doc =
      mutation.ApplyTo(base, base, testutil::TestTimestamp(), mutation_result);
  if (expected) {
    EXPECT_TRUE(mutated_doc);
    EXPECT_EQ(*expected, *mutated_doc);
  } else {
    EXPECT_FALSE(mutated_doc);
  }
}

// Tests the transition table documented in mutations.h.
TEST(Mutation, Transitions) {
  const MaybeDocumentPointer doc_v0 =
      testutil::DocPointer("collection/key", 0, {});
  const MaybeDocumentPointer deleted_v0 =
      testutil::DeletedDocPointer("collection/key", 0);

  const MaybeDocumentPointer doc_v3 =
      testutil::DocPointer("collection/key", 3, {});
  const MaybeDocumentPointer deleted_v3 =
      testutil::DeletedDocPointer("collection/key", 3);

  SetMutation set_mutation = testutil::TestSetMutation("collection/key", {});
  PatchMutation patch_mutation =
      testutil::TestPatchMutation("collection/key", {}, {});
  DeleteMutation delete_mutation =
      testutil::TestDeleteMutation("collection/key");

  AssertVersionTransition(set_mutation, doc_v3, doc_v3);
  AssertVersionTransition(set_mutation, deleted_v3, doc_v0);
  AssertVersionTransition(set_mutation, nullptr, doc_v0);

  AssertVersionTransition(patch_mutation, doc_v3, doc_v3);
  AssertVersionTransition(patch_mutation, deleted_v3, deleted_v3);
  AssertVersionTransition(patch_mutation, nullptr, nullptr);

  AssertVersionTransition(delete_mutation, doc_v3, deleted_v0);
  AssertVersionTransition(delete_mutation, deleted_v3, deleted_v0);
  AssertVersionTransition(delete_mutation, nullptr, deleted_v0);
}
}  // namespace model
}  // namespace firestore
}  // namespace firebase
