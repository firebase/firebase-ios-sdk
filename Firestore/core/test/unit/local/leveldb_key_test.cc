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

#include "Firestore/core/src/local/leveldb_key.h"

#include <type_traits>

#include "Firestore/core/src/util/autoid.h"
#include "Firestore/core/src/util/string_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/strings/match.h"
#include "gtest/gtest.h"

using firebase::firestore::model::BatchId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;

namespace firebase {
namespace firestore {
namespace local {

namespace {

std::string RemoteDocKey(absl::string_view path_string) {
  return LevelDbRemoteDocumentKey::Key(testutil::Key(path_string));
}

std::string RemoteDocKeyPrefix(absl::string_view path_string) {
  return LevelDbRemoteDocumentKey::KeyPrefix(testutil::Resource(path_string));
}

std::string DocMutationKey(absl::string_view user_id,
                           absl::string_view key,
                           BatchId batch_id) {
  return LevelDbDocumentMutationKey::Key(user_id, testutil::Key(key), batch_id);
}

std::string TargetDocKey(TargetId target_id, absl::string_view key) {
  return LevelDbTargetDocumentKey::Key(target_id, testutil::Key(key));
}

std::string DocTargetKey(absl::string_view key, TargetId target_id) {
  return LevelDbDocumentTargetKey::Key(testutil::Key(key), target_id);
}

std::string RemoteDocumentReadTimeKeyPrefix(absl::string_view collection_path,
                                            int64_t version) {
  return LevelDbRemoteDocumentReadTimeKey::KeyPrefix(
      testutil::Resource(collection_path), testutil::Version(version));
}

std::string RemoteDocumentReadTimeKey(absl::string_view collection_path,
                                      int64_t version,
                                      absl::string_view document_id) {
  return LevelDbRemoteDocumentReadTimeKey::Key(
      testutil::Resource(collection_path), testutil::Version(version),
      document_id);
}

}  // namespace

/**
 * Asserts that the description for given key is equal to the expected
 * description.
 *
 * @param key A StringView of a textual key
 * @param key A string that `Describe(key)` is expected to produce.
 */
#define AssertExpectedKeyDescription(expected_description, key) \
  ASSERT_EQ((expected_description), DescribeKey(key))

TEST(LevelDbMutationKeyTest, Prefixing) {
  auto table_key = LevelDbMutationKey::KeyPrefix();
  auto empty_user_key = LevelDbMutationKey::KeyPrefix("");
  auto foo_user_key = LevelDbMutationKey::KeyPrefix("foo");

  auto foo2_key = LevelDbMutationKey::Key("foo", 2);

  ASSERT_TRUE(absl::StartsWith(empty_user_key, table_key));

  // This is critical: prefixes of the a value don't convert into prefixes of
  // the key.
  ASSERT_TRUE(absl::StartsWith(foo_user_key, table_key));
  ASSERT_FALSE(absl::StartsWith(foo_user_key, empty_user_key));

  // However whole segments in common are prefixes.
  ASSERT_TRUE(absl::StartsWith(foo2_key, table_key));
  ASSERT_TRUE(absl::StartsWith(foo2_key, foo_user_key));
}

TEST(LevelDbMutationKeyTest, EncodeDecodeCycle) {
  LevelDbMutationKey key;
  std::string user("foo");

  std::vector<BatchId> batch_ids{0, 1, 100, INT_MAX - 1, INT_MAX};
  for (auto batch_id : batch_ids) {
    auto encoded = LevelDbMutationKey::Key(user, batch_id);

    bool ok = key.Decode(encoded);
    ASSERT_TRUE(ok);
    ASSERT_EQ(user, key.user_id());
    ASSERT_EQ(batch_id, key.batch_id());
  }
}

TEST(LevelDbMutationKeyTest, Description) {
  AssertExpectedKeyDescription("[mutation: incomplete key]",
                               LevelDbMutationKey::KeyPrefix());

  AssertExpectedKeyDescription("[mutation: user_id=user1 incomplete key]",
                               LevelDbMutationKey::KeyPrefix("user1"));

  auto key = LevelDbMutationKey::Key("user1", 42);
  AssertExpectedKeyDescription("[mutation: user_id=user1 batch_id=42]", key);

  AssertExpectedKeyDescription(
      "[mutation: user_id=user1 batch_id=42 invalid "
      "key=<hW11dGF0aW9uAAGNdXNlcjEAAYqqgCBleHRyYQ==>]",
      key + " extra");

  // Truncate the key so that it's missing its terminator.
  key.resize(key.size() - 1);
  AssertExpectedKeyDescription(
      "[mutation: user_id=user1 batch_id=42 incomplete key]", key);
}

TEST(LevelDbDocumentMutationKeyTest, Prefixing) {
  auto table_key = LevelDbDocumentMutationKey::KeyPrefix();
  auto empty_user_key = LevelDbDocumentMutationKey::KeyPrefix("");
  auto foo_user_key = LevelDbDocumentMutationKey::KeyPrefix("foo");

  DocumentKey document_key = testutil::Key("foo/bar");
  auto foo2_key = LevelDbDocumentMutationKey::Key("foo", document_key, 2);

  ASSERT_TRUE(absl::StartsWith(empty_user_key, table_key));

  // While we want a key with whole segments in common be considered a prefix
  // it's vital that partial segments in common not be prefixes.
  ASSERT_TRUE(absl::StartsWith(foo_user_key, table_key));

  // Here even though "" is a prefix of "foo", that prefix is within a segment,
  // so keys derived from those segments cannot be prefixes of each other.
  ASSERT_FALSE(absl::StartsWith(foo_user_key, empty_user_key));
  ASSERT_FALSE(absl::StartsWith(empty_user_key, foo_user_key));

  // However whole segments in common are prefixes.
  ASSERT_TRUE(absl::StartsWith(foo2_key, table_key));
  ASSERT_TRUE(absl::StartsWith(foo2_key, foo_user_key));
}

TEST(LevelDbDocumentMutationKeyTest, EncodeDecodeCycle) {
  LevelDbDocumentMutationKey key;
  std::string user("foo");

  std::vector<DocumentKey> document_keys{testutil::Key("a/b"),
                                         testutil::Key("a/b/c/d")};

  std::vector<BatchId> batch_ids{0, 1, 100, INT_MAX - 1, INT_MAX};

  for (BatchId batch_id : batch_ids) {
    for (auto&& document_key : document_keys) {
      auto encoded =
          LevelDbDocumentMutationKey::Key(user, document_key, batch_id);

      bool ok = key.Decode(encoded);
      ASSERT_TRUE(ok);
      ASSERT_EQ(user, key.user_id());
      ASSERT_EQ(document_key, key.document_key());
      ASSERT_EQ(batch_id, key.batch_id());
    }
  }
}

TEST(LevelDbDocumentMutationKeyTest, Ordering) {
  // Different user:
  ASSERT_LT(DocMutationKey("1", "foo/bar", 0),
            DocMutationKey("10", "foo/bar", 0));
  ASSERT_LT(DocMutationKey("1", "foo/bar", 0),
            DocMutationKey("2", "foo/bar", 0));

  // Different paths:
  ASSERT_LT(DocMutationKey("1", "foo/bar", 0),
            DocMutationKey("1", "foo/baz", 0));
  ASSERT_LT(DocMutationKey("1", "foo/bar", 0),
            DocMutationKey("1", "foo/bar2", 0));
  ASSERT_LT(DocMutationKey("1", "foo/bar", 0),
            DocMutationKey("1", "foo/bar/suffix/key", 0));
  ASSERT_LT(DocMutationKey("1", "foo/bar/suffix/key", 0),
            DocMutationKey("1", "foo/bar2", 0));

  // Different batch_id:
  ASSERT_LT(DocMutationKey("1", "foo/bar", 0),
            DocMutationKey("1", "foo/bar", 1));
}

TEST(LevelDbDocumentMutationKeyTest, Description) {
  AssertExpectedKeyDescription("[document_mutation: incomplete key]",
                               LevelDbDocumentMutationKey::KeyPrefix());

  AssertExpectedKeyDescription(
      "[document_mutation: user_id=user1 incomplete key]",
      LevelDbDocumentMutationKey::KeyPrefix("user1"));

  auto key = LevelDbDocumentMutationKey::KeyPrefix(
      "user1", testutil::Resource("foo/bar"));
  AssertExpectedKeyDescription(
      "[document_mutation: user_id=user1 path=foo/bar incomplete key]", key);

  key = LevelDbDocumentMutationKey::Key("user1", testutil::Key("foo/bar"), 42);
  AssertExpectedKeyDescription(
      "[document_mutation: user_id=user1 path=foo/bar batch_id=42]", key);
}

TEST(LevelDbTargetGlobalKeyTest, EncodeDecodeCycle) {
  LevelDbTargetGlobalKey key;

  auto encoded = LevelDbTargetGlobalKey::Key();
  bool ok = key.Decode(encoded);
  ASSERT_TRUE(ok);
}

TEST(LevelDbTargetGlobalKeyTest, Description) {
  AssertExpectedKeyDescription("[target_global:]",
                               LevelDbTargetGlobalKey::Key());
}

TEST(LevelDbTargetKeyTest, EncodeDecodeCycle) {
  LevelDbTargetKey key;
  TargetId target_id = 42;

  auto encoded = LevelDbTargetKey::Key(42);
  bool ok = key.Decode(encoded);
  ASSERT_TRUE(ok);
  ASSERT_EQ(target_id, key.target_id());
}

TEST(LevelDbTargetKeyTest, Description) {
  AssertExpectedKeyDescription("[target: target_id=42]",
                               LevelDbTargetKey::Key(42));
}

TEST(LevelDbQueryTargetKeyTest, EncodeDecodeCycle) {
  LevelDbQueryTargetKey key;
  std::string canonical_id("foo");
  TargetId target_id = 42;

  auto encoded = LevelDbQueryTargetKey::Key(canonical_id, 42);
  bool ok = key.Decode(encoded);
  ASSERT_TRUE(ok);
  ASSERT_EQ(canonical_id, key.canonical_id());
  ASSERT_EQ(target_id, key.target_id());
}

TEST(LevelDbQueryKeyTest, Description) {
  AssertExpectedKeyDescription("[query_target: canonical_id=foo target_id=42]",
                               LevelDbQueryTargetKey::Key("foo", 42));
}

TEST(TargetDocumentKeyTest, EncodeDecodeCycle) {
  LevelDbTargetDocumentKey key;

  auto encoded = LevelDbTargetDocumentKey::Key(42, testutil::Key("foo/bar"));
  bool ok = key.Decode(encoded);
  ASSERT_TRUE(ok);
  ASSERT_EQ(42, key.target_id());
  ASSERT_EQ(testutil::Key("foo/bar"), key.document_key());
}

TEST(TargetDocumentKeyTest, Ordering) {
  // Different target_id:
  ASSERT_LT(TargetDocKey(1, "foo/bar"), TargetDocKey(2, "foo/bar"));
  ASSERT_LT(TargetDocKey(2, "foo/bar"), TargetDocKey(10, "foo/bar"));
  ASSERT_LT(TargetDocKey(10, "foo/bar"), TargetDocKey(100, "foo/bar"));
  ASSERT_LT(TargetDocKey(42, "foo/bar"), TargetDocKey(100, "foo/bar"));

  // Different paths:
  ASSERT_LT(TargetDocKey(1, "foo/bar"), TargetDocKey(1, "foo/baz"));
  ASSERT_LT(TargetDocKey(1, "foo/bar"), TargetDocKey(1, "foo/bar2"));
  ASSERT_LT(TargetDocKey(1, "foo/bar"), TargetDocKey(1, "foo/bar/suffix/key"));
  ASSERT_LT(TargetDocKey(1, "foo/bar/suffix/key"), TargetDocKey(1, "foo/bar2"));
}

TEST(TargetDocumentKeyTest, Description) {
  auto key = LevelDbTargetDocumentKey::Key(42, testutil::Key("foo/bar"));
  ASSERT_EQ("[target_document: target_id=42 path=foo/bar]", DescribeKey(key));
}

TEST(DocumentTargetKeyTest, EncodeDecodeCycle) {
  LevelDbDocumentTargetKey key;

  auto encoded = LevelDbDocumentTargetKey::Key(testutil::Key("foo/bar"), 42);
  bool ok = key.Decode(encoded);
  ASSERT_TRUE(ok);
  ASSERT_EQ(testutil::Key("foo/bar"), key.document_key());
  ASSERT_EQ(42, key.target_id());
}

TEST(DocumentTargetKeyTest, Description) {
  auto key = LevelDbDocumentTargetKey::Key(testutil::Key("foo/bar"), 42);
  ASSERT_EQ("[document_target: path=foo/bar target_id=42]", DescribeKey(key));
}

TEST(DocumentTargetKeyTest, Ordering) {
  // Different paths:
  ASSERT_LT(DocTargetKey("foo/bar", 1), DocTargetKey("foo/baz", 1));
  ASSERT_LT(DocTargetKey("foo/bar", 1), DocTargetKey("foo/bar2", 1));
  ASSERT_LT(DocTargetKey("foo/bar", 1), DocTargetKey("foo/bar/suffix/key", 1));
  ASSERT_LT(DocTargetKey("foo/bar/suffix/key", 1), DocTargetKey("foo/bar2", 1));

  // Different target_id:
  ASSERT_LT(DocTargetKey("foo/bar", 1), DocTargetKey("foo/bar", 2));
  ASSERT_LT(DocTargetKey("foo/bar", 2), DocTargetKey("foo/bar", 10));
  ASSERT_LT(DocTargetKey("foo/bar", 10), DocTargetKey("foo/bar", 100));
  ASSERT_LT(DocTargetKey("foo/bar", 42), DocTargetKey("foo/bar", 100));
}

TEST(RemoteDocumentKeyTest, Prefixing) {
  auto table_key = LevelDbRemoteDocumentKey::KeyPrefix();

  ASSERT_TRUE(absl::StartsWith(RemoteDocKey("foo/bar"), table_key));

  // This is critical: foo/bar2 should not contain foo/bar.
  ASSERT_FALSE(
      absl::StartsWith(RemoteDocKey("foo/bar2"), RemoteDocKey("foo/bar")));

  // Prefixes must be encoded specially
  ASSERT_FALSE(absl::StartsWith(RemoteDocKey("foo/bar/baz/quu"),
                                RemoteDocKey("foo/bar")));
  ASSERT_TRUE(absl::StartsWith(RemoteDocKey("foo/bar/baz/quu"),
                               RemoteDocKeyPrefix("foo/bar")));
  ASSERT_TRUE(absl::StartsWith(RemoteDocKeyPrefix("foo/bar/baz/quu"),
                               RemoteDocKeyPrefix("foo/bar")));
  ASSERT_TRUE(absl::StartsWith(RemoteDocKeyPrefix("foo/bar/baz"),
                               RemoteDocKeyPrefix("foo/bar")));
  ASSERT_TRUE(absl::StartsWith(RemoteDocKeyPrefix("foo/bar"),
                               RemoteDocKeyPrefix("foo")));
}

TEST(RemoteDocumentKeyTest, Ordering) {
  ASSERT_LT(RemoteDocKey("foo/bar"), RemoteDocKey("foo/bar2"));
  ASSERT_LT(RemoteDocKey("foo/bar"), RemoteDocKey("foo/bar/suffix/key"));
}

TEST(RemoteDocumentKeyTest, EncodeDecodeCycle) {
  LevelDbRemoteDocumentKey key;

  std::vector<std::string> paths{"foo/bar", "foo/bar2", "foo/bar/baz/quux"};
  for (auto&& path : paths) {
    auto encoded = RemoteDocKey(path);
    bool ok = key.Decode(encoded);
    ASSERT_TRUE(ok);
    ASSERT_EQ(testutil::Key(path), key.document_key());
  }
}

TEST(RemoteDocumentKeyTest, Description) {
  AssertExpectedKeyDescription(
      "[remote_document: path=foo/bar/baz/quux]",
      LevelDbRemoteDocumentKey::Key(testutil::Key("foo/bar/baz/quux")));
}

TEST(RemoteDocumentReadTimeKeyTest, Ordering) {
  // Different collection paths:
  ASSERT_LT(RemoteDocumentReadTimeKeyPrefix("bar", 1),
            RemoteDocumentReadTimeKeyPrefix("baz", 1));
  ASSERT_LT(RemoteDocumentReadTimeKeyPrefix("bar", 1),
            RemoteDocumentReadTimeKeyPrefix("foo/doc/bar", 1));
  ASSERT_LT(RemoteDocumentReadTimeKeyPrefix("foo/doc/bar", 1),
            RemoteDocumentReadTimeKeyPrefix("foo/doc/baz", 1));

  // Different read times:
  ASSERT_LT(RemoteDocumentReadTimeKeyPrefix("foo", 1),
            RemoteDocumentReadTimeKeyPrefix("foo", 2));
  ASSERT_LT(RemoteDocumentReadTimeKeyPrefix("foo", 1),
            RemoteDocumentReadTimeKeyPrefix("foo", 1000000));
  ASSERT_LT(RemoteDocumentReadTimeKeyPrefix("foo", 1000000),
            RemoteDocumentReadTimeKeyPrefix("foo", 1000001));

  // Different document ids:
  ASSERT_LT(RemoteDocumentReadTimeKey("foo", 1, "a"),
            RemoteDocumentReadTimeKey("foo", 1, "b"));
}

TEST(RemoteDocumentReadTimeKeyTest, EncodeDecodeCycle) {
  LevelDbRemoteDocumentReadTimeKey key;

  std::vector<std::string> collection_paths{"foo", "foo/doc/bar",
                                            "foo/doc/bar/doc/baz"};
  std::vector<int64_t> versions{1, 1000000, 1000001};
  std::vector<std::string> document_ids{"docA", "docB"};

  for (const auto& collection_path : collection_paths) {
    for (auto version : versions) {
      for (const auto& document_id : document_ids) {
        auto encoded =
            RemoteDocumentReadTimeKey(collection_path, version, document_id);
        bool ok = key.Decode(encoded);
        ASSERT_TRUE(ok);
        ASSERT_EQ(testutil::Resource(collection_path), key.collection_path());
        ASSERT_EQ(testutil::Version(version), key.read_time());
        ASSERT_EQ(document_id, key.document_id());
      }
    }
  }
}

TEST(RemoteDocumentReadTimeKeyTest, Description) {
  AssertExpectedKeyDescription(
      "[remote_document_read_time: path=coll "
      "snapshot_version=Timestamp(seconds=1, nanoseconds=1000) "
      "document_id=doc]",
      RemoteDocumentReadTimeKey("coll", 1000001, "doc"));
}

TEST(BundleKeyTest, Prefixing) {
  auto table_key = LevelDbBundleKey::KeyPrefix();

  ASSERT_TRUE(absl::StartsWith(LevelDbBundleKey::Key("foo/bar"), table_key));

  ASSERT_FALSE(absl::StartsWith(LevelDbBundleKey::Key("foo/bar2"),
                                LevelDbBundleKey::Key("foo/bar")));
}

TEST(BundleKeyTest, Ordering) {
  ASSERT_LT(LevelDbBundleKey::Key("foo/bar"),
            LevelDbBundleKey::Key("foo/bar2"));
  ASSERT_LT(LevelDbBundleKey::Key("foo/bar"),
            LevelDbBundleKey::Key("foo/bar/suffix/key"));
}

TEST(BundleKeyTest, EncodeDecodeCycle) {
  LevelDbBundleKey key;

  std::vector<std::string> ids{"foo", "bar", "foo-bar?baz!quux"};
  for (auto&& id : ids) {
    auto encoded = LevelDbBundleKey::Key(id);
    bool ok = key.Decode(encoded);
    ASSERT_TRUE(ok);
    ASSERT_EQ(id, key.bundle_id());
  }
}

TEST(BundleKeyTest, Description) {
  AssertExpectedKeyDescription("[bundles: bundle_id=foo-bar?baz!quux]",
                               LevelDbBundleKey::Key("foo-bar?baz!quux"));
}

TEST(NamedQueryKeyTest, Prefixing) {
  auto table_key = LevelDbNamedQueryKey::KeyPrefix();

  ASSERT_TRUE(
      absl::StartsWith(LevelDbNamedQueryKey::Key("foo-bar"), table_key));

  ASSERT_FALSE(absl::StartsWith(LevelDbNamedQueryKey::Key("foo-bar2"),
                                LevelDbNamedQueryKey::Key("foo-bar")));
}

TEST(NamedQueryKeyTest, Ordering) {
  ASSERT_LT(LevelDbNamedQueryKey::Key("foo/bar"),
            LevelDbNamedQueryKey::Key("foo/bar2"));
  ASSERT_LT(LevelDbNamedQueryKey::Key("foo/bar"),
            LevelDbNamedQueryKey::Key("foo/bar/suffix/key"));
}

TEST(NamedQueryKeyTest, EncodeDecodeCycle) {
  LevelDbNamedQueryKey key;

  std::vector<std::string> names{"foo/bar", "foo/bar2", "foo-bar?baz!quux"};
  for (auto&& name : names) {
    auto encoded = LevelDbNamedQueryKey::Key(name);
    bool ok = key.Decode(encoded);
    ASSERT_TRUE(ok);
    ASSERT_EQ(name, key.name());
  }
}

TEST(NamedQueryKeyTest, Description) {
  AssertExpectedKeyDescription("[named_queries: query_name=foo-bar?baz!quux]",
                               LevelDbNamedQueryKey::Key("foo-bar?baz!quux"));
}

TEST(IndexConfigurationKeyTest, Prefixing) {
  auto table_key = LevelDbIndexConfigurationKey::KeyPrefix();

  ASSERT_TRUE(
      absl::StartsWith(LevelDbIndexConfigurationKey::Key(0, ""), table_key));

  ASSERT_FALSE(absl::StartsWith(LevelDbIndexConfigurationKey::Key(1, ""),
                                LevelDbIndexConfigurationKey::Key(2, "")));

  ASSERT_FALSE(absl::StartsWith(LevelDbIndexConfigurationKey::Key(1, "g"),
                                LevelDbIndexConfigurationKey::Key(1, "ag")));
}

TEST(IndexConfigurationKeyTest, Ordering) {
  ASSERT_LT(LevelDbIndexConfigurationKey::Key(0, ""),
            LevelDbIndexConfigurationKey::Key(1, ""));
  ASSERT_EQ(LevelDbIndexConfigurationKey::Key(1, ""),
            LevelDbIndexConfigurationKey::Key(1, ""));
  ASSERT_LT(LevelDbIndexConfigurationKey::Key(0, "a"),
            LevelDbIndexConfigurationKey::Key(0, "b"));
  ASSERT_EQ(LevelDbIndexConfigurationKey::Key(1, "a"),
            LevelDbIndexConfigurationKey::Key(1, "a"));
}

TEST(IndexConfigurationKeyTest, EncodeDecodeCycle) {
  LevelDbIndexConfigurationKey key;

  std::vector<std::string> groups = {
      "",
      "ab",
      "12",
      ",867t-b",
      "汉语; traditional Chinese: 漢語; pinyin: Hànyǔ[b]",
      "اَلْعَرَبِيَّةُ, al-ʿarabiyyah "};
  for (int32_t id = -5; id < 10; ++id) {
    auto s = groups[(id + 5) % groups.size()];
    auto encoded = LevelDbIndexConfigurationKey::Key(id, s);
    bool ok = key.Decode(encoded);
    ASSERT_TRUE(ok);
    ASSERT_EQ(id, key.index_id());
    ASSERT_EQ(s, key.collection_group());
  }
}

TEST(IndexConfigurationKeyTest, Description) {
  AssertExpectedKeyDescription(
      "[index_configuration: index_id=8 collection_group=group]",
      LevelDbIndexConfigurationKey::Key(8, "group"));
}

TEST(IndexStateKeyTest, Prefixing) {
  auto table_key = LevelDbIndexStateKey::KeyPrefix();

  ASSERT_TRUE(
      absl::StartsWith(LevelDbIndexStateKey::Key("user_a", 0), table_key));

  ASSERT_FALSE(absl::StartsWith(LevelDbIndexStateKey::Key("user_a", 0),
                                LevelDbIndexStateKey::Key("user_b", 0)));
  ASSERT_FALSE(absl::StartsWith(LevelDbIndexStateKey::Key("user_a", 0),
                                LevelDbIndexStateKey::Key("user_a", 1)));
}

TEST(IndexStateKeyTest, Ordering) {
  ASSERT_LT(LevelDbIndexStateKey::Key("foo/bar", 0),
            LevelDbIndexStateKey::Key("foo/bar", 1));
  ASSERT_LT(LevelDbIndexStateKey::Key("foo/bar", 0),
            LevelDbIndexStateKey::Key("foo/bar1", 0));
}

TEST(IndexStateKeyTest, EncodeDecodeCycle) {
  LevelDbIndexStateKey key;

  std::vector<std::pair<std::string, int32_t>> ids{
      {"foo/bar", 0}, {"foo/bar2", 1}, {"foo-bar?baz!quux", -1}};
  for (auto&& id : ids) {
    auto encoded = LevelDbIndexStateKey::Key(id.first, id.second);
    bool ok = key.Decode(encoded);
    ASSERT_TRUE(ok);
    ASSERT_EQ(id.first, key.user_id());
    ASSERT_EQ(id.second, key.index_id());
  }
}

TEST(IndexStateKeyTest, Description) {
  AssertExpectedKeyDescription(
      "[index_state: user_id=foo-bar?baz!quux index_id=99]",
      LevelDbIndexStateKey::Key("foo-bar?baz!quux", 99));
}

TEST(IndexEntryKeyTest, Prefixing) {
  auto table_key = LevelDbIndexEntryKey::KeyPrefix();

  ASSERT_TRUE(absl::StartsWith(
      LevelDbIndexEntryKey::Key(0, "user_id", "array_value_encoded",
                                "directional_value_encoded", "document_id_99"),
      table_key));

  ASSERT_TRUE(
      absl::StartsWith(LevelDbIndexEntryKey::Key(0, "user_id", "", "", ""),
                       LevelDbIndexEntryKey::KeyPrefix(0)));

  ASSERT_FALSE(absl::StartsWith(LevelDbIndexEntryKey::Key(0, "", "", "", ""),
                                LevelDbIndexEntryKey::Key(1, "", "", "", "")));
}

TEST(IndexEntryKeyTest, Ordering) {
  std::vector<std::string> entries = {
      LevelDbIndexEntryKey::Key(-1, "", "", "", ""),
      LevelDbIndexEntryKey::Key(0, "", "", "", ""),
      LevelDbIndexEntryKey::Key(0, "u", "", "", ""),
      LevelDbIndexEntryKey::Key(0, "v", "", "", ""),
      LevelDbIndexEntryKey::Key(0, "v", "a", "", ""),
      LevelDbIndexEntryKey::Key(0, "v", "b", "", ""),
      LevelDbIndexEntryKey::Key(0, "v", "b", "d", ""),
      LevelDbIndexEntryKey::Key(0, "v", "b", "e", ""),
      LevelDbIndexEntryKey::Key(0, "v", "b", "e", "doc"),
      LevelDbIndexEntryKey::Key(0, "v", "b", "e", "eoc"),
  };

  for (size_t i = 0; i < entries.size() - 1; ++i) {
    auto& left = entries[i];
    auto& right = entries[i + 1];
    ASSERT_LT(left, right);
  }
}

TEST(IndexEntryKeyTest, EncodeDecodeCycle) {
  LevelDbIndexEntryKey key;

  struct IndexEntry {
    int32_t index_id;
    std::string user_id;
    std::string array_value;
    std::string dir_value;
    std::string document_name;
  };

  std::vector<IndexEntry> entries = {
      {-1, "", "", "", ""},
      {0, "foo", "bar", "baz", "did"},
      {999, "u", "foo-bar?baz!quux", "", ""},
      {-999, "u",
       "اَلْعَرَبِيَّةُ, al-ʿarabiyyah [al ʕaraˈbijːa] (audio speaker iconlisten) or "
       "عَرَبِيّ, ʿarabīy",
       "汉语; traditional Chinese: 漢語; pinyin: Hànyǔ[b] or also 中文", "doc"},
  };

  for (auto&& entry : entries) {
    auto encoded = LevelDbIndexEntryKey::Key(entry.index_id, entry.user_id,
                                             entry.array_value, entry.dir_value,
                                             entry.document_name);
    bool ok = key.Decode(encoded);
    ASSERT_TRUE(ok);
    ASSERT_EQ(entry.index_id, key.index_id());
    ASSERT_EQ(entry.user_id, key.user_id());
    ASSERT_EQ(entry.array_value, key.array_value());
    ASSERT_EQ(entry.dir_value, key.directional_value());
    ASSERT_EQ(entry.document_name, key.document_key());
  }
}

TEST(IndexEntryKeyTest, Description) {
  AssertExpectedKeyDescription(
      "[index_entries: index_id=1 user_id=user array_value=array "
      "directional_value=directional document_id=foo-bar?baz!quux]",
      LevelDbIndexEntryKey::Key(1, "user", "array", "directional",
                                "foo-bar?baz!quux"));
}

TEST(LevelDbDocumentOverlayKeyTest, Constructor) {
  LevelDbDocumentOverlayKey key("test_user", testutil::Key("coll/doc"), 123);
  EXPECT_EQ(key.user_id(), "test_user");
  EXPECT_EQ(key.document_key(), testutil::Key("coll/doc"));
  EXPECT_EQ(key.largest_batch_id(), 123);
}

TEST(LevelDbDocumentOverlayKeyTest, RvalueOverloadedGetters) {
  LevelDbDocumentOverlayKey key("test_user", testutil::Key("coll/doc"), 123);
  model::DocumentKey&& document_key = std::move(key).document_key();
  EXPECT_EQ(document_key, testutil::Key("coll/doc"));
}

TEST(LevelDbDocumentOverlayKeyTest, Encode) {
  LevelDbDocumentOverlayKey key("test_user", testutil::Key("coll/doc"), 123);
  const std::string encoded_key = key.Encode();
  LevelDbDocumentOverlayKey decoded_key;
  ASSERT_TRUE(decoded_key.Decode(encoded_key));
  EXPECT_EQ(decoded_key.user_id(), "test_user");
  EXPECT_EQ(decoded_key.document_key(), testutil::Key("coll/doc"));
  EXPECT_EQ(decoded_key.largest_batch_id(), 123);
}

TEST(LevelDbDocumentOverlayKeyTest, Prefixing) {
  const std::string user1_key =
      LevelDbDocumentOverlayKey::KeyPrefix("test_user1");
  const std::string user2_key =
      LevelDbDocumentOverlayKey::KeyPrefix("test_user2");
  const std::string user1_doc1_key = LevelDbDocumentOverlayKey::KeyPrefix(
      "test_user1", testutil::Key("coll/doc1"));
  const std::string user2_doc2_key = LevelDbDocumentOverlayKey::KeyPrefix(
      "test_user2", testutil::Key("coll/doc2"));
  const std::string user1_doc2_key = LevelDbDocumentOverlayKey::KeyPrefix(
      "test_user1", testutil::Key("coll/doc2"));
  ASSERT_TRUE(absl::StartsWith(user1_doc1_key, user1_key));
  ASSERT_TRUE(absl::StartsWith(user2_doc2_key, user2_key));
  ASSERT_FALSE(absl::StartsWith(user1_key, user2_key));
  ASSERT_FALSE(absl::StartsWith(user2_key, user1_key));
  ASSERT_FALSE(absl::StartsWith(user1_doc1_key, user1_doc2_key));
  ASSERT_FALSE(absl::StartsWith(user1_doc2_key, user1_doc1_key));

  const std::string user1_doc1_batch_1_key = LevelDbDocumentOverlayKey::Key(
      "test_user1", testutil::Key("coll/doc1"), 1);
  const std::string user2_doc1_batch_1_key = LevelDbDocumentOverlayKey::Key(
      "test_user2", testutil::Key("coll/doc1"), 1);
  ASSERT_TRUE(absl::StartsWith(user1_doc1_batch_1_key, user1_key));
  ASSERT_TRUE(absl::StartsWith(user2_doc1_batch_1_key, user2_key));
}

TEST(LevelDbDocumentOverlayKeyTest, Ordering) {
  const std::string user1_doc1_batch_1_key = LevelDbDocumentOverlayKey::Key(
      "test_user1", testutil::Key("coll/doc1"), 1);
  const std::string user2_doc1_batch_1_key = LevelDbDocumentOverlayKey::Key(
      "test_user2", testutil::Key("coll/doc1"), 1);
  const std::string user1_doc2_batch_1_key = LevelDbDocumentOverlayKey::Key(
      "test_user1", testutil::Key("coll/doc2"), 1);
  const std::string user1_doc1_batch_2_key = LevelDbDocumentOverlayKey::Key(
      "test_user1", testutil::Key("coll/doc1"), 2);

  ASSERT_LT(user1_doc1_batch_1_key, user2_doc1_batch_1_key);
  ASSERT_LT(user1_doc1_batch_1_key, user1_doc2_batch_1_key);
  ASSERT_LT(user1_doc1_batch_1_key, user1_doc1_batch_2_key);
}

TEST(LevelDbDocumentOverlayKeyTest, EncodeDecodeCycle) {
  const std::vector<std::string> user_ids{"test_user", "foo/bar2",
                                          "foo-bar?baz!quux"};
  const std::vector<std::string> document_keys{"col1/doc1",
                                               "col2/doc2/col3/doc3"};
  const std::vector<BatchId> batch_ids{1, 2, 3};
  for (const std::string& user_id : user_ids) {
    for (const std::string& document_key : document_keys) {
      for (BatchId batch_id : batch_ids) {
        SCOPED_TRACE(absl::StrCat("user_name=", user_id,
                                  " document_key=", document_key,
                                  " largest_batch_id=", batch_id));
        const std::string encoded = LevelDbDocumentOverlayKey::Key(
            user_id, testutil::Key(document_key), batch_id);
        LevelDbDocumentOverlayKey key;
        EXPECT_TRUE(key.Decode(encoded));
        EXPECT_EQ(key.user_id(), user_id);
        EXPECT_EQ(key.document_key(), testutil::Key(document_key));
        EXPECT_EQ(key.largest_batch_id(), batch_id);
      }
    }
  }
}

TEST(LevelDbDocumentOverlayKeyTest, Description) {
  AssertExpectedKeyDescription(
      "[document_overlays: user_id=foo-bar?baz!quux path=coll/doc "
      "batch_id=123]",
      LevelDbDocumentOverlayKey::Key("foo-bar?baz!quux",
                                     testutil::Key("coll/doc"), 123));
}

TEST(LevelDbDocumentOverlayIndexKeyTest, TypeTraits) {
  static_assert(
      std::has_virtual_destructor<LevelDbDocumentOverlayIndexKey>::value,
      "LevelDbDocumentOverlayIndexKey should have a virtual destructor");
}

TEST(LevelDbDocumentOverlayIndexKeyTest, ToLevelDbDocumentOverlayKey) {
  LevelDbDocumentOverlayIndexKey index_key;
  index_key.Reset("test_user", 123, testutil::Key("coll/doc1"));
  LevelDbDocumentOverlayKey key = index_key.ToLevelDbDocumentOverlayKey();
  EXPECT_EQ(key.user_id(), "test_user");
  EXPECT_EQ(key.largest_batch_id(), 123);
  EXPECT_EQ(key.document_key(), testutil::Key("coll/doc1"));
}

TEST(LevelDbDocumentOverlayIndexKeyTest, ToLevelDbDocumentOverlayKeyRvalue) {
  LevelDbDocumentOverlayIndexKey index_key;
  index_key.Reset("test_user", 123, testutil::Key("coll/doc1"));
  LevelDbDocumentOverlayKey key =
      std::move(index_key).ToLevelDbDocumentOverlayKey();
  EXPECT_EQ(key.user_id(), "test_user");
  EXPECT_EQ(key.largest_batch_id(), 123);
  EXPECT_EQ(key.document_key(), testutil::Key("coll/doc1"));
}

TEST(LevelDbDocumentOverlayIndexKeyTest, Getters) {
  LevelDbDocumentOverlayIndexKey key;
  key.Reset("test_user", 123, testutil::Key("coll/doc1"));
  EXPECT_EQ(key.user_id(), "test_user");
  EXPECT_EQ(key.largest_batch_id(), 123);
  EXPECT_EQ(key.document_key(), testutil::Key("coll/doc1"));
}

TEST(LevelDbDocumentOverlayLargestBatchIdIndexKeyTest, Prefixing) {
  const std::string user1_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::KeyPrefix("test_user1");
  const std::string user2_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::KeyPrefix("test_user2");
  const std::string user1_batch1_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::KeyPrefix("test_user1", 1);
  const std::string user2_batch2_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::KeyPrefix("test_user2", 2);
  const std::string user1_batch2_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::KeyPrefix("test_user1", 2);
  ASSERT_TRUE(absl::StartsWith(user1_batch1_key, user1_key));
  ASSERT_TRUE(absl::StartsWith(user2_batch2_key, user2_key));
  ASSERT_FALSE(absl::StartsWith(user1_key, user2_key));
  ASSERT_FALSE(absl::StartsWith(user2_key, user1_key));
  ASSERT_FALSE(absl::StartsWith(user1_batch1_key, user1_batch2_key));
  ASSERT_FALSE(absl::StartsWith(user1_batch2_key, user1_batch1_key));

  const std::string user1_batch1_doc1_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(
          "test_user1", 1, testutil::Key("coll/doc1"));
  const std::string user2_batch1_doc1_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(
          "test_user2", 1, testutil::Key("coll/doc1"));
  ASSERT_TRUE(absl::StartsWith(user1_batch1_doc1_key, user1_key));
  ASSERT_FALSE(absl::StartsWith(user1_batch1_doc1_key, user2_key));
  ASSERT_TRUE(absl::StartsWith(user2_batch1_doc1_key, user2_key));
  ASSERT_FALSE(absl::StartsWith(user2_batch1_doc1_key, user1_key));
  ASSERT_TRUE(absl::StartsWith(user1_batch1_doc1_key, user1_batch1_key));
  ASSERT_FALSE(absl::StartsWith(user1_batch1_doc1_key, user1_batch2_key));
}

TEST(LevelDbDocumentOverlayLargestBatchIdIndexKeyTest, Ordering) {
  const std::string user1_batch1_doc1_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(
          "user1", 1, testutil::Key("coll/doc1"));
  const std::string user2_batch1_doc1_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(
          "user2", 1, testutil::Key("coll/doc1"));
  const std::string user1_batch2_doc1_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(
          "user1", 2, testutil::Key("coll/doc1"));
  const std::string user2_batch2_doc1_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(
          "user2", 2, testutil::Key("coll/doc1"));
  const std::string user1_batch1_doc2_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(
          "user1", 1, testutil::Key("coll/doc2"));
  const std::string user2_batch1_doc2_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(
          "user2", 1, testutil::Key("coll/doc2"));
  const std::string user1_batch2_doc2_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(
          "user1", 2, testutil::Key("coll/doc2"));
  const std::string user2_batch2_doc2_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(
          "user2", 2, testutil::Key("coll/doc2"));

  ASSERT_LT(user1_batch1_doc1_key, user2_batch1_doc1_key);
  ASSERT_LT(user1_batch1_doc1_key, user1_batch2_doc1_key);
  ASSERT_LT(user1_batch1_doc1_key, user1_batch1_doc2_key);
  ASSERT_LT(user2_batch1_doc1_key, user2_batch2_doc1_key);
  ASSERT_LT(user2_batch1_doc1_key, user2_batch1_doc2_key);
  ASSERT_LT(user2_batch2_doc1_key, user2_batch2_doc2_key);
}

TEST(LevelDbDocumentOverlayLargestBatchIdIndexKeyTest, EncodeDecodeCycle) {
  const std::vector<std::string> user_ids{"test_user", "foo/bar2",
                                          "foo-bar?baz!quux"};
  const std::vector<BatchId> batch_ids{1, 2, 3};
  const std::vector<DocumentKey> document_keys{testutil::Key("coll/doc1"),
                                               testutil::Key("coll/doc2"),
                                               testutil::Key("coll/doc3")};
  for (const std::string& user_id : user_ids) {
    for (BatchId batch_id : batch_ids) {
      for (const DocumentKey& document_key : document_keys) {
        SCOPED_TRACE(absl::StrCat("user_name=", user_id, " batch_id=", batch_id,
                                  " path=", document_key.ToString()));
        const std::string encoded =
            LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(user_id, batch_id,
                                                              document_key);
        LevelDbDocumentOverlayLargestBatchIdIndexKey key;
        EXPECT_TRUE(key.Decode(encoded));
        EXPECT_EQ(key.user_id(), user_id);
        EXPECT_EQ(key.largest_batch_id(), batch_id);
        EXPECT_EQ(key.document_key(), document_key);
      }
    }
  }
}

TEST(LevelDbDocumentOverlayLargestBatchIdIndexKeyTest, Description) {
  AssertExpectedKeyDescription(
      "[document_overlays_largest_batch_id_index: user_id=foo-bar?baz!quux "
      "batch_id=123 path=coll/docX]",
      LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(
          "foo-bar?baz!quux", 123, testutil::Key("coll/docX")));
}

TEST(LevelDbDocumentOverlayLargestBatchIdIndexKeyTest,
     FromLevelDbDocumentOverlayKey) {
  LevelDbDocumentOverlayKey key("test_user", testutil::Key("coll/doc"), 123);

  const std::string encoded_key =
      LevelDbDocumentOverlayLargestBatchIdIndexKey::Key(key);

  LevelDbDocumentOverlayLargestBatchIdIndexKey decoded_key;
  ASSERT_TRUE(decoded_key.Decode(encoded_key));
  EXPECT_EQ(decoded_key.user_id(), "test_user");
  EXPECT_EQ(decoded_key.largest_batch_id(), 123);
  EXPECT_EQ(decoded_key.document_key(), testutil::Key("coll/doc"));
}

TEST(LevelDbDocumentOverlayCollectionIndexKeyTest, Prefixing) {
  const std::string user1_key =
      LevelDbDocumentOverlayCollectionIndexKey::KeyPrefix("test_user1");
  const std::string user2_key =
      LevelDbDocumentOverlayCollectionIndexKey::KeyPrefix("test_user2");
  const std::string user1_coll1_key =
      LevelDbDocumentOverlayCollectionIndexKey::KeyPrefix(
          "test_user1", ResourcePath{"coll1"});
  const std::string user1_coll2_key =
      LevelDbDocumentOverlayCollectionIndexKey::KeyPrefix(
          "test_user1", ResourcePath{"coll2"});
  const std::string user2_coll1_key =
      LevelDbDocumentOverlayCollectionIndexKey::KeyPrefix(
          "test_user2", ResourcePath{"coll1"});
  const std::string user2_coll2_key =
      LevelDbDocumentOverlayCollectionIndexKey::KeyPrefix(
          "test_user2", ResourcePath{"coll2"});
  const std::string user1_coll1_batch1_key =
      LevelDbDocumentOverlayCollectionIndexKey::KeyPrefix(
          "test_user1", ResourcePath{"coll1"}, 1);
  const std::string user1_coll1_batch2_key =
      LevelDbDocumentOverlayCollectionIndexKey::KeyPrefix(
          "test_user1", ResourcePath{"coll1"}, 2);
  const std::string user2_coll2_batch2_key =
      LevelDbDocumentOverlayCollectionIndexKey::KeyPrefix(
          "test_user2", ResourcePath{"coll2"}, 2);

  ASSERT_TRUE(absl::StartsWith(user1_coll1_key, user1_key));
  ASSERT_TRUE(absl::StartsWith(user1_coll2_key, user1_key));
  ASSERT_TRUE(absl::StartsWith(user2_coll1_key, user2_key));
  ASSERT_TRUE(absl::StartsWith(user2_coll2_key, user2_key));
  ASSERT_TRUE(absl::StartsWith(user1_coll1_batch1_key, user1_coll1_key));
  ASSERT_TRUE(absl::StartsWith(user1_coll1_batch2_key, user1_coll1_key));
  ASSERT_FALSE(absl::StartsWith(user1_key, user2_key));
  ASSERT_FALSE(absl::StartsWith(user2_key, user1_key));
  ASSERT_FALSE(absl::StartsWith(user1_coll1_key, user1_coll2_key));
  ASSERT_FALSE(absl::StartsWith(user1_coll2_key, user1_coll1_key));
  ASSERT_FALSE(
      absl::StartsWith(user1_coll1_batch1_key, user1_coll1_batch2_key));
  ASSERT_FALSE(
      absl::StartsWith(user1_coll1_batch2_key, user1_coll1_batch1_key));

  const std::string user1_coll1_batch1_doc1_key =
      LevelDbDocumentOverlayCollectionIndexKey::Key(
          "test_user1", ResourcePath{"coll1"}, 1, "doc1");
  const std::string user2_coll2_batch2_doc2_key =
      LevelDbDocumentOverlayCollectionIndexKey::Key(
          "test_user2", ResourcePath{"coll2"}, 2, "doc2");
  ASSERT_TRUE(absl::StartsWith(user1_coll1_batch1_doc1_key, user1_key));
  ASSERT_TRUE(absl::StartsWith(user2_coll2_batch2_doc2_key, user2_key));
  ASSERT_TRUE(absl::StartsWith(user1_coll1_batch1_doc1_key, user1_coll1_key));
  ASSERT_TRUE(absl::StartsWith(user2_coll2_batch2_doc2_key, user2_coll2_key));
  ASSERT_TRUE(
      absl::StartsWith(user1_coll1_batch1_doc1_key, user1_coll1_batch1_key));
  ASSERT_TRUE(
      absl::StartsWith(user2_coll2_batch2_doc2_key, user2_coll2_batch2_key));
}

TEST(LevelDbDocumentOverlayCollectionIndexKeyTest, Ordering) {
  const std::string user1_coll1_batch1_doc1_key =
      LevelDbDocumentOverlayCollectionIndexKey::Key(
          "user1", ResourcePath{"coll1"}, 1, "doc1");
  const std::string user2_coll1_batch1_doc1_key =
      LevelDbDocumentOverlayCollectionIndexKey::Key(
          "user2", ResourcePath{"coll1"}, 1, "doc1");
  const std::string user2_coll2_batch1_doc1_key =
      LevelDbDocumentOverlayCollectionIndexKey::Key(
          "user2", ResourcePath{"coll2"}, 1, "doc1");
  const std::string user2_coll2_batch2_doc1_key =
      LevelDbDocumentOverlayCollectionIndexKey::Key(
          "user2", ResourcePath{"coll2"}, 2, "doc1");
  const std::string user2_coll2_batch2_doc2_key =
      LevelDbDocumentOverlayCollectionIndexKey::Key(
          "user2", ResourcePath{"coll2"}, 2, "doc2");

  ASSERT_LT(user1_coll1_batch1_doc1_key, user2_coll1_batch1_doc1_key);
  ASSERT_LT(user2_coll1_batch1_doc1_key, user2_coll2_batch1_doc1_key);
  ASSERT_LT(user2_coll2_batch1_doc1_key, user2_coll2_batch2_doc1_key);
  ASSERT_LT(user2_coll2_batch2_doc1_key, user2_coll2_batch2_doc2_key);
}

TEST(LevelDbDocumentOverlayCollectionIndexKeyTest, EncodeDecodeCycle) {
  const std::vector<std::string> user_ids{"test_user", "foo/bar2",
                                          "foo-bar?baz!quux"};
  const std::vector<ResourcePath> collections{
      ResourcePath{"coll1"}, ResourcePath{"coll2"},
      ResourcePath{"coll3", "docX", "coll4"}};
  const std::vector<BatchId> batch_ids{1, 2, 3};
  const std::vector<std::string> document_ids{"doc1", "doc2", "doc3"};
  for (const std::string& user_id : user_ids) {
    for (const ResourcePath& collection : collections) {
      for (const BatchId batch_id : batch_ids) {
        for (const std::string& document_id : document_ids) {
          SCOPED_TRACE(absl::StrCat("user_name=", user_id, " collection=",
                                    collection.CanonicalString(),
                                    " document_id=", document_id));
          const std::string encoded =
              LevelDbDocumentOverlayCollectionIndexKey::Key(
                  user_id, collection, batch_id, document_id);
          LevelDbDocumentOverlayCollectionIndexKey key;
          EXPECT_TRUE(key.Decode(encoded));
          EXPECT_EQ(key.user_id(), user_id);
          EXPECT_EQ(key.collection(), collection);
          EXPECT_EQ(key.largest_batch_id(), batch_id);
          EXPECT_EQ(key.document_key(),
                    DocumentKey(key.collection().Append(document_id)));
        }
      }
    }
  }
}

TEST(LevelDbDocumentOverlayCollectionIndexKeyTest, Description) {
  AssertExpectedKeyDescription(
      "[document_overlays_collection_index: user_id=foo-bar?baz!quux "
      "path=coll1 batch_id=123 document_id=docX]",
      LevelDbDocumentOverlayCollectionIndexKey::Key(
          "foo-bar?baz!quux", ResourcePath{"coll1"}, 123, "docX"));
}

TEST(LevelDbDocumentOverlayCollectionIndexKeyTest,
     FromLevelDbDocumentOverlayKey) {
  LevelDbDocumentOverlayKey key("test_user", testutil::Key("coll/doc"), 123);

  const std::string encoded_key =
      LevelDbDocumentOverlayCollectionIndexKey::Key(key);

  LevelDbDocumentOverlayCollectionIndexKey decoded_key;
  ASSERT_TRUE(decoded_key.Decode(encoded_key));
  EXPECT_EQ(decoded_key.user_id(), "test_user");
  EXPECT_EQ(decoded_key.collection(), ResourcePath{"coll"});
  EXPECT_EQ(decoded_key.largest_batch_id(), 123);
  EXPECT_EQ(decoded_key.document_key(), testutil::Key("coll/doc"));
}

TEST(LevelDbDocumentOverlayCollectionGroupIndexKeyTest, Prefixing) {
  const std::string user1_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::KeyPrefix("test_user1");
  const std::string user2_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::KeyPrefix("test_user2");
  const std::string user1_group1_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::KeyPrefix("test_user1",
                                                               "group1");
  const std::string user1_group2_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::KeyPrefix("test_user1",
                                                               "group2");
  const std::string user2_group2_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::KeyPrefix("test_user2",
                                                               "group2");
  const std::string user1_group1_batch1_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::KeyPrefix("test_user1",
                                                               "group1", 1);
  const std::string user1_group1_batch2_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::KeyPrefix("test_user1",
                                                               "group1", 2);
  const std::string user2_group2_batch2_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::KeyPrefix("test_user2",
                                                               "group2", 2);

  ASSERT_TRUE(absl::StartsWith(user1_group1_key, user1_key));
  ASSERT_TRUE(absl::StartsWith(user1_group2_key, user1_key));
  ASSERT_TRUE(absl::StartsWith(user2_group2_key, user2_key));
  ASSERT_TRUE(absl::StartsWith(user1_group1_batch1_key, user1_group1_key));
  ASSERT_TRUE(absl::StartsWith(user1_group1_batch2_key, user1_group1_key));
  ASSERT_FALSE(absl::StartsWith(user1_key, user2_key));
  ASSERT_FALSE(absl::StartsWith(user2_key, user1_key));
  ASSERT_FALSE(absl::StartsWith(user1_group1_key, user1_group2_key));
  ASSERT_FALSE(absl::StartsWith(user1_group2_key, user1_group1_key));
  ASSERT_FALSE(
      absl::StartsWith(user1_group1_batch1_key, user1_group1_batch2_key));
  ASSERT_FALSE(
      absl::StartsWith(user1_group1_batch2_key, user1_group1_batch1_key));

  const std::string user1_group1_batch1_doc1_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::Key(
          "test_user1", "group1", 1, testutil::Key("coll/doc1"));
  const std::string user2_group2_batch2_doc2_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::Key(
          "test_user2", "group2", 2, testutil::Key("coll/doc2"));
  ASSERT_TRUE(absl::StartsWith(user1_group1_batch1_doc1_key, user1_key));
  ASSERT_TRUE(absl::StartsWith(user2_group2_batch2_doc2_key, user2_key));
  ASSERT_TRUE(absl::StartsWith(user1_group1_batch1_doc1_key, user1_group1_key));
  ASSERT_TRUE(absl::StartsWith(user2_group2_batch2_doc2_key, user2_group2_key));
  ASSERT_TRUE(
      absl::StartsWith(user1_group1_batch1_doc1_key, user1_group1_batch1_key));
  ASSERT_TRUE(
      absl::StartsWith(user2_group2_batch2_doc2_key, user2_group2_batch2_key));
}

TEST(LevelDbDocumentOverlayCollectionGroupIndexKeyTest, Ordering) {
  const std::string user1_group1_batch1_doc1_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::Key(
          "user1", "group1", 1, testutil::Key("coll/doc1"));
  const std::string user2_group1_batch1_doc1_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::Key(
          "user2", "group1", 1, testutil::Key("coll/doc1"));
  const std::string user2_group2_batch1_doc1_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::Key(
          "user2", "group2", 1, testutil::Key("coll/doc1"));
  const std::string user2_group2_batch2_doc1_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::Key(
          "user2", "group2", 2, testutil::Key("coll/doc1"));
  const std::string user2_group2_batch2_doc2_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::Key(
          "user2", "group2", 2, testutil::Key("coll/doc2"));

  ASSERT_LT(user1_group1_batch1_doc1_key, user2_group1_batch1_doc1_key);
  ASSERT_LT(user2_group1_batch1_doc1_key, user2_group2_batch1_doc1_key);
  ASSERT_LT(user2_group2_batch1_doc1_key, user2_group2_batch2_doc1_key);
  ASSERT_LT(user2_group2_batch2_doc1_key, user2_group2_batch2_doc2_key);
}

TEST(LevelDbDocumentOverlayCollectionGroupIndexKeyTest, EncodeDecodeCycle) {
  const std::vector<std::string> user_ids{"test_user", "foo/bar2",
                                          "foo-bar?baz!quux"};
  // NOTE: These collection groups do not actually match the document keys used;
  // however, that's okay here in this unit test because the LevelDb key itself
  // doesn't care if they match.
  const std::vector<std::string> collection_groups{"group1", "group2"};
  const std::vector<model::BatchId> batch_ids{1, 2, 3};
  const std::vector<model::DocumentKey> document_keys{
      testutil::Key("coll/doc1"), testutil::Key("coll/doc2"),
      testutil::Key("coll/doc3")};
  for (const std::string& user_id : user_ids) {
    for (const std::string& collection_group : collection_groups) {
      for (const model::BatchId batch_id : batch_ids) {
        for (const model::DocumentKey& document_key : document_keys) {
          SCOPED_TRACE(absl::StrCat("user_name=", user_id,
                                    " collection_group=", collection_group,
                                    " path=", document_key.ToString()));
          const std::string encoded =
              LevelDbDocumentOverlayCollectionGroupIndexKey::Key(
                  user_id, collection_group, batch_id, document_key);
          LevelDbDocumentOverlayCollectionGroupIndexKey key;
          EXPECT_TRUE(key.Decode(encoded));
          EXPECT_EQ(key.user_id(), user_id);
          EXPECT_EQ(key.collection_group(), collection_group);
          EXPECT_EQ(key.largest_batch_id(), batch_id);
          EXPECT_EQ(key.document_key(), document_key);
        }
      }
    }
  }
}

TEST(LevelDbDocumentOverlayCollectionGroupIndexKeyTest, Description) {
  AssertExpectedKeyDescription(
      "[document_overlays_collection_group_index: user_id=foo-bar?baz!quux "
      "collection_group=group1 batch_id=123 path=coll/docX]",
      LevelDbDocumentOverlayCollectionGroupIndexKey::Key(
          "foo-bar?baz!quux", "group1", 123, testutil::Key("coll/docX")));
}

TEST(LevelDbDocumentOverlayCollectionGroupIndexKeyTest,
     FromLevelDbDocumentOverlayKey) {
  LevelDbDocumentOverlayKey key("test_user", testutil::Key("coll/doc"), 123);

  const absl::optional<std::string> encoded_key =
      LevelDbDocumentOverlayCollectionGroupIndexKey::Key(key);
  ASSERT_TRUE(encoded_key.has_value());

  LevelDbDocumentOverlayCollectionGroupIndexKey decoded_key;
  ASSERT_TRUE(decoded_key.Decode(encoded_key.value()));
  EXPECT_EQ(decoded_key.user_id(), "test_user");
  EXPECT_EQ(decoded_key.collection_group(), "coll");
  EXPECT_EQ(decoded_key.largest_batch_id(), 123);
  EXPECT_EQ(decoded_key.document_key(), testutil::Key("coll/doc"));
}

#undef AssertExpectedKeyDescription

}  // namespace local
}  // namespace firestore
}  // namespace firebase
