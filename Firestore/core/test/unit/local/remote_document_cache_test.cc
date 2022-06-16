/*
 * Copyright 2019 Google
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

#include "Firestore/core/test/unit/local/remote_document_cache_test.h"

#include <memory>
#include <vector>

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/memory_remote_document_cache.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/local/remote_document_cache.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/document_key_set.h"
#include "Firestore/core/src/model/object_value.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/strings/string_view.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using model::DeepClone;
using model::DocumentKey;
using model::DocumentKeySet;
using model::DocumentMap;
using model::MutableDocument;
using model::MutableDocumentMap;
using model::ObjectValue;
using model::SnapshotVersion;
using nanopb::Message;

using testing::Eq;
using testing::IsSupersetOf;
using testing::Matches;
using testing::UnorderedElementsAreArray;
using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Field;
using testutil::Key;
using testutil::Map;
using testutil::Query;
using testutil::Value;
using testutil::Version;

const char* kDocPath = "a/b";
const char* kLongDocPath = "a/b/c/d/e/f";
const int kVersion = 42;

/**
 * Extracts all the actual MaybeDocument instances from the given document map.
 *
 * @tparam MapType Some map type like OptionalMaybeDocumentMap or
 *     MaybeDocumentMap.
 */
template <typename MapType>
std::vector<MutableDocument> ExtractDocuments(const MapType& docs) {
  std::vector<MutableDocument> result;
  for (const auto& kv : docs) {
    const absl::optional<MutableDocument>& doc = kv.second;
    if (doc) {
      result.push_back(*doc);
    }
  }
  return result;
}

MATCHER_P(HasExactlyDocs,
          expected,
          negation ? "missing docs" : "has exactly docs") {
  std::vector<MutableDocument> arg_docs = ExtractDocuments(arg);
  return testing::Value(arg_docs, UnorderedElementsAreArray(expected));
}

MATCHER_P(HasAtLeastDocs,
          expected,
          negation ? "missing docs" : "has at least docs") {
  std::vector<MutableDocument> arg_docs = ExtractDocuments(arg);
  return testing::Value(arg_docs, IsSupersetOf(expected));
}

}  // namespace

RemoteDocumentCacheTest::RemoteDocumentCacheTest()
    : persistence_{GetParam()()},
      cache_{persistence_->remote_document_cache()},
      index_manager_{
          persistence_->GetIndexManager(credentials::User::Unauthenticated())} {
  cache_->SetIndexManager(index_manager_);
}

TEST_P(RemoteDocumentCacheTest, ReadDocumentNotInCache) {
  persistence_->Run("test_read_document_not_in_cache", [&] {
    ASSERT_FALSE(cache_->Get(Key(kDocPath)).is_valid_document());
  });
}

TEST_P(RemoteDocumentCacheTest, SetAndReadADocument) {
  SetAndReadTestDocument(kDocPath);
}

TEST_P(RemoteDocumentCacheTest, SetAndReadSeveralDocuments) {
  persistence_->Run("test_set_and_read_several_documents", [=] {
    std::vector<MutableDocument> written = {
        SetTestDocument(kDocPath),
        SetTestDocument(kLongDocPath),
    };
    MutableDocumentMap read =
        cache_->GetAll(DocumentKeySet{Key(kDocPath), Key(kLongDocPath)});
    EXPECT_THAT(read, HasExactlyDocs(written));
  });
}

TEST_P(RemoteDocumentCacheTest,
       SetAndReadSeveralDocumentsIncludingMissingDocument) {
  persistence_->Run(
      "test_set_and_read_several_documents_including_missing_document", [=] {
        std::vector<MutableDocument> written = {
            SetTestDocument(kDocPath),
            SetTestDocument(kLongDocPath),
        };
        MutableDocumentMap read = cache_->GetAll(DocumentKeySet{
            Key(kDocPath),
            Key(kLongDocPath),
            Key("foo/nonexistent"),
        });
        EXPECT_THAT(read, HasAtLeastDocs(written));
        auto found = read.find(DocumentKey::FromPathString("foo/nonexistent"));
        ASSERT_TRUE(found != read.end());
        ASSERT_FALSE(found->second.is_valid_document());
      });
}

TEST_P(RemoteDocumentCacheTest, SetAndReadADocumentAtDeepPath) {
  SetAndReadTestDocument(kLongDocPath);
}

TEST_P(RemoteDocumentCacheTest, SetAndReadDeletedDocument) {
  persistence_->Run("test_set_and_read_deleted_document", [&] {
    absl::optional<MutableDocument> deleted_doc =
        DeletedDoc(kDocPath, kVersion);
    cache_->Add(*deleted_doc, deleted_doc->version());

    ASSERT_EQ(cache_->Get(Key(kDocPath)), deleted_doc);
  });
}

TEST_P(RemoteDocumentCacheTest, SetDocumentToNewValue) {
  persistence_->Run("test_set_document_to_new_value", [&] {
    SetTestDocument(kDocPath);
    absl::optional<MutableDocument> new_doc =
        Doc(kDocPath, kVersion, Map("data", 2));
    cache_->Add(*new_doc, new_doc->version());
    ASSERT_EQ(cache_->Get(Key(kDocPath)), new_doc);
  });
}

TEST_P(RemoteDocumentCacheTest, RemoveDocument) {
  persistence_->Run("test_remove_document", [&] {
    SetTestDocument(kDocPath);
    cache_->Remove(Key(kDocPath));

    ASSERT_FALSE(cache_->Get(Key(kDocPath)).is_valid_document());
  });
}

TEST_P(RemoteDocumentCacheTest, RemoveNonExistentDocument) {
  persistence_->Run("test_remove_non_existent_document", [&] {
    // no-op, but make sure it doesn't throw.
    EXPECT_NO_THROW(cache_->Remove(Key(kDocPath)));
  });
}

// TODO(mikelehen): Write more elaborate tests once we have more elaborate
// implementations.
TEST_P(RemoteDocumentCacheTest, DocumentsMatchingQuery) {
  persistence_->Run("test_documents_matching_query", [&] {
    // TODO(rsgowman): This just verifies that we do a prefix scan against the
    // query path. We'll need more tests once we add index support.
    SetTestDocument("a/1");
    SetTestDocument("b/1");
    SetTestDocument("b/1/z/1");
    SetTestDocument("b/2");
    SetTestDocument("c/1");

    core::Query query = Query("b");
    MutableDocumentMap results =
        cache_->GetAll(query.path(), model::IndexOffset::None());
    std::vector<MutableDocument> docs = {
        Doc("b/1", kVersion, Map("a", 1, "b", 2)),
        Doc("b/2", kVersion, Map("a", 1, "b", 2)),
    };
    EXPECT_THAT(results, HasExactlyDocs(docs));
  });
}

TEST_P(RemoteDocumentCacheTest, DocumentsMatchingQuerySinceReadTime) {
  persistence_->Run("test_documents_matching_query_since_read_time", [&] {
    SetTestDocument("b/old", /* updateTime= */ 1, /* readTime= */ 11);
    SetTestDocument("b/current", /* updateTime= */ 2, /* readTime= = */ 12);
    SetTestDocument("b/new", /* updateTime= */ 3, /* readTime= = */ 13);

    core::Query query = Query("b");
    MutableDocumentMap results = cache_->GetAll(
        query.path(), model::IndexOffset::CreateSuccessor(Version(12)));
    std::vector<MutableDocument> docs = {
        Doc("b/new", 3, Map("a", 1, "b", 2)),
    };
    EXPECT_THAT(results, HasExactlyDocs(docs));
  });
}

TEST_P(RemoteDocumentCacheTest, DocumentsMatchingUsesReadTimeNotUpdateTime) {
  persistence_->Run(
      "test_documents_matching_query_uses_read_time_not_update_time", [&] {
        SetTestDocument("b/old", /* updateTime= */ 1, /* readTime= */ 2);
        SetTestDocument("b/new", /* updateTime= */ 2, /* readTime= */ 1);

        core::Query query = Query("b");
        MutableDocumentMap results = cache_->GetAll(
            query.path(), model::IndexOffset::CreateSuccessor(Version(1)));
        std::vector<MutableDocument> docs = {
            Doc("b/old", 1, Map("a", 1, "b", 2)),
        };
        EXPECT_THAT(results, HasExactlyDocs(docs));
      });
}

TEST_P(RemoteDocumentCacheTest, DoesNotApplyDocumentModificationsToCache) {
  // This test verifies that the MemoryMutationCache returns copies of all
  // data to ensure that the documents in the cache cannot be modified.
  persistence_->Run("test_does_not_apply_document_modifications_to_cache", [&] {
    MutableDocument document = SetTestDocument("coll/doc", Map("value", "old"));
    document = cache_->Get(Key("coll/doc"));
    EXPECT_EQ(document.value(), *Map("value", "old"));
    document.data().Set(Field("value"), Value("new"));

    document = cache_->Get(Key("coll/doc"));
    EXPECT_EQ(document.value(), *Map("value", "old"));
    document.data().Set(Field("value"), Value("new"));

    MutableDocumentMap documents =
        cache_->GetAll(DocumentKeySet{Key("coll/doc")});
    document = documents.find(Key("coll/doc"))->second;
    EXPECT_EQ(document.value(), *Map("value", "old"));
    document.data().Set(Field("value"), Value("new"));

    documents =
        cache_->GetAll(Query("coll").path(), model::IndexOffset::None());
    document = documents.find(Key("coll/doc"))->second;
    EXPECT_EQ(document.value(), *Map("value", "old"));
    document.data().Set(Field("value"), Value("new"));

    document = cache_->Get(Key("coll/doc"));
    EXPECT_EQ(document.value(), *Map("value", "old"));
  });
}
// MARK: - Helpers

MutableDocument RemoteDocumentCacheTest::SetTestDocument(
    absl::string_view path,
    Message<google_firestore_v1_Value> data,
    int update_time,
    int read_time) {
  MutableDocument doc = Doc(path, update_time, std::move(data));
  cache_->Add(doc, Version(read_time));
  return doc;
}

MutableDocument RemoteDocumentCacheTest::SetTestDocument(absl::string_view path,
                                                         int update_time,
                                                         int read_time) {
  return SetTestDocument(path, Map("a", 1, "b", 2), update_time, read_time);
}

MutableDocument RemoteDocumentCacheTest::SetTestDocument(
    absl::string_view path, Message<google_firestore_v1_Value> data) {
  return SetTestDocument(path, std::move(data), kVersion, kVersion);
}

MutableDocument RemoteDocumentCacheTest::SetTestDocument(
    const absl::string_view path) {
  return SetTestDocument(path, Map("a", 1, "b", 2), kVersion, kVersion);
}

void RemoteDocumentCacheTest::SetAndReadTestDocument(
    const absl::string_view path) {
  persistence_->Run("SetAndReadTestDocument", [&] {
    MutableDocument written = SetTestDocument(path);
    absl::optional<MutableDocument> read = cache_->Get(Key(path));
    EXPECT_EQ(*read, written);
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
