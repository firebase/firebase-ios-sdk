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

#include "Firestore/core/src/model/document_key.h"

#include <initializer_list>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/util/comparison.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

using firebase::firestore::testutil::Key;

namespace firebase {
namespace firestore {
namespace model {

TEST(DocumentKey, Constructor_Empty) {
  const DocumentKey default_key;
  EXPECT_TRUE(default_key.path().empty());

  const auto& empty_key = DocumentKey::Empty();
  const auto& another_empty_key = DocumentKey::Empty();
  EXPECT_EQ(default_key, empty_key);
  EXPECT_EQ(empty_key, another_empty_key);
  EXPECT_EQ(&empty_key, &another_empty_key);
}

TEST(DocumentKey, Constructor_FromPath) {
  ResourcePath path{"rooms", "firestore", "messages", "1"};
  const DocumentKey key_from_path_copy{path};
  // path shouldn't have been moved from.
  EXPECT_FALSE(path.empty());
  EXPECT_EQ(key_from_path_copy.path(), path);

  const DocumentKey key_from_moved_path{std::move(path)};
  EXPECT_TRUE(path.empty());  // NOLINT: use after move intended
  EXPECT_FALSE(key_from_moved_path.path().empty());
  EXPECT_EQ(key_from_path_copy.path(), key_from_moved_path.path());
}

#if !__clang_analyzer__
TEST(DocumentKey, CopyAndMove) {
  DocumentKey key({"rooms", "firestore", "messages", "1"});
  const std::string path_string = "rooms/firestore/messages/1";
  EXPECT_EQ(path_string, key.path().CanonicalString());

  DocumentKey copied = key;
  EXPECT_EQ(path_string, copied.path().CanonicalString());
  EXPECT_EQ(key, copied);

  const DocumentKey moved = std::move(key);
  EXPECT_EQ(path_string, moved.path().CanonicalString());
  EXPECT_NE(key, moved);  // NOLINT: use after move intended
  EXPECT_TRUE(key.path().empty());

  // Reassignment.

  key = copied;
  EXPECT_EQ(copied, key);
  EXPECT_EQ(path_string, key.path().CanonicalString());

  key = {};
  EXPECT_TRUE(key.path().empty());
  key = std::move(copied);
  EXPECT_NE(copied, key);  // NOLINT: use after move intended
  EXPECT_TRUE(copied.path().empty());
  EXPECT_EQ(path_string, key.path().CanonicalString());
}
#endif  // !__clang_analyzer__

TEST(DocumentKey, Constructor_StaticFactory) {
  const auto key_from_segments =
      DocumentKey::FromSegments({"rooms", "firestore", "messages", "1"});
  const std::string path_string = "rooms/firestore/messages/1";
  const auto key_from_string = DocumentKey::FromPathString(path_string);
  EXPECT_EQ(path_string, key_from_string.path().CanonicalString());
  EXPECT_EQ(path_string, key_from_segments.path().CanonicalString());
  EXPECT_EQ(key_from_segments, key_from_string);

  const auto from_empty_path = DocumentKey::FromPathString("");
  EXPECT_EQ(from_empty_path, DocumentKey{});
}

TEST(DocumentKey, Constructor_BadArguments) {
  ASSERT_ANY_THROW(DocumentKey(ResourcePath{"foo"}));
  ASSERT_ANY_THROW(DocumentKey(ResourcePath{"foo", "bar", "baz"}));

  ASSERT_ANY_THROW(DocumentKey::FromSegments({"foo"}));
  ASSERT_ANY_THROW(DocumentKey::FromSegments({"foo", "bar", "baz"}));

  ASSERT_ANY_THROW(DocumentKey::FromPathString("invalid"));
  ASSERT_ANY_THROW(DocumentKey::FromPathString("invalid//string"));
  ASSERT_ANY_THROW(DocumentKey::FromPathString("invalid/key/path"));
}

TEST(DocumentKey, IsDocumentKey) {
  EXPECT_TRUE(DocumentKey::IsDocumentKey({}));
  EXPECT_FALSE(DocumentKey::IsDocumentKey({"foo"}));
  EXPECT_TRUE(DocumentKey::IsDocumentKey({"foo", "bar"}));
  EXPECT_FALSE(DocumentKey::IsDocumentKey({"foo", "bar", "baz"}));
}

TEST(DocumentKey, Comparison) {
  DocumentKey abcd = Key("a/b/c/d");
  DocumentKey abcd_too = Key("a/b/c/d");
  DocumentKey xyzw = Key("x/y/z/w");
  EXPECT_EQ(abcd, abcd_too);
  EXPECT_NE(abcd, xyzw);

  DocumentKey empty;
  DocumentKey a = Key("a/a");
  DocumentKey b = Key("b/b");
  DocumentKey ab = Key("a/a/b/b");

  EXPECT_FALSE(empty < empty);
  EXPECT_TRUE(empty <= empty);
  EXPECT_TRUE(empty < a);
  EXPECT_TRUE(empty <= a);
  EXPECT_TRUE(a > empty);
  EXPECT_TRUE(a >= empty);

  EXPECT_FALSE(a < a);
  EXPECT_TRUE(a <= a);
  EXPECT_FALSE(a > a);
  EXPECT_TRUE(a >= a);
  EXPECT_TRUE(a == a);
  EXPECT_FALSE(a != a);

  EXPECT_TRUE(a < b);
  EXPECT_TRUE(a <= b);
  EXPECT_TRUE(b > a);
  EXPECT_TRUE(b >= a);

  EXPECT_TRUE(a < ab);
  EXPECT_TRUE(a <= ab);
  EXPECT_TRUE(ab > a);
  EXPECT_TRUE(ab >= a);
}

TEST(DocumentKey, Comparator) {
  DocumentKey abcd = Key("a/b/c/d");
  DocumentKey xyzw = Key("x/y/z/w");
  util::Comparator<DocumentKey> comparator;
  EXPECT_EQ(comparator.Compare(abcd, xyzw), util::ComparisonResult::Ascending);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
