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
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/server_timestamp_util.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/src/model/transform_operation.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {
namespace {

using nanopb::Message;
using testutil::Array;
using testutil::DeletedDoc;
using testutil::DeleteMutation;
using testutil::Doc;
using testutil::Field;
using testutil::Key;
using testutil::Map;
using testutil::MergeMutation;
using testutil::MutationResult;
using testutil::PatchMutation;
using testutil::SetMutation;
using testutil::UnknownDoc;
using testutil::Value;
using testutil::Version;
using testutil::WrapObject;

const Timestamp now = Timestamp::Now();

std::string GetDescription(const MutableDocument& doc,
                           const std::vector<Mutation>& mutations,
                           const absl::optional<Mutation>& overlay) {
  std::string desc =
      absl::StrCat("Overlay Mutation failed with:\n", "document:\n",
                   doc.ToString() + "\n", "\n", "mutations:\n");

  for (const Mutation& mutation : mutations) {
    absl::StrAppend(&desc, mutation.ToString(), "\n");
  }

  return absl::StrCat(desc, "\n", "overlay: \n",
                      overlay.has_value() ? overlay.value().ToString() : "null",
                      "\n\n");
}

void VerifyOverlayRoundTrips(const MutableDocument& doc,
                             std::vector<Mutation> mutations) {
  MutableDocument doc_for_mutations = doc.Clone();
  MutableDocument doc_for_overlay = doc.Clone();

  absl::optional<FieldMask> mask = FieldMask();
  for (const Mutation& mutation : mutations) {
    mask = mutation.ApplyToLocalView(doc_for_mutations, mask, now);
  }

  absl::optional<Mutation> overlay =
      Mutation::CalculateOverlayMutation(doc_for_mutations, mask);
  if (overlay.has_value()) {
    overlay.value().ApplyToLocalView(doc_for_overlay,
                                     /* previous_mask */ absl::nullopt, now);
  }

  EXPECT_EQ(doc_for_overlay, doc_for_mutations)
      << GetDescription(doc, mutations, overlay);
}

/**
 * For each document in `docs`, calculate the overlay mutations of each
 * possible permutation, check whether this holds:
 * document + overlay_mutation = document + mutation_list
 *
 * Returns how many cases it has run.
 */
int RunPermutationTests(std::vector<MutableDocument> docs,
                        std::vector<Mutation> mutations) {
  int test_cases = 0;
  std::vector<size_t> indexes;
  for (size_t i = 0; i < mutations.size(); ++i) {
    indexes.push_back(i);
  }
  for (MutableDocument doc : docs) {
    std::vector<size_t> indexes_copy(indexes);
    do {
      std::vector<Mutation> mutations_copy;
      for (size_t idx : indexes_copy) {
        mutations_copy.push_back(mutations[idx]);
      }
      VerifyOverlayRoundTrips(doc, mutations_copy);
      test_cases += 1;
    } while (std::next_permutation(indexes_copy.begin(), indexes_copy.end()));
  }
  return test_cases;
}

/**
 * Given a vector of `Mutation`s, returns all possible combinations by picking
 * `size` number of mutations from that vector.
 *
 * See: https://stackoverflow.com/questions/9430568/generating-combinations-in-c
 */
std::vector<std::vector<Mutation>> Combinations(std::vector<Mutation> mutations,
                                                size_t size) {
  std::vector<bool> v(mutations.size());
  std::fill(v.begin(), v.begin() + size, true);

  std::vector<std::vector<Mutation>> combs;
  do {
    std::vector<Mutation> comb;
    for (size_t i = 0; i < mutations.size(); ++i) {
      if (v[i]) {
        comb.push_back(mutations[i]);
      }
    }
    combs.push_back(std::move(comb));
  } while (std::prev_permutation(v.begin(), v.end()));

  return combs;
}

TEST(MutationTest, AppliesSetsToDocuments) {
  MutableDocument doc =
      Doc("collection/key", 0, Map("foo", "foo-value", "baz", "baz-value"));

  Mutation set = SetMutation("collection/key", Map("bar", "bar-value"));
  set.ApplyToLocalView(doc, absl::nullopt, now);

  EXPECT_EQ(
      doc,
      Doc("collection/key", 0, Map("bar", "bar-value")).SetHasLocalMutations());
}

TEST(MutationTest, AppliesPatchToDocuments) {
  MutableDocument doc =
      Doc("collection/key", 0,
          Map("foo", Map("bar", "bar-value"), "baz", "baz-value"));

  Mutation patch =
      PatchMutation("collection/key", Map("foo.bar", "new-bar-value"));
  patch.ApplyToLocalView(doc, absl::nullopt, now);

  EXPECT_EQ(doc,
            Doc("collection/key", 0,
                Map("foo", Map("bar", "new-bar-value"), "baz", "baz-value"))
                .SetHasLocalMutations());
}

TEST(MutationTest, AppliesPatchWithMergeToNoDocuments) {
  MutableDocument doc = DeletedDoc("collection/key", 0);

  Mutation upsert = MergeMutation(
      "collection/key", Map("foo.bar", "new-bar-value"), {Field("foo.bar")});
  upsert.ApplyToLocalView(doc, absl::nullopt, now);

  EXPECT_EQ(doc,
            Doc("collection/key", 0, Map("foo", Map("bar", "new-bar-value")))
                .SetHasLocalMutations());
}

TEST(MutationTest, AppliesPatchWithMergeToNullDocuments) {
  MutableDocument doc = MutableDocument::InvalidDocument(Key("collection/key"));

  Mutation upsert = MergeMutation(
      "collection/key", Map("foo.bar", "new-bar-value"), {Field("foo.bar")});
  upsert.ApplyToLocalView(doc, absl::nullopt, now);

  EXPECT_EQ(doc,
            Doc("collection/key", 0, Map("foo", Map("bar", "new-bar-value")))
                .SetHasLocalMutations());
}

TEST(MutationTest, DeletesValuesFromTheFieldMask) {
  MutableDocument doc =
      Doc("collection/key", 0,
          Map("foo", Map("bar", "bar-value", "baz", "baz-value")));

  Mutation patch = MergeMutation("collection/key", Map(), {Field("foo.bar")});
  patch.ApplyToLocalView(doc, absl::nullopt, now);

  EXPECT_EQ(doc, Doc("collection/key", 0, Map("foo", Map("baz", "baz-value")))
                     .SetHasLocalMutations());
}

TEST(MutationTest, PatchesPrimitiveValue) {
  MutableDocument doc =
      Doc("collection/key", 0, Map("foo", "foo-value", "baz", "baz-value"));

  Mutation patch =
      PatchMutation("collection/key", Map("foo.bar", "new-bar-value"));
  patch.ApplyToLocalView(doc, absl::nullopt, now);

  EXPECT_EQ(doc,
            Doc("collection/key", 0,
                Map("foo", Map("bar", "new-bar-value"), "baz", "baz-value"))
                .SetHasLocalMutations());
}

TEST(MutationTest, PatchingDeletedDocumentsDoesNothing) {
  MutableDocument doc = testutil::DeletedDoc("collection/key", 0);

  Mutation patch = PatchMutation("collection/key", Map("foo", "bar"));
  patch.ApplyToLocalView(doc, absl::nullopt, now);

  EXPECT_EQ(doc, testutil::DeletedDoc("collection/key", 0));
}

TEST(MutationTest, AppliesLocalServerTimestampTransformToDocuments) {
  MutableDocument doc =
      Doc("collection/key", 0,
          Map("foo", Map("bar", "bar-value"), "baz", "baz-value"));

  Mutation transform = PatchMutation("collection/key", Map(),
                                     {{"foo.bar", ServerTimestampTransform()}});
  transform.ApplyToLocalView(doc, absl::nullopt, now);

  // Server timestamps aren't parsed, so we manually insert it.
  ObjectValue expected_data =
      WrapObject("foo", Map("bar", "<server-timestamp>"), "baz", "baz-value");
  expected_data.Set(Field("foo.bar"),
                    EncodeServerTimestamp(now, absl::nullopt));

  MutableDocument expected_doc =
      MutableDocument::FoundDocument(Key("collection/key"), Version(0),
                                     std::move(expected_data))
          .SetHasLocalMutations();

  EXPECT_EQ(doc, expected_doc);
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
void TransformBaseDoc(Message<google_firestore_v1_Value> base_data,
                      const TransformPairs& transforms,
                      Message<google_firestore_v1_Value> expected_data) {
  MutableDocument current_doc = Doc("collection/key", 0, std::move(base_data));

  for (const auto& transform : transforms) {
    Mutation mutation = PatchMutation("collection/key", Map(), {transform});
    mutation.ApplyToLocalView(current_doc, absl::nullopt, now);
    EXPECT_TRUE(current_doc.is_found_document());
  }

  MutableDocument expected_doc =
      Doc("collection/key", 0, std::move(expected_data)).SetHasLocalMutations();

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
  return ArrayTransform(TransformOperation::Type::ArrayUnion,
                        Array(std::move(args)...));
}

template <typename... Args>
TransformOperation ArrayRemove(Args... args) {
  return ArrayTransform(TransformOperation::Type::ArrayRemove,
                        Array(std::move(args)...));
}

TransformOperation ServerTimestamp() {
  return ServerTimestampTransform();
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
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesIncrementTransformToUnexpectedType) {
  auto base_data = Map("string", "zero");
  TransformPairs transforms = {
      {"string", Increment(1)},
  };
  auto expected = Map("string", 1);
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesIncrementTransformToMissingField) {
  auto base_data = Map();
  TransformPairs transforms = {
      {"missing", Increment(1)},
  };
  auto expected = Map("missing", 1);
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesIncrementTransformsConsecutively) {
  auto base_data = Map("number", 1);
  TransformPairs transforms = {
      {"number", Increment(2)},
      {"number", Increment(3)},
      {"number", Increment(4)},
  };
  auto expected = Map("number", 10);
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
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
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
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
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesLocalArrayUnionTransformToMissingField) {
  auto base_data = Map();
  TransformPairs transforms = {{"missing", ArrayUnion(1, 2)}};
  auto expected = Map("missing", Array(1, 2));
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesLocalArrayUnionTransformToNonArrayField) {
  auto base_data = Map("non-array", 42);
  TransformPairs transforms = {{"non-array", ArrayUnion(1, 2)}};
  auto expected = Map("non-array", Array(1, 2));
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithNonExistingElements) {
  auto base_data = Map("array", Array(1, 3));
  TransformPairs transforms = {{"array", ArrayUnion(2, 4)}};
  auto expected = Map("array", Array(1, 3, 2, 4));
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithExistingElements) {
  auto base_data = Map("array", Array(1, 3));
  TransformPairs transforms = {{"array", ArrayUnion(1, 3)}};
  auto expected = Map("array", Array(1, 3));
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest,
     AppliesLocalArrayUnionTransformWithDuplicateExistingElements) {
  // Duplicate entries in your existing array should be preserved.
  auto base_data = Map("array", Array(1, 2, 2, 3));
  TransformPairs transforms = {{"array", ArrayUnion(2)}};
  auto expected = Map("array", Array(1, 2, 2, 3));
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithExistingElementsInOrder) {
  // New elements should be appended in order.
  auto base_data = Map("array", Array(1, 3));
  TransformPairs transforms = {{"array", ArrayUnion(1, 2, 3, 4, 5)}};
  auto expected = Map("array", Array(1, 3, 2, 4, 5));
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithDuplicateUnionElements) {
  // Duplicate entries in your union array should only be added once.
  auto base_data = Map("array", Array(1, 3));
  TransformPairs transforms = {{"array", ArrayUnion(2, 2)}};
  auto expected = Map("array", Array(1, 3, 2));
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesLocalArrayUnionTransformWithNonPrimitiveElements) {
  // Union nested object values (one existing, one not).
  auto base_data = Map("array", Array(1, Map("a", "b")));
  TransformPairs transforms = {
      {"array", ArrayUnion(Map("a", "b"), Map("c", "d"))}};
  auto expected = Map("array", Array(1, Map("a", "b"), Map("c", "d")));
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest,
     AppliesLocalArrayUnionTransformWithPartiallyOverlappingElements) {
  // Union objects that partially overlap an existing object.
  auto base_data = Map("array", Array(1, Map("a", "b", "c", "d")));
  TransformPairs transforms = {
      {"array", ArrayUnion(Map("a", "b"), Map("c", "d"))}};
  auto expected = Map(
      "array", Array(1, Map("a", "b", "c", "d"), Map("a", "b"), Map("c", "d")));
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformToMissingField) {
  auto base_data = Map();
  TransformPairs transforms = {{"missing", ArrayRemove(1, 2)}};
  auto expected = Map("missing", Array());
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformToNonArrayField) {
  auto base_data = Map("non-array", 42);
  TransformPairs transforms = {{"non-array", ArrayRemove(1, 2)}};
  auto expected = Map("non-array", Array());
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformWithNonExistingElements) {
  auto base_data = Map("array", Array(1, 3));
  TransformPairs transforms = {{"array", ArrayRemove(2, 4)}};
  auto expected = Map("array", Array(1, 3));
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformWithExistingElements) {
  auto base_data = Map("array", Array(1, 2, 3, 4));
  TransformPairs transforms = {{"array", ArrayRemove(1, 3)}};
  auto expected = Map("array", Array(2, 4));
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesLocalArrayRemoveTransformWithNonPrimitiveElements) {
  // Remove nested object values (one existing, one not).
  auto base_data = Map("array", Array(1, Map("a", "b")));
  TransformPairs transforms = {
      {"array", ArrayRemove(Map("a", "b"), Map("c", "d"))}};
  auto expected = Map("array", Array(1));
  TransformBaseDoc(std::move(base_data), transforms, std::move(expected));
}

TEST(MutationTest, AppliesServerAckedIncrementTransformToDocuments) {
  MutableDocument doc = Doc("collection/key", 0, Map("sum", 1));

  Mutation transform =
      SetMutation("collection/key", Map(), {{"sum", Increment(2)}});

  model::MutationResult mutation_result(Version(1), Array(3));

  transform.ApplyToRemoteDocument(doc, std::move(mutation_result));

  EXPECT_EQ(doc,
            Doc("collection/key", 1, Map("sum", 3)).SetHasCommittedMutations());
}

TEST(MutationTest, AppliesServerAckedServerTimestampTransformToDocuments) {
  MutableDocument doc =
      Doc("collection/key", 0,
          Map("foo", Map("bar", "bar-value"), "baz", "baz-value"));

  Mutation transform = PatchMutation("collection/key", Map(),
                                     {{"foo.bar", ServerTimestampTransform()}});

  model::MutationResult mutation_result(Version(1), Array(now));

  transform.ApplyToRemoteDocument(doc, std::move(mutation_result));

  MutableDocument expected_doc =
      Doc("collection/key", 1, Map("foo", Map("bar", now), "baz", "baz-value"))
          .SetHasCommittedMutations();

  EXPECT_EQ(doc, expected_doc);
}

TEST(MutationTest, AppliesServerAckedArrayTransformsToDocuments) {
  MutableDocument doc =
      Doc("collection/key", 0,
          Map("array_1", Array(1, 2), "array_2", Array("a", "b")));

  Mutation transform = PatchMutation("collection/key", Map(),
                                     {
                                         {"array_1", ArrayUnion(2, 3)},
                                         {"array_2", ArrayRemove("a", "c")},
                                     });

  // Server just sends null transform results for array operations.
  model::MutationResult mutation_result(Version(1), Array(nullptr, nullptr));

  transform.ApplyToRemoteDocument(doc, std::move(mutation_result));

  EXPECT_EQ(doc, Doc("collection/key", 1,
                     Map("array_1", Array(1, 2, 3), "array_2", Array("b")))
                     .SetHasCommittedMutations());
}

TEST(MutationTest, DeleteDeletes) {
  MutableDocument doc = Doc("collection/key", 0, Map("foo", "bar"));

  Mutation del = DeleteMutation("collection/key");
  del.ApplyToLocalView(doc, absl::nullopt, now);

  EXPECT_EQ(doc, DeletedDoc("collection/key", 0).SetHasLocalMutations());
}

TEST(MutationTest, SetWithMutationResult) {
  MutableDocument doc = Doc("collection/key", 0, Map("foo", "bar"));

  Mutation set = SetMutation("collection/key", Map("foo", "new-bar"));
  set.ApplyToRemoteDocument(doc, MutationResult(4));

  EXPECT_EQ(doc, Doc("collection/key", 4, Map("foo", "new-bar"))
                     .SetHasCommittedMutations());
}

TEST(MutationTest, PatchWithMutationResult) {
  MutableDocument doc = Doc("collection/key", 0, Map("foo", "bar"));

  Mutation patch = PatchMutation("collection/key", Map("foo", "new-bar"));
  patch.ApplyToRemoteDocument(doc, MutationResult(4));

  EXPECT_EQ(doc, Doc("collection/key", 4, Map("foo", "new-bar"))
                     .SetHasCommittedMutations());
}

TEST(MutationTest, Transitions) {
  // TODO(rsgowman)
}

TEST(MutationTest, OverlayWithNoMutation) {
  VerifyOverlayRoundTrips(
      Doc("collection/key", 1, Map("foo", "foo-value", "baz", "baz-value")),
      {});
}

TEST(MutationTest, OverlayWithMutationsFailByPreconditions) {
  VerifyOverlayRoundTrips(DeletedDoc("collection/key", 1),
                          {PatchMutation("collection/key", Map("foo", "bar")),
                           PatchMutation("collection/key", Map("a", 1))});
}

TEST(MutationTest, OverlayWithPatchOnInvalidDocument) {
  VerifyOverlayRoundTrips(
      MutableDocument::InvalidDocument(Key("collection/key")),
      {PatchMutation("collection/key", Map("a", 1))});
}

TEST(MutationTest, OverlayWithOneSetMutation) {
  auto data = Map("foo", "foo-value", "baz", "baz-value");
  VerifyOverlayRoundTrips(
      Doc("collection/key", 1, std::move(data)),
      {SetMutation("collection/key", Map("bar", "bar-value"))});
}

TEST(MutationTest, OverlayWithOnePatchMutation) {
  auto data = Map("foo", Map("bar", "bar-value"), "baz", "baz-value");
  VerifyOverlayRoundTrips(
      Doc("collection/key", 1, std::move(data)),
      {PatchMutation("collection/key", Map("foo.bar", "new-bar-value"))});
}

TEST(MutationTest, OverlayWithPatchThenMerge) {
  Mutation upsert = MergeMutation(
      "collection/key", Map("foo.bar", "new-bar-value"), {Field("foo.bar")});
  VerifyOverlayRoundTrips(DeletedDoc("collection/key", 1), {upsert});
}

TEST(MutationTest, OverlayWithDeleteThenPatch) {
  MutableDocument doc = Doc("collection/key", 1, Map("foo", 1));
  Mutation del = DeleteMutation("collection/key");
  Mutation patch =
      PatchMutation("collection/key", Map("foo.bar", "new-bar-value"));

  VerifyOverlayRoundTrips(doc, {del, patch});
}

TEST(MutationTest, OverlayWithDeleteThenMerge) {
  MutableDocument doc = Doc("collection/key", 1, Map("foo", 1));
  Mutation del = DeleteMutation("collection/key");
  Mutation patch = MergeMutation(
      "collection/key", Map("foo.bar", "new-bar-value"), {Field("foo.bar")});

  VerifyOverlayRoundTrips(doc, {del, patch});
}

TEST(MutationTest, OverlayWithPatchThenPatchToDeleteField) {
  MutableDocument doc = Doc("collection/key", 1, Map("foo", 1));
  Mutation patch =
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {testutil::Increment("bar.baz", Value(1))});
  Mutation patchToDeleteField =
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {Field("foo"), Field("bar.baz")}, {});

  VerifyOverlayRoundTrips(doc, {patch, patchToDeleteField});
}

TEST(MutationTest, OverlayWithPatchThenMergeWithArrayUnion) {
  MutableDocument doc = Doc("collection/key", 1, Map("foo", 1));
  Mutation patch =
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {testutil::Increment("bar.baz", Value(1))});
  Mutation merge = MergeMutation("collection/key", Map(), {},
                                 {{"array", ArrayUnion(1, 2, 3)}});

  VerifyOverlayRoundTrips(doc, {patch, merge});
}

TEST(MutationTest, OverlayWithArrayUnionThenRemove) {
  MutableDocument doc = Doc("collection/key", 1, Map("foo", 1));
  Mutation union_merge = MergeMutation("collection/key", Map(), {},
                                       {{"arrays", ArrayUnion(1, 2, 3)}});
  Mutation remove = MergeMutation("collection/key", Map("foo", "xxx"),
                                  {Field("foo")}, {{"arrays", ArrayRemove(2)}});

  VerifyOverlayRoundTrips(doc, {union_merge, remove});
}

TEST(MutationTest, OverlayWithSetThenIncrement) {
  MutableDocument doc = Doc("collection/key", 1, Map("foo", 1));
  Mutation set = SetMutation("collection/key", Map("foo", 2));
  Mutation update =
      PatchMutation("collection/key", Map(), {{"foo", Increment(2)}});

  VerifyOverlayRoundTrips(doc, {set, update});
}

TEST(MutationTest, OverlayWithSetThenPatchOnDeletedDoc) {
  MutableDocument doc = DeletedDoc("collection/key", 1);
  Mutation set = SetMutation("collection/key", Map("bar", "bar-value"));
  Mutation patch =
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {{"bar.baz", ServerTimestamp()}});

  VerifyOverlayRoundTrips(doc, {set, patch});
}

TEST(MutationTest, OverlayWithFieldDeletionOfNestedField) {
  MutableDocument doc = Doc("collection/key", 1, Map("foo", 1));
  Mutation patch1 =
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {{"bar.baz", Increment(1)}});
  Mutation patch2 =
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {{"bar.baz", ServerTimestamp()}});
  Mutation patch3 =
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {Field("bar.baz")}, {});

  VerifyOverlayRoundTrips(doc, {patch1, patch2, patch3});
}

// See: https://github.com/firebase/firebase-ios-sdk/issues/9985
TEST(MutationTest, OverlayWithFieldDeletionOfNestedFieldAndParentField) {
  MutableDocument doc = Doc("collection/key", 1, Map("foo", 1));
  Mutation patch1 =
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {{"bar.baz", Increment(1)}});
  Mutation patch2 =
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {{"bar.baz", ServerTimestamp()}, {"a.b.c", Increment(1)}});
  Mutation patch3 =
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {Field("bar.baz"), Field("a.b.c")}, {});

  Mutation patch4 =
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {Field("bar"), Field("a.b")}, {});

  VerifyOverlayRoundTrips(doc, {patch1, patch2, patch3, patch4});
}

// See: https://github.com/firebase/firebase-ios-sdk/issues/10018
// Same root cause as OverlayWithFieldDeletionOfNestedFieldAndParentField,
// different way to trigger.
TEST(MutationTest, OverlayWorksWithDeletingSameField) {
  MutableDocument doc = Doc("collection/key", 1, Map("foo", 1));
  Mutation patch1 =
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {{"bar", ServerTimestamp()}});
  Mutation patch2 = PatchMutation(
      "collection/key", Map("foo", "foo-patched-value"), {Field("bar")}, {});

  Mutation patch3 = PatchMutation(
      "collection/key", Map("foo", "foo-patched-value"), {Field("bar")}, {});

  VerifyOverlayRoundTrips(doc, {patch1, patch2, patch3});
}

TEST(MutationTest, OverlayCreatedFromSetToEmptyWithMerge) {
  MutableDocument doc = DeletedDoc("collection/key", 1);
  Mutation merge = MergeMutation("collection/key", Map(), {});
  VerifyOverlayRoundTrips(doc, {merge});

  doc = Doc("collection/key", 1, Map("foo", "foo-value"));
  VerifyOverlayRoundTrips(doc, {merge});
}

// Below tests run on automatically generated mutation list, they are
// deterministic, but hard to debug when they fail. They will print the failure
// case, and the best way to debug is recreate the case manually in a separate
// test.

TEST(MutationTest, OverlayWithMutationWithMultipleDeletes) {
  std::vector<MutableDocument> docs = {
      Doc("collection/key", 1, Map("foo", "foo-value", "bar.baz", 1)),
      DeletedDoc("collection/key", 1), UnknownDoc("collection/key", 1)};
  std::vector<Mutation> mutations = {
      SetMutation("collection/key", Map("bar", "bar-value")),
      DeleteMutation("collection/key"), DeleteMutation("collection/key"),
      PatchMutation("collection/key", Map("foo", "foo-patched-value"),
                    {{"bar.baz", ServerTimestamp()}})};

  int test_cases = RunPermutationTests(docs, std::move(mutations));

  // There are 4! * 3 cases
  EXPECT_EQ(72, test_cases);
}

TEST(MutationTest, OverlayByCombinationsAndPermutations) {
  std::vector<MutableDocument> docs = {
      Doc("collection/key", 1, Map("foo", "foo-value", "bar", 1)),
      DeletedDoc("collection/key", 1), UnknownDoc("collection/key", 1)};
  std::vector<Mutation> mutations = {
      SetMutation("collection/key", Map("bar", "bar-value")),
      SetMutation("collection/key", Map("bar.rab", "bar.rab-value")),
      DeleteMutation("collection/key"),
      PatchMutation("collection/key", Map("foo", "foo-patched-value-incr"),
                    {{"bar", Increment(1)}}),
      PatchMutation("collection/key", Map("foo", "foo-patched-value-delete"),
                    {Field("foo"), Field("bar")}, {}),
      PatchMutation("collection/key", Map("foo", "foo-patched-value-st"),
                    {{"bar", ServerTimestamp()}}),
      MergeMutation("collection/key", {}, {Field("arrays")},
                    {{"arrays", ArrayUnion(1, 2, 3)}})};

  // Take all possible combinations of the subsets of the mutation list, run
  // each combination for all possible permutation, for all 3 different type of
  // documents.
  int test_cases = 0;
  for (size_t subset_size = 0; subset_size <= mutations.size(); ++subset_size) {
    std::vector<std::vector<Mutation>> combinations =
        Combinations(mutations, subset_size);
    for (const auto& combination : combinations) {
      test_cases += RunPermutationTests(docs, combination);
    }
  }

  // There are (0! + 7*1! + 21*2! + 35*3! + 35*4! + 21*5! + 7*6! + 7!) * 3 =
  // 41100 cases.
  EXPECT_EQ(41100, test_cases);
}

TEST(MutationTest, OverlayByCombinationsAndPermutations_ArrayTransforms) {
  std::vector<MutableDocument> docs = {
      Doc("collection/key", 1, Map("foo", "foo-value", "bar.baz", 1)),
      DeletedDoc("collection/key", 1), UnknownDoc("collection/key", 1)};
  std::vector<Mutation> mutations = {
      SetMutation("collection/key", Map("bar", "bar-value")),
      MergeMutation("collection/key", Map("foo", "xxx"), {Field("foo")},
                    {{"arrays", ArrayRemove(2)}}),
      DeleteMutation("collection/key"),
      PatchMutation("collection/key", Map("foo", "foo-patched-value-1"),
                    {{"arrays", ArrayUnion(4, 5)}}),
      PatchMutation("collection/key", Map("foo", "foo-patched-value-2"),
                    {{"arrays", ArrayRemove(5, 6)}}),
      MergeMutation("collection/key", Map("foo", "yyy"), {Field("foo")},
                    {{"arrays", ArrayUnion(1, 2, 3, 999)}})};

  int test_cases = 0;
  for (size_t subset_size = 0; subset_size <= mutations.size(); ++subset_size) {
    std::vector<std::vector<Mutation>> combinations =
        Combinations(mutations, subset_size);
    for (const auto& combination : combinations) {
      test_cases += RunPermutationTests(docs, combination);
    }
  }

  // There are (0! + 6*1! + 15*2! + 20*3! + 15*4! + 6*5! + 6!) * 3 = 5871 cases.
  EXPECT_EQ(5871, test_cases);
}

TEST(MutationTest, OverlayByCombinationsAndPermutations_Increments) {
  std::vector<MutableDocument> docs = {
      Doc("collection/key", 1, Map("foo", "foo-value", "bar", 1)),
      DeletedDoc("collection/key", 1), UnknownDoc("collection/key", 1)};
  std::vector<Mutation> mutations = {
      SetMutation("collection/key", Map("bar", "bar-value")),
      MergeMutation("collection/key", Map("foo", "foo-merge"), {Field("foo")},
                    {{"bar", Increment(2)}}),
      DeleteMutation("collection/key"),
      PatchMutation("collection/key", Map("foo", "foo-patched-value-1"),
                    {{"bar", Increment(-1.4)}}),
      PatchMutation("collection/key", Map("foo", "foo-patched-value-2"),
                    {{"bar", Increment(3.3)}}),
      MergeMutation("collection/key", Map("foo", "yyy"), {Field("foo")},
                    {{"bar", Increment(-41)}})};

  int test_cases = 0;
  for (size_t subset_size = 0; subset_size <= mutations.size(); ++subset_size) {
    std::vector<std::vector<Mutation>> combinations =
        Combinations(mutations, subset_size);
    for (const auto& combination : combinations) {
      test_cases += RunPermutationTests(docs, combination);
    }
  }

  // There are (0! + 6*1! + 15*2! + 20*3! + 15*4! + 6*5! + 6!) * 3 = 5871 cases.
  EXPECT_EQ(5871, test_cases);
}

}  // namespace
}  // namespace model
}  // namespace firestore
}  // namespace firebase
