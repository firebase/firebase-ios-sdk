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
using api::DatabaseSource;  // Used in TS tests
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
using testutil::AddExpr;
using testutil::AndExpr;
using testutil::ArrayContainsAllExpr;
using testutil::ArrayContainsAnyExpr;
using testutil::ArrayContainsExpr;
using testutil::DivideExpr;  // Added for divide test
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

// Test Fixture for Error Handling Pipeline tests
class ErrorHandlingPipelineTest : public ::testing::Test {
 public:
  // Helper to create a pipeline starting with a collection stage
  RealtimePipeline StartPipeline(const std::string& collection_path) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(std::make_shared<CollectionSource>(collection_path));
    return RealtimePipeline(std::move(stages), TestSerializer());
  }
};

TEST_F(ErrorHandlingPipelineTest, WherePartialErrorOr) {
  // Documents with mixed types for boolean fields 'a', 'b', 'c'
  auto doc1 =
      Doc("k/1", 1000,
          Map("a", "true", "b", true, "c",
              false));  // a:string, b:true, c:false -> OR result: true (from b)
  auto doc2 =
      Doc("k/2", 1000,
          Map("a", true, "b", "true", "c",
              false));  // a:true, b:string, c:false -> OR result: true (from a)
  auto doc3 = Doc(
      "k/3", 1000,
      Map("a", true, "b", false, "c",
          "true"));  // a:true, b:false, c:string -> OR result: true (from a)
  auto doc4 =
      Doc("k/4", 1000,
          Map("a", "true", "b", "true", "c",
              true));  // a:string, b:string, c:true -> OR result: true (from c)
  auto doc5 = Doc(
      "k/5", 1000,
      Map("a", "true", "b", true, "c",
          "true"));  // a:string, b:true, c:string -> OR result: true (from b)
  auto doc6 = Doc(
      "k/6", 1000,
      Map("a", true, "b", "true", "c",
          "true"));  // a:true, b:string, c:string -> OR result: true (from a)
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4, doc5, doc6};

  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(OrExpr(
      {EqExpr({std::make_shared<Field>("a"),
               SharedConstant(Value(true))}),  // Expects boolean true
       EqExpr({std::make_shared<Field>("b"), SharedConstant(Value(true))}),
       EqExpr({std::make_shared<Field>("c"), SharedConstant(Value(true))})})));

  // In Firestore, comparisons between different types are generally false.
  // The OR evaluates to true if *any* of the fields 'a', 'b', or 'c' is the
  // boolean value `true`. All documents have at least one field that is boolean
  // `true` or can be evaluated. Assuming type mismatches evaluate to false in
  // EqExpr for OR.
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4, doc5, doc6));
}

TEST_F(ErrorHandlingPipelineTest, WherePartialErrorAnd) {
  auto doc1 =
      Doc("k/1", 1000,
          Map("a", "true", "b", true, "c", false));  // Fails on a != true
  auto doc2 =
      Doc("k/2", 1000,
          Map("a", true, "b", "true", "c", false));  // Fails on b != true
  auto doc3 =
      Doc("k/3", 1000,
          Map("a", true, "b", false, "c", "true"));  // Fails on b != true
  auto doc4 =
      Doc("k/4", 1000,
          Map("a", "true", "b", "true", "c", true));  // Fails on a != true
  auto doc5 =
      Doc("k/5", 1000,
          Map("a", "true", "b", true, "c", "true"));  // Fails on a != true
  auto doc6 =
      Doc("k/6", 1000,
          Map("a", true, "b", "true", "c", "true"));  // Fails on b != true
  auto doc7 =
      Doc("k/7", 1000,
          Map("a", true, "b", true, "c", true));  // All true, should pass
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4,
                                         doc5, doc6, doc7};

  RealtimePipeline pipeline = StartPipeline("k");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {EqExpr({std::make_shared<Field>("a"), SharedConstant(Value(true))}),
       EqExpr({std::make_shared<Field>("b"), SharedConstant(Value(true))}),
       EqExpr({std::make_shared<Field>("c"), SharedConstant(Value(true))})})));

  // AND requires all conditions to be true. Type mismatches evaluate EqExpr to
  // false. Only doc7 has a=true, b=true, AND c=true.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc7));
}

TEST_F(ErrorHandlingPipelineTest, WherePartialErrorXor) {
  // XOR is true if an odd number of inputs are true.
  auto doc1 =
      Doc("k/1", 1000,
          Map("a", "true", "b", true, "c", false));  // a:F, b:T, c:F -> XOR: T
  auto doc2 =
      Doc("k/2", 1000,
          Map("a", true, "b", "true", "c", false));  // a:T, b:F, c:F -> XOR: T
  auto doc3 =
      Doc("k/3", 1000,
          Map("a", true, "b", false, "c", "true"));  // a:T, b:F, c:F -> XOR: T
  auto doc4 =
      Doc("k/4", 1000,
          Map("a", "true", "b", "true", "c", true));  // a:F, b:F, c:T -> XOR: T
  auto doc5 =
      Doc("k/5", 1000,
          Map("a", "true", "b", true, "c", "true"));  // a:F, b:T, c:F -> XOR: T
  auto doc6 =
      Doc("k/6", 1000,
          Map("a", true, "b", "true", "c", "true"));  // a:T, b:F, c:F -> XOR: T
  auto doc7 = Doc("k/7", 1000,
                  Map("a", true, "b", true, "c",
                      true));  // a:T, b:T, c:T -> XOR: T (odd number)
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4,
                                         doc5, doc6, doc7};

  RealtimePipeline pipeline = StartPipeline("k");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(XorExpr(
      {// Casting might not work directly, using EqExpr for boolean check
       EqExpr({std::make_shared<Field>("a"), SharedConstant(Value(true))}),
       EqExpr({std::make_shared<Field>("b"), SharedConstant(Value(true))}),
       EqExpr({std::make_shared<Field>("c"), SharedConstant(Value(true))})})));

  // Assuming type mismatches evaluate EqExpr to false:
  // doc1: F ^ T ^ F = T
  // doc2: T ^ F ^ F = T
  // doc3: T ^ F ^ F = T
  // doc4: F ^ F ^ T = T
  // doc5: F ^ T ^ F = T
  // doc6: T ^ F ^ F = T
  // doc7: T ^ T ^ T = T
  EXPECT_THAT(RunPipeline(pipeline, documents),
              UnorderedElementsAre(doc1, doc2, doc3, doc4, doc5, doc6, doc7));
}

TEST_F(ErrorHandlingPipelineTest, WhereNotError) {
  auto doc1 = Doc("k/1", 1000, Map("a", false));  // a is false -> NOT a is true
  auto doc2 = Doc("k/2", 1000,
                  Map("a", "true"));  // a is string -> NOT a is error/false?
  auto doc3 = Doc("k/3", 1000,
                  Map("b", true));  // a is missing -> NOT a is error/false?
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("k");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(NotExpr(std::make_shared<Field>("a"))));

  // Only doc1 has a == false.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(ErrorHandlingPipelineTest, WhereErrorProducingFunctionReturnsEmpty) {
  auto doc1 = Doc("users/a", 1000, Map("name", "alice", "age", true));
  auto doc2 = Doc("users/b", 1000, Map("name", "bob", "age", "42"));
  auto doc3 = Doc("users/c", 1000, Map("name", "charlie", "age", 0));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("k");
  // Division operation with string constants - this should likely cause an
  // evaluation error.
  pipeline = pipeline.AddingStage(std::make_shared<Where>(EqExpr({
      DivideExpr({SharedConstant(Value("100")),
                  SharedConstant(Value("50"))}),  // Error here
      SharedConstant(Value(2LL))  // Comparing result to integer 2
  })));

  // The TS test expects an empty result, suggesting the error in DivideExpr
  // prevents any match.
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
