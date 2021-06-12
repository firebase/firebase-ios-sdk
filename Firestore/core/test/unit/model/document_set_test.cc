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

#include "Firestore/core/src/model/document_set.h"

#include <vector>

#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/util/delayed_constructor.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {
namespace {

using testing::ElementsAre;
using testing::Eq;
using testutil::Doc;
using testutil::DocComparator;
using testutil::DocSet;
using testutil::Map;

class DocumentSetTest : public testing::Test {
 public:
  DocumentComparator comp_ = DocComparator("sort");
  Document doc1_ = Doc("docs/1", 0, Map("sort", 2));
  Document doc2_ = Doc("docs/2", 0, Map("sort", 3));
  Document doc3_ = Doc("docs/3", 0, Map("sort", 1));
};

TEST_F(DocumentSetTest, Count) {
  EXPECT_EQ(DocSet(comp_, {}).size(), 0);
  EXPECT_EQ(DocSet(comp_, {doc1_, doc2_, doc3_}).size(), 3);
}

TEST_F(DocumentSetTest, HasKey) {
  DocumentSet set = DocSet(comp_, {doc1_, doc2_});

  EXPECT_TRUE(set.ContainsKey(doc1_->key()));
  EXPECT_TRUE(set.ContainsKey(doc2_->key()));
  EXPECT_FALSE(set.ContainsKey(doc3_->key()));
}

TEST_F(DocumentSetTest, DocumentForKey) {
  DocumentSet set = DocSet(comp_, {doc1_, doc2_});

  EXPECT_EQ(set.GetDocument(doc1_->key()), doc1_);
  EXPECT_EQ(set.GetDocument(doc2_->key()), doc2_);
  EXPECT_EQ(set.GetDocument(doc3_->key()), absl::nullopt);
}

TEST_F(DocumentSetTest, FirstAndLastDocument) {
  DocumentSet set = DocSet(comp_, {});
  EXPECT_EQ(set.GetFirstDocument(), absl::nullopt);
  EXPECT_EQ(set.GetLastDocument(), absl::nullopt);

  set = DocSet(comp_, {doc1_, doc2_, doc3_});
  EXPECT_EQ(set.GetFirstDocument(), doc3_);
  EXPECT_EQ(set.GetLastDocument(), doc2_);
}

TEST_F(DocumentSetTest, KeepsDocumentsInTheRightOrder) {
  DocumentSet set = DocSet(comp_, {doc1_, doc2_, doc3_});
  ASSERT_THAT(set, ElementsAre(doc3_, doc1_, doc2_));
}

TEST_F(DocumentSetTest, Deletes) {
  DocumentSet set = DocSet(comp_, {doc1_, doc2_, doc3_});

  DocumentSet set_without_doc1 = set.erase(doc1_->key());
  ASSERT_THAT(set_without_doc1, ElementsAre(doc3_, doc2_));
  EXPECT_EQ(set_without_doc1.size(), 2);

  // Original remains unchanged
  ASSERT_THAT(set, ElementsAre(doc3_, doc1_, doc2_));

  DocumentSet set_without_doc3 = set_without_doc1.erase(doc3_->key());
  ASSERT_THAT(set_without_doc3, ElementsAre(doc2_));
  EXPECT_EQ(set_without_doc3.size(), 1);
}

TEST_F(DocumentSetTest, Updates) {
  DocumentSet set = DocSet(comp_, {doc1_, doc2_, doc3_});

  Document doc2_prime = Doc("docs/2", 0, Map("sort", 9));

  set = set.insert(doc2_prime);
  ASSERT_EQ(set.size(), 3);
  EXPECT_EQ(set.GetDocument(doc2_prime->key()), doc2_prime);
  ASSERT_THAT(set, ElementsAre(doc3_, doc1_, doc2_prime));
}

TEST_F(DocumentSetTest, AddsDocsWithEqualComparisonValues) {
  Document doc4 = Doc("docs/4", 0, Map("sort", 2));

  DocumentSet set = DocSet(comp_, {doc1_, doc4});
  ASSERT_THAT(set, ElementsAre(doc1_, doc4));
}

TEST_F(DocumentSetTest, Equality) {
  DocumentSet empty{DocumentComparator::ByKey()};
  DocumentSet set1 = DocSet(DocumentComparator::ByKey(), {doc1_, doc2_, doc3_});
  DocumentSet set2 = DocSet(DocumentComparator::ByKey(), {doc1_, doc2_, doc3_});
  EXPECT_EQ(set1, set1);
  EXPECT_EQ(set1, set2);
  EXPECT_NE(set1, empty);

  DocumentSet sorted_set1 = DocSet(comp_, {doc1_, doc2_, doc3_});
  DocumentSet sorted_set2 = DocSet(comp_, {doc1_, doc2_, doc3_});
  EXPECT_EQ(sorted_set1, sorted_set1);
  EXPECT_EQ(sorted_set1, sorted_set2);
  EXPECT_NE(sorted_set1, empty);

  DocumentSet short_set = DocSet(DocumentComparator::ByKey(), {doc1_, doc2_});
  EXPECT_NE(set1, short_set);
  EXPECT_NE(set1, sorted_set1);
}

}  // namespace
}  // namespace model
}  // namespace firestore
}  // namespace firebase
