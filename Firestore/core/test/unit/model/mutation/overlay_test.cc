/*
 * Copyright 2022 Google
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

#include <type_traits>
#include <utility>

#include "Firestore/core/src/model/mutation/overlay.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/strings/string_view.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {
namespace mutation {
namespace {

using testutil::Map;
using testutil::PatchMutation;

constexpr int SAMPLE_BATCH_ID = 123;

Mutation SampleMutation(absl::string_view path = "doc/col") {
  return PatchMutation(path, Map("key", "value"));
}

TEST(OverlayTest, TypeTraits) {
  static_assert(std::is_constructible<Overlay>::value, "is_constructible");
  static_assert(std::is_destructible<Overlay>::value, "is_destructible");
  static_assert(std::is_default_constructible<Overlay>::value, "is_default_constructible");
  static_assert(std::is_copy_constructible<Overlay>::value, "is_copy_constructible");
  static_assert(std::is_move_constructible<Overlay>::value, "is_move_constructible");
  static_assert(std::is_copy_assignable<Overlay>::value, "is_copy_assignable");
  static_assert(std::is_move_assignable<Overlay>::value, "is_move_assignable");
}

TEST(OverlayTest, DefaultConstructor) {
  Overlay overlay;

  EXPECT_FALSE(overlay.is_valid());
  EXPECT_EQ(overlay.largest_batch_id(), 0);
  EXPECT_EQ(overlay.mutation(), Mutation());
}

TEST(OverlayTest, ConstructorWithValidMutation) {
  Overlay overlay(SAMPLE_BATCH_ID, SampleMutation());

  EXPECT_TRUE(overlay.is_valid());
  EXPECT_EQ(overlay.largest_batch_id(), SAMPLE_BATCH_ID);
  EXPECT_EQ(overlay.mutation(), SampleMutation());
  EXPECT_EQ(overlay.key(), SampleMutation().key());
}

TEST(OverlayTest, ConstructorWithInvalidMutation) {
  Overlay overlay(SAMPLE_BATCH_ID, Mutation());

  EXPECT_FALSE(overlay.is_valid());
  EXPECT_EQ(overlay.largest_batch_id(), SAMPLE_BATCH_ID);
  EXPECT_EQ(overlay.mutation(), Mutation());
}

TEST(OverlayTest, CopyConstructorWithValidInstance) {
  const Overlay overlay_copy_src(SAMPLE_BATCH_ID, SampleMutation());

  Overlay overlay_copy_dest(overlay_copy_src);

  EXPECT_TRUE(overlay_copy_dest.is_valid());
  EXPECT_EQ(overlay_copy_dest.largest_batch_id(), SAMPLE_BATCH_ID);
  EXPECT_EQ(overlay_copy_dest.mutation(), SampleMutation());
}

TEST(OverlayTest, CopyConstructorWithInvalidInstance) {
  Overlay invalid_overlay(SAMPLE_BATCH_ID, SampleMutation());
  Overlay(std::move(invalid_overlay));

  Overlay overlay_copy_dest(invalid_overlay);

  EXPECT_FALSE(overlay_copy_dest.is_valid());
}

TEST(OverlayTest, MoveConstructorWithValidInstance) {
  Overlay overlay_move_src(SAMPLE_BATCH_ID, SampleMutation());

  Overlay overlay_move_dest(std::move(overlay_move_src));

  EXPECT_FALSE(overlay_move_src.is_valid());
  EXPECT_FALSE(overlay_move_src.mutation().is_valid());
  EXPECT_TRUE(overlay_move_dest.is_valid());
  EXPECT_EQ(overlay_move_dest.largest_batch_id(), SAMPLE_BATCH_ID);
  EXPECT_EQ(overlay_move_dest.mutation(), SampleMutation());
}

TEST(OverlayTest, MoveConstructorWithInvalidInstance) {
  Overlay invalid_overlay(SAMPLE_BATCH_ID, SampleMutation());
  Overlay(std::move(invalid_overlay));

  Overlay overlay_move_dest(std::move(invalid_overlay));

  EXPECT_FALSE(invalid_overlay.is_valid());
  EXPECT_FALSE(overlay_move_dest.is_valid());
}

TEST(OverlayTest, CopyAssignmentOperatorWithValidInstance) {
  const Overlay overlay_copy_src(123, SampleMutation("col1/doc1"));
  Overlay overlay_copy_dest(456, SampleMutation("col2/doc2"));

  overlay_copy_dest = overlay_copy_src;

  EXPECT_TRUE(overlay_copy_dest.is_valid());
  EXPECT_EQ(overlay_copy_dest.largest_batch_id(), 123);
  EXPECT_EQ(overlay_copy_dest.mutation(), SampleMutation("col1/doc1"));
}

TEST(OverlayTest, CopyAssignmentOperatorWithInvalidInstance) {
  Overlay invalid_overlay(123, SampleMutation("col1/doc1"));
  Overlay(std::move(invalid_overlay));
  Overlay overlay_copy_dest(456, SampleMutation("col2/doc2"));

  overlay_copy_dest = invalid_overlay;

  EXPECT_FALSE(invalid_overlay.is_valid());
  EXPECT_FALSE(overlay_copy_dest.is_valid());
}

TEST(OverlayTest, MoveAssignmentOperatorWithValidInstance) {
  Overlay overlay_move_src(123, SampleMutation("col1/doc1"));
  Overlay overlay_move_dest(456, SampleMutation("col2/doc2"));

  overlay_move_dest = std::move(overlay_move_src);

  EXPECT_FALSE(overlay_move_src.is_valid());
  EXPECT_FALSE(overlay_move_src.mutation().is_valid());
  EXPECT_TRUE(overlay_move_dest.is_valid());
  EXPECT_EQ(overlay_move_dest.largest_batch_id(), 123);
  EXPECT_EQ(overlay_move_dest.mutation(), SampleMutation("col1/doc1"));
}

TEST(OverlayTest, MoveAssignmentOperatorWithInvalidInstance) {
  Overlay invalid_overlay(123, SampleMutation("col1/doc1"));
  Overlay(std::move(invalid_overlay));
  Overlay overlay_move_dest(456, SampleMutation("col2/doc2"));

  overlay_move_dest = std::move(invalid_overlay);

  EXPECT_FALSE(invalid_overlay.is_valid());
  EXPECT_FALSE(overlay_move_dest.is_valid());
}

TEST(OverlayTest, is_valid) {
  EXPECT_FALSE(Overlay().is_valid());
  EXPECT_FALSE(Overlay(123, Mutation()).is_valid());
  EXPECT_TRUE(Overlay(123, SampleMutation()).is_valid());
}

TEST(OverlayTest, largest_batch_id) {
  Overlay overlay123(123, SampleMutation());
  Overlay overlay456(456, SampleMutation());

  EXPECT_EQ(overlay123.largest_batch_id(), 123);
  EXPECT_EQ(overlay456.largest_batch_id(), 456);
}

TEST(OverlayTest, mutation_ConstRefQualified) {
  Overlay overlay_abc(SAMPLE_BATCH_ID, SampleMutation("col/abc"));
  Overlay overlay_xyz(SAMPLE_BATCH_ID, SampleMutation("col/xyz"));

  EXPECT_EQ(overlay_abc.mutation(), SampleMutation("col/abc"));
  EXPECT_EQ(overlay_xyz.mutation(), SampleMutation("col/xyz"));
}

TEST(OverlayTest, mutation_RvalueRefQualified) {
  Overlay overlay(SAMPLE_BATCH_ID, SampleMutation());

  Mutation&& mutation_rvalue_ref = std::move(overlay).mutation();

  Mutation mutation_move_dest(std::move(mutation_rvalue_ref));
  EXPECT_EQ(mutation_move_dest, SampleMutation());
  EXPECT_FALSE(overlay.is_valid());
}

// TODO(dconeybe): Add tests for:
// bool operator==(const Overlay&, const Overlay&);
// std::size_t Hash() const;
// std::string ToString() const;
// std::ostream& operator<<(std::ostream&, const Overlay&);

}  // namespace
}  // namespace mutation
}  // namespace model
}  // namespace firestore
}  // namespace firebase