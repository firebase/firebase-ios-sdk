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
#include <string>
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
#include "Firestore/core/test/unit/core/pipeline/utils.h"  // Shared utils
#include "Firestore/core/test/unit/testutil/expression_test_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using api::CollectionSource;
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
using model::ObjectValue;
using model::PipelineInputOutputVector;
using testing::ElementsAre;
using testing::UnorderedElementsAre;  // Use for unordered checks
using testutil::Array;
using testutil::Doc;
using testutil::Map;
using testutil::SharedConstant;
using testutil::Value;
// Expression helpers
using testutil::AddExpr;
using testutil::AndExpr;
using testutil::ArrayContainsAllExpr;
using testutil::ArrayContainsAnyExpr;
using testutil::ArrayContainsExpr;
using testutil::EqAnyExpr;
using testutil::EqExpr;
using testutil::GteExpr;
using testutil::GtExpr;
using testutil::IsNanExpr;
using testutil::IsNullExpr;
using testutil::LikeExpr;
using testutil::LteExpr;
using testutil::LtExpr;
using testutil::NeqExpr;
using testutil::NotEqAnyExpr;
using testutil::NotExpr;
using testutil::OrExpr;
using testutil::XorExpr;

// Test Fixture for Disjunctive Pipeline tests
class DisjunctivePipelineTest : public ::testing::Test {
 public:
  // Helper to create a pipeline starting with a collection stage
  RealtimePipeline StartPipeline(const std::string& collection_path) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(std::make_shared<CollectionSource>(collection_path));
    return RealtimePipeline(std::move(stages), TestSerializer());
  }

  // Helper for collection group pipelines
  RealtimePipeline StartCollectionGroupPipeline(
      const std::string& collection_id) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(
        std::make_shared<api::CollectionGroupSource>(collection_id));
    return RealtimePipeline(std::move(stages), TestSerializer());
  }
};

TEST_F(DisjunctivePipelineTest, BasicEqAny) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000,
                  Map("name", "bob", "age", 25.0));  // Use 25.0 for double
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(EqAnyExpr(
      std::make_shared<Field>("name"),
      SharedConstant(Array(Value("alice"), Value("bob"), Value("charlie"),
                           Value("diane"), Value("eric"))))));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, MultipleEqAny) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqAnyExpr(
           std::make_shared<Field>("name"),
           SharedConstant(Array(Value("alice"), Value("bob"), Value("charlie"),
                                Value("diane"), Value("eric")))),
       EqAnyExpr(std::make_shared<Field>("age"),
                 SharedConstant(Array(Value(10.0), Value(25.0))))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, EqAnyMultipleStages) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(EqAnyExpr(
      std::make_shared<Field>("name"),
      SharedConstant(Array(Value("alice"), Value("bob"), Value("charlie"),
                           Value("diane"), Value("eric"))))));
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqAnyExpr(std::make_shared<Field>("age"),
                SharedConstant(Array(Value(10.0), Value(25.0))))));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, MultipleEqAnysWithOr) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      OrExpr({EqAnyExpr(std::make_shared<Field>("name"),
                        SharedConstant(Array(Value("alice"), Value("bob")))),
              EqAnyExpr(std::make_shared<Field>("age"),
                        SharedConstant(Array(Value(10.0), Value(25.0))))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, EqAnyOnCollectionGroup) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("other_users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 =
      Doc("root/child/users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 =
      Doc("root/child/other_users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartCollectionGroupPipeline("users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqAnyExpr(std::make_shared<Field>("name"),
                SharedConstant(Array(Value("alice"), Value("bob"),
                                     Value("diane"), Value("eric"))))));

  // Note: Collection group queries only match documents in collections with the
  // specified ID.
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc4));
}

TEST_F(DisjunctivePipelineTest, EqAnyWithSortOnDifferentField) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 =
      Doc("users/c", 1000,
          Map("name", "charlie", "age", 100.0));  // Not matched by EqAny
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqAnyExpr(std::make_shared<Field>("name"),
                SharedConstant(Array(Value("alice"), Value("bob"),
                                     Value("diane"), Value("eric"))))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  // Order matters here due to sort
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc4, doc5, doc2, doc1));
}

TEST_F(DisjunctivePipelineTest, EqAnyWithSortOnEqAnyField) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000,
                  Map("name", "charlie", "age", 100.0));  // Not matched
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqAnyExpr(std::make_shared<Field>("name"),
                SharedConstant(Array(Value("alice"), Value("bob"),
                                     Value("diane"), Value("eric"))))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("name"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc1, doc2, doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, EqAnyWithAdditionalEqualityDifferentFields) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqAnyExpr(
           std::make_shared<Field>("name"),
           SharedConstant(Array(Value("alice"), Value("bob"), Value("charlie"),
                                Value("diane"), Value("eric")))),
       EqExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(10.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("name"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, EqAnyWithAdditionalEqualitySameField) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      AndExpr({EqAnyExpr(std::make_shared<Field>("name"),
                         SharedConstant(Array(Value("alice"), Value("diane"),
                                              Value("eric")))),
               EqExpr({std::make_shared<Field>("name"),
                       SharedConstant(Value("eric"))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc5));
}

TEST_F(DisjunctivePipelineTest,
       EqAnyWithAdditionalEqualitySameFieldEmptyResult) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      AndExpr({EqAnyExpr(std::make_shared<Field>("name"),
                         SharedConstant(Array(Value("alice"), Value("bob")))),
               EqExpr({std::make_shared<Field>("name"),
                       SharedConstant(Value("other"))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre());  // Expect empty result
}

TEST_F(DisjunctivePipelineTest, EqAnyWithInequalitiesExclusiveRange) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000,
                  Map("name", "eric", "age", 10.0));  // Not matched by EqAny
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqAnyExpr(std::make_shared<Field>("name"),
                 SharedConstant(Array(Value("alice"), Value("bob"),
                                      Value("charlie"), Value("diane")))),
       GtExpr({std::make_shared<Field>("age"), SharedConstant(Value(10.0))}),
       LtExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(100.0))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2));
}

TEST_F(DisjunctivePipelineTest, EqAnyWithInequalitiesInclusiveRange) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000,
                  Map("name", "eric", "age", 10.0));  // Not matched by EqAny
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqAnyExpr(std::make_shared<Field>("name"),
                 SharedConstant(Array(Value("alice"), Value("bob"),
                                      Value("charlie"), Value("diane")))),
       GteExpr({std::make_shared<Field>("age"), SharedConstant(Value(10.0))}),
       LteExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(100.0))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4));
}

TEST_F(DisjunctivePipelineTest, EqAnyWithInequalitiesAndSort) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000,
                  Map("name", "eric", "age", 10.0));  // Not matched by EqAny
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqAnyExpr(std::make_shared<Field>("name"),
                 SharedConstant(Array(Value("alice"), Value("bob"),
                                      Value("charlie"), Value("diane")))),
       GtExpr({std::make_shared<Field>("age"), SharedConstant(Value(10.0))}),
       LtExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(100.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2, doc1));
}

TEST_F(DisjunctivePipelineTest, EqAnyWithNotEqual) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000,
                  Map("name", "eric", "age", 10.0));  // Not matched by EqAny
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqAnyExpr(std::make_shared<Field>("name"),
                 SharedConstant(Array(Value("alice"), Value("bob"),
                                      Value("charlie"), Value("diane")))),
       NeqExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(100.0))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc4));
}

TEST_F(DisjunctivePipelineTest,
       EqAnySortOnEqAnyField) {  // Duplicate of EqAnyWithSortOnEqAnyField?
                                 // Renaming slightly.
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000,
                  Map("name", "eric", "age", 10.0));  // Not matched by EqAny
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqAnyExpr(std::make_shared<Field>("name"),
                SharedConstant(Array(Value("alice"), Value("bob"),
                                     Value("charlie"), Value("diane"))))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("name"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc1, doc2, doc3, doc4));
}

TEST_F(DisjunctivePipelineTest, EqAnySingleValueSortOnInFieldAmbiguousOrder) {
  auto doc1 = Doc("users/c", 1000,
                  Map("name", "charlie", "age", 100.0));  // Not matched
  auto doc2 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc3 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(EqAnyExpr(
      std::make_shared<Field>("age"), SharedConstant(Array(Value(10.0))))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  // Order between doc2 and doc3 is ambiguous based only on age, gMock
  // ElementsAre checks order. We expect them, but the exact order isn't
  // guaranteed by the query itself. Using UnorderedElementsAre might be more
  // appropriate if strict order isn't required by the test intent. Sticking to
  // ElementsAre to match TS `ordered.members`.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2, doc3));
}

TEST_F(DisjunctivePipelineTest, EqAnyWithExtraEqualitySortOnEqAnyField) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqAnyExpr(
           std::make_shared<Field>("name"),
           SharedConstant(Array(Value("alice"), Value("bob"), Value("charlie"),
                                Value("diane"), Value("eric")))),
       EqExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(10.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("name"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, EqAnyWithExtraEqualitySortOnEquality) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqAnyExpr(
           std::make_shared<Field>("name"),
           SharedConstant(Array(Value("alice"), Value("bob"), Value("charlie"),
                                Value("diane"), Value("eric")))),
       EqExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(10.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  // Sort by age (which is constant 10.0 for matches), secondary sort by key
  // implicitly happens.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, EqAnyWithInequalityOnSameField) {
  auto doc1 = Doc("users/a", 1000,
                  Map("name", "alice", "age", 75.5));  // Not matched by EqAny
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000,
                  Map("name", "diane", "age", 10.0));  // Not matched by Gt
  auto doc5 = Doc("users/e", 1000,
                  Map("name", "eric", "age", 10.0));  // Not matched by Gt
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqAnyExpr(std::make_shared<Field>("age"),
                 SharedConstant(Array(Value(10.0), Value(25.0), Value(100.0)))),
       GtExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(20.0))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc3));
}

TEST_F(
    DisjunctivePipelineTest,
    EqAnyWithDifferentInequalitySortOnEqAnyField) {  // Renamed from TS:
                                                     // eqAny_withDifferentInequality_sortOnInField
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000,
                  Map("name", "diane", "age", 10.0));  // Not matched by Gt
  auto doc5 =
      Doc("users/e", 1000,
          Map("name", "eric", "age", 10.0));  // Not matched by EqAny or Gt
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqAnyExpr(std::make_shared<Field>("name"),
                 SharedConstant(Array(Value("alice"), Value("bob"),
                                      Value("charlie"), Value("diane")))),
       GtExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(20.0))})})));
  // Sort field is 'age', which is the inequality field, not the EqAny field
  // 'name'. The TS test name seems misleading based on the sort field used.
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2, doc1, doc3));
}

TEST_F(DisjunctivePipelineTest, EqAnyContainsNull) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 =
      Doc("users/b", 1000, Map("name", nullptr, "age", 25.0));  // name is null
  auto doc3 = Doc("users/c", 1000, Map("age", 100.0));  // name is missing
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // Firestore queries do not match Null values with equality filters, including
  // IN.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqAnyExpr(std::make_shared<Field>("name"),
                SharedConstant(Array(Value(nullptr), Value("alice"))))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(DisjunctivePipelineTest, ArrayContainsNull) {
  auto doc1 =
      Doc("users/a", 1000, Map("field", Array(Value(nullptr), Value(42LL))));
  auto doc2 =
      Doc("users/b", 1000, Map("field", Array(Value(101LL), Value(nullptr))));
  auto doc3 = Doc("users/c", 1000, Map("field", Array(Value(nullptr))));
  auto doc4 =
      Doc("users/d", 1000, Map("field", Array(Value("foo"), Value("bar"))));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  // Firestore array_contains does not match Null values.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(ArrayContainsExpr(
      {std::make_shared<Field>("field"), SharedConstant(Value(nullptr))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

TEST_F(DisjunctivePipelineTest, ArrayContainsAnyNull) {
  auto doc1 =
      Doc("users/a", 1000, Map("field", Array(Value(nullptr), Value(42LL))));
  auto doc2 =
      Doc("users/b", 1000, Map("field", Array(Value(101LL), Value(nullptr))));
  auto doc3 =
      Doc("users/c", 1000, Map("field", Array(Value("foo"), Value("bar"))));
  auto doc4 = Doc(
      "users/d", 1000,
      Map("not_field", Array(Value("foo"), Value("bar"))));  // Field missing
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  // Firestore array_contains_any does not match Null values.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(ArrayContainsAnyExpr(
      {std::make_shared<Field>("field"),
       SharedConstant(Array(Value(nullptr), Value("foo")))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3));
}

TEST_F(DisjunctivePipelineTest, EqAnyContainsNullOnly) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", nullptr));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // Firestore IN queries do not match Null values.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(EqAnyExpr(
      std::make_shared<Field>("age"), SharedConstant(Array(Value(nullptr))))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

TEST_F(DisjunctivePipelineTest, BasicArrayContainsAny) {
  auto doc1 = Doc("users/a", 1000,
                  Map("name", "alice", "groups",
                      Array(Value(1LL), Value(2LL), Value(3LL))));
  auto doc2 = Doc(
      "users/b", 1000,
      Map("name", "bob", "groups", Array(Value(1LL), Value(2LL), Value(4LL))));
  auto doc3 = Doc("users/c", 1000,
                  Map("name", "charlie", "groups",
                      Array(Value(2LL), Value(3LL), Value(4LL))));
  auto doc4 = Doc("users/d", 1000,
                  Map("name", "diane", "groups",
                      Array(Value(2LL), Value(3LL), Value(5LL))));
  auto doc5 = Doc(
      "users/e", 1000,
      Map("name", "eric", "groups", Array(Value(3LL), Value(4LL), Value(5LL))));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      ArrayContainsAnyExpr({std::make_shared<Field>("groups"),
                            SharedConstant(Array(Value(1LL), Value(5LL)))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, MultipleArrayContainsAny) {
  auto doc1 = Doc(
      "users/a", 1000,
      Map("name", "alice", "groups", Array(Value(1LL), Value(2LL), Value(3LL)),
          "records", Array(Value("a"), Value("b"), Value("c"))));
  auto doc2 = Doc(
      "users/b", 1000,
      Map("name", "bob", "groups", Array(Value(1LL), Value(2LL), Value(4LL)),
          "records", Array(Value("b"), Value("c"), Value("d"))));
  auto doc3 = Doc("users/c", 1000,
                  Map("name", "charlie", "groups",
                      Array(Value(2LL), Value(3LL), Value(4LL)), "records",
                      Array(Value("b"), Value("c"), Value("e"))));
  auto doc4 = Doc(
      "users/d", 1000,
      Map("name", "diane", "groups", Array(Value(2LL), Value(3LL), Value(5LL)),
          "records", Array(Value("c"), Value("d"), Value("e"))));
  auto doc5 = Doc(
      "users/e", 1000,
      Map("name", "eric", "groups", Array(Value(3LL), Value(4LL), Value(5LL)),
          "records", Array(Value("c"), Value("d"), Value("f"))));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {ArrayContainsAnyExpr({std::make_shared<Field>("groups"),
                             SharedConstant(Array(Value(1LL), Value(5LL)))}),
       ArrayContainsAnyExpr(
           {std::make_shared<Field>("records"),
            SharedConstant(Array(Value("a"), Value("e")))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc4));
}

TEST_F(DisjunctivePipelineTest, ArrayContainsAnyWithInequality) {
  auto doc1 = Doc("users/a", 1000,
                  Map("name", "alice", "groups",
                      Array(Value(1LL), Value(2LL), Value(3LL))));
  auto doc2 = Doc(
      "users/b", 1000,
      Map("name", "bob", "groups", Array(Value(1LL), Value(2LL), Value(4LL))));
  auto doc3 = Doc("users/c", 1000,
                  Map("name", "charlie", "groups",
                      Array(Value(2LL), Value(3LL),
                            Value(4LL))));  // Matched by ACA, filtered by LT
  auto doc4 = Doc("users/d", 1000,
                  Map("name", "diane", "groups",
                      Array(Value(2LL), Value(3LL), Value(5LL))));
  auto doc5 = Doc(
      "users/e", 1000,
      Map("name", "eric", "groups", Array(Value(3LL), Value(4LL), Value(5LL))));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {ArrayContainsAnyExpr({std::make_shared<Field>("groups"),
                             SharedConstant(Array(Value(1LL), Value(5LL)))}),
       // Note: Comparing an array field with an array constant using LT might
       // not behave as expected in Firestore backend queries. This test
       // replicates the TS behavior for pipeline evaluation.
       LtExpr({std::make_shared<Field>("groups"),
               SharedConstant(Array(Value(3LL), Value(4LL), Value(5LL)))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc4));
}

TEST_F(DisjunctivePipelineTest,
       ArrayContainsAnyWithIn) {  // Renamed from TS: arrayContainsAny_withIn
  auto doc1 = Doc("users/a", 1000,
                  Map("name", "alice", "groups",
                      Array(Value(1LL), Value(2LL), Value(3LL))));
  auto doc2 = Doc(
      "users/b", 1000,
      Map("name", "bob", "groups", Array(Value(1LL), Value(2LL), Value(4LL))));
  auto doc3 = Doc("users/c", 1000,
                  Map("name", "charlie", "groups",
                      Array(Value(2LL), Value(3LL), Value(4LL))));
  auto doc4 = Doc("users/d", 1000,
                  Map("name", "diane", "groups",
                      Array(Value(2LL), Value(3LL), Value(5LL))));
  auto doc5 = Doc(
      "users/e", 1000,
      Map("name", "eric", "groups", Array(Value(3LL), Value(4LL), Value(5LL))));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {ArrayContainsAnyExpr({std::make_shared<Field>("groups"),
                             SharedConstant(Array(Value(1LL), Value(5LL)))}),
       EqAnyExpr(std::make_shared<Field>("name"),
                 SharedConstant(Array(Value("alice"), Value("bob"))))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2));
}

TEST_F(DisjunctivePipelineTest, BasicOr) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {EqExpr({std::make_shared<Field>("name"), SharedConstant(Value("bob"))}),
       EqExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(10.0))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc4));
}

TEST_F(DisjunctivePipelineTest, MultipleOr) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {EqExpr({std::make_shared<Field>("name"), SharedConstant(Value("bob"))}),
       EqExpr(
           {std::make_shared<Field>("name"), SharedConstant(Value("diane"))}),
       EqExpr({std::make_shared<Field>("age"), SharedConstant(Value(25.0))}),
       EqExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(100.0))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc3, doc4));
}

TEST_F(DisjunctivePipelineTest, OrMultipleStages) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {EqExpr({std::make_shared<Field>("name"), SharedConstant(Value("bob"))}),
       EqExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(10.0))})})));
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      OrExpr({EqExpr({std::make_shared<Field>("name"),
                      SharedConstant(Value("diane"))}),
              EqExpr({std::make_shared<Field>("age"),
                      SharedConstant(Value(100.0))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4));
}

TEST_F(DisjunctivePipelineTest, OrTwoConjunctions) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      OrExpr({AndExpr({EqExpr({std::make_shared<Field>("name"),
                               SharedConstant(Value("bob"))}),
                       EqExpr({std::make_shared<Field>("age"),
                               SharedConstant(Value(25.0))})}),
              AndExpr({EqExpr({std::make_shared<Field>("name"),
                               SharedConstant(Value("diane"))}),
                       EqExpr({std::make_shared<Field>("age"),
                               SharedConstant(Value(10.0))})})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc4));
}

TEST_F(DisjunctivePipelineTest, OrWithInAnd) {  // Renamed from TS: or_withInAnd
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      AndExpr({OrExpr({EqExpr({std::make_shared<Field>("name"),
                               SharedConstant(Value("bob"))}),
                       EqExpr({std::make_shared<Field>("age"),
                               SharedConstant(Value(10.0))})}),
               LtExpr({std::make_shared<Field>("age"),
                       SharedConstant(Value(80.0))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc4));
}

TEST_F(DisjunctivePipelineTest, AndOfTwoOrs) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      AndExpr({OrExpr({EqExpr({std::make_shared<Field>("name"),
                               SharedConstant(Value("bob"))}),
                       EqExpr({std::make_shared<Field>("age"),
                               SharedConstant(Value(10.0))})}),
               OrExpr({EqExpr({std::make_shared<Field>("name"),
                               SharedConstant(Value("diane"))}),
                       EqExpr({std::make_shared<Field>("age"),
                               SharedConstant(Value(100.0))})})})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4));
}

TEST_F(DisjunctivePipelineTest, OrOfTwoOrs) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      OrExpr({OrExpr({EqExpr({std::make_shared<Field>("name"),
                              SharedConstant(Value("bob"))}),
                      EqExpr({std::make_shared<Field>("age"),
                              SharedConstant(Value(10.0))})}),
              OrExpr({EqExpr({std::make_shared<Field>("name"),
                              SharedConstant(Value("diane"))}),
                      EqExpr({std::make_shared<Field>("age"),
                              SharedConstant(Value(100.0))})})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc3, doc4));
}

TEST_F(DisjunctivePipelineTest, OrWithEmptyRangeInOneDisjunction) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {EqExpr({std::make_shared<Field>("name"), SharedConstant(Value("bob"))}),
       AndExpr({// This conjunction will always be false
                EqExpr({std::make_shared<Field>("age"),
                        SharedConstant(Value(10.0))}),
                GtExpr({std::make_shared<Field>("age"),
                        SharedConstant(Value(20.0))})})})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2));
}

TEST_F(DisjunctivePipelineTest, OrWithSort) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(OrExpr({EqExpr({std::make_shared<Field>("name"),
                                              SharedConstant(Value("diane"))}),
                                      GtExpr({std::make_shared<Field>("age"),
                                              SharedConstant(Value(20.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc4, doc2, doc1, doc3));
}

TEST_F(DisjunctivePipelineTest, OrWithInequalityAndSortSameField) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 =
      Doc("users/b", 1000, Map("name", "bob", "age", 25.0));  // Not matched
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {LtExpr({std::make_shared<Field>("age"), SharedConstant(Value(20.0))}),
       GtExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(50.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc1, doc3));
}

TEST_F(DisjunctivePipelineTest, OrWithInequalityAndSortDifferentFields) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 =
      Doc("users/b", 1000, Map("name", "bob", "age", 25.0));  // Not matched
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {LtExpr({std::make_shared<Field>("age"), SharedConstant(Value(20.0))}),
       GtExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(50.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("name"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc3, doc4));
}

TEST_F(DisjunctivePipelineTest, OrWithInequalityAndSortMultipleFields) {
  auto doc1 =
      Doc("users/a", 1000, Map("name", "alice", "age", 25.0, "height", 170.0));
  auto doc2 =
      Doc("users/b", 1000, Map("name", "bob", "age", 25.0, "height", 180.0));
  auto doc3 = Doc(
      "users/c", 1000,
      Map("name", "charlie", "age", 100.0, "height", 155.0));  // Not matched
  auto doc4 =
      Doc("users/d", 1000, Map("name", "diane", "age", 10.0, "height", 150.0));
  auto doc5 =
      Doc("users/e", 1000, Map("name", "eric", "age", 25.0, "height", 170.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {LtExpr({std::make_shared<Field>("age"), SharedConstant(Value(80.0))}),
       GtExpr({std::make_shared<Field>("height"),
               SharedConstant(Value(160.0))})})));
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(std::make_unique<Field>("age"),
                   Ordering::Direction::ASCENDING),
          Ordering(std::make_unique<Field>("height"),
                   Ordering::Direction::DESCENDING),
          Ordering(std::make_unique<Field>("name"),
                   Ordering::Direction::ASCENDING)  // Use name for tie-breaking
      }));

  // Expected order: doc4 (age 10), doc2 (age 25, height 180), doc1 (age 25,
  // height 170, name alice), doc5 (age 25, height 170, name eric)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc4, doc2, doc1, doc5));
}

TEST_F(DisjunctivePipelineTest, OrWithSortOnPartialMissingField) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "diane"));  // age missing
  auto doc4 = Doc("users/d", 1000,
                  Map("name", "diane", "height", 150.0));  // age missing
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(OrExpr({EqExpr({std::make_shared<Field>("name"),
                                              SharedConstant(Value("diane"))}),
                                      GtExpr({std::make_shared<Field>("age"),
                                              SharedConstant(Value(20.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  // Order: Missing age sorts first (doc3, doc4), then by age (doc2, doc1).
  // Within missing age, order by key: users/c < users/d
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc3, doc4, doc2, doc1));
}

TEST_F(DisjunctivePipelineTest, OrWithLimit) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(OrExpr({EqExpr({std::make_shared<Field>("name"),
                                              SharedConstant(Value("diane"))}),
                                      GtExpr({std::make_shared<Field>("age"),
                                              SharedConstant(Value(20.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(2));

  // Takes the first 2 after sorting: doc4, doc2
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc2));
}

// TODO(pipeline): uncomment when we have isNot implemented
// The original TS test 'or_isNullAndEqOnSameField' uses isNull which is
// available.
TEST_F(DisjunctivePipelineTest, OrIsNullAndEqOnSameField) {
  auto doc1 = Doc("users/a", 1000, Map("a", 1LL));
  auto doc2 =
      Doc("users/b", 1000,
          Map("a", 1.0));  // Matches Eq(1) due to type coercion? Check
                           // Firestore rules. Assuming 1.0 matches 1LL for now.
  auto doc3 = Doc("users/c", 1000, Map("a", 1LL, "b", 1LL));
  auto doc4 = Doc("users/d", 1000, Map("a", nullptr));
  auto doc5 = Doc("users/e", 1000,
                  Map("a", std::numeric_limits<double>::quiet_NaN()));  // NaN
  auto doc6 = Doc("users/f", 1000, Map("b", "abc"));  // 'a' missing
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5, doc6};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {EqExpr({std::make_shared<Field>("a"), SharedConstant(Value(1LL))}),
       IsNullExpr(std::make_shared<Field>("a"))})));

  // Expect docs where a==1 (doc1, doc2, doc3) or a is null (doc4)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4));
}

TEST_F(DisjunctivePipelineTest, OrIsNullAndEqOnDifferentField) {
  auto doc1 = Doc("users/a", 1000, Map("a", 1LL));
  auto doc2 = Doc("users/b", 1000, Map("a", 1.0));
  auto doc3 = Doc("users/c", 1000, Map("a", 1LL, "b", 1LL));
  auto doc4 = Doc("users/d", 1000, Map("a", nullptr));
  auto doc5 =
      Doc("users/e", 1000, Map("a", std::numeric_limits<double>::quiet_NaN()));
  auto doc6 = Doc("users/f", 1000, Map("b", "abc"));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5, doc6};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {EqExpr({std::make_shared<Field>("b"), SharedConstant(Value(1LL))}),
       IsNullExpr(std::make_shared<Field>("a"))})));

  // Expect docs where b==1 (doc3) or a is null (doc4)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc3, doc4));
}

TEST_F(DisjunctivePipelineTest, OrIsNotNullAndEqOnSameField) {
  auto doc1 = Doc("users/a", 1000, Map("a", 1LL));
  auto doc2 = Doc("users/b", 1000, Map("a", 1.0));
  auto doc3 = Doc("users/c", 1000, Map("a", 1LL, "b", 1LL));
  auto doc4 = Doc("users/d", 1000, Map("a", nullptr));
  auto doc5 =
      Doc("users/e", 1000, Map("a", std::numeric_limits<double>::quiet_NaN()));
  auto doc6 = Doc("users/f", 1000, Map("b", "abc"));  // 'a' missing
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5, doc6};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr({
      // Note: TS test uses gt(1), C++ uses gt(1) here too.
      GtExpr({std::make_shared<Field>("a"), SharedConstant(Value(1LL))}),
      NotExpr(IsNullExpr(std::make_shared<Field>("a")))  // isNotNull
  })));

  // Expect docs where a > 1 (none) or a is not null (doc1, doc2, doc3, doc5 -
  // NaN is not null)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc5));
}

TEST_F(DisjunctivePipelineTest, OrIsNotNullAndEqOnDifferentField) {
  auto doc1 = Doc("users/a", 1000, Map("a", 1LL));
  auto doc2 = Doc("users/b", 1000, Map("a", 1.0));
  auto doc3 = Doc("users/c", 1000, Map("a", 1LL, "b", 1LL));
  auto doc4 = Doc("users/d", 1000, Map("a", nullptr));
  auto doc5 =
      Doc("users/e", 1000, Map("a", std::numeric_limits<double>::quiet_NaN()));
  auto doc6 = Doc("users/f", 1000, Map("b", "abc"));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5, doc6};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr({
      EqExpr({std::make_shared<Field>("b"), SharedConstant(Value(1LL))}),
      NotExpr(IsNullExpr(std::make_shared<Field>("a")))  // isNotNull
  })));

  // Expect docs where b==1 (doc3) or a is not null (doc1, doc2, doc3, doc5)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc5));
}

TEST_F(DisjunctivePipelineTest, OrIsNullAndIsNaNOnSameField) {
  auto doc1 = Doc("users/a", 1000, Map("a", nullptr));
  auto doc2 =
      Doc("users/b", 1000, Map("a", std::numeric_limits<double>::quiet_NaN()));
  auto doc3 = Doc("users/c", 1000, Map("a", "abc"));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      OrExpr({IsNullExpr(std::make_shared<Field>("a")),
              IsNanExpr(std::make_shared<Field>("a"))})));

  // Expect docs where a is null (doc1) or a is NaN (doc2)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2));
}

TEST_F(DisjunctivePipelineTest, OrIsNullAndIsNaNOnDifferentField) {
  auto doc1 = Doc("users/a", 1000, Map("a", nullptr));
  auto doc2 =
      Doc("users/b", 1000, Map("a", std::numeric_limits<double>::quiet_NaN()));
  auto doc3 = Doc("users/c", 1000, Map("a", "abc"));
  auto doc4 = Doc("users/d", 1000, Map("b", nullptr));
  auto doc5 =
      Doc("users/e", 1000, Map("b", std::numeric_limits<double>::quiet_NaN()));
  auto doc6 = Doc("users/f", 1000, Map("b", "abc"));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5, doc6};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      OrExpr({IsNullExpr(std::make_shared<Field>("a")),
              IsNanExpr(std::make_shared<Field>("b"))})));

  // Expect docs where a is null (doc1) or b is NaN (doc5)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc5));
}

TEST_F(DisjunctivePipelineTest, BasicNotEqAny) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotEqAnyExpr(std::make_shared<Field>("name"),
                   SharedConstant(Array(Value("alice"), Value("bob"))))));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc3, doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, MultipleNotEqAnys) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {NotEqAnyExpr(std::make_shared<Field>("name"),
                    SharedConstant(Array(Value("alice"), Value("bob")))),
       NotEqAnyExpr(std::make_shared<Field>("age"),
                    SharedConstant(Array(Value(10.0), Value(25.0))))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3));
}

TEST_F(DisjunctivePipelineTest,
       MultipleNotEqAnysWithOr) {  // Renamed from TS: multipileNotEqAnys_withOr
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      OrExpr({NotEqAnyExpr(std::make_shared<Field>("name"),
                           SharedConstant(Array(Value("alice"), Value("bob")))),
              NotEqAnyExpr(std::make_shared<Field>("age"),
                           SharedConstant(Array(Value(10.0), Value(25.0))))})));

  // Expect docs where name is not alice/bob (doc3, doc4, doc5) OR age is not
  // 10/25 (doc1, doc3)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc3, doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, NotEqAnyOnCollectionGroup) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 =
      Doc("other_users/b", 1000,
          Map("name", "bob", "age", 25.0));  // Not in collection group 'users'
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 =
      Doc("root/child/users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 =
      Doc("root/child/other_users/e", 1000,
          Map("name", "eric", "age", 10.0));  // Not in collection group 'users'
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartCollectionGroupPipeline("users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(NotEqAnyExpr(
      std::make_shared<Field>("name"),
      SharedConstant(Array(Value("alice"), Value("bob"), Value("diane"))))));

  // Expect docs in collection group 'users' where name is not alice, bob, or
  // diane (doc3)
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3));
}

TEST_F(DisjunctivePipelineTest, NotEqAnyWithSort) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotEqAnyExpr(std::make_shared<Field>("name"),
                   SharedConstant(Array(Value("alice"), Value("diane"))))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  // Expect docs where name is not alice/diane (doc2, doc3, doc5), sorted by
  // age.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc5, doc2, doc3));
}

TEST_F(DisjunctivePipelineTest, NotEqAnyWithAdditionalEqualityDifferentFields) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {NotEqAnyExpr(std::make_shared<Field>("name"),
                    SharedConstant(Array(Value("alice"), Value("bob")))),
       EqExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(10.0))})})));

  // Expect docs where name is not alice/bob (doc3, doc4, doc5) AND age is 10
  // (doc4, doc5)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, NotEqAnyWithAdditionalEqualitySameField) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {NotEqAnyExpr(std::make_shared<Field>("name"),
                    SharedConstant(Array(Value("alice"), Value("diane")))),
       EqExpr({std::make_shared<Field>("name"),
               SharedConstant(Value("eric"))})})));

  // Expect docs where name is not alice/diane (doc2, doc3, doc5) AND name is
  // eric (doc5)
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc5));
}

TEST_F(DisjunctivePipelineTest, NotEqAnyWithInequalitiesExclusiveRange) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {NotEqAnyExpr(std::make_shared<Field>("name"),
                    SharedConstant(Array(Value("alice"), Value("charlie")))),
       GtExpr({std::make_shared<Field>("age"), SharedConstant(Value(10.0))}),
       LtExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(100.0))})})));

  // Expect docs where name is not alice/charlie (doc2, doc4, doc5) AND age > 10
  // AND age < 100 (doc2)
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2));
}

TEST_F(DisjunctivePipelineTest, NotEqAnyWithInequalitiesInclusiveRange) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {NotEqAnyExpr(
           std::make_shared<Field>("name"),
           SharedConstant(Array(Value("alice"), Value("bob"), Value("eric")))),
       GteExpr({std::make_shared<Field>("age"), SharedConstant(Value(10.0))}),
       LteExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(100.0))})})));

  // Expect docs where name is not alice/bob/eric (doc3, doc4) AND age >= 10 AND
  // age <= 100 (doc3, doc4)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc3, doc4));
}

TEST_F(DisjunctivePipelineTest, NotEqAnyWithInequalitiesAndSort) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {NotEqAnyExpr(std::make_shared<Field>("name"),
                    SharedConstant(Array(Value("alice"), Value("diane")))),
       GtExpr({std::make_shared<Field>("age"), SharedConstant(Value(10.0))}),
       LteExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(100.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  // Expect docs where name is not alice/diane (doc2, doc3, doc5) AND age > 10
  // AND age <= 100 (doc2, doc3) Sorted by age.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2, doc3));
}

TEST_F(DisjunctivePipelineTest, NotEqAnyWithNotEqual) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {NotEqAnyExpr(std::make_shared<Field>("name"),
                    SharedConstant(Array(Value("alice"), Value("bob")))),
       NeqExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(100.0))})})));

  // Expect docs where name is not alice/bob (doc3, doc4, doc5) AND age is not
  // 100 (doc4, doc5)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, NotEqAnySortOnNotEqAnyField) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotEqAnyExpr(std::make_shared<Field>("name"),
                   SharedConstant(Array(Value("alice"), Value("bob"))))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("name"), Ordering::Direction::ASCENDING)}));

  // Expect docs where name is not alice/bob (doc3, doc4, doc5), sorted by name.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3, doc4, doc5));
}

TEST_F(DisjunctivePipelineTest,
       NotEqAnySingleValueSortOnNotEqAnyFieldAmbiguousOrder) {
  auto doc1 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc2 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc3 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(NotEqAnyExpr(
      std::make_shared<Field>("age"), SharedConstant(Array(Value(100.0))))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  // Expect docs where age is not 100 (doc2, doc3), sorted by age. Order is
  // ambiguous.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2, doc3));
}

TEST_F(DisjunctivePipelineTest, NotEqAnyWithExtraEqualitySortOnNotEqAnyField) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {NotEqAnyExpr(std::make_shared<Field>("name"),
                    SharedConstant(Array(Value("alice"), Value("bob")))),
       EqExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(10.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("name"), Ordering::Direction::ASCENDING)}));

  // Expect docs where name is not alice/bob (doc3, doc4, doc5) AND age is 10
  // (doc4, doc5) Sorted by name.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, NotEqAnyWithExtraEqualitySortOnEquality) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {NotEqAnyExpr(std::make_shared<Field>("name"),
                    SharedConstant(Array(Value("alice"), Value("bob")))),
       EqExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(10.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  // Expect docs where name is not alice/bob (doc3, doc4, doc5) AND age is 10
  // (doc4, doc5) Sorted by age (constant), then implicitly by key.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, NotEqAnyWithInequalityOnSameField) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      AndExpr({NotEqAnyExpr(std::make_shared<Field>("age"),
                            SharedConstant(Array(Value(10.0), Value(100.0)))),
               GtExpr({std::make_shared<Field>("age"),
                       SharedConstant(Value(20.0))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  // Expect docs where age is not 10/100 (doc1, doc2, doc5) AND age > 20 (doc1,
  // doc2) Sorted by age.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2, doc1));
}

TEST_F(
    DisjunctivePipelineTest,
    NotEqAnyWithDifferentInequalitySortOnInField) {  // Renamed from TS:
                                                     // notEqAny_withDifferentInequality_sortOnInField
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {NotEqAnyExpr(std::make_shared<Field>("name"),
                    SharedConstant(Array(Value("alice"), Value("diane")))),
       GtExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(20.0))})})));
  // Sort field is 'age', the inequality field. TS name was misleading.
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));

  // Expect docs where name is not alice/diane (doc2, doc3, doc5) AND age > 20
  // (doc2, doc3) Sorted by age.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2, doc3));
}

TEST_F(DisjunctivePipelineTest, NoLimitOnNumOfDisjunctions) {
  auto doc1 =
      Doc("users/a", 1000, Map("name", "alice", "age", 25.0, "height", 170.0));
  auto doc2 =
      Doc("users/b", 1000, Map("name", "bob", "age", 25.0, "height", 180.0));
  auto doc3 = Doc("users/c", 1000,
                  Map("name", "charlie", "age", 100.0, "height", 155.0));
  auto doc4 =
      Doc("users/d", 1000, Map("name", "diane", "age", 10.0, "height", 150.0));
  auto doc5 =
      Doc("users/e", 1000, Map("name", "eric", "age", 25.0, "height", 170.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {EqExpr(
           {std::make_shared<Field>("name"), SharedConstant(Value("alice"))}),
       EqExpr({std::make_shared<Field>("name"), SharedConstant(Value("bob"))}),
       EqExpr(
           {std::make_shared<Field>("name"), SharedConstant(Value("charlie"))}),
       EqExpr(
           {std::make_shared<Field>("name"), SharedConstant(Value("diane"))}),
       EqExpr({std::make_shared<Field>("age"), SharedConstant(Value(10.0))}),
       EqExpr({std::make_shared<Field>("age"), SharedConstant(Value(25.0))}),
       EqExpr({std::make_shared<Field>("age"),
               SharedConstant(Value(40.0))}),  // No doc matches this
       EqExpr({std::make_shared<Field>("age"), SharedConstant(Value(100.0))}),
       EqExpr(
           {std::make_shared<Field>("height"), SharedConstant(Value(150.0))}),
       EqExpr({std::make_shared<Field>("height"),
               SharedConstant(Value(160.0))}),  // No doc matches this
       EqExpr(
           {std::make_shared<Field>("height"), SharedConstant(Value(170.0))}),
       EqExpr({std::make_shared<Field>("height"),
               SharedConstant(Value(180.0))})})));

  // Since each doc matches at least one condition, all should be returned.
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4, doc5));
}

TEST_F(DisjunctivePipelineTest, EqAnyDuplicateValues) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqAnyExpr(std::make_shared<Field>("score"),
                SharedConstant(Array(Value(50LL), Value(97LL), Value(97LL),
                                     Value(97LL))))));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc3));
}

TEST_F(DisjunctivePipelineTest, NotEqAnyDuplicateValues) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotEqAnyExpr(std::make_shared<Field>("score"),
                   // Note: The TS test includes `true` which is not directly
                   // comparable to numbers in C++. Assuming the intent was to
                   // test duplicate numeric values. Using 50LL twice.
                   SharedConstant(Array(Value(50LL), Value(50LL))))));

  // Expect docs where score is not 50 (doc1, doc3)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc3));
}

TEST_F(DisjunctivePipelineTest, ArrayContainsAnyDuplicateValues) {
  auto doc1 = Doc("users/a", 1000,
                  Map("scores", Array(Value(1LL), Value(2LL), Value(3LL))));
  auto doc2 = Doc("users/b", 1000,
                  Map("scores", Array(Value(4LL), Value(5LL), Value(6LL))));
  auto doc3 = Doc("users/c", 1000,
                  Map("scores", Array(Value(7LL), Value(8LL), Value(9LL))));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      ArrayContainsAnyExpr({std::make_shared<Field>("scores"),
                            SharedConstant(Array(Value(1LL), Value(2LL),
                                                 Value(2LL), Value(2LL)))})));

  // Expect docs where scores contain 1 or 2 (doc1)
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(DisjunctivePipelineTest, ArrayContainsAllDuplicateValues) {
  auto doc1 = Doc("users/a", 1000,
                  Map("scores", Array(Value(1LL), Value(2LL), Value(3LL))));
  auto doc2 = Doc("users/b", 1000,
                  Map("scores", Array(Value(1LL), Value(2LL), Value(2LL),
                                      Value(2LL), Value(3LL))));
  PipelineInputOutputVector documents = {doc1, doc2};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(ArrayContainsAllExpr(
      {std::make_shared<Field>("scores"),
       SharedConstant(Array(Value(1LL), Value(2LL), Value(2LL), Value(2LL),
                            Value(3LL)))})));

  // Expect docs where scores contain 1, two 2s, and 3 (only doc2)
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc2));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
