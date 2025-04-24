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
using api::Constant;
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
using testutil::AndExpr;
using testutil::Constant;  // Renamed from ConstantExpr
using testutil::EqExpr;
using testutil::GteExpr;
using testutil::GtExpr;
using testutil::LteExpr;
using testutil::LtExpr;

// Test Fixture for Unicode Pipeline tests
class UnicodePipelineTest : public ::testing::Test {
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

TEST_F(UnicodePipelineTest, BasicUnicode) {
  auto doc1 = Doc("🐵/Łukasiewicz", 1000, Map("Ł", "Jan Łukasiewicz"));
  auto doc2 = Doc("🐵/Sierpiński", 1000, Map("Ł", "Wacław Sierpiński"));
  auto doc3 = Doc("🐵/iwasawa", 1000, Map("Ł", "岩澤"));

  PipelineInputOutputVector documents = {doc1, doc2, doc3};
  RealtimePipeline pipeline = StartPipeline("/🐵");
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("Ł"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc2, doc3));
}

TEST_F(UnicodePipelineTest, UnicodeSurrogates) {
  auto doc1 = Doc("users/a", 1000, Map("str", "🄟"));
  auto doc2 = Doc("users/b", 1000, Map("str", "Ｐ"));
  auto doc3 = Doc("users/c", 1000, Map("str", "︒"));

  PipelineInputOutputVector documents = {doc1, doc2, doc3};
  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(std::make_shared<Where>(AndExpr(
      {LteExpr({std::make_shared<Field>("str"),
                SharedConstant("🄟")}),  // Renamed from ConstantExpr
       GteExpr({std::make_shared<Field>("str"),
                SharedConstant("Ｐ")})})));  // Renamed from ConstantExpr
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("str"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2, doc1));
}

TEST_F(UnicodePipelineTest, UnicodeSurrogatesInArray) {
  auto doc1 = Doc("users/a", 1000, Map("foo", Array("🄟")));
  auto doc2 = Doc("users/b", 1000, Map("foo", Array("Ｐ")));
  auto doc3 = Doc("users/c", 1000, Map("foo", Array("︒")));

  PipelineInputOutputVector documents = {doc1, doc2, doc3};
  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("foo"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc3, doc2, doc1));
}

TEST_F(UnicodePipelineTest, UnicodeSurrogatesInMapKeys) {
  auto doc1 = Doc("users/a", 1000, Map("map", Map("︒", true, "z", true)));
  auto doc2 = Doc("users/b", 1000, Map("map", Map("🄟", true, "︒", true)));
  auto doc3 = Doc("users/c", 1000, Map("map", Map("Ｐ", true, "︒", true)));

  PipelineInputOutputVector documents = {doc1, doc2, doc3};
  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("map"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc3, doc2));
}

TEST_F(UnicodePipelineTest, UnicodeSurrogatesInMapValues) {
  auto doc1 = Doc("users/a", 1000, Map("map", Map("foo", "︒")));
  auto doc2 = Doc("users/b", 1000, Map("map", Map("foo", "🄟")));
  auto doc3 = Doc("users/c", 1000, Map("map", Map("foo", "Ｐ")));

  PipelineInputOutputVector documents = {doc1, doc2, doc3};
  RealtimePipeline pipeline = StartDatabasePipeline();
  pipeline = pipeline.AddingStage(
      std::make_shared<SortStage>(std::vector<Ordering>{Ordering(
          std::make_unique<Field>("map"), Ordering::Direction::ASCENDING)}));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc3, doc2));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
