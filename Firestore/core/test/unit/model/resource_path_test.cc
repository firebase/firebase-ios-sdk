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

#include "Firestore/core/src/model/resource_path.h"

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
  EXPECT_EQ(0u, empty_path.size());
  EXPECT_TRUE(empty_path.begin() == empty_path.end());

  const ResourcePath path_from_list{{"rooms", "Eros", "messages"}};
  EXPECT_FALSE(path_from_list.empty());
  EXPECT_EQ(3u, path_from_list.size());
  EXPECT_TRUE(path_from_list.begin() + 3 == path_from_list.end());

  std::vector<std::string> segments{"rooms", "Eros", "messages"};
  const ResourcePath path_from_segments{segments.begin(), segments.end()};
  EXPECT_FALSE(path_from_segments.empty());
  EXPECT_EQ(3u, path_from_segments.size());
  EXPECT_TRUE(path_from_segments.begin() + 3 == path_from_segments.end());

  ResourcePath copied = path_from_list;
  EXPECT_EQ(path_from_list, copied);
  const ResourcePath moved = std::move(copied);
  EXPECT_EQ(path_from_list, moved);
  EXPECT_NE(copied, moved);  // NOLINT: use after move intended
  EXPECT_EQ(empty_path, copied);
}

TEST(ResourcePath, Comparison) {
  const ResourcePath abc{"a", "b", "c"};
  const ResourcePath abc2{"a", "b", "c"};
  const ResourcePath xyz{"x", "y", "z"};
  EXPECT_EQ(abc, abc2);
  EXPECT_NE(abc, xyz);

  const ResourcePath empty;
  const ResourcePath a{"a"};
  const ResourcePath b{"b"};
  const ResourcePath ab{"a", "b"};

  EXPECT_TRUE(empty < a);
  EXPECT_TRUE(a < b);
  EXPECT_TRUE(a < ab);

  EXPECT_TRUE(a > empty);
  EXPECT_TRUE(b > a);
  EXPECT_TRUE(ab > a);
}

TEST(ResourcePath, Parsing) {
  const auto parse = [](const std::pair<std::string, size_t> expected) {
    const auto path = ResourcePath::FromString(expected.first);
    return std::make_pair(path.CanonicalString(), path.size());
  };
  const auto make_expected = [](const std::string& str, const size_t size) {
    return std::make_pair(str, size);
  };

  auto expected = make_expected("", 0);
  EXPECT_EQ(expected, parse(expected));
  expected = make_expected("foo", 1);
  EXPECT_EQ(expected, parse(expected));
  expected = make_expected("foo/bar", 2);
  EXPECT_EQ(expected, parse(expected));
  expected = make_expected("foo/bar/baz", 3);
  EXPECT_EQ(expected, parse(expected));
  expected = make_expected(R"(foo/__!?#@..`..\`/baz)", 3);
  EXPECT_EQ(expected, parse(expected));

  EXPECT_EQ(ResourcePath::FromString("/foo/").CanonicalString(), "foo");
}

TEST(ResourcePath, ParseFailures) {
  ASSERT_ANY_THROW(ResourcePath::FromString("//"));
  ASSERT_ANY_THROW(ResourcePath::FromString("foo//bar"));
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
