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

#include "Firestore/core/src/firebase/firestore/model/mutation.h"

#include <utility>

#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Field;
using testutil::MutationResult;
using testutil::PatchMutation;
using testutil::SetMutation;

TEST(Mutation, AppliesSetsToDocuments) {
  Document base_doc = Doc("collection/key", 0,
                          {{"foo", FieldValue::FromString("foo-value")},
                           {"baz", FieldValue::FromString("baz-value")}});

  std::unique_ptr<Mutation> set = SetMutation(
      "collection/key", {{"bar", FieldValue::FromString("bar-value")}});
  absl::optional<MaybeDocument> set_doc =
      set->ApplyToLocalView(base_doc, base_doc, Timestamp::Now());
  ASSERT_NE(set_doc, absl::nullopt);
  ASSERT_EQ(set_doc->type(), MaybeDocument::Type::Document);
  EXPECT_EQ(*set_doc, Doc("collection/key", 0,
                          {{"bar", FieldValue::FromString("bar-value")}},
                          DocumentState::kLocalMutations));
}

TEST(Mutation, AppliesPatchToDocuments) {
  Document base_doc = Doc(
      "collection/key", 0,
      {{"foo",
        FieldValue::FromMap({{"bar", FieldValue::FromString("bar-value")}})},
       {"baz", FieldValue::FromString("baz-value")}});

  std::unique_ptr<Mutation> patch = PatchMutation(
      "collection/key", {{"foo.bar", FieldValue::FromString("new-bar-value")}});
  absl::optional<MaybeDocument> local =
      patch->ApplyToLocalView(base_doc, base_doc, Timestamp::Now());
  ASSERT_NE(local, absl::nullopt);
  EXPECT_EQ(
      *local,
      Doc("collection/key", 0,
          {{"foo", FieldValue::FromMap(
                       {{"bar", FieldValue::FromString("new-bar-value")}})},
           {"baz", FieldValue::FromString("baz-value")}},
          DocumentState::kLocalMutations));
}

TEST(Mutation, AppliesPatchWithMergeToDocuments) {
  NoDocument base_doc = DeletedDoc("collection/key", 0);

  std::unique_ptr<Mutation> upsert = PatchMutation(
      "collection/key", {{"foo.bar", FieldValue::FromString("new-bar-value")}},
      {Field("foo.bar")});
  absl::optional<MaybeDocument> new_doc =
      upsert->ApplyToLocalView(base_doc, base_doc, Timestamp::Now());
  ASSERT_NE(new_doc, absl::nullopt);
  EXPECT_EQ(
      *new_doc,
      Doc("collection/key", 0,
          {{"foo", FieldValue::FromMap(
                       {{"bar", FieldValue::FromString("new-bar-value")}})}},
          DocumentState::kLocalMutations));
}

TEST(Mutation, AppliesPatchToNullDocWithMergeToDocuments) {
  absl::optional<MaybeDocument> base_doc;

  std::unique_ptr<Mutation> upsert = PatchMutation(
      "collection/key", {{"foo.bar", FieldValue::FromString("new-bar-value")}},
      {Field("foo.bar")});
  absl::optional<MaybeDocument> new_doc =
      upsert->ApplyToLocalView(base_doc, base_doc, Timestamp::Now());
  ASSERT_NE(new_doc, absl::nullopt);
  EXPECT_EQ(
      *new_doc,
      Doc("collection/key", 0,
          {{"foo", FieldValue::FromMap(
                       {{"bar", FieldValue::FromString("new-bar-value")}})}},
          DocumentState::kLocalMutations));
}

TEST(Mutation, DeletesValuesFromTheFieldMask) {
  Document base_doc = Doc(
      "collection/key", 0,
      {{"foo",
        FieldValue::FromMap({{"bar", FieldValue::FromString("bar-value")},
                             {"baz", FieldValue::FromString("baz-value")}})}});

  std::unique_ptr<Mutation> patch =
      PatchMutation("collection/key", FieldValue::Map(), {Field("foo.bar")});

  absl::optional<MaybeDocument> patch_doc =
      patch->ApplyToLocalView(base_doc, base_doc, Timestamp::Now());
  ASSERT_NE(patch_doc, absl::nullopt);
  EXPECT_EQ(*patch_doc,
            Doc("collection/key", 0,
                {{"foo", FieldValue::FromMap(
                             {{"baz", FieldValue::FromString("baz-value")}})}},
                DocumentState::kLocalMutations));
}

TEST(Mutation, PatchesPrimitiveValue) {
  Document base_doc = Doc("collection/key", 0,
                          {{"foo", FieldValue::FromString("foo-value")},
                           {"baz", FieldValue::FromString("baz-value")}});

  std::unique_ptr<Mutation> patch = PatchMutation(
      "collection/key", {{"foo.bar", FieldValue::FromString("new-bar-value")}});

  absl::optional<MaybeDocument> patched_doc =
      patch->ApplyToLocalView(base_doc, base_doc, Timestamp::Now());
  ASSERT_NE(patched_doc, absl::nullopt);
  EXPECT_EQ(
      *patched_doc,
      Doc("collection/key", 0,
          {{"foo", FieldValue::FromMap(
                       {{"bar", FieldValue::FromString("new-bar-value")}})},
           {"baz", FieldValue::FromString("baz-value")}},
          DocumentState::kLocalMutations));
}

TEST(Mutation, PatchingDeletedDocumentsDoesNothing) {
  NoDocument base_doc = testutil::DeletedDoc("collection/key", 0);
  std::unique_ptr<Mutation> patch =
      PatchMutation("collection/key", {{"foo", FieldValue::FromString("bar")}});
  absl::optional<MaybeDocument> patched_doc =
      patch->ApplyToLocalView(base_doc, base_doc, Timestamp::Now());
  EXPECT_EQ(base_doc, patched_doc);
}

TEST(Mutation, AppliesLocalServerTimestampTransformsToDocuments) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesIncrementTransformToDocument) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesIncrementTransformToUnexpectedType) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesIncrementTransformToMissingField) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesIncrementTransformsConsecutively) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesIncrementWithoutOverflow) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesIncrementWithoutUnderflow) {
  // TODO(rsgowman)
}

TEST(Mutation, CreatesArrayUnionTransform) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalArrayUnionTransformToMissingField) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalArrayUnionTransformToNonArrayField) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalArrayUnionTransformWithNonExistingElements) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalArrayUnionTransformWithExistingElements) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalArrayUnionTransformWithDuplicateExistingElements) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalArrayUnionTransformWithDuplicateUnionElements) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalArrayUnionTransformWithNonPrimitiveElements) {
  // TODO(rsgowman)
}

TEST(Mutation,
     AppliesLocalArrayUnionTransformWithPartiallyOverlappingElements) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalArrayRemoveTransformToMissingField) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalArrayRemoveTransformToNonArrayField) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalArrayRemoveTransformWithNonExistingElements) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalArrayRemoveTransformWithExistingElements) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalArrayRemoveTransformWithNonPrimitiveElements) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesServerAckedServerTimestampTransformsToDocuments) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesServerAckedArrayTransformsToDocuments) {
  // TODO(rsgowman)
}

TEST(Mutation, DeleteDeletes) {
  Document base_doc =
      Doc("collection/key", 0, {{"foo", FieldValue::FromString("bar")}});

  std::unique_ptr<Mutation> del = testutil::DeleteMutation("collection/key");
  absl::optional<MaybeDocument> deleted_doc =
      del->ApplyToLocalView(base_doc, base_doc, Timestamp::Now());

  ASSERT_NE(deleted_doc, absl::nullopt);
  EXPECT_EQ(*deleted_doc, testutil::DeletedDoc("collection/key", 0));
}

TEST(Mutation, SetWithMutationResult) {
  Document base_doc =
      Doc("collection/key", 0, {{"foo", FieldValue::FromString("bar")}});

  std::unique_ptr<Mutation> set = SetMutation(
      "collection/key", {{"foo", FieldValue::FromString("new-bar")}});
  MaybeDocument set_doc =
      set->ApplyToRemoteDocument(base_doc, MutationResult(4));

  EXPECT_EQ(set_doc, Doc("collection/key", 4,
                         {{"foo", FieldValue::FromString("new-bar")}},
                         DocumentState::kCommittedMutations));
}

TEST(Mutation, PatchWithMutationResult) {
  Document base_doc =
      Doc("collection/key", 0, {{"foo", FieldValue::FromString("bar")}});

  std::unique_ptr<Mutation> patch = PatchMutation(
      "collection/key", {{"foo", FieldValue::FromString("new-bar")}});
  MaybeDocument patch_doc =
      patch->ApplyToRemoteDocument(base_doc, MutationResult(4));

  EXPECT_EQ(patch_doc, Doc("collection/key", 4,
                           {{"foo", FieldValue::FromString("new-bar")}},
                           DocumentState::kCommittedMutations));
}

TEST(Mutation, Transitions) {
  // TODO(rsgowman)
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
