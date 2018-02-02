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

#include "Firestore/core/src/firebase/firestore/model/resource_path.h"

#include <initializer_list>
#include <string>
#include <vector>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(ResourcePath, Constructor) {
  const ResourcePath empty_path;
  EXPECT_TRUE(empty_path.empty());
  EXPECT_EQ(0, empty_path.size());
  EXPECT_TRUE(empty_path.begin() == empty_path.end());

  const ResourcePath path_from_list{{"rooms", "Eros", "messages"}};
  EXPECT_FALSE(path_from_list.empty());
  EXPECT_EQ(3, path_from_list.size());
  EXPECT_TRUE(path_from_list.begin() + 3 == path_from_list.end());

  std::vector<std::string> segments{"rooms", "Eros", "messages"};
  const ResourcePath path_from_segments{segments.begin(), segments.end()};
  EXPECT_FALSE(path_from_segments.empty());
  EXPECT_EQ(3, path_from_segments.size());
  EXPECT_TRUE(path_from_segments.begin() + 3 == path_from_segments.end());

  ResourcePath copied = path_from_list;
  EXPECT_EQ(path_from_list, copied);
  const ResourcePath moved = std::move(copied);
  // Because ResourcePath is immutable, move constructor performs a copy.
  EXPECT_EQ(copied, moved);
}

TEST(ResourcePath, Parsing) {
  const auto expect_round_trip = [](const std::string& str,
                                    const size_t expected_segments) {
    const auto path = ResourcePath::Parse(str);
    EXPECT_EQ(str, path.CanonicalString());
    EXPECT_EQ(expected_segments, path.size());
  };

  expect_round_trip("", 0);
  expect_round_trip("foo", 1);
  expect_round_trip("foo/bar", 2);
  expect_round_trip("foo/bar/baz", 3);
  expect_round_trip(R"(foo/__..`..\`/baz)", 3);

  EXPECT_EQ("foo", ResourcePath::Parse("/foo/").CanonicalString());
}

TEST(ResourcePath, ParseFailures) {
  const auto expect_fail = [](const absl::string_view str) {
    ASSERT_DEATH_IF_SUPPORTED(ResourcePath::Parse(str), "");
  };

  expect_fail("//");
  expect_fail("foo//bar");
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
