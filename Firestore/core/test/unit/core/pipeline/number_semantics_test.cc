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
using model::MutableDocument;
using model::ObjectValue;
using model::PipelineInputOutputVector;
using testing::ElementsAre;
using testing::UnorderedElementsAre;
using testutil::Array;
using testutil::Doc;
using testutil::Map;
using testutil::SharedConstant;
using testutil::Value;
// Expression helpers
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
using testutil::LteExpr;
using testutil::LtExpr;
using testutil::NeqExpr;
using testutil::NotEqAnyExpr;
using testutil::NotExpr;
using testutil::OrExpr;
using testutil::XorExpr;

// Test Fixture for Number Semantics Pipeline tests
class NumberSemanticsPipelineTest : public ::testing::Test {
 public:
  // Helper to create a pipeline starting with a collection stage
  RealtimePipeline StartPipeline(const std::string& collection_path) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(std::make_shared<CollectionSource>(collection_path));
    return RealtimePipeline(std::move(stages), TestSerializer());
  }
};

TEST_F(NumberSemanticsPipelineTest, ZeroNegativeDoubleZero) {
  auto doc1 = Doc("users/a", 1000, Map("score", 0LL));   // Integer 0
  auto doc2 = Doc("users/b", 1000, Map("score", -0LL));  // Integer -0
  auto doc3 = Doc("users/c", 1000, Map("score", 0.0));   // Double 0.0
  auto doc4 = Doc("users/d", 1000, Map("score", -0.0));  // Double -0.0
  auto doc5 = Doc("users/e", 1000, Map("score", 1LL));   // Integer 1
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline =
      StartPipeline("/users");  // Assuming /users based on keys
  // Firestore treats 0, -0, 0.0, -0.0 as equal.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("score"), SharedConstant(Value(-0.0))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4));
}

TEST_F(NumberSemanticsPipelineTest, ZeroNegativeIntegerZero) {
  auto doc1 = Doc("users/a", 1000, Map("score", 0LL));
  auto doc2 = Doc("users/b", 1000, Map("score", -0LL));
  auto doc3 = Doc("users/c", 1000, Map("score", 0.0));
  auto doc4 = Doc("users/d", 1000, Map("score", -0.0));
  auto doc5 = Doc("users/e", 1000, Map("score", 1LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("score"), SharedConstant(Value(-0LL))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4));
}

TEST_F(NumberSemanticsPipelineTest, ZeroPositiveDoubleZero) {
  auto doc1 = Doc("users/a", 1000, Map("score", 0LL));
  auto doc2 = Doc("users/b", 1000, Map("score", -0LL));
  auto doc3 = Doc("users/c", 1000, Map("score", 0.0));
  auto doc4 = Doc("users/d", 1000, Map("score", -0.0));
  auto doc5 = Doc("users/e", 1000, Map("score", 1LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("score"), SharedConstant(Value(0.0))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4));
}

TEST_F(NumberSemanticsPipelineTest, ZeroPositiveIntegerZero) {
  auto doc1 = Doc("users/a", 1000, Map("score", 0LL));
  auto doc2 = Doc("users/b", 1000, Map("score", -0LL));
  auto doc3 = Doc("users/c", 1000, Map("score", 0.0));
  auto doc4 = Doc("users/d", 1000, Map("score", -0.0));
  auto doc5 = Doc("users/e", 1000, Map("score", 1LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("score"), SharedConstant(Value(0LL))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4));
}

TEST_F(NumberSemanticsPipelineTest, EqualNan) {
  auto doc1 = Doc(
      "users/a", 1000,
      Map("name", "alice", "age", std::numeric_limits<double>::quiet_NaN()));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25LL));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // NaN is not equal to anything, including NaN.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(EqExpr(
      {std::make_shared<Field>("age"),
       SharedConstant(Value(std::numeric_limits<double>::quiet_NaN()))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

TEST_F(NumberSemanticsPipelineTest, LessThanNan) {
  auto doc1 = Doc(
      "users/a", 1000,
      Map("name", "alice", "age", std::numeric_limits<double>::quiet_NaN()));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", nullptr));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // Comparisons with NaN are always false.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(LtExpr(
      {std::make_shared<Field>("age"),
       SharedConstant(Value(std::numeric_limits<double>::quiet_NaN()))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

TEST_F(NumberSemanticsPipelineTest, LessThanEqualNan) {
  auto doc1 = Doc(
      "users/a", 1000,
      Map("name", "alice", "age", std::numeric_limits<double>::quiet_NaN()));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", nullptr));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // Comparisons with NaN are always false.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(LteExpr(
      {std::make_shared<Field>("age"),
       SharedConstant(Value(std::numeric_limits<double>::quiet_NaN()))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

TEST_F(NumberSemanticsPipelineTest, GreaterThanEqualNan) {
  auto doc1 = Doc(
      "users/a", 1000,
      Map("name", "alice", "age", std::numeric_limits<double>::quiet_NaN()));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 100LL));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // Comparisons with NaN are always false.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(GteExpr(
      {std::make_shared<Field>("age"),
       SharedConstant(Value(std::numeric_limits<double>::quiet_NaN()))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

TEST_F(NumberSemanticsPipelineTest, GreaterThanNan) {
  auto doc1 = Doc(
      "users/a", 1000,
      Map("name", "alice", "age", std::numeric_limits<double>::quiet_NaN()));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 100LL));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // Comparisons with NaN are always false.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(GtExpr(
      {std::make_shared<Field>("age"),
       SharedConstant(Value(std::numeric_limits<double>::quiet_NaN()))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

TEST_F(NumberSemanticsPipelineTest, NotEqualNan) {
  auto doc1 = Doc(
      "users/a", 1000,
      Map("name", "alice", "age", std::numeric_limits<double>::quiet_NaN()));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25LL));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // != NaN is always true (as NaN != NaN).
  pipeline = pipeline.AddingStage(std::make_shared<Where>(NeqExpr(
      {std::make_shared<Field>("age"),
       SharedConstant(Value(std::numeric_limits<double>::quiet_NaN()))})));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3));
}

TEST_F(NumberSemanticsPipelineTest, EqAnyContainsNan) {
  auto doc1 =
      Doc("users/a", 1000, Map("name", "alice", "age", 75.5));  // Match 'alice'
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25LL));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // IN filter ignores NaN.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(EqAnyExpr(
      std::make_shared<Field>("name"),
      SharedConstant(Array(Value(std::numeric_limits<double>::quiet_NaN()),
                           Value("alice"))))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(NumberSemanticsPipelineTest, EqAnyContainsNanOnlyIsEmpty) {
  auto doc1 = Doc(
      "users/a", 1000,
      Map("name", "alice", "age", std::numeric_limits<double>::quiet_NaN()));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25LL));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // IN [NaN] matches nothing.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(EqAnyExpr(
      std::make_shared<Field>("age"),
      SharedConstant(Array(Value(std::numeric_limits<double>::quiet_NaN()))))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

TEST_F(NumberSemanticsPipelineTest, ArrayContainsNanOnlyIsEmpty) {
  auto doc1 = Doc(
      "users/a", 1000,
      Map("name", "alice", "age", std::numeric_limits<double>::quiet_NaN()));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", 25LL));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 100LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // arrayContains does not match NaN.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(ArrayContainsExpr(
      {std::make_shared<Field>("age"),
       SharedConstant(Value(std::numeric_limits<double>::quiet_NaN()))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

TEST_F(NumberSemanticsPipelineTest, ArrayContainsAnyWithNaN) {
  auto doc1 =
      Doc("k/a", 1000,
          Map("field",
              Value(Array(Value(std::numeric_limits<double>::quiet_NaN())))));
  auto doc2 = Doc(
      "k/b", 1000,
      Map("field", Value(Array(Value(std::numeric_limits<double>::quiet_NaN()),
                               Value(42LL)))));
  auto doc3 = Doc(
      "k/c", 1000,
      Map("field", Value(Array(Value("foo"), Value(42LL)))));  // Match 'foo'
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/k");
  // arrayContainsAny ignores NaN, matches 'foo'.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(ArrayContainsAnyExpr(
      {std::make_shared<Field>("field"),
       SharedConstant(Array(Value(std::numeric_limits<double>::quiet_NaN()),
                            Value("foo")))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3));
}

TEST_F(NumberSemanticsPipelineTest, NotEqAnyContainsNan) {
  auto doc1 =
      Doc("users/a", 1000, Map("age", 42LL));  // age is in [NaN, 42] -> false
  auto doc2 =
      Doc("users/b", 1000,
          Map("age",
              std::numeric_limits<double>::quiet_NaN()));  // age is NaN -> true
                                                           // (since NaN != NaN)
  auto doc3 =
      Doc("users/c", 1000, Map("age", 25LL));  // age not in [NaN, 42] -> true
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // NOT IN ignores NaN in the list, effectively becoming NOT IN [42].
  // It matches fields that are not equal to 42. NaN is not equal to 42.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(NotEqAnyExpr(
      std::make_shared<Field>("age"),
      SharedConstant(Array(Value(std::numeric_limits<double>::quiet_NaN()),
                           Value(42LL))))));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc2, doc3));
}

TEST_F(NumberSemanticsPipelineTest,
       NotEqAnyContainsNanOnlyIsEmpty) {  // Renamed from TS:
                                          // notEqAny_containsNanOnly_isEmpty ->
                                          // notEqAny_containsNanOnly_matchesAll
  auto doc1 = Doc("users/a", 1000, Map("age", 42LL));
  auto doc2 = Doc("users/b", 1000,
                  Map("age", std::numeric_limits<double>::quiet_NaN()));
  auto doc3 = Doc("users/c", 1000, Map("age", 25LL));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // NOT IN [NaN] matches everything because nothing is equal to NaN.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(NotEqAnyExpr(
      std::make_shared<Field>("age"),
      SharedConstant(Array(Value(std::numeric_limits<double>::quiet_NaN()))))));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3));
}

TEST_F(NumberSemanticsPipelineTest, ArrayWithNan) {
  auto doc1 =
      Doc("k/a", 1000,
          Map("foo",
              Value(Array(Value(std::numeric_limits<double>::quiet_NaN())))));
  auto doc2 = Doc("k/b", 1000, Map("foo", Value(Array(Value(42LL)))));
  PipelineInputOutputVector documents = {doc1, doc2};

  RealtimePipeline pipeline = StartPipeline("/k");
  // Equality filters never match NaN values, even within arrays.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("foo"),
              SharedConstant(Value(
                  Array(Value(std::numeric_limits<double>::quiet_NaN()))))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

// Skipping map_withNan test as it was commented out in TS.

}  // namespace core
}  // namespace firestore
}  // namespace firebase
