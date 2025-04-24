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
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/api/ordering.h"
#include "Firestore/core/src/api/realtime_pipeline.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/core/pipeline_run.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/test/unit/core/pipeline/utils.h"  // Include the new utils header
#include "Firestore/core/test/unit/testutil/expression_test_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

// Using directives from collection_test.cc
using api::CollectionGroupSource;  // Use CollectionGroupSource
using api::EvaluableStage;
using api::Expr;
using api::Field;
using api::LimitStage;
using api::Ordering;
using api::RealtimePipeline;
using api::SortStage;
using api::Where;
using model::DatabaseId;
using model::FieldPath;
using model::MutableDocument;
using model::PipelineInputOutputVector;
using testing::ElementsAre;
using testutil::Array;
using testutil::ArrayContainsExpr;
using testutil::Doc;
using testutil::EqAnyExpr;
using testutil::GtExpr;
using testutil::Map;
using testutil::NeqExpr;
using testutil::SharedConstant;
using testutil::Value;

// Test Fixture for Collection Group tests
class CollectionGroupTest : public ::testing::Test {
 public:
  // Helper to create a pipeline starting with a collection group stage
  RealtimePipeline StartPipeline(const std::string& collection_id) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    // Use CollectionGroupSource here
    stages.push_back(std::make_shared<CollectionGroupSource>(collection_id));
    return RealtimePipeline(std::move(stages),
                            TestSerializer());  // Use shared TestSerializer()
  }
};

TEST_F(CollectionGroupTest, ReturnsNoResultFromEmptyDb) {
  RealtimePipeline pipeline = StartPipeline("users");
  PipelineInputOutputVector input_docs = {};
  PipelineInputOutputVector expected_docs = {};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, ReturnsSingleDocument) {
  RealtimePipeline pipeline = StartPipeline("users");
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 1LL));
  PipelineInputOutputVector input_docs = {doc1};
  PipelineInputOutputVector expected_docs = {doc1};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, ReturnsMultipleDocuments) {
  RealtimePipeline pipeline = StartPipeline("users");
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 1LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL, "rank", 2LL));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3};
  // Expected order based on TS test (alice, bob, charlie) - assumes key sort
  PipelineInputOutputVector expected_docs = {doc2, doc1, doc3};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, SkipsOtherCollectionIds) {
  RealtimePipeline pipeline = StartPipeline("users");
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users-other/bob", 1000, Map("score", 90LL));
  auto doc3 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc4 = Doc("users-other/alice", 1000, Map("score", 50LL));
  auto doc5 = Doc("users/charlie", 1000, Map("score", 97LL));
  auto doc6 = Doc("users-other/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4, doc5, doc6};
  PipelineInputOutputVector expected_docs = {doc3, doc1,
                                             doc5};  // alice, bob, charlie
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, DifferentParents) {
  RealtimePipeline pipeline = StartPipeline("games");
  // Add sort stage from TS test
  std::vector<Ordering> orders;
  orders.emplace_back(std::make_unique<Field>("order"), Ordering::ASCENDING);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(orders)));

  auto doc1 =
      Doc("users/bob/games/game1", 1000, Map("score", 90LL, "order", 1LL));
  auto doc2 =
      Doc("users/alice/games/game1", 1000, Map("score", 90LL, "order", 2LL));
  auto doc3 =
      Doc("users/bob/games/game2", 1000, Map("score", 20LL, "order", 3LL));
  auto doc4 =
      Doc("users/charlie/games/game1", 1000, Map("score", 20LL, "order", 4LL));
  auto doc5 =
      Doc("users/bob/games/game3", 1000, Map("score", 30LL, "order", 5LL));
  auto doc6 =
      Doc("users/alice/games/game2", 1000, Map("score", 30LL, "order", 6LL));
  auto doc7 = Doc("users/charlie/profiles/profile1", 1000,
                  Map("order", 7LL));  // Different collection ID

  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4,
                                          doc5, doc6, doc7};
  // Expected: all 'games' documents, sorted by 'order'
  PipelineInputOutputVector expected_docs = {doc1, doc2, doc3,
                                             doc4, doc5, doc6};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, DifferentParentsStableOrderingOnPath) {
  RealtimePipeline pipeline = StartPipeline("games");
  std::vector<Ordering> orders;
  orders.emplace_back(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                      Ordering::ASCENDING);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(orders)));

  auto doc1 = Doc("users/bob/games/1", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice/games/2", 1000, Map("score", 90LL));
  auto doc3 = Doc("users/bob/games/3", 1000, Map("score", 20LL));
  auto doc4 = Doc("users/charlie/games/4", 1000, Map("score", 20LL));
  auto doc5 = Doc("users/bob/games/5", 1000, Map("score", 30LL));
  auto doc6 = Doc("users/alice/games/6", 1000, Map("score", 30LL));
  auto doc7 =
      Doc("users/charlie/profiles/7", 1000, Map());  // Different collection ID

  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4,
                                          doc5, doc6, doc7};
  // Expected order based on TS test (sorted by full path)
  PipelineInputOutputVector expected_docs = {doc2, doc6, doc1,
                                             doc3, doc5, doc4};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, DifferentParentsStableOrderingOnKey) {
  // This test is identical to DifferentParentsStableOrderingOnPath in TS,
  // as kDocumentKeyPath refers to the full path. Replicating.
  RealtimePipeline pipeline = StartPipeline("games");
  std::vector<Ordering> orders;
  orders.emplace_back(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                      Ordering::ASCENDING);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(orders)));

  auto doc1 = Doc("users/bob/games/1", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice/games/2", 1000, Map("score", 90LL));
  auto doc3 = Doc("users/bob/games/3", 1000, Map("score", 20LL));
  auto doc4 = Doc("users/charlie/games/4", 1000, Map("score", 20LL));
  auto doc5 = Doc("users/bob/games/5", 1000, Map("score", 30LL));
  auto doc6 = Doc("users/alice/games/6", 1000, Map("score", 30LL));
  auto doc7 =
      Doc("users/charlie/profiles/7", 1000, Map());  // Different collection ID

  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4,
                                          doc5, doc6, doc7};
  PipelineInputOutputVector expected_docs = {doc2, doc6, doc1,
                                             doc3, doc5, doc4};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

// Skipping commented out tests from TS related to collectionId() function

TEST_F(CollectionGroupTest, WhereOnValues) {
  RealtimePipeline pipeline = StartPipeline("users");
  auto where_expr = EqAnyExpr(std::make_shared<Field>("score"),
                              SharedConstant(Array(Value(90LL), Value(97LL))));
  pipeline = pipeline.AddingStage(std::make_shared<Where>(where_expr));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  auto doc4 = Doc("users/diane", 1000, Map("score", 97LL));
  auto doc5 = Doc("profiles/admin/users/bob", 1000,
                  Map("score", 90LL));  // Different path, same collection ID

  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4, doc5};
  // Expected: bob, charlie, diane (users collection) + bob (profiles
  // collection) Order based on key sort: alice, bob(profiles), bob(users),
  // charlie, diane Filtered: bob(profiles), bob(users), charlie, diane
  PipelineInputOutputVector expected_docs = {doc5, doc1, doc3, doc4};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, WhereInequalityOnValues) {
  RealtimePipeline pipeline = StartPipeline("users");
  auto where_expr =
      GtExpr({std::make_shared<Field>("score"), SharedConstant(80LL)});
  pipeline = pipeline.AddingStage(std::make_shared<Where>(where_expr));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  auto doc4 = Doc("profiles/admin/users/bob", 1000,
                  Map("score", 90LL));  // Different path

  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4};
  // Expected: bob(users), charlie(users), bob(profiles)
  // Order: bob(profiles), bob(users), charlie(users)
  PipelineInputOutputVector expected_docs = {doc4, doc1, doc3};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, WhereNotEqualOnValues) {
  RealtimePipeline pipeline = StartPipeline("users");
  auto where_expr =
      NeqExpr({std::make_shared<Field>("score"), SharedConstant(50LL)});
  pipeline = pipeline.AddingStage(std::make_shared<Where>(where_expr));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  auto doc4 = Doc("profiles/admin/users/bob", 1000,
                  Map("score", 90LL));  // Different path

  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4};
  // Expected: bob(users), charlie(users), bob(profiles)
  // Order: bob(profiles), bob(users), charlie(users)
  PipelineInputOutputVector expected_docs = {doc4, doc1, doc3};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, WhereArrayContainsValues) {
  RealtimePipeline pipeline = StartPipeline("users");
  auto where_expr = ArrayContainsExpr(
      {std::make_shared<Field>("rounds"), SharedConstant("round3")});
  pipeline = pipeline.AddingStage(std::make_shared<Where>(where_expr));

  auto doc1 = Doc("users/bob", 1000,
                  Map("score", 90LL, "rounds", Array("round1", "round3")));
  auto doc2 = Doc("users/alice", 1000,
                  Map("score", 50LL, "rounds", Array("round2", "round4")));
  auto doc3 =
      Doc("users/charlie", 1000,
          Map("score", 97LL, "rounds", Array("round2", "round3", "round4")));
  auto doc4 = Doc("profiles/admin/users/bob", 1000,
                  Map("score", 90LL, "rounds",
                      Array("round1", "round3")));  // Different path

  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4};
  // Expected: bob(users), charlie(users), bob(profiles)
  // Order: bob(profiles), bob(users), charlie(users)
  PipelineInputOutputVector expected_docs = {doc4, doc1, doc3};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, SortOnValues) {
  RealtimePipeline pipeline = StartPipeline("users");
  std::vector<Ordering> orders;
  orders.emplace_back(std::make_unique<Field>("score"), Ordering::DESCENDING);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(orders)));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  auto doc4 = Doc("profiles/admin/users/bob", 1000,
                  Map("score", 90LL));  // Different path

  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4};
  // Expected: charlie(97), bob(users, 90), bob(profiles, 90), alice(50)
  // Stable sort preserves original relative order for ties (bob(users) before
  // bob(profiles))? Let's assume key sort breaks ties: bob(profiles) before
  // bob(users)
  PipelineInputOutputVector expected_docs = {doc3, doc4, doc1, doc2};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, SortOnValuesHasDenseSemantics) {
  RealtimePipeline pipeline = StartPipeline("users");
  std::vector<Ordering> orders;
  orders.emplace_back(std::make_unique<Field>("score"), Ordering::DESCENDING);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(orders)));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 =
      Doc("users/charlie", 1000, Map("number", 97LL));  // Missing 'score'
  auto doc4 = Doc("profiles/admin/users/bob", 1000,
                  Map("score", 90LL));  // Different path

  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4};
  // Expected: bob(users, 90), bob(profiles, 90), alice(50), charlie(missing
  // score - sorts last?) Tie break: bob(profiles) before bob(users) Order:
  // bob(profiles), bob(users), alice, charlie
  PipelineInputOutputVector expected_docs = {doc4, doc1, doc2, doc3};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, SortOnPath) {
  RealtimePipeline pipeline = StartPipeline("users");
  std::vector<Ordering> orders;
  orders.emplace_back(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                      Ordering::ASCENDING);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(orders)));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  auto doc4 = Doc("profiles/admin/users/bob", 1000,
                  Map("score", 90LL));  // Different path

  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4};
  // Expected: sorted by path: profiles/bob, users/alice, users/bob,
  // users/charlie
  PipelineInputOutputVector expected_docs = {doc4, doc2, doc1, doc3};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

TEST_F(CollectionGroupTest, Limit) {
  RealtimePipeline pipeline = StartPipeline("users");
  std::vector<Ordering> orders;
  orders.emplace_back(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                      Ordering::ASCENDING);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(orders)));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(2));

  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  auto doc4 = Doc("profiles/admin/users/bob", 1000,
                  Map("score", 90LL));  // Different path

  PipelineInputOutputVector input_docs = {doc1, doc2, doc3, doc4};
  // Expected: sorted by path, then limited: profiles/bob, users/alice
  PipelineInputOutputVector expected_docs = {doc4, doc2};
  EXPECT_THAT(RunPipeline(pipeline, input_docs),
              ReturnsDocs(expected_docs));  // Use shared DocsEq
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
