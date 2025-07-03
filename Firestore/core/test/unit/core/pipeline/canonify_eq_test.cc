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
#include "Firestore/core/src/core/pipeline_util.h"  // Target of testing
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/test/unit/core/pipeline/utils.h"
#include "Firestore/core/test/unit/testutil/expression_test_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using api::AggregateStage;
using api::CollectionGroupSource;
using api::CollectionSource;
using api::DatabaseSource;
using api::DocumentsSource;
using api::EvaluableStage;
using api::Expr;
using api::Field;
using api::FindNearestStage;
using api::Firestore;
using api::LimitStage;
using api::OffsetStage;
using api::Ordering;
using api::RealtimePipeline;
using api::SelectStage;
using api::SortStage;
using api::Where;
// using api::AddFields; // Not EvaluableStage
// using api::DistinctStage; // Not EvaluableStage

using model::DatabaseId;
using model::DocumentKey;
using model::FieldPath;
using model::ResourcePath;
using testing::ElementsAre;
using testing::UnorderedElementsAre;
using testutil::Array;
using testutil::Doc;
using testutil::Map;
using testutil::SharedConstant;
using testutil::Value;
// Expression helpers
using testutil::EqAnyExpr;
using testutil::EqExpr;

// Helper to get canonical ID directly for RealtimePipeline
std::string GetPipelineCanonicalId(const RealtimePipeline& pipeline) {
  QueryOrPipeline variant = pipeline;
  // Use the specific helper for QueryOrPipeline canonicalization
  return variant.CanonicalId();
}

// Test Fixture
class CanonifyEqPipelineTest : public ::testing::Test {
 public:
  // Helper to create a pipeline starting with a collection stage
  RealtimePipeline StartPipeline(const std::string& collection_path) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(std::make_shared<CollectionSource>(collection_path));
    return RealtimePipeline(std::move(stages), TestSerializer());
  }
  // Helper to create a pipeline starting with a collection group stage
  RealtimePipeline StartCollectionGroupPipeline(
      const std::string& collection_id) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(std::make_shared<CollectionGroupSource>(collection_id));
    return RealtimePipeline(std::move(stages), TestSerializer());
  }
  // Helper to create a pipeline starting with a database stage
  RealtimePipeline StartDatabasePipeline() {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(std::make_shared<DatabaseSource>());
    return RealtimePipeline(std::move(stages), TestSerializer());
  }
  // Helper to create a pipeline starting with a documents stage
  // Note: DocumentsSource is not EvaluableStage, this helper is problematic
  RealtimePipeline StartDocumentsPipeline(
      const std::vector<std::string>& /* doc_paths */) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    // Cannot construct RealtimePipeline with DocumentsSource directly
    return RealtimePipeline({}, TestSerializer());
  }
};

// ===================================================================
// Canonify Tests (Using EXACT expected strings from TS tests)
// These will FAIL until C++ canonicalization is implemented correctly.
// ===================================================================

TEST_F(CanonifyEqPipelineTest, CanonifySimpleWhere) {
  RealtimePipeline p = StartPipeline("test");
  p = p.AddingStage(std::make_shared<Where>(EqExpr(
      {std::make_shared<api::Field>("foo"), SharedConstant(Value(42LL))})));

  EXPECT_EQ(GetPipelineCanonicalId(p),
            "collection(test)|where(fn(eq[fld(foo),cst(42)]))|sort(fld(__name__"
            ")asc)");
}

TEST_F(CanonifyEqPipelineTest, CanonifyMultipleStages) {
  RealtimePipeline p = StartPipeline("test");
  p = p.AddingStage(std::make_shared<Where>(EqExpr(
      {std::make_shared<api::Field>("foo"), SharedConstant(Value(42LL))})));
  p = p.AddingStage(std::make_shared<LimitStage>(10));
  p = p.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_shared<api::Field>("bar"),
                                     api::Ordering::Direction::DESCENDING)}));
  EXPECT_EQ(GetPipelineCanonicalId(p),
            "collection(test)|where(fn(eq[fld(foo),cst(42)]))|sort(fld(__name__"
            ")asc)|limit(10)|sort(fld(bar)desc,fld(__name__)asc)");
}

// TEST_F(CanonifyEqPipelineTest, CanonifyAddFields) {
//   // Requires constructing pipeline with AddFields stage
//   // RealtimePipeline p = StartPipeline("test");
//   // p = p.AddingStage(std::make_shared<api::AddFields>(...)); // AddFields
//   not Evaluable
//   // EXPECT_EQ(GetPipelineCanonicalId(p),
//   //
//   "collection(/test)|add_fields(__create_time__=fld(__create_time__),__name__=fld(__name__),__update_time__=fld(__update_time__),existingField=fld(existingField),val=cst(10))|sort(fld(__name__)ascending)");
// }

// TEST_F(CanonifyEqPipelineTest, CanonifyAggregateWithGrouping) {
//   // Requires constructing pipeline with AggregateStage stage
//   // RealtimePipeline p = StartPipeline("test");
//   // std::unordered_map<std::string, std::shared_ptr<AggregateExpr>>
//   accumulators;
//   // accumulators["totalValue"] = std::make_shared<AggregateExpr>("sum",
//   std::vector<std::shared_ptr<Expr>>{std::make_shared<api::Field>("value")});
//   // std::unordered_map<std::string, std::shared_ptr<Expr>> groups;
//   // groups["category"] = std::make_shared<api::Field>("category");
//   // p =
//   p.AddingStage(std::make_shared<api::AggregateStage>(std::move(accumulators),
//   std::move(groups))); // AggregateStage not Evaluable
//   // EXPECT_EQ(GetPipelineCanonicalId(p),
//   //
//   "collection(/test)|aggregate(totalValue=fn(sum,[fld(value)]))grouping(category=fld(category))|sort(fld(__name__)ascending)");
// }

// TEST_F(CanonifyEqPipelineTest, CanonifyDistinct) {
//   // Requires constructing pipeline with DistinctStage stage
//   // RealtimePipeline p = StartPipeline("test");
//   // p = p.AddingStage(std::make_shared<api::DistinctStage>(...)); //
//   DistinctStage not Evaluable
//   // EXPECT_EQ(GetPipelineCanonicalId(p),
//   //
//   "collection(/test)|distinct(category=fld(category),city=fld(city))|sort(fld(__name__)ascending)");
// }

// TEST_F(CanonifyEqPipelineTest, CanonifySelect) {
//   // Requires constructing pipeline with SelectStage stage
//   // RealtimePipeline p = StartPipeline("test");
//   // p = p.AddingStage(std::make_shared<api::SelectStage>(...)); //
//   SelectStage not Evaluable
//   // EXPECT_EQ(GetPipelineCanonicalId(p),
//   //
//   "collection(/test)|select(__create_time__=fld(__create_time__),__name__=fld(__name__),__update_time__=fld(__update_time__),age=fld(age),name=fld(name))|sort(fld(__name__)ascending)");
// }

// TEST_F(CanonifyEqPipelineTest, CanonifyOffset) {
//   // OffsetStage is not EvaluableStage. Test skipped.
//   RealtimePipeline p = StartPipeline("test");
//   EXPECT_EQ(GetPipelineCanonicalId(p),
//            "collection(/test)|offset(5)|sort(fld(__name__)ascending)");
// }

// TEST_F(CanonifyEqPipelineTest, CanonifyFindNearest) {
//    // FindNearestStage is not EvaluableStage. Test skipped.
//    RealtimePipeline p = StartPipeline("test");
//   // EXPECT_EQ(GetPipelineCanonicalId(p),
//   //
//   "collection(/test)|find_nearest(fld(location),cosine,[1,2,3],10,distance)|sort(fld(__name__)ascending)");
// }

TEST_F(CanonifyEqPipelineTest, CanonifyCollectionGroupSource) {
  RealtimePipeline p = StartCollectionGroupPipeline("cities");
  EXPECT_EQ(GetPipelineCanonicalId(p),
            "collection_group(cities)|sort(fld(__name__)asc)");
}

// TEST_F(CanonifyEqPipelineTest, CanonifyDatabaseSource) {
//   RealtimePipeline p = StartDatabasePipeline();
//   EXPECT_EQ(GetPipelineCanonicalId(p),
//             "database()|sort(fld(__name__)ascending)");
// }

// TEST_F(CanonifyEqPipelineTest, CanonifyDocumentsSource) {
//   // DocumentsSource is not EvaluableStage. Test skipped.
//   // RealtimePipeline p = StartDocumentsPipeline({"cities/SF", "cities/LA"});
//   // EXPECT_EQ(GetPipelineCanonicalId(p),
//   // "documents(/cities/LA,/cities/SF)|sort(fld(__name__)ascending)");
// }

// TEST_F(CanonifyEqPipelineTest, CanonifyEqAnyArrays) {
//   RealtimePipeline p = StartPipeline("foo");
//   p = p.AddingStage(std::make_shared<Where>(EqAnyExpr(
//       std::make_shared<api::Field>("bar"), SharedConstant(Array(Value("a"),
//       Value("b"))))));
//
//   EXPECT_EQ(GetPipelineCanonicalId(p),
//             "collection(/foo)|where(fn(eq_any,[fld(bar),list([cst(\"a\"),cst(\"b\")])]))|sort(fld(__name__)asc)");
// }

// ===================================================================
// Equality Tests (Using QueryOrPipelineEquals)
// These should pass/fail based on the TS expectation, even with placeholder C++
// canonicalization.
// ===================================================================

TEST_F(CanonifyEqPipelineTest, EqReturnsTrueForIdenticalPipelines) {
  RealtimePipeline p1 = StartPipeline("test");
  p1 = p1.AddingStage(std::make_shared<Where>(EqExpr(
      {std::make_shared<api::Field>("foo"), SharedConstant(Value(42LL))})));

  RealtimePipeline p2 = StartPipeline("test");
  p2 = p2.AddingStage(std::make_shared<Where>(EqExpr(
      {std::make_shared<api::Field>("foo"), SharedConstant(Value(42LL))})));

  QueryOrPipeline v1 = p1;
  QueryOrPipeline v2 = p2;
  EXPECT_TRUE(v1 == v2);  // Expect TRUE based on TS
}

TEST_F(CanonifyEqPipelineTest, EqReturnsFalseForDifferentStages) {
  RealtimePipeline p1 = StartPipeline("test");
  p1 = p1.AddingStage(std::make_shared<Where>(EqExpr(
      {std::make_shared<api::Field>("foo"), SharedConstant(Value(42LL))})));

  RealtimePipeline p2 = StartPipeline("test");
  p2 = p2.AddingStage(std::make_shared<LimitStage>(10));

  QueryOrPipeline v1 = p1;
  QueryOrPipeline v2 = p2;
  EXPECT_FALSE(v1 == v2);  // Expect FALSE based on TS
}

TEST_F(CanonifyEqPipelineTest, EqReturnsFalseForDifferentParamsInStage) {
  RealtimePipeline p1 = StartPipeline("test");
  p1 = p1.AddingStage(std::make_shared<Where>(EqExpr(
      {std::make_shared<api::Field>("foo"), SharedConstant(Value(42LL))})));

  RealtimePipeline p2 = StartPipeline("test");
  p2 = p2.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<api::Field>("bar"),
              SharedConstant(Value(42LL))})));  // Different field

  QueryOrPipeline v1 = p1;
  QueryOrPipeline v2 = p2;
  EXPECT_FALSE(v1 == v2);  // Expect FALSE based on TS
}

TEST_F(CanonifyEqPipelineTest, EqReturnsFalseForDifferentStageOrder) {
  RealtimePipeline p1 = StartPipeline("test");
  p1 = p1.AddingStage(std::make_shared<Where>(EqExpr(
      {std::make_shared<api::Field>("foo"), SharedConstant(Value(42LL))})));
  p1 = p1.AddingStage(std::make_shared<LimitStage>(10));

  RealtimePipeline p2 = StartPipeline("test");
  p2 = p2.AddingStage(std::make_shared<LimitStage>(10));
  p2 = p2.AddingStage(std::make_shared<Where>(EqExpr(
      {std::make_shared<api::Field>("foo"), SharedConstant(Value(42LL))})));

  QueryOrPipeline v1 = p1;
  QueryOrPipeline v2 = p2;
  EXPECT_FALSE(v1 == v2);  // Expect FALSE based on TS
}

// TEST_F(CanonifyEqPipelineTest, EqReturnsTrueForDifferentSelectOrder) {
//   // Requires constructing pipeline with SelectStage stage
//   // RealtimePipeline p1 = StartPipeline("test");
//   // p1 = p1.AddingStage(std::make_shared<Where>(...));
//   // p1 = p1.AddingStage(std::make_shared<SelectStage>(...)); // SelectStage
//   not Evaluable
//
//   // RealtimePipeline p2 = StartPipeline("test");
//   // p2 = p2.AddingStage(std::make_shared<Where>(...));
//   // p2 = p2.AddingStage(std::make_shared<SelectStage>(...)); // SelectStage
//   not Evaluable
//
//   // QueryOrPipeline v1 = p1;
//   // QueryOrPipeline v2 = p2;
//   // EXPECT_TRUE(v1 == v2); // Expect TRUE based on TS
// }

}  // namespace core
}  // namespace firestore
}  // namespace firebase
