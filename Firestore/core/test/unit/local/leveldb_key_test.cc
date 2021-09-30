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

#include "Firestore/core/src/util/string_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/strings/match.h"
#include "gtest/gtest.h"

using firebase::firestore::model::BatchId;
using firebase::firestore::model::DocumentKey;
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
                           model::BatchId batch_id) {
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

#undef AssertExpectedKeyDescription

}  // namespace local
}  // namespace firestore
}  // namespace firebase
