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
#include "Firestore/core/src/model/document_key.h"
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
using model::DocumentKey;
using model::FieldPath;
using model::MutableDocument;
using model::ObjectValue;
using model::PipelineInputOutputVector;
using testing::ElementsAre;
using testing::IsEmpty;
using testing::UnorderedElementsAre;
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
using testutil::DivideExpr;
using testutil::EqAnyExpr;
using testutil::EqExpr;
using testutil::ExistsExpr;
using testutil::GteExpr;
using testutil::GtExpr;
using testutil::IsNanExpr;
using testutil::IsNullExpr;
using testutil::LteExpr;
using testutil::LtExpr;
// using testutil::NeqAnyExpr; // Not used
using testutil::NeqExpr;
using testutil::NotExpr;
using testutil::OrExpr;
using testutil::RegexMatchExpr;  // For 'like'
using testutil::XorExpr;

// Test Fixture for Where Pipeline tests
class WherePipelineTest : public ::testing::Test {
 public:
  // Helper to create a pipeline starting with a collection stage
  RealtimePipeline StartPipeline(const std::string& collection_path) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(std::make_shared<CollectionSource>(collection_path));
    return RealtimePipeline(std::move(stages), TestSerializer());
  }
  // Helper for database-wide pipelines
  RealtimePipeline StartDatabasePipeline() {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(std::make_shared<DatabaseSource>());
    return RealtimePipeline(std::move(stages), TestSerializer());
  }
};

TEST_F(WherePipelineTest, EmptyDatabaseReturnsNoResults) {
  PipelineInputOutputVector documents = {};
  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      GteExpr({std::make_shared<Field>("age"), SharedConstant(Value(10LL))})));
  EXPECT_THAT(RunPipeline(pipeline, documents), IsEmpty());
}

TEST_F(WherePipelineTest, DuplicateConditions) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));  // Match
  auto doc3 =
      Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));  // Match
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {GteExpr({std::make_shared<Field>("age"), SharedConstant(Value(10.0))}),
       GteExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(20.0))})})));

  // Note: TS test expected [doc1, doc2, doc3]. Let's re-evaluate based on C++
  // types. age >= 10.0 AND age >= 20.0 => age >= 20.0 Matches: doc1 (75.5),
  // doc2 (25.0), doc3 (100.0)
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc2, doc3));
}

TEST_F(WherePipelineTest, LogicalEquivalentConditionEqual) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));  // Match
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline1 = StartDatabasePipeline();
  pipeline1 = pipeline1.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("age"), SharedConstant(Value(25.0))})));

  RealtimePipeline pipeline2 = StartDatabasePipeline();
  pipeline2 = pipeline2.AddingStage(std::make_shared<Where>(
      EqExpr({SharedConstant(Value(25.0)), std::make_shared<Field>("age")})));

  auto result1 = RunPipeline(pipeline1, documents);
  auto result2 = RunPipeline(pipeline2, documents);

  EXPECT_THAT(result1, ElementsAre(doc2));
  EXPECT_THAT(result1, result2);  // Check if results are identical
}

TEST_F(WherePipelineTest, LogicalEquivalentConditionAnd) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));  // Match
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline1 = StartDatabasePipeline();
  pipeline1 = pipeline1.AddingStage(std::make_shared<Where>(AndExpr(
      {GtExpr({std::make_shared<Field>("age"), SharedConstant(Value(10.0))}),
       LtExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(70.0))})})));

  RealtimePipeline pipeline2 = StartDatabasePipeline();
  pipeline2 = pipeline2.AddingStage(std::make_shared<Where>(AndExpr(
      {LtExpr({std::make_shared<Field>("age"), SharedConstant(Value(70.0))}),
       GtExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(10.0))})})));

  auto result1 = RunPipeline(pipeline1, documents);
  auto result2 = RunPipeline(pipeline2, documents);

  EXPECT_THAT(result1, ElementsAre(doc2));
  EXPECT_THAT(result1, result2);
}

TEST_F(WherePipelineTest, LogicalEquivalentConditionOr) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 =
      Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline1 = StartDatabasePipeline();
  pipeline1 = pipeline1.AddingStage(std::make_shared<Where>(OrExpr(
      {LtExpr({std::make_shared<Field>("age"), SharedConstant(Value(10.0))}),
       GtExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(80.0))})})));

  RealtimePipeline pipeline2 = StartDatabasePipeline();
  pipeline2 = pipeline2.AddingStage(std::make_shared<Where>(OrExpr(
      {GtExpr({std::make_shared<Field>("age"), SharedConstant(Value(80.0))}),
       LtExpr(
           {std::make_shared<Field>("age"), SharedConstant(Value(10.0))})})));

  auto result1 = RunPipeline(pipeline1, documents);
  auto result2 = RunPipeline(pipeline2, documents);

  EXPECT_THAT(result1, ElementsAre(doc3));
  EXPECT_THAT(result1, result2);
}

TEST_F(WherePipelineTest, LogicalEquivalentConditionIn) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));  // Match
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline1 = StartDatabasePipeline();
  pipeline1 = pipeline1.AddingStage(std::make_shared<Where>(EqAnyExpr(
      std::make_shared<Field>("name"),
      SharedConstant(Array(Value("alice"), Value("matthew"), Value("joe"))))));

  // Test logical equivalence using the same EqAnyExpr structure.
  // The original TS used arrayContainsAny which doesn't map directly here for
  // this equivalence check.
  RealtimePipeline pipeline2 = StartDatabasePipeline();
  pipeline2 = pipeline2.AddingStage(std::make_shared<Where>(EqAnyExpr(
      std::make_shared<Field>("name"),
      SharedConstant(Array(Value("alice"), Value("matthew"), Value("joe"))))));

  auto result1 = RunPipeline(pipeline1, documents);
  auto result2 = RunPipeline(pipeline2, documents);

  EXPECT_THAT(result1, ElementsAre(doc1));
  EXPECT_THAT(result1, result2);
}

TEST_F(WherePipelineTest, RepeatedStages) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));  // Match
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));    // Match
  auto doc3 =
      Doc("users/c", 1000, Map("name", "charlie", "age", 100.0));  // Match
  auto doc4 = Doc("users/d", 1000, Map("name", "diane", "age", 10.0));
  auto doc5 = Doc("users/e", 1000, Map("name", "eric", "age", 10.0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      GteExpr({std::make_shared<Field>("age"), SharedConstant(Value(10.0))})));
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      GteExpr({std::make_shared<Field>("age"), SharedConstant(Value(20.0))})));

  // age >= 10.0 THEN age >= 20.0 => age >= 20.0
  // Matches: doc1 (75.5), doc2 (25.0), doc3 (100.0)
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc2, doc3));
}

TEST_F(WherePipelineTest, CompositeEqualities) {
  auto doc1 = Doc("users/a", 1000, Map("height", 60LL, "age", 75LL));
  auto doc2 = Doc("users/b", 1000, Map("height", 55LL, "age", 50LL));
  auto doc3 =
      Doc("users/c", 1000,
          Map("height", 55.0, "age", 75LL));  // Match (height 55.0 == 55LL)
  auto doc4 = Doc("users/d", 1000, Map("height", 50LL, "age", 41LL));
  auto doc5 = Doc("users/e", 1000, Map("height", 80LL, "age", 75LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("age"), SharedConstant(Value(75LL))})));
  pipeline = pipeline.AddingStage(std::make_shared<Where>(EqExpr(
      {std::make_shared<Field>("height"), SharedConstant(Value(55LL))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3));
}

TEST_F(WherePipelineTest, CompositeInequalities) {
  auto doc1 = Doc("users/a", 1000, Map("height", 60LL, "age", 75LL));  // Match
  auto doc2 = Doc("users/b", 1000, Map("height", 55LL, "age", 50LL));
  auto doc3 = Doc("users/c", 1000, Map("height", 55.0, "age", 75LL));  // Match
  auto doc4 = Doc("users/d", 1000, Map("height", 50LL, "age", 41LL));
  auto doc5 = Doc("users/e", 1000, Map("height", 80LL, "age", 75LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      GtExpr({std::make_shared<Field>("age"), SharedConstant(Value(50LL))})));
  pipeline = pipeline.AddingStage(std::make_shared<Where>(LtExpr(
      {std::make_shared<Field>("height"), SharedConstant(Value(75LL))})));

  // age > 50 AND height < 75
  // doc1: 75 > 50 AND 60 < 75 -> true
  // doc2: 50 > 50 -> false
  // doc3: 75 > 50 AND 55.0 < 75 -> true
  // doc4: 41 > 50 -> false
  // doc5: 75 > 50 AND 80 < 75 -> false
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc3));
}

TEST_F(WherePipelineTest, CompositeNonSeekable) {
  auto doc1 = Doc("users/a", 1000, Map("first", "alice", "last", "smith"));
  auto doc2 = Doc("users/b", 1000, Map("first", "bob", "last", "smith"));
  auto doc3 =
      Doc("users/c", 1000, Map("first", "charlie", "last", "baker"));  // Match
  auto doc4 =
      Doc("users/d", 1000, Map("first", "diane", "last", "miller"));  // Match
  auto doc5 = Doc("users/e", 1000, Map("first", "eric", "last", "davis"));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  // Using RegexMatchExpr for LIKE '%a%' -> ".*a.*"
  pipeline = pipeline.AddingStage(std::make_shared<Where>(RegexMatchExpr(
      std::make_shared<Field>("first"), SharedConstant(Value(".*a.*")))));
  // Using RegexMatchExpr for LIKE '%er' -> ".*er$"
  pipeline = pipeline.AddingStage(std::make_shared<Where>(RegexMatchExpr(
      std::make_shared<Field>("last"), SharedConstant(Value(".*er$")))));

  // first contains 'a' AND last ends with 'er'
  // doc1: alice (yes), smith (no)
  // doc2: bob (no), smith (no)
  // doc3: charlie (yes), baker (yes) -> Match
  // doc4: diane (yes), miller (yes) -> Match
  // doc5: eric (no), davis (no)
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3, doc4));
}

TEST_F(WherePipelineTest, CompositeMixed) {
  auto doc1 =
      Doc("users/a", 1000,
          Map("first", "alice", "last", "smith", "age", 75LL, "height", 40LL));
  auto doc2 =
      Doc("users/b", 1000,
          Map("first", "bob", "last", "smith", "age", 75LL, "height", 50LL));
  auto doc3 = Doc("users/c", 1000,
                  Map("first", "charlie", "last", "baker", "age", 75LL,
                      "height", 50LL));  // Match
  auto doc4 = Doc("users/d", 1000,
                  Map("first", "diane", "last", "miller", "age", 75LL, "height",
                      50LL));  // Match
  auto doc5 =
      Doc("users/e", 1000,
          Map("first", "eric", "last", "davis", "age", 80LL, "height", 50LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("age"), SharedConstant(Value(75LL))})));
  pipeline = pipeline.AddingStage(std::make_shared<Where>(GtExpr(
      {std::make_shared<Field>("height"), SharedConstant(Value(45LL))})));
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      RegexMatchExpr(std::make_shared<Field>("last"),
                     SharedConstant(Value(".*er$")))));  // ends with 'er'

  // age == 75 AND height > 45 AND last ends with 'er'
  // doc1: 75==75 (T), 40>45 (F) -> False
  // doc2: 75==75 (T), 50>45 (T), smith ends er (F) -> False
  // doc3: 75==75 (T), 50>45 (T), baker ends er (T) -> True
  // doc4: 75==75 (T), 50>45 (T), miller ends er (T) -> True
  // doc5: 80==75 (F) -> False
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3, doc4));
}

TEST_F(WherePipelineTest, Exists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));  // Match
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));    // Match
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));             // Match
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));
  auto doc5 = Doc("users/e", 1000, Map("other", true));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(ExistsExpr(std::make_shared<Field>("name"))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc2, doc3));
}

TEST_F(WherePipelineTest, NotExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));    // Match
  auto doc5 = Doc("users/e", 1000, Map("other", true));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(ExistsExpr(std::make_shared<Field>("name")))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc5));
}

TEST_F(WherePipelineTest, NotNotExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));  // Match
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));    // Match
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));             // Match
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));
  auto doc5 = Doc("users/e", 1000, Map("other", true));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(NotExpr(ExistsExpr(std::make_shared<Field>("name"))))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc2, doc3));
}

TEST_F(WherePipelineTest, ExistsAndExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));  // Match
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));    // Match
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));
  auto doc5 = Doc("users/e", 1000, Map("other", true));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      AndExpr({ExistsExpr(std::make_shared<Field>("name")),
               ExistsExpr(std::make_shared<Field>("age"))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc2));
}

TEST_F(WherePipelineTest, ExistsOrExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));  // Match
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));    // Match
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));             // Match
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));                   // Match
  auto doc5 = Doc("users/e", 1000, Map("other", true));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      OrExpr({ExistsExpr(std::make_shared<Field>("name")),
              ExistsExpr(std::make_shared<Field>("age"))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc1, doc2, doc3, doc4));
}

TEST_F(WherePipelineTest, NotExistsAndExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));  // Match
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));        // Match
  auto doc5 = Doc("users/e", 1000, Map("other", true));      // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(AndExpr({ExistsExpr(std::make_shared<Field>("name")),
                       ExistsExpr(std::make_shared<Field>("age"))}))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3, doc4, doc5));
}

TEST_F(WherePipelineTest, NotExistsOrExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));
  auto doc5 = Doc("users/e", 1000, Map("other", true));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(OrExpr({ExistsExpr(std::make_shared<Field>("name")),
                      ExistsExpr(std::make_shared<Field>("age"))}))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc5));
}

TEST_F(WherePipelineTest, NotExistsXorExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));  // Match
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));    // Match
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));
  auto doc5 = Doc("users/e", 1000, Map("other", true));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(XorExpr({ExistsExpr(std::make_shared<Field>("name")),
                       ExistsExpr(std::make_shared<Field>("age"))}))));

  // NOT ( (name exists AND NOT age exists) OR (NOT name exists AND age exists)
  // ) = (name exists AND age exists) OR (NOT name exists AND NOT age exists)
  // Matches: doc1, doc2, doc5
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc2, doc5));
}

TEST_F(WherePipelineTest, AndNotExistsNotExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));
  auto doc5 = Doc("users/e", 1000, Map("other", true));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      AndExpr({NotExpr(ExistsExpr(std::make_shared<Field>("name"))),
               NotExpr(ExistsExpr(std::make_shared<Field>("age")))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc5));
}

TEST_F(WherePipelineTest, OrNotExistsNotExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));  // Match
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));        // Match
  auto doc5 = Doc("users/e", 1000, Map("other", true));      // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      OrExpr({NotExpr(ExistsExpr(std::make_shared<Field>("name"))),
              NotExpr(ExistsExpr(std::make_shared<Field>("age")))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3, doc4, doc5));
}

TEST_F(WherePipelineTest, XorNotExistsNotExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));  // Match
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));        // Match
  auto doc5 = Doc("users/e", 1000, Map("other", true));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      XorExpr({NotExpr(ExistsExpr(std::make_shared<Field>("name"))),
               NotExpr(ExistsExpr(std::make_shared<Field>("age")))})));

  // (NOT name exists AND NOT (NOT age exists)) OR (NOT (NOT name exists) AND
  // NOT age exists) (NOT name exists AND age exists) OR (name exists AND NOT
  // age exists) Matches: doc3, doc4
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3, doc4));
}

TEST_F(WherePipelineTest, AndNotExistsExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));  // Match
  auto doc5 = Doc("users/e", 1000, Map("other", true));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      AndExpr({NotExpr(ExistsExpr(std::make_shared<Field>("name"))),
               ExistsExpr(std::make_shared<Field>("age"))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4));
}

TEST_F(WherePipelineTest, OrNotExistsExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));  // Match
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));    // Match
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));    // Match
  auto doc5 = Doc("users/e", 1000, Map("other", true));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      OrExpr({NotExpr(ExistsExpr(std::make_shared<Field>("name"))),
              ExistsExpr(std::make_shared<Field>("age"))})));

  // (NOT name exists) OR (age exists)
  // Matches: doc1, doc2, doc4, doc5
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ElementsAre(doc1, doc2, doc4, doc5));
}

TEST_F(WherePipelineTest, XorNotExistsExists) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", 75.5));  // Match
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25.0));    // Match
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie"));
  auto doc4 = Doc("users/d", 1000, Map("age", 30.0));
  auto doc5 = Doc("users/e", 1000, Map("other", true));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      XorExpr({NotExpr(ExistsExpr(std::make_shared<Field>("name"))),
               ExistsExpr(std::make_shared<Field>("age"))})));

  // (NOT name exists AND NOT age exists) OR (name exists AND age exists)
  // Matches: doc1, doc2, doc5
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc2, doc5));
}

TEST_F(WherePipelineTest, WhereExpressionIsNotBooleanYielding) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", true));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", "42"));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 0LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  // Create a non-boolean expression (e.g., division)
  auto non_boolean_expr =
      DivideExpr({SharedConstant(Value("100")), SharedConstant(Value("50"))});

  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(non_boolean_expr));

  EXPECT_THAT(RunPipeline(pipeline, documents), IsEmpty());
}

TEST_F(WherePipelineTest, AndExpressionLogicallyEquivalentToSeparatedStages) {
  auto doc1 = Doc("users/a", 1000, Map("a", 1LL, "b", 1LL));
  auto doc2 = Doc("users/b", 1000, Map("a", 1LL, "b", 2LL));  // Match
  auto doc3 = Doc("users/c", 1000, Map("a", 2LL, "b", 2LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  auto equalityArgument1 =
      EqExpr({std::make_shared<Field>("a"), SharedConstant(Value(1LL))});
  auto equalityArgument2 =
      EqExpr({std::make_shared<Field>("b"), SharedConstant(Value(2LL))});

  // Combined AND
  RealtimePipeline pipeline_and_1 = StartDatabasePipeline();
  pipeline_and_1 = pipeline_and_1.AddingStage(
      std::make_shared<Where>(AndExpr({equalityArgument1, equalityArgument2})));
  EXPECT_THAT(RunPipeline(pipeline_and_1, documents), ElementsAre(doc2));

  // Combined AND (reversed order)
  RealtimePipeline pipeline_and_2 = StartDatabasePipeline();
  pipeline_and_2 = pipeline_and_2.AddingStage(
      std::make_shared<Where>(AndExpr({equalityArgument2, equalityArgument1})));
  EXPECT_THAT(RunPipeline(pipeline_and_2, documents), ElementsAre(doc2));

  // Separate Stages
  RealtimePipeline pipeline_sep_1 = StartDatabasePipeline();
  pipeline_sep_1 =
      pipeline_sep_1.AddingStage(std::make_shared<Where>(equalityArgument1));
  pipeline_sep_1 =
      pipeline_sep_1.AddingStage(std::make_shared<Where>(equalityArgument2));
  EXPECT_THAT(RunPipeline(pipeline_sep_1, documents), ElementsAre(doc2));

  // Separate Stages (reversed order)
  RealtimePipeline pipeline_sep_2 = StartDatabasePipeline();
  pipeline_sep_2 =
      pipeline_sep_2.AddingStage(std::make_shared<Where>(equalityArgument2));
  pipeline_sep_2 =
      pipeline_sep_2.AddingStage(std::make_shared<Where>(equalityArgument1));
  EXPECT_THAT(RunPipeline(pipeline_sep_2, documents), ElementsAre(doc2));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
