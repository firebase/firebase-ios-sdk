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

#include "Firestore/core/src/model/field_path.h"

#include <initializer_list>
#include <string>
#include <vector>

#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/test/unit/testutil/status_testing.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

namespace {

FieldPath Parse(const std::string& path) {
  return FieldPath::FromServerFormat(path).ConsumeValueOrDie();
}

}  // namespace

TEST(FieldPath, Constructors) {
  const FieldPath empty_path;
  EXPECT_TRUE(empty_path.empty());
  EXPECT_EQ(0u, empty_path.size());
  EXPECT_TRUE(empty_path.begin() == empty_path.end());

  const FieldPath path_from_list = {"rooms", "Eros", "messages"};
  EXPECT_FALSE(path_from_list.empty());
  EXPECT_EQ(3u, path_from_list.size());
  EXPECT_TRUE(path_from_list.begin() + 3 == path_from_list.end());

  std::vector<std::string> segments{"rooms", "Eros", "messages"};
  const FieldPath path_from_segments{segments.begin(), segments.end()};
  EXPECT_FALSE(path_from_segments.empty());
  EXPECT_EQ(3u, path_from_segments.size());
  EXPECT_TRUE(path_from_segments.begin() + 3 == path_from_segments.end());

#if !__clang_analyzer__
  FieldPath copied = path_from_list;
  EXPECT_EQ(path_from_list, copied);
  const FieldPath moved = std::move(copied);
  EXPECT_EQ(path_from_list, moved);
  EXPECT_NE(copied, moved);  // NOLINT: use after move intended
  EXPECT_EQ(empty_path, copied);
#endif  // !__clang_analyzer__
}

TEST(FieldPath, Indexing) {
  const FieldPath path{"rooms", "Eros", "messages"};

  EXPECT_EQ(path.first_segment(), "rooms");
  EXPECT_EQ(path[0], "rooms");

  EXPECT_EQ(path[1], "Eros");

  EXPECT_EQ(path[2], "messages");
  EXPECT_EQ(path.last_segment(), "messages");
}

TEST(FieldPath, PopFirst) {
  const FieldPath abc{"rooms", "Eros", "messages"};
  const FieldPath bc{"Eros", "messages"};
  const FieldPath c{"messages"};
  const FieldPath empty;
  const FieldPath abc_dup{"rooms", "Eros", "messages"};

  EXPECT_NE(empty, c);
  EXPECT_NE(c, bc);
  EXPECT_NE(bc, abc);

  EXPECT_EQ(bc, abc.PopFirst());
  EXPECT_EQ(c, abc.PopFirst(2));
  EXPECT_EQ(empty, abc.PopFirst(3));
  EXPECT_EQ(abc_dup, abc);
}

TEST(FieldPath, PopLast) {
  const FieldPath abc{"rooms", "Eros", "messages"};
  const FieldPath ab{"rooms", "Eros"};
  const FieldPath a{"rooms"};
  const FieldPath empty;
  const FieldPath abc_dup{"rooms", "Eros", "messages"};

  EXPECT_EQ(ab, abc.PopLast());
  EXPECT_EQ(a, abc.PopLast().PopLast());
  EXPECT_EQ(empty, abc.PopLast().PopLast().PopLast());
}

TEST(FieldPath, Concatenation) {
  const FieldPath path;
  const FieldPath a{"rooms"};
  const FieldPath ab{"rooms", "Eros"};
  const FieldPath abc{"rooms", "Eros", "messages"};

  EXPECT_EQ(a, path.Append("rooms"));
  EXPECT_EQ(ab, path.Append("rooms").Append("Eros"));
  EXPECT_EQ(abc, path.Append("rooms").Append("Eros").Append("messages"));
  EXPECT_EQ(abc, path.Append(FieldPath{"rooms", "Eros", "messages"}));
  EXPECT_EQ(abc, path.Append({"rooms", "Eros", "messages"}));

  const FieldPath bcd{"Eros", "messages", "this_week"};
  EXPECT_EQ(bcd, abc.PopFirst().Append("this_week"));
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
  ASSERT_ANY_THROW(path.first_segment());
  ASSERT_ANY_THROW(path.last_segment());
  ASSERT_ANY_THROW(path[0]);
  ASSERT_ANY_THROW(path[1]);
  ASSERT_ANY_THROW(path.PopFirst());
  ASSERT_ANY_THROW(path.PopFirst(2));
  ASSERT_ANY_THROW(path.PopLast());
}

TEST(FieldPath, Parsing) {
  const auto parse = [](const std::pair<std::string, size_t> expected) {
    const auto path = Parse(expected.first);
    return std::make_pair(path.CanonicalString(), path.size());
  };
  const auto make_expected = [](const std::string& str, const size_t size) {
    return std::make_pair(str, size);
  };

  auto expected = make_expected("foo", 1);
  EXPECT_EQ(expected, parse(expected));
  expected = make_expected("foo.bar", 2);
  EXPECT_EQ(expected, parse(expected));
  expected = make_expected("foo.bar.baz", 3);
  EXPECT_EQ(expected, parse(expected));
  expected = make_expected(R"(`.foo\\`)", 1);
  EXPECT_EQ(expected, parse(expected));
  expected = make_expected(R"(`.foo\\`.`.foo`)", 2);
  EXPECT_EQ(expected, parse(expected));
  expected = make_expected(R"(foo.`\``.bar)", 3);
  EXPECT_EQ(expected, parse(expected));

  const auto path_with_dot = Parse(R"(foo\.bar)");
  EXPECT_EQ(path_with_dot.CanonicalString(), "`foo.bar`");
  EXPECT_EQ(path_with_dot.size(), 1u);
}

// This is a special case in C++: std::string may contain embedded nulls. To
// fully mimic behavior of Objective-C code, parsing must terminate upon
// encountering the first null terminator in the string.
TEST(FieldPath, ParseEmbeddedNull) {
  std::string str{"foo"};
  str += '\0';
  str += ".bar";

  const auto path = Parse(str);
  EXPECT_EQ(path.size(), 1u);
  EXPECT_EQ(path.CanonicalString(), "foo");
}

TEST(FieldPath, ParseFailures) {
  ASSERT_NOT_OK(FieldPath::FromServerFormat(""));
  ASSERT_NOT_OK(FieldPath::FromServerFormat("."));
  ASSERT_NOT_OK(FieldPath::FromServerFormat(".."));
  ASSERT_NOT_OK(FieldPath::FromServerFormat("foo."));
  ASSERT_NOT_OK(FieldPath::FromServerFormat(".bar"));
  ASSERT_NOT_OK(FieldPath::FromServerFormat("foo..bar"));
  ASSERT_NOT_OK(FieldPath::FromServerFormat(R"(foo\)"));
  ASSERT_NOT_OK(FieldPath::FromServerFormat(R"(foo.\)"));
  ASSERT_NOT_OK(FieldPath::FromServerFormat("foo`"));
  ASSERT_NOT_OK(FieldPath::FromServerFormat("foo```"));
  ASSERT_NOT_OK(FieldPath::FromServerFormat("`foo"));
}

TEST(FieldPath, CanonicalStringOfSubstring) {
  const auto path = Parse("foo.bar.baz");
  EXPECT_EQ(path.CanonicalString(), "foo.bar.baz");
  EXPECT_EQ(path.PopFirst().CanonicalString(), "bar.baz");
  EXPECT_EQ(path.PopLast().CanonicalString(), "foo.bar");
  EXPECT_EQ(path.PopFirst().PopLast().CanonicalString(), "bar");
  EXPECT_EQ(path.PopFirst().PopLast().CanonicalString(), "bar");
  EXPECT_EQ(path.PopLast().PopFirst().PopLast().CanonicalString(), "");
}

TEST(FieldPath, CanonicalStringEscaping) {
  // Should be escaped
  EXPECT_EQ(Parse("1").CanonicalString(), "`1`");
  EXPECT_EQ(Parse("1ab").CanonicalString(), "`1ab`");
  EXPECT_EQ(Parse("ab!").CanonicalString(), "`ab!`");
  EXPECT_EQ(Parse("/ab").CanonicalString(), "`/ab`");
  EXPECT_EQ(Parse("a#b").CanonicalString(), "`a#b`");

  // Should not be escaped
  EXPECT_EQ(Parse("_ab").CanonicalString(), "_ab");
  EXPECT_EQ(Parse("a1").CanonicalString(), "a1");
  EXPECT_EQ(Parse("a_").CanonicalString(), "a_");
}

TEST(FieldPath, EmptyPath) {
  const auto& empty_path = FieldPath::EmptyPath();
  EXPECT_EQ(empty_path, FieldPath{empty_path});
  EXPECT_EQ(empty_path, FieldPath{});
  EXPECT_EQ(&empty_path, &FieldPath::EmptyPath());
}

TEST(FieldPath, KeyFieldPath) {
  const auto& key_field_path = FieldPath::KeyFieldPath();
  EXPECT_EQ(key_field_path, FieldPath{key_field_path});
  EXPECT_EQ(key_field_path, Parse(key_field_path.CanonicalString()));
  EXPECT_EQ(&key_field_path, &FieldPath::KeyFieldPath());
  EXPECT_NE(key_field_path, Parse(key_field_path.CanonicalString().substr(1)));
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
