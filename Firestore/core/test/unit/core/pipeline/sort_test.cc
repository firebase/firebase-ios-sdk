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

#include <limits>  // Required for quiet_NaN
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
#include "Firestore/core/src/model/document_key.h"  // For kDocumentKeyPath
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
using api::DatabaseSource;
using api::EvaluableStage;
using api::Expr;
using api::Field;
using api::LimitStage;
using api::Ordering;
using api::RealtimePipeline;
using api::SortStage;
using api::Where;
using model::DatabaseId;
using model::DocumentKey;  // Added for kDocumentKeyPath
using model::FieldPath;
using model::MutableDocument;
using model::ObjectValue;
using model::PipelineInputOutputVector;
using testing::ElementsAre;
using testing::IsEmpty;  // For checking empty results
using testing::UnorderedElementsAre;
using testutil::Array;
using testutil::Doc;
using testutil::Map;
using testutil::SharedConstant;
using testutil::Value;
// Expression helpers
using testutil::AddExpr;
using testutil::AndExpr;
using testutil::EqExpr;
using testutil::ExistsExpr;
using testutil::GtExpr;
using testutil::NotExpr;
using testutil::RegexMatchExpr;

// Test Fixture for Sort Pipeline tests
class SortPipelineTest : public ::testing::Test {
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

TEST_F(SortPipelineTest, EmptyAscending) {
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  PipelineInputOutputVector documents = {};
  EXPECT_THAT(RunPipeline(pipeline, documents), IsEmpty());
}

TEST_F(SortPipelineTest, EmptyDescending) {
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::DESCENDING)}));
  PipelineInputOutputVector documents = {};
  EXPECT_THAT(RunPipeline(pipeline, documents), IsEmpty());
}

TEST_F(SortPipelineTest, SingleResultAscending) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 10LL));
  PipelineInputOutputVector documents = {doc1};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(SortPipelineTest, SingleResultAscendingExplicitExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 10LL));
  PipelineInputOutputVector documents = {doc1};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(ExistsExpr(std::make_shared<Field>("age"))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(SortPipelineTest, SingleResultAscendingExplicitNotExistsEmpty) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 10LL));
  PipelineInputOutputVector documents = {doc1};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(ExistsExpr(std::make_shared<Field>("age")))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), IsEmpty());
}

TEST_F(SortPipelineTest, SingleResultAscendingImplicitExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 10LL));
  PipelineInputOutputVector documents = {doc1};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("age"), SharedConstant(Value(10LL))})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(SortPipelineTest, SingleResultDescending) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 10LL));
  PipelineInputOutputVector documents = {doc1};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::DESCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(SortPipelineTest, SingleResultDescendingExplicitExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 10LL));
  PipelineInputOutputVector documents = {doc1};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(ExistsExpr(std::make_shared<Field>("age"))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::DESCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(SortPipelineTest, SingleResultDescendingImplicitExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 10LL));
  PipelineInputOutputVector documents = {doc1};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("age"), SharedConstant(Value(10LL))})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::DESCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(SortPipelineTest, MultipleResultsAmbiguousOrder) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::DESCENDING)}));
  // Order between doc4 and doc5 is ambiguous.
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4, doc5));
}

TEST_F(SortPipelineTest, MultipleResultsAmbiguousOrderExplicitExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(ExistsExpr(std::make_shared<Field>("age"))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::DESCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4, doc5));
}

TEST_F(SortPipelineTest, MultipleResultsAmbiguousOrderImplicitExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      GtExpr({std::make_shared<Field>("age"), SharedConstant(Value(0.0))})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::DESCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4, doc5));
}

TEST_F(SortPipelineTest, MultipleResultsFullOrder) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("age"),
                                     Ordering::Direction::DESCENDING),
                            Ordering(std::make_unique<Field>("name"),
                                     Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc3, doc1, doc2, doc4, doc5));
}

TEST_F(SortPipelineTest, MultipleResultsFullOrderExplicitExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(ExistsExpr(std::make_shared<Field>("age"))));
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(ExistsExpr(std::make_shared<Field>("name"))));
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("age"),
                                     Ordering::Direction::DESCENDING),
                            Ordering(std::make_unique<Field>("name"),
                                     Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc3, doc1, doc2, doc4, doc5));
}

TEST_F(SortPipelineTest, MultipleResultsFullOrderExplicitNotExistsEmpty) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob"));
  auto doc3 = Doc("users/c", 1000, Map("age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("other_name", "diane"));  // Matches
  auto doc5 = Doc("users/e", 1000, Map("other_age", 10.0));      // Matches
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(ExistsExpr(std::make_shared<Field>("age")))));
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(ExistsExpr(std::make_shared<Field>("name")))));
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("age"),
                                     Ordering::Direction::DESCENDING),
                            Ordering(std::make_unique<Field>("name"),
                                     Ordering::Direction::ASCENDING)}));
  // Sort order for missing fields is undefined relative to each other, but
  // defined by key. d < e
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc5));
}

TEST_F(SortPipelineTest, MultipleResultsFullOrderImplicitExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("age"),
              std::make_shared<Field>("age")})));  // Implicit exists age
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      RegexMatchExpr(std::make_shared<Field>("name"),
                     SharedConstant(Value(".*")))));  // Implicit exists name
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("age"),
                                     Ordering::Direction::DESCENDING),
                            Ordering(std::make_unique<Field>("name"),
                                     Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc3, doc1, doc2, doc4, doc5));
}

TEST_F(SortPipelineTest, MultipleResultsFullOrderPartialExplicitExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(ExistsExpr(std::make_shared<Field>("name"))));
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("age"),
                                     Ordering::Direction::DESCENDING),
                            Ordering(std::make_unique<Field>("name"),
                                     Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc3, doc1, doc2, doc4, doc5));
}

TEST_F(SortPipelineTest, MultipleResultsFullOrderPartialExplicitNotExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("age", 25.0));  // name missing -> Match
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 =
      Doc("users/d", 1000, Map("name", "diane"));  // age missing, name exists
  auto doc5 =
      Doc("users/e", 1000, Map("name", "eric"));  // age missing, name exists
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(NotExpr(
      ExistsExpr(std::make_shared<Field>("name")))));  // Only doc2 matches
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(std::make_unique<Field>("age"),
                   Ordering::Direction::DESCENDING),
          Ordering(std::make_unique<Field>("name"),
                   Ordering::Direction::DESCENDING)  // name doesn't exist for
                                                     // matches
      }));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2));
}

TEST_F(
    SortPipelineTest,
    MultipleResultsFullOrderPartialExplicitNotExistsSortOnNonExistFieldFirst) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("age", 25.0));  // name missing -> Match
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 =
      Doc("users/d", 1000, Map("name", "diane"));  // age missing, name exists
  auto doc5 =
      Doc("users/e", 1000, Map("name", "eric"));  // age missing, name exists
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(NotExpr(
      ExistsExpr(std::make_shared<Field>("name")))));  // Only doc2 matches
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(std::make_unique<Field>("name"),
                   Ordering::Direction::DESCENDING),  // name doesn't exist
          Ordering(std::make_unique<Field>("age"),
                   Ordering::Direction::DESCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2));
}

TEST_F(SortPipelineTest, MultipleResultsFullOrderPartialImplicitExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(RegexMatchExpr(
      std::make_shared<Field>("name"), SharedConstant(Value(".*")))));
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("age"),
                                     Ordering::Direction::DESCENDING),
                            Ordering(std::make_unique<Field>("name"),
                                     Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc3, doc1, doc2, doc4, doc5));
}

TEST_F(SortPipelineTest, MissingFieldAllFields) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("not_age"),
                                     Ordering::Direction::DESCENDING)}));
  // Sorting by a missing field results in undefined order relative to each
  // other, but documents are secondarily sorted by key.
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4, doc5));
}

TEST_F(SortPipelineTest, MissingFieldWithExistEmpty) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(ExistsExpr(std::make_shared<Field>("not_age"))));
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("not_age"),
                                     Ordering::Direction::DESCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), IsEmpty());
}

TEST_F(SortPipelineTest, MissingFieldPartialFields) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob"));  // age missing
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane"));  // age missing
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  // Missing fields sort first in ascending order, then by key. b < d
  // Then existing fields sorted by value: e < a < c
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc2, doc4, doc5, doc1, doc3));
}

TEST_F(SortPipelineTest, MissingFieldPartialFieldsWithExist) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob"));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane"));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(ExistsExpr(std::make_shared<Field>("age"))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc5, doc1, doc3));
}

TEST_F(SortPipelineTest, MissingFieldPartialFieldsWithNotExist) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob"));  // Match
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane"));  // Match
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(ExistsExpr(std::make_shared<Field>("age")))));
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(
              std::make_unique<Field>("age"),
              Ordering::Direction::ASCENDING)  // Sort by non-existent field
      }));
  // Sort by missing field, then key: b < d
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2, doc4));
}

TEST_F(SortPipelineTest, LimitAfterSort) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(2));
  // Sort: d, e, b, a, c. Limit 2: d, e.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc5));
}

TEST_F(SortPipelineTest, LimitAfterSortWithExist) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("age", 25.0));  // name missing
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane"));  // age missing
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      ExistsExpr(std::make_shared<Field>("age"))));  // Filter: a, b, c, e
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(std::make_unique<Field>("age"),
                   Ordering::Direction::ASCENDING)}));  // Sort: e, b, a, c
  pipeline =
      pipeline.AddingStage(std::make_shared<LimitStage>(2));  // Limit 2: e, b
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc5, doc2));
}

TEST_F(SortPipelineTest, LimitAfterSortWithNotExist) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("age", 25.0));  // name missing
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 =
      Doc("users/d", 1000, Map("name", "diane"));  // age missing -> Match
  auto doc5 =
      Doc("users/e", 1000, Map("name", "eric"));  // age missing -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(ExistsExpr(std::make_shared<Field>("age")))));  // Filter: d, e
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(std::make_unique<Field>("age"),
                   Ordering::Direction::ASCENDING)  // Sort by missing field ->
                                                    // key order
      }));                                          // Sort: d, e
  pipeline =
      pipeline.AddingStage(std::make_shared<LimitStage>(2));  // Limit 2: d, e
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc5));
}

TEST_F(SortPipelineTest, LimitZeroAfterSort) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(0));
  EXPECT_THAT(RunPipeline(pipeline, documents), IsEmpty());
}

TEST_F(SortPipelineTest, LimitBeforeSort) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  // Note: Limit before sort has different semantics online vs offline.
  // Offline evaluation applies limit first based on implicit key order.
  RealtimePipeline pipeline = StartCollectionGroupPipeline("users");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(1));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(SortPipelineTest, LimitBeforeSortWithExist) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane"));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartCollectionGroupPipeline("users");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(ExistsExpr(std::make_shared<Field>("age"))));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(1));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(SortPipelineTest, LimitBeforeSortWithNotExist) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane"));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric"));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartCollectionGroupPipeline("users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(ExistsExpr(std::make_shared<Field>("age")))));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(1));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4));
}

TEST_F(SortPipelineTest, LimitBeforeNotExistFilter) {
  auto doc1 = Doc("users/a", 1000, Map("age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane"));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric"));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartCollectionGroupPipeline("users");
  pipeline = pipeline.AddingStage(
      std::make_shared<LimitStage>(2));  // Limit to a, b (by key)
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(ExistsExpr(std::make_shared<Field>("age")))));  // Filter out a, b
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), IsEmpty());
}

TEST_F(SortPipelineTest, LimitZeroBeforeSort) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartCollectionGroupPipeline("users");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(0));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), IsEmpty());
}

TEST_F(SortPipelineTest, SortExpression) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 10LL));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 30LL));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 50LL));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 40LL));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 20LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartCollectionGroupPipeline("users");
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(AddExpr({std::make_shared<Field>("age"),
                            SharedConstant(Value(10LL))}),  // age + 10
                   Ordering::Direction::DESCENDING)}));
  // Sort by (age+10) desc: 60(c), 50(d), 40(b), 30(e), 20(a)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc3, doc4, doc2, doc5, doc1));
}

TEST_F(SortPipelineTest, SortExpressionWithExist) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 10LL));
  auto doc2 = Doc("users/b", 1000, Map("age", 30LL));  // name missing
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 50LL));
  auto doc4 = Doc("users/d", 1000, Map("name", "diane"));  // age missing
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 20LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartCollectionGroupPipeline("users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      ExistsExpr(std::make_shared<Field>("age"))));  // Filter: a, b, c, e
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          AddExpr(
              {std::make_shared<Field>("age"), SharedConstant(Value(10LL))}),
          Ordering::Direction::DESCENDING)}));  // Sort by (age+10) desc: 60(c),
                                                // 40(b), 30(e), 20(a)
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc3, doc2, doc5, doc1));
}

TEST_F(SortPipelineTest, SortExpressionWithNotExist) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 10LL));
  auto doc2 = Doc("users/b", 1000, Map("age", 30LL));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 50LL));
  auto doc4 =
      Doc("users/d", 1000, Map("name", "diane"));  // age missing -> Match
  auto doc5 =
      Doc("users/e", 1000, Map("name", "eric"));  // age missing -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};
  RealtimePipeline pipeline = StartCollectionGroupPipeline("users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(ExistsExpr(std::make_shared<Field>("age")))));  // Filter: d, e
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(AddExpr({std::make_shared<Field>("age"),
                            SharedConstant(Value(
                                10LL))}),  // Sort by missing field -> key order
                   Ordering::Direction::DESCENDING)}));  // Sort: d, e
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc5));
}

TEST_F(SortPipelineTest, SortOnPathAndOtherFieldOnDifferentStages) {
  auto doc1 = Doc("users/1", 1000, Map("name", "alice", "age", 40LL));
  auto doc2 = Doc("users/2", 1000, Map("name", "bob", "age", 30LL));
  auto doc3 = Doc("users/3", 1000, Map("name", "charlie", "age", 50LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      ExistsExpr(std::make_shared<Field>(FieldPath::kDocumentKeyPath))));
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                   Ordering::Direction::ASCENDING)}));  // Sort by key: 1, 2, 3
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(std::make_unique<Field>("age"),
                   Ordering::Direction::ASCENDING)}));  // Sort by age: 2(30),
                                                        // 1(40), 3(50) - Last
                                                        // sort takes precedence
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2, doc1, doc3));
}

TEST_F(SortPipelineTest, SortOnOtherFieldAndPathOnDifferentStages) {
  auto doc1 = Doc("users/1", 1000, Map("name", "alice", "age", 40LL));
  auto doc2 = Doc("users/2", 1000, Map("name", "bob", "age", 30LL));
  auto doc3 = Doc("users/3", 1000, Map("name", "charlie", "age", 50LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      ExistsExpr(std::make_shared<Field>(FieldPath::kDocumentKeyPath))));
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(std::make_unique<Field>("age"),
                   Ordering::Direction::ASCENDING)}));  // Sort by age: 2(30),
                                                        // 1(40), 3(50)
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                   Ordering::Direction::ASCENDING)}));  // Sort by key: 1(40),
                                                        // 2(30), 3(50) - Last
                                                        // sort takes precedence
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc2, doc3));
}

TEST_F(SortPipelineTest, SortOnKeyAndOtherFieldOnMultipleStages) {
  // Same as SortOnPathAndOtherFieldOnDifferentStages
  auto doc1 = Doc("users/1", 1000, Map("name", "alice", "age", 40LL));
  auto doc2 = Doc("users/2", 1000, Map("name", "bob", "age", 30LL));
  auto doc3 = Doc("users/3", 1000, Map("name", "charlie", "age", 50LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      ExistsExpr(std::make_shared<Field>(FieldPath::kDocumentKeyPath))));
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                   Ordering::Direction::ASCENDING)}));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2, doc1, doc3));
}

TEST_F(SortPipelineTest, SortOnOtherFieldAndKeyOnMultipleStages) {
  // Same as SortOnOtherFieldAndPathOnDifferentStages
  auto doc1 = Doc("users/1", 1000, Map("name", "alice", "age", 40LL));
  auto doc2 = Doc("users/2", 1000, Map("name", "bob", "age", 30LL));
  auto doc3 = Doc("users/3", 1000, Map("name", "charlie", "age", 50LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};
  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      ExistsExpr(std::make_shared<Field>(FieldPath::kDocumentKeyPath))));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("age"), Ordering::Direction::ASCENDING)}));
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                   Ordering::Direction::ASCENDING)}));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc2, doc3));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
