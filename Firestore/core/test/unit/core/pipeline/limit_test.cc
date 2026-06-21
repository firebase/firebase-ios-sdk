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

#include <limits>  // Required for numeric_limits
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
using api::LimitStage;
using api::RealtimePipeline;
using model::MutableDocument;
using model::PipelineInputOutputVector;
using testing::ElementsAre;  // For checking empty results
using testing::SizeIs;       // For checking result count
using testutil::Doc;
using testutil::Map;
using testutil::Value;

// Test Fixture for Limit Pipeline tests
class LimitPipelineTest : public ::testing::Test {
 public:
  // Helper to create a pipeline starting with a collection stage
  RealtimePipeline StartPipeline(const std::string& collection_path) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(std::make_shared<CollectionSource>(collection_path));
    return RealtimePipeline(std::move(stages), TestSerializer());
  }

  // Common test documents
  PipelineInputOutputVector CreateDocs() {
    auto doc1 = Doc("k/a", 1000, Map("a", 1LL, "b", 2LL));
    auto doc2 = Doc("k/b", 1000, Map("a", 3LL, "b", 4LL));
    auto doc3 = Doc("k/c", 1000, Map("a", 5LL, "b", 6LL));
    auto doc4 = Doc("k/d", 1000, Map("a", 7LL, "b", 8LL));
    return {doc1, doc2, doc3, doc4};
  }
};

TEST_F(LimitPipelineTest, LimitZero) {
  PipelineInputOutputVector documents = CreateDocs();
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(0));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

TEST_F(LimitPipelineTest, LimitZeroDuplicated) {
  PipelineInputOutputVector documents = CreateDocs();
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(0));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(0));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(0));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre());
}

TEST_F(LimitPipelineTest, LimitOne) {
  PipelineInputOutputVector documents = CreateDocs();
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(1));

  EXPECT_THAT(RunPipeline(pipeline, documents), SizeIs(1));
}

TEST_F(LimitPipelineTest, LimitOneDuplicated) {
  PipelineInputOutputVector documents = CreateDocs();
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(1));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(1));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(1));

  EXPECT_THAT(RunPipeline(pipeline, documents), SizeIs(1));
}

TEST_F(LimitPipelineTest, LimitTwo) {
  PipelineInputOutputVector documents = CreateDocs();
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(2));

  EXPECT_THAT(RunPipeline(pipeline, documents), SizeIs(2));
}

TEST_F(LimitPipelineTest, LimitTwoDuplicated) {
  PipelineInputOutputVector documents = CreateDocs();
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(2));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(2));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(2));

  EXPECT_THAT(RunPipeline(pipeline, documents), SizeIs(2));
}

TEST_F(LimitPipelineTest, LimitThree) {
  PipelineInputOutputVector documents = CreateDocs();
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(3));

  EXPECT_THAT(RunPipeline(pipeline, documents), SizeIs(3));
}

TEST_F(LimitPipelineTest, LimitThreeDuplicated) {
  PipelineInputOutputVector documents = CreateDocs();
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(3));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(3));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(3));

  EXPECT_THAT(RunPipeline(pipeline, documents), SizeIs(3));
}

TEST_F(LimitPipelineTest, LimitFour) {
  PipelineInputOutputVector documents = CreateDocs();
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(4));

  EXPECT_THAT(RunPipeline(pipeline, documents), SizeIs(4));
}

TEST_F(LimitPipelineTest, LimitFourDuplicated) {
  PipelineInputOutputVector documents = CreateDocs();
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(4));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(4));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(4));

  EXPECT_THAT(RunPipeline(pipeline, documents), SizeIs(4));
}

TEST_F(LimitPipelineTest, LimitFive) {
  PipelineInputOutputVector documents = CreateDocs();  // Only 4 docs created
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(5));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              SizeIs(4));  // Limited by actual doc count
}

TEST_F(LimitPipelineTest, LimitFiveDuplicated) {
  PipelineInputOutputVector documents = CreateDocs();  // Only 4 docs created
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(5));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(5));
  pipeline = pipeline.AddingStage(std::make_shared<LimitStage>(5));

  EXPECT_THAT(RunPipeline(pipeline, documents),
              SizeIs(4));  // Limited by actual doc count
}

TEST_F(LimitPipelineTest, LimitMax) {
  PipelineInputOutputVector documents = CreateDocs();
  RealtimePipeline pipeline = StartPipeline("/k");
  // Use a large number, as MAX_SAFE_INTEGER concept doesn't directly map,
  // and LimitStage likely takes int32_t or int64_t.
  pipeline = pipeline.AddingStage(
      std::make_shared<LimitStage>(std::numeric_limits<int32_t>::max()));

  EXPECT_THAT(RunPipeline(pipeline, documents), SizeIs(4));
}

TEST_F(LimitPipelineTest, LimitMaxDuplicated) {
  PipelineInputOutputVector documents = CreateDocs();
  RealtimePipeline pipeline = StartPipeline("/k");
  pipeline = pipeline.AddingStage(
      std::make_shared<LimitStage>(std::numeric_limits<int32_t>::max()));
  pipeline = pipeline.AddingStage(
      std::make_shared<LimitStage>(std::numeric_limits<int32_t>::max()));
  pipeline = pipeline.AddingStage(
      std::make_shared<LimitStage>(std::numeric_limits<int32_t>::max()));

  EXPECT_THAT(RunPipeline(pipeline, documents), SizeIs(4));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
