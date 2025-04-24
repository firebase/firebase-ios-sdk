/*
 * Copyright 2025 Google LLC
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

#include <memory>
#include <vector>

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/firestore.h"  // Needed for Pipeline constructor
#include "Firestore/core/src/api/ordering.h"
#include "Firestore/core/src/api/realtime_pipeline.h"  // Use RealtimePipeline
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/core/pipeline_run.h"
#include "Firestore/core/src/model/database_id.h"  // Needed for Firestore constructor
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/remote/firebase_metadata_provider.h"
#include "Firestore/core/test/unit/core/pipeline/utils.h"  // Include the new utils header
#include "Firestore/core/test/unit/testutil/expression_test_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using api::CollectionSource;
using api::EvaluableStage;  // Use EvaluableStage
using api::Expr;
using api::Field;
using api::LimitStage;
using api::Ordering;
using api::RealtimePipeline;  // Use RealtimePipeline
using api::SortStage;
using api::Where;
using model::DatabaseId;
using model::FieldPath;
using model::MutableDocument;
using model::PipelineInputOutputVector;
using testutil::Array;
using testutil::ArrayContainsExpr;
using testutil::Doc;
using testutil::EqAnyExpr;
using testutil::GtExpr;
using testutil::Map;
using testutil::NeqExpr;
using testutil::SharedConstant;
using testutil::Value;

class CollectionTest : public ::testing::Test {
 public:
  // Helper to create a pipeline starting with a collection stage
  RealtimePipeline StartPipeline(
      const std::string& collection_path) {  // Return RealtimePipeline
    std::vector<std::shared_ptr<EvaluableStage>> stages;  // Use EvaluableStage
    stages.push_back(std::make_shared<CollectionSource>(collection_path));
    return RealtimePipeline(std::move(stages),
                            TestSerializer());  // Construct RealtimePipeline
  }
};

TEST_F(CollectionTest, EmptyDatabaseReturnsNoResults) {
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  PipelineInputOutputVector input_docs = {};
  PipelineInputOutputVector expected_docs = {};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, EmptyCollectionOtherCollectionIdsReturnsNoResults) {
  RealtimePipeline pipeline =
      StartPipeline("/users/bob/games");  // Use RealtimePipeline
  PipelineInputOutputVector input_docs = {
      Doc("users/alice/games/doc1", 1000, Map("title", "minecraft")),
      Doc("users/charlie/games/doc1", 1000, Map("title", "halo"))};
  PipelineInputOutputVector expected_docs = {};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, EmptyCollectionOtherParentsReturnsNoResults) {
  RealtimePipeline pipeline =
      StartPipeline("/users/bob/games");  // Use RealtimePipeline
  PipelineInputOutputVector input_docs = {
      Doc("users/bob/addresses/doc1", 1000, Map("city", "New York")),
      Doc("users/bob/inventories/doc1", 1000, Map("item_id", 42LL))};
  PipelineInputOutputVector expected_docs = {};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, SingletonAtRootReturnsSingleDocument) {
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  auto doc1 = Doc("games/42", 1000, Map("title", "minecraft"));
  auto doc2 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 1LL));
  PipelineInputOutputVector input_docs = {doc1, doc2};
  PipelineInputOutputVector expected_docs = {doc2};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, SingletonNestedCollectionReturnsSingleDocument) {
  RealtimePipeline pipeline =
      StartPipeline("/users/bob/games");  // Use RealtimePipeline
  auto doc1 = Doc("users/bob/addresses/doc1", 1000, Map("city", "New York"));
  auto doc2 = Doc("users/bob/games/doc1", 1000, Map("title", "minecraft"));
  auto doc3 = Doc("users/alice/games/doc1", 1000, Map("title", "halo"));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3};
  PipelineInputOutputVector expected_docs = {doc2};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, MultipleDocumentsAtRootReturnsDocuments) {
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 1LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL, "rank", 2LL));
  auto doc4 = Doc("games/doc1", 1000, Map("title", "minecraft"));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4};
  // Expected order based on TS test (alice, bob, charlie) - assumes RunPipeline
  // sorts by key implicitly?
  PipelineInputOutputVector expected_docs = {doc2, doc1, doc3};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, MultipleDocumentsNestedCollectionReturnsDocuments) {
  // This test seems identical to MultipleDocumentsAtRootReturnsDocuments in TS?
  // Replicating the TS test name and logic.
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 1LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL, "rank", 2LL));
  auto doc4 = Doc("games/doc1", 1000, Map("title", "minecraft"));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4};
  PipelineInputOutputVector expected_docs = {doc2, doc1, doc3};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, SubcollectionNotReturned) {
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 1LL));
  auto doc2 = Doc("users/bob/games/minecraft", 1000, Map("title", "minecraft"));
  auto doc3 = Doc("users/bob/games/minecraft/players/player1", 1000,
                  Map("location", "sf"));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3};
  PipelineInputOutputVector expected_docs = {doc1};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, SkipsOtherCollectionIds) {
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 1LL));
  auto doc2 = Doc("users-other/bob", 1000, Map("score", 90LL, "rank", 1LL));
  auto doc3 = Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));
  auto doc4 = Doc("users-other/alice", 1000, Map("score", 50LL, "rank", 3LL));
  auto doc5 = Doc("users/charlie", 1000, Map("score", 97LL, "rank", 2LL));
  auto doc6 = Doc("users-other/charlie", 1000, Map("score", 97LL, "rank", 2LL));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4, doc5, doc6};
  PipelineInputOutputVector expected_docs = {doc3, doc1,
                                             doc5};  // alice, bob, charlie
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, SkipsOtherParents) {
  RealtimePipeline pipeline =
      StartPipeline("/users/bob/games");  // Use RealtimePipeline
  auto doc1 = Doc("users/bob/games/doc1", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice/games/doc1", 1000, Map("score", 90LL));
  auto doc3 = Doc("users/bob/games/doc2", 1000, Map("score", 20LL));
  auto doc4 = Doc("users/charlie/games/doc1", 1000, Map("score", 20LL));
  auto doc5 = Doc("users/bob/games/doc3", 1000, Map("score", 30LL));
  auto doc6 =
      Doc("users/alice/games/doc1", 1000,
          Map("score", 30LL));  // Note: TS has duplicate alice/games/doc1?
                                // Assuming typo, keeping data.
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4, doc5, doc6};
  PipelineInputOutputVector expected_docs = {
      doc1, doc3, doc5};  // doc1, doc2, doc3 for user bob
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

// --- Where Tests ---

TEST_F(CollectionTest, WhereOnValues) {
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  auto where_expr = EqAnyExpr(std::make_shared<Field>("score"),
                              SharedConstant(Array(Value(90LL), Value(97LL))));
  pipeline = pipeline.AddingStage(std::make_shared<Where>(where_expr));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  auto doc4 = Doc("users/diane", 1000, Map("score", 97LL));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4};
  PipelineInputOutputVector expected_docs = {doc1, doc3,
                                             doc4};  // bob, charlie, diane
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

// Skipping commented out tests from TS: where_sameCollectionId_onPath,
// where_sameCollectionId_onKey, where_differentCollectionId_onPath,
// where_differentCollectionId_onKey

TEST_F(CollectionTest, WhereInequalityOnValues) {
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  auto where_expr =
      GtExpr({std::make_shared<Field>("score"), SharedConstant(80LL)});
  pipeline = pipeline.AddingStage(std::make_shared<Where>(where_expr));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3};
  PipelineInputOutputVector expected_docs = {doc1, doc3};  // bob, charlie
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, WhereNotEqualOnValues) {
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  auto where_expr =
      NeqExpr({std::make_shared<Field>("score"), SharedConstant(50LL)});
  pipeline = pipeline.AddingStage(std::make_shared<Where>(where_expr));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3};
  PipelineInputOutputVector expected_docs = {doc1, doc3};  // bob, charlie
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, WhereArrayContainsValues) {
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  auto where_expr = ArrayContainsExpr(
      {std::make_shared<Field>("rounds"), SharedConstant("round3")});
  // ArrayContainsExpr returns Expr, but Where expects BooleanExpr in TS.
  // Assuming the C++ Where stage handles this conversion or the Expr is
  // boolean.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(where_expr));

  auto doc1 = Doc("users/bob", 1000,
                  Map("score", 90LL, "rounds", Array("round1", "round3")));
  auto doc2 = Doc("users/alice", 1000,
                  Map("score", 50LL, "rounds", Array("round2", "round4")));
  auto doc3 =
      Doc("users/charlie", 1000,
          Map("score", 97LL, "rounds", Array("round2", "round3", "round4")));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3};
  PipelineInputOutputVector expected_docs = {doc1, doc3};  // bob, charlie
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

// --- Sort Tests ---

TEST_F(CollectionTest, SortOnValues) {
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  std::vector<Ordering> orders;
  orders.emplace_back(std::make_unique<Field>("score"), Ordering::DESCENDING);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(orders)));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3};
  PipelineInputOutputVector expected_docs = {doc3, doc1,
                                             doc2};  // charlie, bob, alice
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, SortOnPath) {
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  std::vector<Ordering> orders;
  orders.emplace_back(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                      Ordering::ASCENDING);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(orders)));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3};
  PipelineInputOutputVector expected_docs = {doc2, doc1,
                                             doc3};  // alice, bob, charlie
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

// --- Limit Tests ---

TEST_F(CollectionTest, Limit) {
  RealtimePipeline pipeline = StartPipeline("/users");  // Use RealtimePipeline
  std::vector<Ordering> orders;
  orders.emplace_back(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                      Ordering::ASCENDING);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(orders)));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(2));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3};
  PipelineInputOutputVector expected_docs = {doc2, doc1};  // alice, bob
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

// --- Sort on Key Tests ---

TEST_F(CollectionTest, SortOnKeyAscending) {
  RealtimePipeline pipeline =
      StartPipeline("/users/bob/games");  // Use RealtimePipeline
  std::vector<Ordering> orders;
  orders.emplace_back(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                      Ordering::ASCENDING);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(orders)));

  auto doc1 = Doc("users/bob/games/a", 1000, Map("title", "minecraft"));
  auto doc2 = Doc("users/bob/games/b", 1000, Map("title", "halo"));
  auto doc3 = Doc("users/bob/games/c", 1000, Map("title", "mariocart"));
  auto doc4 = Doc("users/bob/inventories/a", 1000, Map("type", "sword"));
  auto doc5 = Doc("users/alice/games/c", 1000, Map("title", "skyrim"));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4, doc5};
  PipelineInputOutputVector expected_docs = {doc1, doc2, doc3};  // a, b, c
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

TEST_F(CollectionTest, SortOnKeyDescending) {
  RealtimePipeline pipeline =
      StartPipeline("/users/bob/games");  // Use RealtimePipeline
  std::vector<Ordering> orders;
  orders.emplace_back(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                      Ordering::DESCENDING);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(orders)));

  auto doc1 = Doc("users/bob/games/a", 1000, Map("title", "minecraft"));
  auto doc2 = Doc("users/bob/games/b", 1000, Map("title", "halo"));
  auto doc3 = Doc("users/bob/games/c", 1000, Map("title", "mariocart"));
  auto doc4 = Doc("users/bob/inventories/a", 1000, Map("type", "sword"));
  auto doc5 = Doc("users/alice/games/c", 1000, Map("title", "skyrim"));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4, doc5};
  PipelineInputOutputVector expected_docs = {doc3, doc2, doc1};  // c, b, a
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Pass pipeline by ref
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
