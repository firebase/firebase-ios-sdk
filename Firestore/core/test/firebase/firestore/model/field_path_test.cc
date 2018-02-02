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

#include "Firestore/core/src/firebase/firestore/model/field_path.h"

#include <initializer_list>
#include <string>
#include <vector>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(FieldPath, Constructor) {
  const FieldPath empty_path;
  EXPECT_TRUE(empty_path.empty());
  EXPECT_EQ(0, empty_path.size());
  EXPECT_TRUE(empty_path.begin() == empty_path.end());

  const FieldPath path_from_list{{"rooms", "Eros", "messages"}};
  EXPECT_FALSE(path_from_list.empty());
  EXPECT_EQ(3, path_from_list.size());
  EXPECT_TRUE(path_from_list.begin() + 3 == path_from_list.end());

  std::vector<std::string> segments{"rooms", "Eros", "messages"};
  const FieldPath path_from_segments{segments.begin(), segments.end()};
  EXPECT_FALSE(path_from_segments.empty());
  EXPECT_EQ(3, path_from_segments.size());
  EXPECT_TRUE(path_from_segments.begin() + 3 == path_from_segments.end());
}

TEST(FieldPath, Indexing) {
  const FieldPath path{{"rooms", "Eros", "messages"}};

  EXPECT_EQ(path.front(), "rooms");
  EXPECT_EQ(path[0], "rooms");
  EXPECT_EQ(path.at(0), "rooms");

  EXPECT_EQ(path[1], "Eros");
  EXPECT_EQ(path.at(1), "Eros");

  EXPECT_EQ(path[2], "messages");
  EXPECT_EQ(path.at(2), "messages");
  EXPECT_EQ(path.back(), "messages");
}

TEST(FieldPath, WithoutFirst) {
  const FieldPath abc{"rooms", "Eros", "messages"};
  const FieldPath bc{"Eros", "messages"};
  const FieldPath c{"messages"};
  const FieldPath empty;
  const FieldPath abc_dupl{"rooms", "Eros", "messages"};

  EXPECT_NE(empty, c);
  EXPECT_NE(c, bc);
  EXPECT_NE(bc, abc);

  EXPECT_EQ(bc, abc.WithoutFirstElement());
  EXPECT_EQ(c, abc.WithoutFirstElements(2));
  EXPECT_EQ(empty, abc.WithoutFirstElements(3));
  EXPECT_EQ(abc_dupl, abc);
}

TEST(FieldPath, WithoutLast) {
  const FieldPath abc{"rooms", "Eros", "messages"};
  const FieldPath ab{"rooms", "Eros"};
  const FieldPath a{"rooms"};
  const FieldPath empty;
  const FieldPath abc_dupl{"rooms", "Eros", "messages"};

  EXPECT_EQ(ab, abc.WithoutLastElement());
  EXPECT_EQ(a, abc.WithoutLastElement().WithoutLastElement());
  EXPECT_EQ(empty,
            abc.WithoutLastElement().WithoutLastElement().WithoutLastElement());
}

TEST(FieldPath, Concatenation) {
  const FieldPath path;
  const FieldPath a{"rooms"};
  const FieldPath ab{"rooms", "Eros"};
  const FieldPath abc{"rooms", "Eros", "messages"};

  EXPECT_EQ(a, path.Concatenated("rooms"));
  EXPECT_EQ(ab, path.Concatenated("rooms").Concatenated("Eros"));
  EXPECT_EQ(abc, path.Concatenated("rooms").Concatenated("Eros").Concatenated(
                     "messages"));
  EXPECT_EQ(abc, path.Concatenated(FieldPath{"rooms", "Eros", "messages"}));

  const FieldPath bcd{"Eros", "messages", "this_week"};
  EXPECT_EQ(bcd, abc.WithoutFirstElement().Concatenated("this_week"));
}

TEST(FieldPath, Comparison) {
  const FieldPath abc{"a", "b", "c"};
  const FieldPath abc2{"a", "b", "c"};
  const FieldPath xyz{"x", "y", "z"};
  EXPECT_EQ(abc, abc2);
  EXPECT_NE(abc, xyz);

  const FieldPath empty;
  const FieldPath a{"a"};
  const FieldPath b{"b"};
  const FieldPath ab{"a", "b"};

  EXPECT_TRUE(empty < a);
  EXPECT_TRUE(a < b);
  EXPECT_TRUE(a < ab);

  EXPECT_TRUE(a > empty);
  EXPECT_TRUE(b > a);
  EXPECT_TRUE(ab > a);
}

TEST(FieldPath, IsPrefixOf) {
  const FieldPath empty;
  const FieldPath a{"a"};
  const FieldPath ab{"a", "b"};
  const FieldPath abc{"a", "b", "c"};
  const FieldPath b{"b"};
  const FieldPath ba{"b", "a"};

  EXPECT_TRUE(empty.IsPrefixOf(empty));
  EXPECT_TRUE(empty.IsPrefixOf(a));
  EXPECT_TRUE(empty.IsPrefixOf(ab));
  EXPECT_TRUE(empty.IsPrefixOf(abc));
  EXPECT_TRUE(empty.IsPrefixOf(b));
  EXPECT_TRUE(empty.IsPrefixOf(ba));

  EXPECT_FALSE(a.IsPrefixOf(empty));
  EXPECT_TRUE(a.IsPrefixOf(a));
  EXPECT_TRUE(a.IsPrefixOf(ab));
  EXPECT_TRUE(a.IsPrefixOf(abc));
  EXPECT_FALSE(a.IsPrefixOf(b));
  EXPECT_FALSE(a.IsPrefixOf(ba));

  EXPECT_FALSE(ab.IsPrefixOf(empty));
  EXPECT_FALSE(ab.IsPrefixOf(a));
  EXPECT_TRUE(ab.IsPrefixOf(ab));
  EXPECT_TRUE(ab.IsPrefixOf(abc));
  EXPECT_FALSE(ab.IsPrefixOf(b));
  EXPECT_FALSE(ab.IsPrefixOf(ba));

  EXPECT_FALSE(abc.IsPrefixOf(empty));
  EXPECT_FALSE(abc.IsPrefixOf(a));
  EXPECT_FALSE(abc.IsPrefixOf(ab));
  EXPECT_TRUE(abc.IsPrefixOf(abc));
  EXPECT_FALSE(abc.IsPrefixOf(b));
  EXPECT_FALSE(abc.IsPrefixOf(ba));
}

TEST(FieldPath, AccessFailures) {
  const FieldPath path;
  ASSERT_DEATH_IF_SUPPORTED(path.front(), "");
  ASSERT_DEATH_IF_SUPPORTED(path.back(), "");
  ASSERT_DEATH_IF_SUPPORTED(path[0], "");
  ASSERT_DEATH_IF_SUPPORTED(path[1], "");
  ASSERT_DEATH_IF_SUPPORTED(path.at(0), "");
  ASSERT_DEATH_IF_SUPPORTED(path.WithoutFirstElement(), "");
  ASSERT_DEATH_IF_SUPPORTED(path.WithoutFirstElements(2), "");
  ASSERT_DEATH_IF_SUPPORTED(path.WithoutLastElement(), "");
}

// DIVE IN:
//   canonical string/roundtrip
//   parse failures
//   concat/skip gives expected canonical string
//   SKIP
//   copy/move constructor
//
//   resourcepathtest

TEST(FieldPath, Parsing) {
  EXPECT_EQ(FieldPath{"foo"}, FieldPath::ParseServerFormat("foo"));
  const FieldPath foo_bar{"foo", "bar"};
  EXPECT_EQ(foo_bar, FieldPath::ParseServerFormat("foo.bar"));
  const FieldPath foo_bar_baz{"foo", "bar", "baz"};
  EXPECT_EQ(foo_bar_baz, FieldPath::ParseServerFormat("foo.bar.baz"));
  const FieldPath foo_slash{R"(.foo\)"};
  EXPECT_EQ(foo_slash, FieldPath::ParseServerFormat(R"(`.foo\\`)"));
  const FieldPath foo_slash_foo{R"(.foo\)", ".foo"};
  EXPECT_EQ(foo_slash_foo, FieldPath::ParseServerFormat(R"(`.foo\\`.`.foo`)"));
  const FieldPath foo_tilde_bar{"foo", "`", "bar"};
  EXPECT_EQ(foo_tilde_bar, FieldPath::ParseServerFormat(R"(foo.`\``.bar)"));
}

TEST(FieldPath, ParseFailures) {
  // const FieldPath path;
  // ASSERT_DEATH_IF_SUPPORTED(path.front(), "");
  // ASSERT_DEATH_IF_SUPPORTED(path.back(), "");
  // ASSERT_DEATH_IF_SUPPORTED(path[0], "");
  // ASSERT_DEATH_IF_SUPPORTED(path[1], "");
  // ASSERT_DEATH_IF_SUPPORTED(path.at(0), "");
  // ASSERT_DEATH_IF_SUPPORTED(path.WithoutFirstElement(), "");
  // ASSERT_DEATH_IF_SUPPORTED(path.WithoutFirstElements(2), "");
  // ASSERT_DEATH_IF_SUPPORTED(path.WithoutLastElement(), "");
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
