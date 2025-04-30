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

#include <limits>  // For numeric_limits
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

// Using directives from previous tests
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
using model::ObjectValue;  // Needed for SeedDatabase
using model::PipelineInputOutputVector;
using testing::ElementsAre;
using testutil::Array;
using testutil::Doc;
using testutil::Map;
using testutil::SharedConstant;
using testutil::Value;
// Expression helpers
using testutil::AddExpr;
using testutil::AndExpr;
using testutil::ArrayContainsAnyExpr;
using testutil::EqAnyExpr;
using testutil::EqExpr;
using testutil::GtExpr;
using testutil::LteExpr;
using testutil::LtExpr;
using testutil::NeqExpr;
using testutil::NotEqAnyExpr;
using testutil::OrExpr;
using testutil::Value;

// Test Fixture for Complex Pipeline tests
class ComplexPipelineTest : public ::testing::Test {
 public:
  const std::string COLLECTION_ID = "test";
  int docIdCounter = 1;

  void SetUp() override {
    docIdCounter = 1;
  }

  // Helper to create a pipeline starting with a collection stage
  RealtimePipeline StartPipeline(const std::string& collection_path) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(std::make_shared<CollectionSource>(collection_path));
    return RealtimePipeline(std::move(stages), TestSerializer());
  }

  // C++ version of seedDatabase helper
  template <typename ValueSupplier>
  PipelineInputOutputVector SeedDatabase(int num_of_documents,
                                         int num_of_fields,
                                         ValueSupplier value_supplier) {
    PipelineInputOutputVector documents;
    documents.reserve(num_of_documents);
    for (int i = 0; i < num_of_documents; ++i) {
      // Use testutil::Map directly within testutil::Doc
      std::vector<std::pair<std::string, google_firestore_v1_Value>> map_data;
      map_data.reserve(num_of_fields);
      for (int j = 1; j <= num_of_fields; ++j) {
        std::string field_name = "field_" + std::to_string(j);
        std::pair<std::string, google_firestore_v1_Value> pair(
            field_name, *value_supplier().release());
        map_data.push_back(pair);
      }
      std::string doc_path = COLLECTION_ID + "/" + std::to_string(docIdCounter);
      // Pass the vector of pairs to testutil::Map
      documents.push_back(
          Doc(doc_path, 1000, testutil::MapFromPairs(map_data)));
      docIdCounter++;
    }
    return documents;
  }
};

TEST_F(ComplexPipelineTest, WhereWithMaxNumberOfStages) {
  const int num_of_fields =
      127;  // Max stages might be different in C++, using TS value.
  int64_t value_counter = 1;
  auto documents =
      SeedDatabase(10, num_of_fields, [&]() { return Value(value_counter++); });

  RealtimePipeline pipeline = StartPipeline("/" + COLLECTION_ID);

  for (int i = 1; i <= num_of_fields; ++i) {
    std::string field_name = "field_" + std::to_string(i);
    pipeline = pipeline.AddingStage(std::make_shared<Where>(
        GtExpr({std::make_shared<Field>(field_name), SharedConstant(0LL)})));
  }

  EXPECT_THAT(RunPipeline(pipeline, documents),
              ReturnsDocsIgnoringOrder(documents));
}

TEST_F(ComplexPipelineTest, EqAnyWithMaxNumberOfElements) {
  const int num_of_documents = 1000;
  const int max_elements = 3000;  // Using TS value
  int64_t value_counter = 1;
  auto documents = SeedDatabase(num_of_documents, 1,
                                [&]() { return Value(value_counter++); });
  // Add one more document not matching 'in' condition
  documents.push_back(Doc(COLLECTION_ID + "/" + std::to_string(docIdCounter),
                          1000, Map("field_1", 3001LL)));

  std::vector<google_firestore_v1_Value> values_proto;
  values_proto.reserve(max_elements);
  for (int i = 1; i <= max_elements; ++i) {
    values_proto.push_back(*Value(static_cast<int64_t>(i)));
  }

  RealtimePipeline pipeline = StartPipeline("/" + COLLECTION_ID);
  pipeline = pipeline.AddingStage(std::make_shared<Where>(EqAnyExpr(
      std::make_shared<Field>("field_1"),
      SharedConstant(testutil::ArrayFromVector(std::move(values_proto))))));

  // Expect all documents except the last one
  PipelineInputOutputVector expected_docs(documents.begin(),
                                          documents.end() - 1);
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ReturnsDocsIgnoringOrder(expected_docs));
}

TEST_F(ComplexPipelineTest, EqAnyWithMaxNumberOfElementsOnMultipleFields) {
  const int num_of_fields = 10;
  const int num_of_documents = 100;
  const int max_elements = 3000;  // Using TS value
  int64_t value_counter = 1;
  auto documents = SeedDatabase(num_of_documents, num_of_fields,
                                [&]() { return Value(value_counter++); });
  // Add one more document not matching 'in' condition
  documents.push_back(Doc(COLLECTION_ID + "/" + std::to_string(docIdCounter),
                          1000, Map("field_1", 3001LL)));

  std::vector<google_firestore_v1_Value> values_proto;
  values_proto.reserve(max_elements);
  for (int i = 1; i <= max_elements; ++i) {
    values_proto.push_back(*Value(static_cast<int64_t>(i)));
  }
  auto values_constant = SharedConstant(
      testutil::ArrayFromVector(std::move(values_proto)));  // Create once

  std::vector<std::shared_ptr<Expr>> conditions;
  conditions.reserve(num_of_fields);
  for (int i = 1; i <= num_of_fields; ++i) {
    std::string field_name = "field_" + std::to_string(i);
    conditions.push_back(
        EqAnyExpr(std::make_shared<Field>(field_name), values_constant));
  }

  RealtimePipeline pipeline = StartPipeline("/" + COLLECTION_ID);
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(AndExpr(std::move(conditions))));

  // Expect all documents except the last one
  PipelineInputOutputVector expected_docs(documents.begin(),
                                          documents.end() - 1);
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ReturnsDocsIgnoringOrder(expected_docs));
}

TEST_F(ComplexPipelineTest, NotEqAnyWithMaxNumberOfElements) {
  const int num_of_documents = 1000;
  const int max_elements = 3000;  // Using TS value
  int64_t value_counter = 1;
  auto documents = SeedDatabase(num_of_documents, 1,
                                [&]() { return Value(value_counter++); });
  // Add one more document matching 'notEqAny' condition
  auto doc_match = Doc(COLLECTION_ID + "/" + std::to_string(docIdCounter), 1000,
                       Map("field_1", 3001LL));
  documents.push_back(doc_match);

  std::vector<google_firestore_v1_Value> values_proto;
  values_proto.reserve(max_elements);
  for (int i = 1; i <= max_elements; ++i) {
    values_proto.push_back(*Value(static_cast<int64_t>(i)));
  }

  RealtimePipeline pipeline = StartPipeline("/" + COLLECTION_ID);
  pipeline = pipeline.AddingStage(std::make_shared<Where>(NotEqAnyExpr(
      std::make_shared<Field>("field_1"),
      SharedConstant(testutil::ArrayFromVector(std::move(values_proto))))));

  PipelineInputOutputVector expected_docs = {doc_match};
  EXPECT_THAT(RunPipeline(pipeline, documents), ReturnsDocs(expected_docs));
}

TEST_F(ComplexPipelineTest, NotEqAnyWithMaxNumberOfElementsOnMultipleFields) {
  const int num_of_fields = 10;
  const int num_of_documents = 100;
  const int max_elements = 3000;  // Using TS value
  int64_t value_counter = 1;
  auto documents = SeedDatabase(num_of_documents, num_of_fields,
                                [&]() { return Value(value_counter++); });
  // Add one more document matching 'notEqAny' condition for field_1
  auto doc_match = Doc(COLLECTION_ID + "/" + std::to_string(docIdCounter), 1000,
                       Map("field_1", 3001LL));
  documents.push_back(doc_match);

  std::vector<google_firestore_v1_Value> values_proto;
  values_proto.reserve(max_elements);
  for (int i = 1; i <= max_elements; ++i) {
    values_proto.push_back(*Value(static_cast<int64_t>(i)));
  }
  auto values_constant = SharedConstant(
      testutil::ArrayFromVector(std::move(values_proto)));  // Create once

  std::vector<std::shared_ptr<Expr>> conditions;
  conditions.reserve(num_of_fields);
  for (int i = 1; i <= num_of_fields; ++i) {
    std::string field_name = "field_" + std::to_string(i);
    conditions.push_back(
        NotEqAnyExpr(std::make_shared<Field>(field_name), values_constant));
  }

  RealtimePipeline pipeline = StartPipeline("/" + COLLECTION_ID);
  // In TS this uses OR, assuming the intent is that *any* field satisfies
  // notEqAny
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(OrExpr(std::move(conditions))));

  // Only the explicitly added document should match
  PipelineInputOutputVector expected_docs = {doc_match};
  EXPECT_THAT(RunPipeline(pipeline, documents), ReturnsDocs(expected_docs));
}

TEST_F(ComplexPipelineTest, ArrayContainsAnyWithLargeNumberOfElements) {
  const int num_of_documents = 1000;
  const int max_elements = 3000;  // Using TS value
  int64_t value_counter = 1;
  // Seed with arrays containing single incrementing number
  auto documents = SeedDatabase(
      num_of_documents, 1, [&]() { return Value(Array(value_counter++)); });
  // Add one more document not matching 'arrayContainsAny' condition
  documents.push_back(Doc(COLLECTION_ID + "/" + std::to_string(docIdCounter),
                          1000, Map("field_1", Value(Array(3001LL)))));

  std::vector<google_firestore_v1_Value> values_proto;
  values_proto.reserve(max_elements);
  for (int i = 1; i <= max_elements; ++i) {
    values_proto.push_back(*Value(static_cast<int64_t>(i)));
  }

  RealtimePipeline pipeline = StartPipeline("/" + COLLECTION_ID);
  pipeline = pipeline.AddingStage(std::make_shared<Where>(ArrayContainsAnyExpr(
      {// Wrap arguments in {}
       std::make_shared<Field>("field_1"),
       SharedConstant(testutil::ArrayFromVector(std::move(values_proto)))})));

  // Expect all documents except the last one
  PipelineInputOutputVector expected_docs(documents.begin(),
                                          documents.end() - 1);
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ReturnsDocsIgnoringOrder(expected_docs));
}

TEST_F(ComplexPipelineTest,
       ArrayContainsAnyWithMaxNumberOfElementsOnMultipleFields) {
  const int num_of_fields = 10;
  const int num_of_documents = 100;
  const int max_elements = 3000;  // Using TS value
  int64_t value_counter = 1;
  // Seed with arrays containing single incrementing number
  auto documents = SeedDatabase(num_of_documents, num_of_fields, [&]() {
    return Value(Array(Value(value_counter++)));
  });
  // Add one more document not matching 'arrayContainsAny' condition
  documents.push_back(Doc(COLLECTION_ID + "/" + std::to_string(docIdCounter),
                          1000, Map("field_1", Value(Array(Value(3001LL))))));

  std::vector<google_firestore_v1_Value> values_proto;
  values_proto.reserve(max_elements);
  for (int i = 1; i <= max_elements; ++i) {
    values_proto.push_back(*Value(static_cast<int64_t>(i)));
  }
  auto values_constant =
      SharedConstant(testutil::ArrayFromVector(std::move(values_proto)));

  std::vector<std::shared_ptr<Expr>> conditions;
  conditions.reserve(num_of_fields);
  for (int i = 1; i <= num_of_fields; ++i) {
    std::string field_name = "field_" + std::to_string(i);
    conditions.push_back(
        ArrayContainsAnyExpr({std::make_shared<Field>(field_name),
                              values_constant}));  // Wrap arguments in {}
  }

  RealtimePipeline pipeline = StartPipeline("/" + COLLECTION_ID);
  // In TS this uses OR
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(OrExpr(std::move(conditions))));

  // Expect all documents except the last one
  PipelineInputOutputVector expected_docs(documents.begin(),
                                          documents.end() - 1);
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ReturnsDocsIgnoringOrder(expected_docs));
}

TEST_F(ComplexPipelineTest, SortByMaxNumOfFieldsWithoutIndex) {
  const int num_of_fields = 31;  // Using TS value
  const int num_of_documents = 100;
  // Passing a constant value here to reduce the complexity on result assertion.
  auto documents = SeedDatabase(num_of_documents, num_of_fields,
                                []() { return Value(10LL); });

  std::vector<Ordering> sort_orders;
  sort_orders.reserve(num_of_fields + 1);
  for (int i = 1; i <= num_of_fields; ++i) {
    std::string field_name = "field_" + std::to_string(i);
    sort_orders.emplace_back(std::make_unique<Field>(field_name),
                             Ordering::ASCENDING);
  }
  // Add __name__ as the last field in sort.
  sort_orders.emplace_back(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                           Ordering::ASCENDING);

  RealtimePipeline pipeline = StartPipeline("/" + COLLECTION_ID);
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::move(sort_orders)));

  // Since all field values are the same, the sort should effectively be by
  // __name__ (key) We need to sort the input documents by key to get the
  // expected order.
  PipelineInputOutputVector expected_docs = documents;
  std::sort(expected_docs.begin(), expected_docs.end(),
            [](const MutableDocument& a, const MutableDocument& b) {
              return a.key() < b.key();
            });

  EXPECT_THAT(RunPipeline(pipeline, documents), ReturnsDocs(expected_docs));
}

TEST_F(ComplexPipelineTest, WhereWithNestedAddFunctionMaxDepth) {
  const int num_of_fields = 1;
  const int num_of_documents = 10;
  const int depth = 31;  // Using TS value
  auto documents = SeedDatabase(num_of_documents, num_of_fields,
                                []() { return Value(0LL); });

  std::shared_ptr<Expr> add_func =
      AddExpr({std::make_shared<Field>("field_1"), SharedConstant(1LL)});
  for (int i = 1; i < depth; ++i) {
    add_func = AddExpr({add_func, SharedConstant(1LL)});
  }

  RealtimePipeline pipeline = StartPipeline("/" + COLLECTION_ID);
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(GtExpr({add_func, SharedConstant(0LL)})));

  // Since field_1 starts at 0, adding 1 repeatedly will always result in > 0
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ReturnsDocsIgnoringOrder(documents));
}

TEST_F(ComplexPipelineTest, WhereWithLargeNumberOrs) {
  const int num_of_fields = 100;  // Using TS value
  const int num_of_documents = 50;
  int64_t value_counter = 1;
  auto documents = SeedDatabase(num_of_documents, num_of_fields,
                                [&]() { return Value(value_counter++); });
  int64_t max_value = value_counter - 1;  // The last value assigned

  std::vector<std::shared_ptr<Expr>> or_conditions;
  or_conditions.reserve(num_of_fields);
  for (int i = 1; i <= num_of_fields; ++i) {
    std::string field_name = "field_" + std::to_string(i);
    // Use LteExpr to match the TS test logic
    or_conditions.push_back(LteExpr(
        {std::make_shared<Field>(field_name), SharedConstant(max_value)}));
  }

  RealtimePipeline pipeline = StartPipeline("/" + COLLECTION_ID);
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(OrExpr(std::move(or_conditions))));

  // Since every document has at least one field <= max_value, all should match
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ReturnsDocsIgnoringOrder(documents));
}

TEST_F(ComplexPipelineTest, WhereWithLargeNumberOfConjunctions) {
  const int num_of_fields = 50;  // Using TS value
  const int num_of_documents = 100;
  int64_t value_counter = 1;
  auto documents = SeedDatabase(num_of_documents, num_of_fields,
                                [&]() { return Value(value_counter++); });

  std::vector<std::shared_ptr<Expr>> and_conditions1;
  std::vector<std::shared_ptr<Expr>> and_conditions2;
  and_conditions1.reserve(num_of_fields);
  and_conditions2.reserve(num_of_fields);

  for (int i = 1; i <= num_of_fields; ++i) {
    std::string field_name = "field_" + std::to_string(i);
    and_conditions1.push_back(
        GtExpr({std::make_shared<Field>(field_name), SharedConstant(0LL)}));
    // Use LtExpr and a large number for the second condition
    and_conditions2.push_back(
        LtExpr({std::make_shared<Field>(field_name),
                SharedConstant(std::numeric_limits<int64_t>::max())}));
  }

  RealtimePipeline pipeline = StartPipeline("/" + COLLECTION_ID);
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(OrExpr({AndExpr(std::move(and_conditions1)),
                                      AndExpr(std::move(and_conditions2))})));

  // Since all seeded values are > 0 and < MAX_LL, all documents should match
  // one of the AND conditions
  EXPECT_THAT(RunPipeline(pipeline, documents),
              ReturnsDocsIgnoringOrder(documents));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
