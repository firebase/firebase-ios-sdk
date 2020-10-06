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
#include "Firestore/core/src/local/memory_remote_document_cache.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/local/remote_document_cache.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/document_key_set.h"
#include "Firestore/core/src/model/document_map.h"
#include "Firestore/core/src/model/no_document.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/strings/string_view.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using model::Document;
using model::DocumentKey;
using model::DocumentKeySet;
using model::DocumentMap;
using model::DocumentState;
using model::FieldValue;
using model::MaybeDocument;
using model::MaybeDocumentMap;
using model::NoDocument;
using model::OptionalMaybeDocumentMap;
using model::SnapshotVersion;

using testing::IsSupersetOf;
using testing::Matches;
using testing::UnorderedElementsAreArray;
using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Map;
using testutil::Query;
using testutil::Version;

const char* kDocPath = "a/b";
const char* kLongDocPath = "a/b/c/d/e/f";
const int kVersion = 42;
FieldValue::Map kDocData;

/**
 * Extracts all the actual MaybeDocument instances from the given document map.
 *
 * @tparam MapType Some map type like OptionalMaybeDocumentMap or
 *     MaybeDocumentMap.
 */
template <typename MapType>
std::vector<MaybeDocument> ExtractDocuments(const MapType& docs) {
  std::vector<MaybeDocument> result;
  for (const auto& kv : docs) {
    const absl::optional<MaybeDocument>& doc = kv.second;
    if (doc) {
      result.push_back(*doc);
    }
  }
  return result;
}

MATCHER_P(HasExactlyDocs,
          expected,
          negation ? "missing docs" : "has exactly docs") {
  std::vector<MaybeDocument> arg_docs = ExtractDocuments(arg);
  return testing::Value(arg_docs, UnorderedElementsAreArray(expected));
}

MATCHER_P(HasAtLeastDocs,
          expected,
          negation ? "missing docs" : "has at least docs") {
  std::vector<MaybeDocument> arg_docs = ExtractDocuments(arg);
  return testing::Value(arg_docs, IsSupersetOf(expected));
}

}  // namespace

RemoteDocumentCacheTest::RemoteDocumentCacheTest()
    : persistence_{GetParam()()},
      cache_{persistence_->remote_document_cache()} {
  // essentially a constant, but can't be a compile-time one.
  kDocData = Map("a", 1, "b", 2);
}

TEST_P(RemoteDocumentCacheTest, ReadDocumentNotInCache) {
  persistence_->Run("test_read_document_not_in_cache", [&] {
    ASSERT_EQ(absl::nullopt, cache_->Get(testutil::Key(kDocPath)));
  });
}

TEST_P(RemoteDocumentCacheTest, SetAndReadADocument) {
  SetAndReadTestDocument(kDocPath);
}

TEST_P(RemoteDocumentCacheTest, SetAndReadSeveralDocuments) {
  persistence_->Run("test_set_and_read_several_documents", [=] {
    std::vector<Document> written = {
        SetTestDocument(kDocPath),
        SetTestDocument(kLongDocPath),
    };
    OptionalMaybeDocumentMap read = cache_->GetAll(
        DocumentKeySet{testutil::Key(kDocPath), testutil::Key(kLongDocPath)});
    EXPECT_THAT(read, HasExactlyDocs(written));
  });
}

TEST_P(RemoteDocumentCacheTest,
       SetAndReadSeveralDocumentsIncludingMissingDocument) {
  persistence_->Run(
      "test_set_and_read_several_documents_including_missing_document", [=] {
        std::vector<Document> written = {
            SetTestDocument(kDocPath),
            SetTestDocument(kLongDocPath),
        };
        OptionalMaybeDocumentMap read = cache_->GetAll(DocumentKeySet{
            testutil::Key(kDocPath),
            testutil::Key(kLongDocPath),
            testutil::Key("foo/nonexistent"),
        });
        EXPECT_THAT(read, HasAtLeastDocs(written));
        auto found = read.find(DocumentKey::FromPathString("foo/nonexistent"));
        ASSERT_TRUE(found != read.end());
        ASSERT_EQ(absl::nullopt, found->second);
      });
}

TEST_P(RemoteDocumentCacheTest, SetAndReadADocumentAtDeepPath) {
  SetAndReadTestDocument(kLongDocPath);
}

TEST_P(RemoteDocumentCacheTest, SetAndReadDeletedDocument) {
  persistence_->Run("test_set_and_read_deleted_document", [&] {
    absl::optional<MaybeDocument> deleted_doc = DeletedDoc(kDocPath, kVersion);
    cache_->Add(*deleted_doc, deleted_doc->version());

    ASSERT_EQ(cache_->Get(testutil::Key(kDocPath)), deleted_doc);
  });
}

TEST_P(RemoteDocumentCacheTest, SetDocumentToNewValue) {
  persistence_->Run("test_set_document_to_new_value", [&] {
    SetTestDocument(kDocPath);
    absl::optional<MaybeDocument> new_doc =
        Doc(kDocPath, kVersion, Map("data", 2));
    cache_->Add(*new_doc, new_doc->version());
    ASSERT_EQ(cache_->Get(testutil::Key(kDocPath)), new_doc);
  });
}

TEST_P(RemoteDocumentCacheTest, RemoveDocument) {
  persistence_->Run("test_remove_document", [&] {
    SetTestDocument(kDocPath);
    cache_->Remove(testutil::Key(kDocPath));

    ASSERT_EQ(cache_->Get(testutil::Key(kDocPath)), absl::nullopt);
  });
}

TEST_P(RemoteDocumentCacheTest, RemoveNonExistentDocument) {
  persistence_->Run("test_remove_non_existent_document", [&] {
    // no-op, but make sure it doesn't throw.
    EXPECT_NO_THROW(cache_->Remove(testutil::Key(kDocPath)));
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
    DocumentMap results = cache_->GetMatching(query, SnapshotVersion::None());
    std::vector<Document> docs = {
        Doc("b/1", kVersion, kDocData),
        Doc("b/2", kVersion, kDocData),
    };
    EXPECT_THAT(results.underlying_map(), HasExactlyDocs(docs));
  });
}

TEST_P(RemoteDocumentCacheTest, DocumentsMatchingQuerySinceReadTime) {
  persistence_->Run("test_documents_matching_query_since_read_time", [&] {
    SetTestDocument("b/old", /* updateTime= */ 1, /* readTime= */ 11);
    SetTestDocument("b/current", /* updateTime= */ 2, /* readTime= = */ 12);
    SetTestDocument("b/new", /* updateTime= */ 3, /* readTime= = */ 13);

    core::Query query = Query("b");
    DocumentMap results = cache_->GetMatching(query, Version(12));
    std::vector<Document> docs = {
        Doc("b/new", 3, kDocData),
    };
    EXPECT_THAT(results.underlying_map(), HasExactlyDocs(docs));
  });
}

TEST_P(RemoteDocumentCacheTest, DocumentsMatchingUsesReadTimeNotUpdateTime) {
  persistence_->Run(
      "test_documents_matching_query_uses_read_time_not_update_time", [&] {
        SetTestDocument("b/old", /* updateTime= */ 1, /* readTime= */ 2);
        SetTestDocument("b/new", /* updateTime= */ 2, /* readTime= */ 1);

        core::Query query = Query("b");
        DocumentMap results = cache_->GetMatching(query, Version(1));
        std::vector<Document> docs = {
            Doc("b/old", 1, kDocData),
        };
        EXPECT_THAT(results.underlying_map(), HasExactlyDocs(docs));
      });
}

// MARK: - Helpers

Document RemoteDocumentCacheTest::SetTestDocument(const absl::string_view path,
                                                  int update_time,
                                                  int read_time) {
  Document doc = Doc(path, update_time, kDocData);
  cache_->Add(doc, Version(read_time));
  return doc;
}

Document RemoteDocumentCacheTest::SetTestDocument(
    const absl::string_view path) {
  return SetTestDocument(path, kVersion, kVersion);
}

void RemoteDocumentCacheTest::SetAndReadTestDocument(
    const absl::string_view path) {
  persistence_->Run("SetAndReadTestDocument", [&] {
    Document written = SetTestDocument(path);
    absl::optional<MaybeDocument> read = cache_->Get(testutil::Key(path));
    ASSERT_EQ(*read, written);
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
