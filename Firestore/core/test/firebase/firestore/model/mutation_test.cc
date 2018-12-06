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
  auto base_doc = std::make_shared<Document>(
      Doc("collection/key", 0,
          {{"foo", FieldValue::FromString("foo-value")},
           {"baz", FieldValue::FromString("baz-value")}}));

  std::unique_ptr<Mutation> set = SetMutation(
      "collection/key", {{"bar", FieldValue::FromString("bar-value")}});
  std::shared_ptr<const MaybeDocument> set_doc =
      set->ApplyToLocalView(base_doc, base_doc.get(), Timestamp::Now());
  ASSERT_TRUE(set_doc);
  ASSERT_EQ(set_doc->type(), MaybeDocument::Type::Document);
  EXPECT_EQ(*set_doc.get(), Doc("collection/key", 0,
                                {{"bar", FieldValue::FromString("bar-value")}},
                                DocumentState::kLocalMutations));
}

TEST(Mutation, AppliesPatchToDocuments) {
  auto base_doc = std::make_shared<Document>(Doc(
      "collection/key", 0,
      {{"foo",
        FieldValue::FromMap({{"bar", FieldValue::FromString("bar-value")}})},
       {"baz", FieldValue::FromString("baz-value")}}));

  std::unique_ptr<Mutation> patch = PatchMutation(
      "collection/key", {{"foo.bar", FieldValue::FromString("new-bar-value")}});
  std::shared_ptr<const MaybeDocument> local =
      patch->ApplyToLocalView(base_doc, base_doc.get(), Timestamp::Now());
  ASSERT_TRUE(local);
  EXPECT_EQ(
      *local.get(),
      Doc("collection/key", 0,
          {{"foo", FieldValue::FromMap(
                       {{"bar", FieldValue::FromString("new-bar-value")}})},
           {"baz", FieldValue::FromString("baz-value")}},
          DocumentState::kLocalMutations));
}

TEST(Mutation, AppliesPatchWithMergeToDocuments) {
  auto base_doc = std::make_shared<NoDocument>(DeletedDoc("collection/key", 0));

  std::unique_ptr<Mutation> upsert = PatchMutation(
      "collection/key", {{"foo.bar", FieldValue::FromString("new-bar-value")}},
      {Field("foo.bar")});
  std::shared_ptr<const MaybeDocument> new_doc =
      upsert->ApplyToLocalView(base_doc, base_doc.get(), Timestamp::Now());
  ASSERT_TRUE(new_doc);
  EXPECT_EQ(
      *new_doc.get(),
      Doc("collection/key", 0,
          {{"foo", FieldValue::FromMap(
                       {{"bar", FieldValue::FromString("new-bar-value")}})}},
          DocumentState::kLocalMutations));
}

TEST(Mutation, AppliesPatchToNullDocWithMergeToDocuments) {
  std::shared_ptr<NoDocument> base_doc = nullptr;

  std::unique_ptr<Mutation> upsert = PatchMutation(
      "collection/key", {{"foo.bar", FieldValue::FromString("new-bar-value")}},
      {Field("foo.bar")});
  std::shared_ptr<const MaybeDocument> new_doc =
      upsert->ApplyToLocalView(base_doc, base_doc.get(), Timestamp::Now());
  ASSERT_TRUE(new_doc);
  EXPECT_EQ(
      *new_doc.get(),
      Doc("collection/key", 0,
          {{"foo", FieldValue::FromMap(
                       {{"bar", FieldValue::FromString("new-bar-value")}})}},
          DocumentState::kLocalMutations));
}

TEST(Mutation, DeletesValuesFromTheFieldMask) {
  auto base_doc = std::make_shared<Document>(Doc(
      "collection/key", 0,
      {{"foo",
        FieldValue::FromMap({{"bar", FieldValue::FromString("bar-value")},
                             {"baz", FieldValue::FromString("baz-value")}})}}));

  std::unique_ptr<Mutation> patch =
      PatchMutation("collection/key", {}, {Field("foo.bar")});

  std::shared_ptr<const MaybeDocument> patch_doc =
      patch->ApplyToLocalView(base_doc, base_doc.get(), Timestamp::Now());
  ASSERT_TRUE(patch_doc);
  EXPECT_EQ(*patch_doc.get(),
            Doc("collection/key", 0,
                {{"foo", FieldValue::FromMap(
                             {{"baz", FieldValue::FromString("baz-value")}})}},
                DocumentState::kLocalMutations));
}

TEST(Mutation, PatchesPrimitiveValue) {
  auto base_doc = std::make_shared<Document>(
      Doc("collection/key", 0,
          {{"foo", FieldValue::FromString("foo-value")},
           {"baz", FieldValue::FromString("baz-value")}}));

  std::unique_ptr<Mutation> patch = PatchMutation(
      "collection/key", {{"foo.bar", FieldValue::FromString("new-bar-value")}});

  std::shared_ptr<const MaybeDocument> patched_doc =
      patch->ApplyToLocalView(base_doc, base_doc.get(), Timestamp::Now());
  ASSERT_TRUE(patched_doc);
  EXPECT_EQ(
      *patched_doc.get(),
      Doc("collection/key", 0,
          {{"foo", FieldValue::FromMap(
                       {{"bar", FieldValue::FromString("new-bar-value")}})},
           {"baz", FieldValue::FromString("baz-value")}},
          DocumentState::kLocalMutations));
}

TEST(Mutation, PatchingDeletedDocumentsDoesNothing) {
  // TODO(rsgowman)
}

TEST(Mutation, AppliesLocalServerTimestampTransformsToDocuments) {
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
  // TODO(rsgowman)
}

TEST(Mutation, SetWithMutationResult) {
  auto base_doc = std::make_shared<Document>(
      Doc("collection/key", 0, {{"foo", FieldValue::FromString("bar")}}));

  std::unique_ptr<Mutation> set = SetMutation(
      "collection/key", {{"foo", FieldValue::FromString("new-bar")}});
  std::shared_ptr<const MaybeDocument> set_doc =
      set->ApplyToRemoteDocument(base_doc, MutationResult(4));

  ASSERT_TRUE(set_doc);
  EXPECT_EQ(*set_doc.get(), Doc("collection/key", 4,
                                {{"foo", FieldValue::FromString("new-bar")}},
                                DocumentState::kCommittedMutations));
}

TEST(Mutation, PatchWithMutationResult) {
  // TODO(rsgowman)
}

TEST(Mutation, Transitions) {
  // TODO(rsgowman)
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
