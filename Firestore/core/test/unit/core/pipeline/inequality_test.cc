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
using model::FieldPath;
// using model::GeoPoint; // Use firebase::GeoPoint
using model::MutableDocument;
using model::ObjectValue;
using model::PipelineInputOutputVector;
// using model::Timestamp; // Use firebase::Timestamp
using firebase::Timestamp;  // Use top-level Timestamp
using testing::ElementsAre;
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

// Test Fixture for Inequality Pipeline tests
class InequalityPipelineTest : public ::testing::Test {
 public:
  // Helper to create a pipeline starting with a collection stage
  RealtimePipeline StartPipeline(const std::string& collection_path) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(std::make_shared<CollectionSource>(collection_path));
    return RealtimePipeline(std::move(stages), TestSerializer());
  }
};

TEST_F(InequalityPipelineTest, GreaterThan) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      GtExpr({std::make_shared<Field>("score"), SharedConstant(Value(90LL))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3));
}

TEST_F(InequalityPipelineTest, GreaterThanOrEqual) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(GteExpr(
      {std::make_shared<Field>("score"), SharedConstant(Value(90LL))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc3));
}

TEST_F(InequalityPipelineTest, LessThan) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      LtExpr({std::make_shared<Field>("score"), SharedConstant(Value(90LL))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2));
}

TEST_F(InequalityPipelineTest, LessThanOrEqual) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(LteExpr(
      {std::make_shared<Field>("score"), SharedConstant(Value(90LL))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2));
}

TEST_F(InequalityPipelineTest, NotEqual) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(NeqExpr(
      {std::make_shared<Field>("score"), SharedConstant(Value(90LL))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc3));
}

TEST_F(InequalityPipelineTest, NotEqualReturnsMixedTypes) {
  auto doc1 =
      Doc("users/alice", 1000, Map("score", 90LL));  // Should be filtered out
  auto doc2 = Doc("users/boc", 1000, Map("score", true));
  auto doc3 = Doc("users/charlie", 1000, Map("score", 42.0));
  auto doc4 = Doc("users/drew", 1000, Map("score", "abc"));
  auto doc5 = Doc(
      "users/eric", 1000,
      Map("score",
          Value(Timestamp(
              0, 2000000))));  // Timestamp from seconds/nanos, wrapped in Value
  auto doc6 =
      Doc("users/francis", 1000,
          Map("score", Value(GeoPoint(0, 0))));  // GeoPoint wrapped in Value
  auto doc7 =
      Doc("users/george", 1000,
          Map("score", Value(Array(Value(42LL)))));  // Array wrapped in Value
  auto doc8 = Doc("users/hope", 1000,
                  Map("score", Map("foo", 42LL)));  // Map is already a Value
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4,
                                         doc5, doc6, doc7, doc8};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(NeqExpr(
      {std::make_shared<Field>("score"), SharedConstant(Value(90LL))})));

  // Neq returns true for different types.
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc3, doc4, doc5, doc6, doc7, doc8));
}

TEST_F(InequalityPipelineTest, ComparisonHasImplicitBound) {
  auto doc1 = Doc("users/alice", 1000, Map("score", 42LL));
  auto doc2 = Doc("users/boc", 1000, Map("score", 100.0));  // Matches > 42
  auto doc3 = Doc("users/charlie", 1000, Map("score", true));
  auto doc4 = Doc("users/drew", 1000, Map("score", "abc"));
  auto doc5 = Doc("users/eric", 1000,
                  Map("score", Value(Timestamp(0, 2000000))));  // Wrap in Value
  auto doc6 = Doc("users/francis", 1000,
                  Map("score", Value(GeoPoint(0, 0))));  // Wrap in Value
  auto doc7 = Doc("users/george", 1000,
                  Map("score", Value(Array(Value(42LL)))));  // Wrap in Value
  auto doc8 = Doc("users/hope", 1000,
                  Map("score", Map("foo", 42LL)));  // Map is already a Value
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4,
                                         doc5, doc6, doc7, doc8};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      GtExpr({std::make_shared<Field>("score"), SharedConstant(Value(42LL))})));

  // Only numeric types greater than 42 are matched.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2));
}

TEST_F(InequalityPipelineTest, NotComparisonReturnsMixedType) {
  auto doc1 =
      Doc("users/alice", 1000, Map("score", 42LL));  // !(42 > 90) -> !F -> T
  auto doc2 =
      Doc("users/boc", 1000, Map("score", 100.0));  // !(100 > 90) -> !T -> F
  auto doc3 = Doc("users/charlie", 1000,
                  Map("score", true));  // !(true > 90) -> !F -> T
  auto doc4 =
      Doc("users/drew", 1000, Map("score", "abc"));  // !("abc" > 90) -> !F -> T
  auto doc5 = Doc(
      "users/eric", 1000,
      Map("score", Value(Timestamp(
                       0, 2000000))));  // !(T > 90) -> !F -> T (Wrap in Value)
  auto doc6 =
      Doc("users/francis", 1000,
          Map("score",
              Value(GeoPoint(0, 0))));  // !(G > 90) -> !F -> T (Wrap in Value)
  auto doc7 = Doc(
      "users/george", 1000,
      Map("score",
          Value(Array(Value(42LL)))));  // !(A > 90) -> !F -> T (Wrap in Value)
  auto doc8 = Doc(
      "users/hope", 1000,
      Map("score",
          Map("foo", 42LL)));  // !(M > 90) -> !F -> T (Map is already Value)
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4,
                                         doc5, doc6, doc7, doc8};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(NotExpr(GtExpr(
      {std::make_shared<Field>("score"), SharedConstant(Value(90LL))}))));

  // NOT (score > 90). Comparison is only true for score=100.0. NOT flips it.
  // Type mismatches result in false for GtExpr, NOT flips to true.
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc3, doc4, doc5, doc6, doc7, doc8));
}

TEST_F(InequalityPipelineTest, InequalityWithEqualityOnDifferentField) {
  auto doc1 =
      Doc("users/bob", 1000,
          Map("score", 90LL, "rank", 2LL));  // rank=2, score=90 > 80 -> Match
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));  // rank!=2
  auto doc3 =
      Doc("users/charlie", 1000, Map("score", 97LL, "rank", 1LL));  // rank!=2
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqExpr({std::make_shared<Field>("rank"), SharedConstant(Value(2LL))}),
       GtExpr(
           {std::make_shared<Field>("score"), SharedConstant(Value(80LL))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(InequalityPipelineTest, InequalityWithEqualityOnSameField) {
  auto doc1 = Doc("users/bob", 1000,
                  Map("score", 90LL));  // score=90, score > 80 -> Match
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));    // score!=90
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));  // score!=90
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqExpr({std::make_shared<Field>("score"), SharedConstant(Value(90LL))}),
       GtExpr(
           {std::make_shared<Field>("score"), SharedConstant(Value(80LL))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(InequalityPipelineTest, WithSortOnSameField) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));  // score < 90
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(GteExpr(
      {std::make_shared<Field>("score"), SharedConstant(Value(90LL))})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("score"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc3));
}

TEST_F(InequalityPipelineTest, WithSortOnDifferentFields) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 2LL));
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));  // score < 90
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL, "rank", 1LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(GteExpr(
      {std::make_shared<Field>("score"), SharedConstant(Value(90LL))})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("rank"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3, doc1));
}

TEST_F(InequalityPipelineTest, WithOrOnSingleField) {
  auto doc1 = Doc("users/bob", 1000,
                  Map("score", 90LL));  // score not > 90 and not < 60
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL));  // score < 60 -> Match
  auto doc3 =
      Doc("users/charlie", 1000, Map("score", 97LL));  // score > 90 -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {GtExpr({std::make_shared<Field>("score"), SharedConstant(Value(90LL))}),
       LtExpr(
           {std::make_shared<Field>("score"), SharedConstant(Value(60LL))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc3));
}

TEST_F(InequalityPipelineTest, WithOrOnDifferentFields) {
  auto doc1 = Doc("users/bob", 1000,
                  Map("score", 90LL, "rank", 2LL));  // score > 80 -> Match
  auto doc2 = Doc("users/alice", 1000,
                  Map("score", 50LL, "rank", 3LL));  // score !> 80, rank !< 2
  auto doc3 =
      Doc("users/charlie", 1000,
          Map("score", 97LL, "rank", 1LL));  // score > 80, rank < 2 -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {GtExpr({std::make_shared<Field>("score"), SharedConstant(Value(80LL))}),
       LtExpr(
           {std::make_shared<Field>("rank"), SharedConstant(Value(2LL))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc3));
}

TEST_F(InequalityPipelineTest, WithEqAnyOnSingleField) {
  auto doc1 = Doc("users/bob", 1000,
                  Map("score", 90LL));  // score > 80, but not in [50, 80, 97]
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));  // score !> 80
  auto doc3 =
      Doc("users/charlie", 1000,
          Map("score", 97LL));  // score > 80, score in [50, 80, 97] -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {GtExpr({std::make_shared<Field>("score"), SharedConstant(Value(80LL))}),
       EqAnyExpr(
           std::make_shared<Field>("score"),
           SharedConstant(Array(Value(50LL), Value(80LL), Value(97LL))))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3));
}

TEST_F(InequalityPipelineTest, WithEqAnyOnDifferentFields) {
  auto doc1 = Doc(
      "users/bob", 1000,
      Map("score", 90LL, "rank", 2LL));  // rank < 3, score not in [50, 80, 97]
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));  // rank !< 3
  auto doc3 = Doc("users/charlie", 1000,
                  Map("score", 97LL, "rank",
                      1LL));  // rank < 3, score in [50, 80, 97] -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {LtExpr({std::make_shared<Field>("rank"), SharedConstant(Value(3LL))}),
       EqAnyExpr(
           std::make_shared<Field>("score"),
           SharedConstant(Array(Value(50LL), Value(80LL), Value(97LL))))})));
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3));
}

TEST_F(InequalityPipelineTest, WithNotEqAnyOnSingleField) {
  auto doc1 = Doc("users/bob", 1000, Map("notScore", 90LL));  // score missing
  auto doc2 = Doc("users/alice", 1000,
                  Map("score", 90LL));  // score > 80, but score is in [90, 95]
  auto doc3 = Doc("users/charlie", 1000, Map("score", 50LL));  // score !> 80
  auto doc4 =
      Doc("users/diane", 1000,
          Map("score", 97LL));  // score > 80, score not in [90, 95] -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {GtExpr({std::make_shared<Field>("score"), SharedConstant(Value(80LL))}),
       NotEqAnyExpr(std::make_shared<Field>("score"),
                    SharedConstant(Array(Value(90LL), Value(95LL))))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4));
}

TEST_F(InequalityPipelineTest, WithNotEqAnyReturnsMixedTypes) {
  auto doc1 = Doc("users/bob", 1000,
                  Map("notScore", 90LL));  // score missing -> NotEqAny is false
  auto doc2 = Doc(
      "users/alice", 1000,
      Map("score", 90LL));  // score is in [foo, 90, false] -> NotEqAny is false
  auto doc3 =
      Doc("users/charlie", 1000,
          Map("score", true));  // score not in [...] -> NotEqAny is true
  auto doc4 =
      Doc("users/diane", 1000,
          Map("score", 42.0));  // score not in [...] -> NotEqAny is true
  auto doc5 = Doc(
      "users/eric", 1000,
      Map("score",
          std::numeric_limits<double>::quiet_NaN()));  // score not in [...] ->
                                                       // NotEqAny is true
  auto doc6 =
      Doc("users/francis", 1000,
          Map("score", "abc"));  // score not in [...] -> NotEqAny is true
  auto doc7 =
      Doc("users/george", 1000,
          Map("score",
              Value(Timestamp(0, 2000000))));  // score not in [...] -> NotEqAny
                                               // is true (Wrap in Value)
  auto doc8 = Doc(
      "users/hope", 1000,
      Map("score", Value(GeoPoint(0, 0))));  // score not in [...] -> NotEqAny
                                             // is true (Wrap in Value)
  auto doc9 =
      Doc("users/isla", 1000,
          Map("score",
              Value(Array(Value(42LL)))));  // score not in [...] -> NotEqAny is
                                            // true (Wrap in Value)
  auto doc10 =
      Doc("users/jack", 1000,
          Map("score", Map("foo", 42LL)));  // score not in [...] -> NotEqAny is
                                            // true (Map is already Value)
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5,
                                         doc6, doc7, doc8, doc9, doc10};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(NotEqAnyExpr(
      std::make_shared<Field>("score"),
      SharedConstant(Array(Value("foo"), Value(90LL), Value(false))))));

  // Expect all docs where score is not 'foo', 90, or false. Missing fields also
  // match NotEqAny.
  EXPECT_THAT(
      RunPipeline(pipeline, documents),
      UnorderedElementsAre(doc3, doc4, doc5, doc6, doc7, doc8, doc9, doc10));
}

TEST_F(InequalityPipelineTest, WithNotEqAnyOnDifferentFields) {
  auto doc1 =
      Doc("users/bob", 1000,
          Map("score", 90LL, "rank", 2LL));  // rank < 3, score is in [90, 95]
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));  // rank !< 3
  auto doc3 = Doc("users/charlie", 1000,
                  Map("score", 97LL, "rank",
                      1LL));  // rank < 3, score not in [90, 95] -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {LtExpr({std::make_shared<Field>("rank"), SharedConstant(Value(3LL))}),
       NotEqAnyExpr(std::make_shared<Field>("score"),
                    SharedConstant(Array(Value(90LL), Value(95LL))))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3));
}

TEST_F(InequalityPipelineTest, SortByEquality) {
  auto doc1 =
      Doc("users/bob", 1000,
          Map("score", 90LL, "rank", 2LL));  // rank=2, score > 80 -> Match
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 4LL));  // rank!=2
  auto doc3 =
      Doc("users/charlie", 1000, Map("score", 97LL, "rank", 1LL));  // rank!=2
  auto doc4 =
      Doc("users/david", 1000,
          Map("score", 91LL, "rank", 2LL));  // rank=2, score > 80 -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqExpr({std::make_shared<Field>("rank"), SharedConstant(Value(2LL))}),
       GtExpr(
           {std::make_shared<Field>("score"), SharedConstant(Value(80LL))})})));
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("rank"),
                                     Ordering::Direction::ASCENDING),
                            Ordering(std::make_unique<Field>("score"),
                                     Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc4));
}

TEST_F(InequalityPipelineTest, WithEqAnySortByEquality) {
  auto doc1 = Doc(
      "users/bob", 1000,
      Map("score", 90LL, "rank", 3LL));  // rank in [2,3,4], score > 80 -> Match
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 4LL));  // score !> 80
  auto doc3 = Doc("users/charlie", 1000,
                  Map("score", 97LL, "rank", 1LL));  // rank not in [2,3,4]
  auto doc4 = Doc(
      "users/david", 1000,
      Map("score", 91LL, "rank", 2LL));  // rank in [2,3,4], score > 80 -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqAnyExpr(std::make_shared<Field>("rank"),
                 SharedConstant(Array(Value(2LL), Value(3LL), Value(4LL)))),
       GtExpr(
           {std::make_shared<Field>("score"), SharedConstant(Value(80LL))})})));
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("rank"),
                                     Ordering::Direction::ASCENDING),
                            Ordering(std::make_unique<Field>("score"),
                                     Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc4, doc1));
}

TEST_F(InequalityPipelineTest, WithArray) {
  auto doc1 = Doc(
      "users/bob", 1000,
      Map("scores", Array(Value(80LL), Value(85LL), Value(90LL)), "rounds",
          Array(Value(1LL), Value(2LL),
                Value(3LL))));  // scores <= [90,90,90], rounds > [1,2] -> Match
  auto doc2 = Doc("users/alice", 1000,
                  Map("scores", Array(Value(50LL), Value(65LL)), "rounds",
                      Array(Value(1LL), Value(2LL))));  // rounds !> [1,2]
  auto doc3 = Doc(
      "users/charlie", 1000,
      Map("scores", Array(Value(90LL), Value(95LL), Value(97LL)), "rounds",
          Array(Value(1LL), Value(2LL), Value(4LL))));  // scores !<= [90,90,90]
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {LteExpr({std::make_shared<Field>("scores"),
                SharedConstant(Array(Value(90LL), Value(90LL), Value(90LL)))}),
       GtExpr({std::make_shared<Field>("rounds"),
               SharedConstant(Array(Value(1LL), Value(2LL)))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(InequalityPipelineTest,
       WithArrayContainsAny) {  // Renamed from TS: withArrayContainsAny ->
                                // withArrayContains
  auto doc1 = Doc(
      "users/bob", 1000,
      Map("scores", Array(Value(80LL), Value(85LL), Value(90LL)), "rounds",
          Array(
              Value(1LL), Value(2LL),
              Value(
                  3LL))));  // scores <= [90,90,90], rounds contains 3 -> Match
  auto doc2 =
      Doc("users/alice", 1000,
          Map("scores", Array(Value(50LL), Value(65LL)), "rounds",
              Array(Value(1LL), Value(2LL))));  // rounds does not contain 3
  auto doc3 = Doc(
      "users/charlie", 1000,
      Map("scores", Array(Value(90LL), Value(95LL), Value(97LL)), "rounds",
          Array(Value(1LL), Value(2LL), Value(4LL))));  // scores !<= [90,90,90]
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr({
      LteExpr({std::make_shared<Field>("scores"),
               SharedConstant(Array(Value(90LL), Value(90LL), Value(90LL)))}),
      ArrayContainsExpr(
          {std::make_shared<Field>("rounds"),
           SharedConstant(Value(3LL))})  // TS used ArrayContains here
  })));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(InequalityPipelineTest, WithSortAndLimit) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 3LL));
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 4LL));  // score !> 80
  auto doc3 = Doc("users/charlie", 1000, Map("score", 97LL, "rank", 1LL));
  auto doc4 = Doc("users/david", 1000, Map("score", 91LL, "rank", 2LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      GtExpr({std::make_shared<Field>("score"), SharedConstant(Value(80LL))})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("rank"), Ordering::Direction::ASCENDING)}));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(2));

  // score > 80 -> doc1, doc3, doc4. Sort by rank asc -> doc3, doc4, doc1. Limit
  // 2 -> doc3, doc4.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3, doc4));
}

TEST_F(InequalityPipelineTest, MultipleInequalitiesOnSingleField) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL));    // score !> 90
  auto doc2 = Doc("users/alice", 1000, Map("score", 50LL));  // score !> 90
  auto doc3 = Doc("users/charlie", 1000,
                  Map("score", 97LL));  // score > 90 and < 100 -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {GtExpr({std::make_shared<Field>("score"), SharedConstant(Value(90LL))}),
       LtExpr({std::make_shared<Field>("score"),
               SharedConstant(Value(100LL))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3));
}

TEST_F(InequalityPipelineTest,
       MultipleInequalitiesOnDifferentFieldsSingleMatch) {
  auto doc1 =
      Doc("users/bob", 1000, Map("score", 90LL, "rank", 2LL));  // rank !< 2
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));  // score !> 90
  auto doc3 =
      Doc("users/charlie", 1000,
          Map("score", 97LL, "rank", 1LL));  // score > 90, rank < 2 -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {GtExpr({std::make_shared<Field>("score"), SharedConstant(Value(90LL))}),
       LtExpr(
           {std::make_shared<Field>("rank"), SharedConstant(Value(2LL))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3));
}

TEST_F(InequalityPipelineTest,
       MultipleInequalitiesOnDifferentFieldsMultipleMatch) {
  auto doc1 =
      Doc("users/bob", 1000,
          Map("score", 90LL, "rank", 2LL));  // score > 80, rank < 3 -> Match
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));  // score !> 80
  auto doc3 =
      Doc("users/charlie", 1000,
          Map("score", 97LL, "rank", 1LL));  // score > 80, rank < 3 -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {GtExpr({std::make_shared<Field>("score"), SharedConstant(Value(80LL))}),
       LtExpr(
           {std::make_shared<Field>("rank"), SharedConstant(Value(3LL))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc3));
}

TEST_F(InequalityPipelineTest, MultipleInequalitiesOnDifferentFieldsAllMatch) {
  auto doc1 =
      Doc("users/bob", 1000,
          Map("score", 90LL, "rank", 2LL));  // score > 40, rank < 4 -> Match
  auto doc2 =
      Doc("users/alice", 1000,
          Map("score", 50LL, "rank", 3LL));  // score > 40, rank < 4 -> Match
  auto doc3 =
      Doc("users/charlie", 1000,
          Map("score", 97LL, "rank", 1LL));  // score > 40, rank < 4 -> Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {GtExpr({std::make_shared<Field>("score"), SharedConstant(Value(40LL))}),
       LtExpr(
           {std::make_shared<Field>("rank"), SharedConstant(Value(4LL))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3));
}

TEST_F(InequalityPipelineTest, MultipleInequalitiesOnDifferentFieldsNoMatch) {
  auto doc1 =
      Doc("users/bob", 1000, Map("score", 90LL, "rank", 2LL));  // rank !> 3
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));  // score !< 90
  auto doc3 =
      Doc("users/charlie", 1000, Map("score", 97LL, "rank", 1LL));  // rank !> 3
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {LtExpr({std::make_shared<Field>("score"), SharedConstant(Value(90LL))}),
       GtExpr(
           {std::make_shared<Field>("rank"), SharedConstant(Value(3LL))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

TEST_F(InequalityPipelineTest, MultipleInequalitiesWithBoundedRanges) {
  auto doc1 = Doc("users/bob", 1000,
                  Map("score", 90LL, "rank",
                      2LL));  // rank > 0 & < 4, score > 80 & < 95 -> Match
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 4LL));  // rank !< 4
  auto doc3 = Doc("users/charlie", 1000,
                  Map("score", 97LL, "rank", 1LL));  // score !< 95
  auto doc4 =
      Doc("users/david", 1000, Map("score", 80LL, "rank", 3LL));  // score !> 80
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {GtExpr({std::make_shared<Field>("rank"), SharedConstant(Value(0LL))}),
       LtExpr({std::make_shared<Field>("rank"), SharedConstant(Value(4LL))}),
       GtExpr({std::make_shared<Field>("score"), SharedConstant(Value(80LL))}),
       LtExpr(
           {std::make_shared<Field>("score"), SharedConstant(Value(95LL))})})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(InequalityPipelineTest, MultipleInequalitiesWithSingleSortAsc) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 2LL));  // Match
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));  // score !> 80
  auto doc3 =
      Doc("users/charlie", 1000, Map("score", 97LL, "rank", 1LL));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {LtExpr({std::make_shared<Field>("rank"), SharedConstant(Value(3LL))}),
       GtExpr(
           {std::make_shared<Field>("score"), SharedConstant(Value(80LL))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("rank"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3, doc1));
}

TEST_F(InequalityPipelineTest, MultipleInequalitiesWithSingleSortDesc) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 2LL));  // Match
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));  // score !> 80
  auto doc3 =
      Doc("users/charlie", 1000, Map("score", 97LL, "rank", 1LL));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {LtExpr({std::make_shared<Field>("rank"), SharedConstant(Value(3LL))}),
       GtExpr(
           {std::make_shared<Field>("score"), SharedConstant(Value(80LL))})})));
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("rank"), Ordering::Direction::DESCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc3));
}

TEST_F(InequalityPipelineTest, MultipleInequalitiesWithMultipleSortAsc) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 2LL));  // Match
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));  // score !> 80
  auto doc3 =
      Doc("users/charlie", 1000, Map("score", 97LL, "rank", 1LL));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {LtExpr({std::make_shared<Field>("rank"), SharedConstant(Value(3LL))}),
       GtExpr(
           {std::make_shared<Field>("score"), SharedConstant(Value(80LL))})})));
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("rank"),
                                     Ordering::Direction::ASCENDING),
                            Ordering(std::make_unique<Field>("score"),
                                     Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3, doc1));
}

TEST_F(InequalityPipelineTest, MultipleInequalitiesWithMultipleSortDesc) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 2LL));  // Match
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));  // score !> 80
  auto doc3 =
      Doc("users/charlie", 1000, Map("score", 97LL, "rank", 1LL));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {LtExpr({std::make_shared<Field>("rank"), SharedConstant(Value(3LL))}),
       GtExpr(
           {std::make_shared<Field>("score"), SharedConstant(Value(80LL))})})));
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("rank"),
                                     Ordering::Direction::DESCENDING),
                            Ordering(std::make_unique<Field>("score"),
                                     Ordering::Direction::DESCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc3));
}

TEST_F(InequalityPipelineTest,
       MultipleInequalitiesWithMultipleSortDescOnReverseIndex) {
  auto doc1 = Doc("users/bob", 1000, Map("score", 90LL, "rank", 2LL));  // Match
  auto doc2 =
      Doc("users/alice", 1000, Map("score", 50LL, "rank", 3LL));  // score !> 80
  auto doc3 =
      Doc("users/charlie", 1000, Map("score", 97LL, "rank", 1LL));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {LtExpr({std::make_shared<Field>("rank"), SharedConstant(Value(3LL))}),
       GtExpr(
           {std::make_shared<Field>("score"), SharedConstant(Value(80LL))})})));
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("score"),
                                     Ordering::Direction::DESCENDING),
                            Ordering(std::make_unique<Field>("rank"),
                                     Ordering::Direction::DESCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3, doc1));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
