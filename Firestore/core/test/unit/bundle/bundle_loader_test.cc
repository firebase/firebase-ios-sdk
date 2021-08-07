/*
 * Copyright 2021 Google LLC
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

#include "Firestore/core/src/bundle/bundle_loader.h"

#include <cstdint>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "Firestore/core/src/bundle/bundle_callback.h"
#include "Firestore/core/src/bundle/bundle_reader.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/model/document_key_set.h"
#include "Firestore/core/test/unit/testutil/status_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/types/optional.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace bundle {
namespace {

using api::LoadBundleTask;
using api::LoadBundleTaskProgress;
using api::LoadBundleTaskState;
using core::LimitType;
using model::DocumentKeySet;
using model::DocumentMap;
using util::StatusOr;

class BundleLoaderTest : public ::testing::Test {
 public:
  class TestBundleCallback : public BundleCallback {
   public:
    explicit TestBundleCallback(BundleLoaderTest& parant) : parent_(parant) {
    }

    model::DocumentMap ApplyBundledDocuments(
        const model::MutableDocumentMap& documents,
        const std::string& bundle_id) override {
      (void)bundle_id;
      for (const auto& entry : documents) {
        parent_.last_documents_ = parent_.last_documents_.insert(entry.first);
      }
      return DocumentMap{};
    }

    void SaveNamedQuery(const NamedQuery& query,
                        const model::DocumentKeySet& keys) override {
      parent_.last_queries_.insert({query.query_name(), keys});
    }

    void SaveBundle(const BundleMetadata& metadata) override {
      parent_.last_bundles_.insert({metadata.bundle_id(), metadata});
    }

   private:
    BundleLoaderTest& parent_;
  };

  BundleLoaderTest() : callback_(absl::make_unique<TestBundleCallback>(*this)) {
  }

  static void AssertProgress(
      absl::optional<LoadBundleTaskProgress> progress_opt,
      int documents_loaded,
      int total_documents,
      int bytes_loaded,
      int total_bytes,
      LoadBundleTaskState state) {
    EXPECT_TRUE(progress_opt.has_value());
    auto progress = progress_opt.value();
    EXPECT_EQ(progress.documents_loaded(), documents_loaded);
    EXPECT_EQ(progress.total_documents(), total_documents);
    EXPECT_EQ(progress.bytes_loaded(), bytes_loaded);
    EXPECT_EQ(progress.total_bytes(), total_bytes);
    EXPECT_EQ(progress.state(), state);
  }

  BundleMetadata CreateMetadata(int documents) {
    return BundleMetadata("bundle-1", 1, create_time_, documents, 10);
  }

 protected:
  std::unique_ptr<BundleCallback> callback_ = nullptr;
  DocumentKeySet last_documents_;
  std::unordered_map<std::string, DocumentKeySet> last_queries_;
  std::unordered_map<std::string, BundleMetadata> last_bundles_;
  model::SnapshotVersion create_time_ =
      model::SnapshotVersion(Timestamp::Now());
};

TEST_F(BundleLoaderTest, LoadsDocuments) {
  BundleLoader loader(callback_.get(), CreateMetadata(2));

  BundleLoader::AddElementResult result = loader.AddElement(
      absl::make_unique<BundledDocumentMetadata>(
          testutil::Key("coll/doc1"), create_time_,
          /*exists=*/true, /*queries*/ std::vector<std::string>{}),
      /*byte_size=*/1);
  EXPECT_OK(result);
  EXPECT_EQ(result.ValueOrDie(), absl::nullopt);

  result = loader.AddElement(
      absl::make_unique<BundleDocument>(testutil::Doc("coll/doc1", 1)),
      /*byte_size=*/4);
  EXPECT_OK(result);
  AssertProgress(result.ValueOrDie(), /*documents_loaded=*/1,
                 /*total_documents=*/2, /*bytes_loaded*/ 5, /*total_bytes*/ 10,
                 LoadBundleTaskState::kInProgress);

  result = loader.AddElement(absl::make_unique<BundledDocumentMetadata>(
                                 testutil::Key("coll/doc2"), create_time_, true,
                                 std::vector<std::string>{}),
                             /*byte_size=*/1);
  EXPECT_OK(result);
  EXPECT_EQ(result.ValueOrDie(), absl::nullopt);

  result = loader.AddElement(
      absl::make_unique<BundleDocument>(testutil::Doc("coll/doc2", 1)),
      /*byte_size=*/4);
  EXPECT_OK(result);
  AssertProgress(result.ValueOrDie(), /*documents_loaded=*/2,
                 /*total_documents=*/2, /*bytes_loaded*/ 10, /*total_bytes*/ 10,
                 LoadBundleTaskState::kInProgress);
}

TEST_F(BundleLoaderTest, LoadsDeletedDocuments) {
  BundleLoader loader(callback_.get(), CreateMetadata(1));

  BundleLoader::AddElementResult result = loader.AddElement(
      absl::make_unique<BundledDocumentMetadata>(
          testutil::Key("coll/doc1"), create_time_,
          /*exists=*/false, /*queries=*/std::vector<std::string>{}),
      /*byte_size*/ 10);

  EXPECT_OK(result);
  AssertProgress(result.ValueOrDie(), /*documents_loaded=*/1,
                 /*total_documents=*/1, /*bytes_loaded*/ 10, /*total_bytes*/ 10,
                 LoadBundleTaskState::kInProgress);
}

TEST_F(BundleLoaderTest, AppliesDocumentChanges) {
  BundleLoader loader(callback_.get(), CreateMetadata(1));

  EXPECT_OK(loader.AddElement(
      absl::make_unique<BundledDocumentMetadata>(
          testutil::Key("coll/doc1"), create_time_,
          /*exists=*/true, /*queries=*/std::vector<std::string>{}),
      1));
  EXPECT_OK(loader.AddElement(
      absl::make_unique<BundleDocument>(testutil::Doc("coll/doc1", 1)),
      /*byte_size=*/9));
  EXPECT_OK(loader.ApplyChanges());

  EXPECT_EQ(last_documents_, DocumentKeySet{testutil::Key("coll/doc1")});
  EXPECT_EQ(last_bundles_["bundle-1"], CreateMetadata(1));
}

TEST_F(BundleLoaderTest, AppliesNamedQueries) {
  BundleLoader loader(callback_.get(), CreateMetadata(2));

  EXPECT_OK(loader.AddElement(
      absl::make_unique<BundledDocumentMetadata>(
          testutil::Key("coll/doc1"), create_time_,
          /*exists=*/false, std::vector<std::string>{"query-1"}),
      /*byte_size=*/2));
  EXPECT_OK(loader.AddElement(
      absl::make_unique<BundledDocumentMetadata>(
          testutil::Key("coll/doc2"), create_time_,
          /*exists=*/false, std::vector<std::string>{"query-2"}),
      /*byte_size=*/2));
  EXPECT_OK(loader.AddElement(
      absl::make_unique<NamedQuery>(
          "query-1",
          BundledQuery(testutil::Query("foo").ToTarget(), LimitType::First),
          create_time_),
      /*byte_size=*/2));
  EXPECT_OK(loader.AddElement(
      absl::make_unique<NamedQuery>(
          "query-2",
          BundledQuery(testutil::Query("foo").ToTarget(), LimitType::First),
          create_time_),
      /*byte_size=*/4));
  (void)loader.ApplyChanges();

  EXPECT_EQ(last_queries_["query-1"],
            DocumentKeySet{testutil::Key("coll/doc1")});
  EXPECT_EQ(last_queries_["query-2"],
            DocumentKeySet{testutil::Key("coll/doc2")});
}

TEST_F(BundleLoaderTest, VerifiesDocumentMetadataSet) {
  BundleLoader loader(callback_.get(), CreateMetadata(1));

  EXPECT_NOT_OK(loader.AddElement(
      absl::make_unique<BundleDocument>(testutil::Doc("coll/doc1", 1)),
      /*byte_size=*/10));
}

TEST_F(BundleLoaderTest, VerifiesDocumentMetadataMatches) {
  BundleLoader loader(callback_.get(), CreateMetadata(1));

  EXPECT_OK(loader.AddElement(absl::make_unique<BundledDocumentMetadata>(
                                  testutil::Key("coll/doc1"), create_time_,
                                  /*exists=*/true, std::vector<std::string>{}),
                              /*byte_size=*/1));
  EXPECT_NOT_OK(loader.AddElement(
      absl::make_unique<BundleDocument>(testutil::Doc("coll/doc_NOT_MATCH", 1)),
      /*byte_size=*/9));
}

TEST_F(BundleLoaderTest, VerifiesDocumentFollowsMetadata) {
  BundleLoader loader(callback_.get(), CreateMetadata(1));

  EXPECT_OK(loader.AddElement(absl::make_unique<BundledDocumentMetadata>(
                                  testutil::Key("coll/doc1"), create_time_,
                                  /*exists=*/true, std::vector<std::string>{}),
                              /*byte_size=*/10));
  // Metadata says document exists, but document is missing.
  EXPECT_NOT_OK(loader.ApplyChanges());
}

TEST_F(BundleLoaderTest, VerifiesDocumentCount) {
  BundleLoader loader(callback_.get(), CreateMetadata(2));

  EXPECT_OK(loader.AddElement(absl::make_unique<BundledDocumentMetadata>(
                                  testutil::Key("coll/doc1"), create_time_,
                                  /*exists=*/false, std::vector<std::string>{}),
                              /*byte_size=*/10));
  // BundleMetadata says there are 2 documents, but only 1 is found.
  EXPECT_NOT_OK(loader.ApplyChanges());
}

}  //  namespace
}  //  namespace bundle
}  //  namespace firestore
}  //  namespace firebase
