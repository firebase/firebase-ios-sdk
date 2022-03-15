/*
 * Copyright 2022 Google LLC
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

#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/src/util/comparison.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/strings/string_view.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

using testutil::Key;
using testutil::MakeFieldIndex;
using testutil::Version;
using util::ComparisonResult;

TEST(FieldIndexTest, ComparatorIncludesCollectionGroup) {
  FieldIndex original = MakeFieldIndex("collA");
  FieldIndex same = MakeFieldIndex("collA");
  FieldIndex different = MakeFieldIndex("collB");
  EXPECT_EQ(FieldIndex::SemanticCompare(original, same),
            ComparisonResult::Same);
  EXPECT_EQ(FieldIndex::SemanticCompare(original, different),
            ComparisonResult::Ascending);
}

TEST(FieldIndexTest, ComparatorIgnoresIndexId) {
  FieldIndex original = MakeFieldIndex("collA", 1, FieldIndex::InitialState());
  FieldIndex same = MakeFieldIndex("collA", 1, FieldIndex::InitialState());
  FieldIndex different = MakeFieldIndex("collA", 2, FieldIndex::InitialState());
  EXPECT_EQ(FieldIndex::SemanticCompare(original, same),
            ComparisonResult::Same);
  EXPECT_EQ(FieldIndex::SemanticCompare(original, different),
            ComparisonResult::Same);
}

TEST(FieldIndexTest, ComparatorIgnoresIndexState) {
  FieldIndex original = MakeFieldIndex("collA", 1, FieldIndex::InitialState());
  FieldIndex same = MakeFieldIndex("collA", 1, FieldIndex::InitialState());
  FieldIndex different =
      MakeFieldIndex("collA", 1,
                     IndexState(1, Version(2), DocumentKey::Empty(),
                                IndexOffset::InitialLargestBatchId()));
  EXPECT_EQ(FieldIndex::SemanticCompare(original, same),
            ComparisonResult::Same);
  EXPECT_EQ(FieldIndex::SemanticCompare(original, different),
            ComparisonResult::Same);
}

TEST(FieldIndexTest, ComparatorIncludesFieldName) {
  FieldIndex original = MakeFieldIndex("collA", "a", Segment::Kind::kAscending);
  FieldIndex same = MakeFieldIndex("collA", "a", Segment::Kind::kAscending);
  FieldIndex different =
      MakeFieldIndex("collA", "b", Segment::Kind::kAscending);
  EXPECT_EQ(FieldIndex::SemanticCompare(original, same),
            ComparisonResult::Same);
  EXPECT_EQ(FieldIndex::SemanticCompare(original, different),
            ComparisonResult::Ascending);
}

TEST(FieldIndexTest, ComparatorIncludesSegmentKind) {
  FieldIndex original = MakeFieldIndex("collA", "a", Segment::Kind::kAscending);
  FieldIndex same = MakeFieldIndex("collA", "a", Segment::Kind::kAscending);
  FieldIndex different =
      MakeFieldIndex("collA", "a", Segment::Kind::kDescending);
  EXPECT_EQ(FieldIndex::SemanticCompare(original, same),
            ComparisonResult::Same);
  EXPECT_EQ(FieldIndex::SemanticCompare(original, different),
            ComparisonResult::Ascending);
}

TEST(FieldIndexTest, ComparatorIncludesSegmentLength) {
  FieldIndex original = MakeFieldIndex("collA", "a", Segment::Kind::kAscending);
  FieldIndex same = MakeFieldIndex("collA", "a", Segment::Kind::kAscending);
  FieldIndex different = MakeFieldIndex("collA", "a", Segment::Kind::kAscending,
                                        "b", Segment::Kind::kDescending);
  EXPECT_EQ(FieldIndex::SemanticCompare(original, same),
            ComparisonResult::Same);
  EXPECT_EQ(FieldIndex::SemanticCompare(original, different),
            ComparisonResult::Ascending);
}

TEST(FieldIndexTest, IndexOffsetCompareToWorks) {
  IndexOffset doc_a_offset = IndexOffset(Version(1), Key("foo/a"),
                                         IndexOffset::InitialLargestBatchId());
  IndexOffset doc_b_offset = IndexOffset(Version(1), Key("foo/b"),
                                         IndexOffset::InitialLargestBatchId());
  IndexOffset version_1_offset = IndexOffset::Create(Version(1));
  IndexOffset doc_c_offset = IndexOffset(Version(2), Key("foo/c"),
                                         IndexOffset::InitialLargestBatchId());
  IndexOffset version_2_offset = IndexOffset::Create(Version(2));

  EXPECT_EQ(doc_a_offset.CompareTo(doc_b_offset), ComparisonResult::Ascending);
  EXPECT_EQ(doc_a_offset.CompareTo(version_1_offset),
            ComparisonResult::Ascending);
  EXPECT_EQ(version_1_offset.CompareTo(doc_c_offset),
            ComparisonResult::Ascending);
  EXPECT_EQ(version_1_offset.CompareTo(version_2_offset),
            ComparisonResult::Ascending);
  EXPECT_EQ(doc_c_offset.CompareTo(version_2_offset),
            ComparisonResult::Ascending);
}

TEST(FieldIndexTest, IndexOffsetAdvancesSeconds) {
  IndexOffset actual = IndexOffset::Create(
      SnapshotVersion(Timestamp(1, static_cast<int32_t>(1e9) - 1)));
  IndexOffset expected =
      IndexOffset(SnapshotVersion(Timestamp(2, 0)), DocumentKey::Empty(),
                  IndexOffset::InitialLargestBatchId());
  EXPECT_EQ(actual, expected);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
