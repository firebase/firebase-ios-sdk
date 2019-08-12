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
namespace {

using testutil::DeletedDoc;
using testutil::DeleteMutation;
using testutil::Doc;
using testutil::Field;
using testutil::Map;
using testutil::MutationResult;
using testutil::PatchMutation;
using testutil::SetMutation;

const Timestamp now = Timestamp::Now();

TEST(MutationTest, AppliesSetsToDocuments) {
  Document base_doc =
      Doc("collection/key", 0, Map("foo", "foo-value", "baz", "baz-value"));

  Mutation set = SetMutation("collection/key", Map("bar", "bar-value"));
  auto result = set.ApplyToLocalView(base_doc, base_doc, now);

  ASSERT_NE(result, absl::nullopt);
  ASSERT_EQ(result->type(), MaybeDocument::Type::Document);
  EXPECT_EQ(result, Doc("collection/key", 0, Map("bar", "bar-value"),
                        DocumentState::kLocalMutations));
}

TEST(MutationTest, AppliesPatchToDocuments) {
  Document base_doc =
      Doc("collection/key", 0,
          Map("foo", Map("bar", "bar-value"), "baz", "baz-value"));

  Mutation patch =
      PatchMutation("collection/key", Map("foo.bar", "new-bar-value"));
  auto result = patch.ApplyToLocalView(base_doc, base_doc, now);

  EXPECT_EQ(result,
            Doc("collection/key", 0,
                Map("foo", Map("bar", "new-bar-value"), "baz", "baz-value"),
                DocumentState::kLocalMutations));
}

TEST(MutationTest, AppliesPatchWithMergeToDocuments) {
  NoDocument base_doc = DeletedDoc("collection/key", 0);

  Mutation upsert = PatchMutation(
      "collection/key", Map("foo.bar", "new-bar-value"), {Field("foo.bar")});
  auto result = upsert.ApplyToLocalView(base_doc, base_doc, now);

  EXPECT_EQ(result,
            Doc("collection/key", 0, Map("foo", Map("bar", "new-bar-value")),
                DocumentState::kLocalMutations));
}

TEST(MutationTest, AppliesPatchToNullDocWithMergeToDocuments) {
  absl::optional<MaybeDocument> base_doc;

  Mutation upsert = PatchMutation(
      "collection/key", Map("foo.bar", "new-bar-value"), {Field("foo.bar")});
  auto result = upsert.ApplyToLocalView(base_doc, base_doc, now);

  EXPECT_EQ(result,
            Doc("collection/key", 0, Map("foo", Map("bar", "new-bar-value")),
                DocumentState::kLocalMutations));
}

TEST(MutationTest, DeletesValuesFromTheFieldMask) {
  Document base_doc =
      Doc("collection/key", 0,
          Map("foo", Map("bar", "bar-value", "baz", "baz-value")));

  Mutation patch = PatchMutation("collection/key", Map(), {Field("foo.bar")});
  auto result = patch.ApplyToLocalView(base_doc, base_doc, now);

  EXPECT_EQ(result,
            Doc("collection/key", 0, Map("foo", Map("baz", "baz-value")),
                DocumentState::kLocalMutations));
}

TEST(MutationTest, PatchesPrimitiveValue) {
  Document base_doc =
      Doc("collection/key", 0, Map("foo", "foo-value", "baz", "baz-value"));

  Mutation patch =
      PatchMutation("collection/key", Map("foo.bar", "new-bar-value"));
  auto result = patch.ApplyToLocalView(base_doc, base_doc, now);

  EXPECT_EQ(result,
            Doc("collection/key", 0,
                Map("foo", Map("bar", "new-bar-value"), "baz", "baz-value"),
                DocumentState::kLocalMutations));
}

TEST(MutationTest, PatchingDeletedDocumentsDoesNothing) {
  NoDocument base_doc = testutil::DeletedDoc("collection/key", 0);

  Mutation patch = PatchMutation("collection/key", Map("foo", "bar"));
  auto result = patch.ApplyToLocalView(base_doc, base_doc, now);

  EXPECT_EQ(result, base_doc);
}

TEST(MutationTest, AppliesLocalServerTimestampTransformsToDocuments) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesIncrementTransformToDocument) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesIncrementTransformToUnexpectedType) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesIncrementTransformToMissingField) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesIncrementTransformsConsecutively) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesIncrementWithoutOverflow) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesIncrementWithoutUnderflow) {
  // TODO(rsgowman)
}

TEST(MutationTest, CreatesArrayUnionTransform) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesLocalArrayUnionTransformToMissingField) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesLocalArrayUnionTransformToNonArrayField) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithNonExistingElements) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithExistingElements) {
  // TODO(rsgowman)
}

TEST(MutationTest,
     AppliesLocalArrayUnionTransformWithDuplicateExistingElements) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithDuplicateUnionElements) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithNonPrimitiveElements) {
  // TODO(rsgowman)
}

TEST(MutationTest,
     AppliesLocalArrayUnionTransformWithPartiallyOverlappingElements) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformToMissingField) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformToNonArrayField) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformWithNonExistingElements) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformWithExistingElements) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformWithNonPrimitiveElements) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesServerAckedServerTimestampTransformsToDocuments) {
  // TODO(rsgowman)
}

TEST(MutationTest, AppliesServerAckedArrayTransformsToDocuments) {
  // TODO(rsgowman)
}

TEST(MutationTest, DeleteDeletes) {
  Document base_doc = Doc("collection/key", 0, Map("foo", "bar"));

  Mutation del = DeleteMutation("collection/key");
  auto result = del.ApplyToLocalView(base_doc, base_doc, now);

  EXPECT_EQ(result, DeletedDoc("collection/key", 0));
}

TEST(MutationTest, SetWithMutationResult) {
  Document base_doc = Doc("collection/key", 0, Map("foo", "bar"));

  Mutation set = SetMutation("collection/key", Map("foo", "new-bar"));
  MaybeDocument result = set.ApplyToRemoteDocument(base_doc, MutationResult(4));

  EXPECT_EQ(result, Doc("collection/key", 4, Map("foo", "new-bar"),
                        DocumentState::kCommittedMutations));
}

TEST(MutationTest, PatchWithMutationResult) {
  Document base_doc = Doc("collection/key", 0, Map("foo", "bar"));

  Mutation patch = PatchMutation("collection/key", Map("foo", "new-bar"));
  MaybeDocument result =
      patch.ApplyToRemoteDocument(base_doc, MutationResult(4));

  EXPECT_EQ(result, Doc("collection/key", 4, Map("foo", "new-bar"),
                        DocumentState::kCommittedMutations));
}

TEST(MutationTest, Transitions) {
  // TODO(rsgowman)
}

}  // namespace
}  // namespace model
}  // namespace firestore
}  // namespace firebase
