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

#include "Firestore/core/src/model/mutation.h"

#include <utility>

#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/field_value.h"
#include "Firestore/core/src/model/maybe_document.h"
#include "Firestore/core/src/model/no_document.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/src/model/transform_operation.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {
namespace {

using testutil::Array;
using testutil::DeletedDoc;
using testutil::DeleteMutation;
using testutil::Doc;
using testutil::Field;
using testutil::Map;
using testutil::MergeMutation;
using testutil::MutationResult;
using testutil::PatchMutation;
using testutil::SetMutation;
using testutil::Value;
using testutil::Version;
using testutil::WrapObject;

const Timestamp now = Timestamp::Now();

TEST(MutationTest, AppliesSetsToDocuments) {
  Document base_doc =
      Doc("collection/key", 0, Map("foo", "foo-value", "baz", "baz-value"));

  Mutation set = SetMutation("collection/key", Map("bar", "bar-value"));
  auto result = set.ApplyToLocalView(base_doc, now);

  EXPECT_EQ(result, Doc("collection/key", 0, Map("bar", "bar-value"),
                        DocumentState::kLocalMutations));
}

TEST(MutationTest, AppliesPatchToDocuments) {
  Document base_doc =
      Doc("collection/key", 0,
          Map("foo", Map("bar", "bar-value"), "baz", "baz-value"));

  Mutation patch =
      PatchMutation("collection/key", Map("foo.bar", "new-bar-value"));
  auto result = patch.ApplyToLocalView(base_doc, now);

  EXPECT_EQ(result,
            Doc("collection/key", 0,
                Map("foo", Map("bar", "new-bar-value"), "baz", "baz-value"),
                DocumentState::kLocalMutations));
}

TEST(MutationTest, AppliesPatchWithMergeToNoDocuments) {
  NoDocument base_doc = DeletedDoc("collection/key", 0);

  Mutation upsert = MergeMutation(
      "collection/key", Map("foo.bar", "new-bar-value"), {Field("foo.bar")});
  auto result = upsert.ApplyToLocalView(base_doc, now);

  EXPECT_EQ(result,
            Doc("collection/key", 0, Map("foo", Map("bar", "new-bar-value")),
                DocumentState::kLocalMutations));
}

TEST(MutationTest, AppliesPatchWithMergeToNullDocuments) {
  absl::optional<MaybeDocument> base_doc;

  Mutation upsert = MergeMutation(
      "collection/key", Map("foo.bar", "new-bar-value"), {Field("foo.bar")});
  auto result = upsert.ApplyToLocalView(base_doc, now);

  EXPECT_EQ(result,
            Doc("collection/key", 0, Map("foo", Map("bar", "new-bar-value")),
                DocumentState::kLocalMutations));
}

TEST(MutationTest, DeletesValuesFromTheFieldMask) {
  Document base_doc =
      Doc("collection/key", 0,
          Map("foo", Map("bar", "bar-value", "baz", "baz-value")));

  Mutation patch = MergeMutation("collection/key", Map(), {Field("foo.bar")});
  auto result = patch.ApplyToLocalView(base_doc, now);

  EXPECT_EQ(result,
            Doc("collection/key", 0, Map("foo", Map("baz", "baz-value")),
                DocumentState::kLocalMutations));
}

TEST(MutationTest, PatchesPrimitiveValue) {
  Document base_doc =
      Doc("collection/key", 0, Map("foo", "foo-value", "baz", "baz-value"));

  Mutation patch =
      PatchMutation("collection/key", Map("foo.bar", "new-bar-value"));
  auto result = patch.ApplyToLocalView(base_doc, now);

  EXPECT_EQ(result,
            Doc("collection/key", 0,
                Map("foo", Map("bar", "new-bar-value"), "baz", "baz-value"),
                DocumentState::kLocalMutations));
}

TEST(MutationTest, PatchingDeletedDocumentsDoesNothing) {
  NoDocument base_doc = testutil::DeletedDoc("collection/key", 0);

  Mutation patch = PatchMutation("collection/key", Map("foo", "bar"));
  auto result = patch.ApplyToLocalView(base_doc, now);

  EXPECT_EQ(result, base_doc);
}

TEST(MutationTest, AppliesLocalServerTimestampTransformToDocuments) {
  Document base_doc =
      Doc("collection/key", 0,
          Map("foo", Map("bar", "bar-value"), "baz", "baz-value"));

  Mutation transform = PatchMutation("collection/key", Map(),
                                     {{"foo.bar", ServerTimestampTransform()}});
  auto result = transform.ApplyToLocalView(base_doc, now);

  // Server timestamps aren't parsed, so we manually insert it.
  ObjectValue expected_data =
      WrapObject("foo", Map("bar", "<server-timestamp>"), "baz", "baz-value");
  expected_data =
      expected_data.Set(Field("foo.bar"), FieldValue::FromServerTimestamp(now));

  Document expected_doc =
      Doc("collection/key", 0, expected_data, DocumentState::kLocalMutations);

  EXPECT_EQ(result, expected_doc);
}

namespace {

/**
 * A list of pairs, where each pair is the field path to transform and the
 * TransformOperation to apply.
 */
using TransformPairs = std::vector<std::pair<std::string, TransformOperation>>;

/**
 * Builds a document around the given `base_data`, then applies each transform
 * pair to the document as a separate `PatchMutation`. The result of each
 * transformation is used as the input to the next. The result of applying all
 * transformations is then compared to the given `expected_data`.
 */
void TransformBaseDoc(const FieldValue::Map& base_data,
                      const TransformPairs& transforms,
                      const FieldValue::Map& expected_data) {
  Document current_doc = Doc("collection/key", 0, base_data);

  for (const auto& transform : transforms) {
    Mutation mutation = PatchMutation("collection/key", Map(), {transform});
    auto result = mutation.ApplyToLocalView(current_doc, now);
    ASSERT_NE(result, absl::nullopt);
    ASSERT_EQ(result->type(), MaybeDocument::Type::Document);
    current_doc = Document(*result);
  }

  Document expected_doc =
      Doc("collection/key", 0, expected_data, DocumentState::kLocalMutations);

  EXPECT_EQ(current_doc, expected_doc);
}

/**
 * Creates a NumericIncrementTransform for the given value. Only defined for
 * types for which `Value(T)` is already defined, though any types that don't
 * result in Type::Integer or Type::Double will result in a run-time failure.
 *
 * (This is defined in this way to reuse all the overload disambiguation that's
 * already built into `Value`.)
 */
template <typename T>
auto Increment(T value) -> decltype(NumericIncrementTransform(Value(value))) {
  return NumericIncrementTransform(Value(value));
}

template <typename... Args>
TransformOperation ArrayUnion(Args... args) {
  std::vector<FieldValue> values = {Value(args)...};
  return ArrayTransform(TransformOperation::Type::ArrayUnion,
                        std::move(values));
}

template <typename... Args>
TransformOperation ArrayRemove(Args... args) {
  std::vector<FieldValue> values = {Value(args)...};
  return ArrayTransform(TransformOperation::Type::ArrayRemove,
                        std::move(values));
}

/**
 * Converts the input arguments to a vector of FieldValues wrapping the input
 * types.
 */
template <typename... Args>
static std::vector<FieldValue> FieldValueVector(Args... values) {
  return Array(values...).array_value();
}

}  // namespace

TEST(MutationTest, AppliesIncrementTransformToDocument) {
  auto base_data =
      Map("long_plus_long", 1, "long_plus_double", 2, "double_plus_long", 3.3,
          "double_plus_double", 4.0, "long_plus_nan", 5, "double_plus_nan", 6.6,
          "long_plus_infinity", 7, "double_plus_infinity", 8.8);
  TransformPairs transforms = {
      {"long_plus_long", Increment(1)},
      {"long_plus_double", Increment(2.2)},
      {"double_plus_long", Increment(3)},
      {"double_plus_double", Increment(4.4)},
      {"long_plus_nan", Increment(NAN)},
      {"double_plus_nan", Increment(NAN)},
      {"long_plus_infinity", Increment(INFINITY)},
      {"double_plus_infinity", Increment(INFINITY)},
  };
  auto expected = Map(
      "long_plus_long", 2L, "long_plus_double", 4.2, "double_plus_long", 6.3,
      "double_plus_double", 8.4, "long_plus_nan", NAN, "double_plus_nan", NAN,
      "long_plus_infinity", INFINITY, "double_plus_infinity", INFINITY);
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesIncrementTransformToUnexpectedType) {
  auto base_data = Map("string", "zero");
  TransformPairs transforms = {
      {"string", Increment(1)},
  };
  auto expected = Map("string", 1);
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesIncrementTransformToMissingField) {
  auto base_data = Map();
  TransformPairs transforms = {
      {"missing", Increment(1)},
  };
  auto expected = Map("missing", 1);
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesIncrementTransformsConsecutively) {
  auto base_data = Map("number", 1);
  TransformPairs transforms = {
      {"number", Increment(2)},
      {"number", Increment(3)},
      {"number", Increment(4)},
  };
  auto expected = Map("number", 10);
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesIncrementWithoutOverflow) {
  auto base_data =
      Map("a", LONG_MAX - 1, "b", LONG_MAX - 1, "c", LONG_MAX, "d", LONG_MAX);
  TransformPairs transforms = {
      {"a", Increment(1)},
      {"b", Increment(LONG_MAX)},
      {"c", Increment(1)},
      {"d", Increment(LONG_MAX)},
  };
  auto expected =
      Map("a", LONG_MAX, "b", LONG_MAX, "c", LONG_MAX, "d", LONG_MAX);
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesIncrementWithoutUnderflow) {
  auto base_data =
      Map("a", LONG_MIN + 1, "b", LONG_MIN + 1, "c", LONG_MIN, "d", LONG_MIN);
  TransformPairs transforms = {
      {"a", Increment(-1)},
      {"b", Increment(LONG_MIN)},
      {"c", Increment(-1)},
      {"d", Increment(LONG_MIN)},
  };
  auto expected =
      Map("a", LONG_MIN, "b", LONG_MIN, "c", LONG_MIN, "d", LONG_MIN);
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesLocalArrayUnionTransformToMissingField) {
  auto base_data = Map();
  TransformPairs transforms = {{"missing", ArrayUnion(1, 2)}};
  auto expected = Map("missing", Array(1, 2));
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesLocalArrayUnionTransformToNonArrayField) {
  auto base_data = Map("non-array", 42);
  TransformPairs transforms = {{"non-array", ArrayUnion(1, 2)}};
  auto expected = Map("non-array", Array(1, 2));
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithNonExistingElements) {
  auto base_data = Map("array", Array(1, 3));
  TransformPairs transforms = {{"array", ArrayUnion(2, 4)}};
  auto expected = Map("array", Array(1, 3, 2, 4));
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithExistingElements) {
  auto base_data = Map("array", Array(1, 3));
  TransformPairs transforms = {{"array", ArrayUnion(1, 3)}};
  auto expected = Map("array", Array(1, 3));
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest,
     AppliesLocalArrayUnionTransformWithDuplicateExistingElements) {
  // Duplicate entries in your existing array should be preserved.
  auto base_data = Map("array", Array(1, 2, 2, 3));
  TransformPairs transforms = {{"array", ArrayUnion(2)}};
  auto expected = Map("array", Array(1, 2, 2, 3));
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithDuplicateUnionElements) {
  // Duplicate entries in your union array should only be added once.
  auto base_data = Map("array", Array(1, 3));
  TransformPairs transforms = {{"array", ArrayUnion(2, 2)}};
  auto expected = Map("array", Array(1, 3, 2));
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithNonPrimitiveElements) {
  // Union nested object values (one existing, one not).
  auto base_data = Map("array", Array(1, Map("a", "b")));
  TransformPairs transforms = {
      {"array", ArrayUnion(WrapObject("a", "b"), WrapObject("c", "d"))}};
  auto expected = Map("array", Array(1, Map("a", "b"), Map("c", "d")));
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest,
     AppliesLocalArrayUnionTransformWithPartiallyOverlappingElements) {
  // Union objects that partially overlap an existing object.
  auto base_data = Map("array", Array(1, Map("a", "b", "c", "d")));
  TransformPairs transforms = {
      {"array", ArrayUnion(WrapObject("a", "b"), WrapObject("c", "d"))}};
  auto expected = Map(
      "array", Array(1, Map("a", "b", "c", "d"), Map("a", "b"), Map("c", "d")));
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformToMissingField) {
  auto base_data = Map();
  TransformPairs transforms = {{"missing", ArrayRemove(1, 2)}};
  auto expected = Map("missing", Array());
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformToNonArrayField) {
  auto base_data = Map("non-array", 42);
  TransformPairs transforms = {{"non-array", ArrayRemove(1, 2)}};
  auto expected = Map("non-array", Array());
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformWithNonExistingElements) {
  auto base_data = Map("array", Array(1, 3));
  TransformPairs transforms = {{"array", ArrayRemove(2, 4)}};
  auto expected = Map("array", Array(1, 3));
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformWithExistingElements) {
  auto base_data = Map("array", Array(1, 2, 3, 4));
  TransformPairs transforms = {{"array", ArrayRemove(1, 3)}};
  auto expected = Map("array", Array(2, 4));
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformWithNonPrimitiveElements) {
  // Remove nested object values (one existing, one not).
  auto base_data = Map("array", Array(1, Map("a", "b")));
  TransformPairs transforms = {
      {"array", ArrayRemove(WrapObject("a", "b"), WrapObject("c", "d"))}};
  auto expected = Map("array", Array(1));
  TransformBaseDoc(base_data, transforms, expected);
}

TEST(MutationTest, AppliesServerAckedIncrementTransformToDocuments) {
  Document base_doc = Doc("collection/key", 0, Map("sum", 1));

  Mutation transform =
      SetMutation("collection/key", Map(), {{"sum", Increment(2)}});

  model::MutationResult mutation_result(Version(1), FieldValueVector(3));

  MaybeDocument result =
      transform.ApplyToRemoteDocument(base_doc, mutation_result);

  EXPECT_EQ(result, Doc("collection/key", 1, Map("sum", 3),
                        DocumentState::kCommittedMutations));
}

TEST(MutationTest, AppliesServerAckedServerTimestampTransformToDocuments) {
  Document base_doc =
      Doc("collection/key", 0,
          Map("foo", Map("bar", "bar-value"), "baz", "baz-value"));

  Mutation transform = PatchMutation("collection/key", Map(),
                                     {{"foo.bar", ServerTimestampTransform()}});

  model::MutationResult mutation_result(Version(1), FieldValueVector(now));

  MaybeDocument result =
      transform.ApplyToRemoteDocument(base_doc, mutation_result);

  Document expected_doc =
      Doc("collection/key", 1, Map("foo", Map("bar", now), "baz", "baz-value"),
          DocumentState::kCommittedMutations);

  EXPECT_EQ(result, expected_doc);
}

TEST(MutationTest, AppliesServerAckedArrayTransformsToDocuments) {
  Document base_doc =
      Doc("collection/key", 0,
          Map("array_1", Array(1, 2), "array_2", Array("a", "b")));

  Mutation transform = PatchMutation("collection/key", Map(),
                                     {
                                         {"array_1", ArrayUnion(2, 3)},
                                         {"array_2", ArrayRemove("a", "c")},
                                     });

  // Server just sends null transform results for array operations.
  model::MutationResult mutation_result(Version(1),
                                        FieldValueVector(nullptr, nullptr));

  MaybeDocument result =
      transform.ApplyToRemoteDocument(base_doc, mutation_result);

  EXPECT_EQ(result, Doc("collection/key", 1,
                        Map("array_1", Array(1, 2, 3), "array_2", Array("b")),
                        DocumentState::kCommittedMutations));
}

TEST(MutationTest, DeleteDeletes) {
  Document base_doc = Doc("collection/key", 0, Map("foo", "bar"));

  Mutation del = DeleteMutation("collection/key");
  auto result = del.ApplyToLocalView(base_doc, now);

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
