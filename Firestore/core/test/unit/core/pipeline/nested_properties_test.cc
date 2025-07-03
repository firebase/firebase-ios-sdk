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
// #include "Firestore/core/src/model/field_value.h" // Removed incorrect
// include
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
// using model::FieldValue; // Removed using
using model::MutableDocument;
using model::ObjectValue;
using model::PipelineInputOutputVector;
using testing::ElementsAre;
using testing::IsEmpty;
using testing::SizeIs;  // For checking result size
using testing::UnorderedElementsAre;
using testutil::Array;
using testutil::Doc;
using testutil::Map;
using testutil::SharedConstant;
using testutil::Value;
// Expression helpers
using testutil::EqExpr;
using testutil::ExistsExpr;
using testutil::GteExpr;
using testutil::GtExpr;
using testutil::IsNullExpr;
using testutil::LtExpr;
using testutil::NeqExpr;
using testutil::NotExpr;

// Test Fixture for Nested Properties Pipeline tests
class NestedPropertiesPipelineTest : public ::testing::Test {
 public:
  // Helper to create a pipeline starting with a collection stage
  RealtimePipeline StartPipeline(const std::string& collection_path) {
    std::vector<std::shared_ptr<EvaluableStage>> stages;
    stages.push_back(std::make_shared<CollectionSource>(collection_path));
    return RealtimePipeline(std::move(stages), TestSerializer());
  }
};

TEST_F(NestedPropertiesPipelineTest, WhereEqualityDeeplyNested) {
  auto doc1 = Doc(
      "users/a", 1000,
      Map("a",
          Map("b",
              Map("c",
                  Map("d",
                      Map("e",
                          Map("f",
                              Map("g",
                                  Map("h",
                                      Map("i",
                                          Map("j",
                                              Map("k",
                                                  42LL))))))))))));  // Match
  auto doc2 = Doc(
      "users/b", 1000,
      Map("a",
          Map("b",
              Map("c",
                  Map("d",
                      Map("e",
                          Map("f",
                              Map("g",
                                  Map("h",
                                      Map("i",
                                          Map("j", Map("k", "42"))))))))))));
  auto doc3 =
      Doc("users/c", 1000,
          Map("a",
              Map("b",
                  Map("c",
                      Map("d",
                          Map("e",
                              Map("f",
                                  Map("g",
                                      Map("h",
                                          Map("i",
                                              Map("j", Map("k", 0LL))))))))))));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("a.b.c.d.e.f.g.h.i.j.k"),
              SharedConstant(Value(42LL))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(NestedPropertiesPipelineTest, WhereInequalityDeeplyNested) {
  auto doc1 = Doc(
      "users/a", 1000,
      Map("a",
          Map("b",
              Map("c",
                  Map("d",
                      Map("e",
                          Map("f",
                              Map("g",
                                  Map("h",
                                      Map("i",
                                          Map("j",
                                              Map("k",
                                                  42LL))))))))))));  // Match
  auto doc2 = Doc(
      "users/b", 1000,
      Map("a",
          Map("b",
              Map("c",
                  Map("d",
                      Map("e",
                          Map("f",
                              Map("g",
                                  Map("h",
                                      Map("i",
                                          Map("j", Map("k", "42"))))))))))));
  auto doc3 =
      Doc("users/c", 1000,
          Map("a",
              Map("b",
                  Map("c",
                      Map("d",
                          Map("e",
                              Map("f",
                                  Map("g",
                                      Map("h",
                                          Map("i",
                                              Map("j",
                                                  Map("k",
                                                      0LL))))))))))));  // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      GteExpr({std::make_shared<Field>("a.b.c.d.e.f.g.h.i.j.k"),
               SharedConstant(Value(0LL))})));
  pipeline =
      pipeline.AddingStage(std::make_shared<SortStage>(std::vector<Ordering>{
          Ordering(std::make_unique<Field>(FieldPath::kDocumentKeyPath),
                   Ordering::Direction::ASCENDING)}));

  // k >= 0 -> Matches doc1 (42) and doc3 (0)
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc3));
}

TEST_F(NestedPropertiesPipelineTest, WhereEquality) {
  auto doc1 = Doc("users/a", 1000,
                  Map("address", Map("city", "San Francisco", "state", "CA",
                                     "zip", 94105LL)));
  auto doc2 = Doc("users/b", 1000,
                  Map("address", Map("street", "76", "city", "New York",
                                     "state", "NY", "zip", 10011LL)));  // Match
  auto doc3 = Doc("users/c", 1000,
                  Map("address", Map("city", "Mountain View", "state", "CA",
                                     "zip", 94043LL)));
  auto doc4 = Doc("users/d", 1000, Map());
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(EqExpr({std::make_shared<Field>("address.street"),
                                      SharedConstant(Value("76"))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2));
}

TEST_F(NestedPropertiesPipelineTest, MultipleFilters) {
  auto doc1 = Doc("users/a", 1000,
                  Map("address", Map("city", "San Francisco", "state", "CA",
                                     "zip", 94105LL)));  // Match
  auto doc2 = Doc("users/b", 1000,
                  Map("address", Map("street", "76", "city", "New York",
                                     "state", "NY", "zip", 10011LL)));
  auto doc3 = Doc("users/c", 1000,
                  Map("address", Map("city", "Mountain View", "state", "CA",
                                     "zip", 94043LL)));
  auto doc4 = Doc("users/d", 1000, Map());
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("address.city"),
              SharedConstant(Value("San Francisco"))})));
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(GtExpr({std::make_shared<Field>("address.zip"),
                                      SharedConstant(Value(90000LL))})));

  // city == "San Francisco" AND zip > 90000
  // doc1: T AND 94105 > 90000 (T) -> True
  // doc2: F -> False
  // doc3: F -> False
  // doc4: F -> False
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(NestedPropertiesPipelineTest, MultipleFiltersRedundant) {
  auto doc1 = Doc("users/a", 1000,
                  Map("address", Map("city", "San Francisco", "state", "CA",
                                     "zip", 94105LL)));  // Match
  auto doc2 = Doc("users/b", 1000,
                  Map("address", Map("street", "76", "city", "New York",
                                     "state", "NY", "zip", 10011LL)));
  auto doc3 = Doc("users/c", 1000,
                  Map("address", Map("city", "Mountain View", "state", "CA",
                                     "zip", 94043LL)));
  auto doc4 = Doc("users/d", 1000, Map());
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("address"),
              SharedConstant(Map(  // Use testutil::Map helper
                  "city", "San Francisco", "state", "CA", "zip", 94105LL))})));
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(GtExpr({std::make_shared<Field>("address.zip"),
                                      SharedConstant(Value(90000LL))})));

  // address == {city: SF, state: CA, zip: 94105} AND address.zip > 90000
  // doc1: T AND 94105 > 90000 (T) -> True
  // doc2: F -> False
  // doc3: F -> False
  // doc4: F -> False
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(NestedPropertiesPipelineTest, MultipleFiltersWithCompositeIndex) {
  // This test is functionally identical to MultipleFilters in the TS version
  // (ignoring async).
  auto doc1 = Doc("users/a", 1000,
                  Map("address", Map("city", "San Francisco", "state", "CA",
                                     "zip", 94105LL)));  // Match
  auto doc2 = Doc("users/b", 1000,
                  Map("address", Map("street", "76", "city", "New York",
                                     "state", "NY", "zip", 10011LL)));
  auto doc3 = Doc("users/c", 1000,
                  Map("address", Map("city", "Mountain View", "state", "CA",
                                     "zip", 94043LL)));
  auto doc4 = Doc("users/d", 1000, Map());
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("address.city"),
              SharedConstant(Value("San Francisco"))})));
  pipeline = pipeline.AddingStage(
      std::make_shared<Where>(GtExpr({std::make_shared<Field>("address.zip"),
                                      SharedConstant(Value(90000LL))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(NestedPropertiesPipelineTest, WhereInequality) {
  auto doc1 =
      Doc("users/a", 1000,
          Map("address", Map("city", "San Francisco", "state", "CA", "zip",
                             94105LL)));  // zip > 90k, zip != 10011
  auto doc2 =
      Doc("users/b", 1000,
          Map("address", Map("street", "76", "city", "New York", "state", "NY",
                             "zip", 10011LL)));  // zip < 90k
  auto doc3 =
      Doc("users/c", 1000,
          Map("address", Map("city", "Mountain View", "state", "CA", "zip",
                             94043LL)));  // zip > 90k, zip != 10011
  auto doc4 = Doc("users/d", 1000, Map());
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline1 = StartPipeline("/users");
  pipeline1 = pipeline1.AddingStage(
      std::make_shared<Where>(GtExpr({std::make_shared<Field>("address.zip"),
                                      SharedConstant(Value(90000LL))})));
  EXPECT_THAT(RunPipeline(pipeline1, documents), ElementsAre(doc1, doc3));

  RealtimePipeline pipeline2 = StartPipeline("/users");
  pipeline2 = pipeline2.AddingStage(
      std::make_shared<Where>(LtExpr({std::make_shared<Field>("address.zip"),
                                      SharedConstant(Value(90000LL))})));
  EXPECT_THAT(RunPipeline(pipeline2, documents), ElementsAre(doc2));

  RealtimePipeline pipeline3 = StartPipeline("/users");
  pipeline3 = pipeline3.AddingStage(std::make_shared<Where>(LtExpr(
      {std::make_shared<Field>("address.zip"), SharedConstant(Value(0LL))})));
  EXPECT_THAT(RunPipeline(pipeline3, documents), IsEmpty());

  RealtimePipeline pipeline4 = StartPipeline("/users");
  pipeline4 = pipeline4.AddingStage(
      std::make_shared<Where>(NeqExpr({std::make_shared<Field>("address.zip"),
                                       SharedConstant(Value(10011LL))})));
  EXPECT_THAT(RunPipeline(pipeline4, documents), ElementsAre(doc1, doc3));
}

TEST_F(NestedPropertiesPipelineTest, WhereExists) {
  auto doc1 = Doc("users/a", 1000,
                  Map("address", Map("city", "San Francisco", "state", "CA",
                                     "zip", 94105LL)));
  auto doc2 = Doc("users/b", 1000,
                  Map("address", Map("street", "76", "city", "New York",
                                     "state", "NY", "zip", 10011LL)));  // Match
  auto doc3 = Doc("users/c", 1000,
                  Map("address", Map("city", "Mountain View", "state", "CA",
                                     "zip", 94043LL)));
  auto doc4 = Doc("users/d", 1000, Map());
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      ExistsExpr(std::make_shared<Field>("address.street"))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2));
}

TEST_F(NestedPropertiesPipelineTest, WhereNotExists) {
  auto doc1 = Doc("users/a", 1000,
                  Map("address", Map("city", "San Francisco", "state", "CA",
                                     "zip", 94105LL)));  // Match
  auto doc2 = Doc("users/b", 1000,
                  Map("address", Map("street", "76", "city", "New York",
                                     "state", "NY", "zip", 10011LL)));
  auto doc3 = Doc("users/c", 1000,
                  Map("address", Map("city", "Mountain View", "state", "CA",
                                     "zip", 94043LL)));  // Match
  auto doc4 = Doc("users/d", 1000, Map());               // Match
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(ExistsExpr(std::make_shared<Field>("address.street")))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc3, doc4));
}

TEST_F(NestedPropertiesPipelineTest, WhereIsNull) {
  auto doc1 =
      Doc("users/a", 1000,
          Map("address", Map("city", "San Francisco", "state", "CA", "zip",
                             94105LL, "street", nullptr)));  // Match
  auto doc2 = Doc("users/b", 1000,
                  Map("address", Map("street", "76", "city", "New York",
                                     "state", "NY", "zip", 10011LL)));
  auto doc3 = Doc("users/c", 1000,
                  Map("address", Map("city", "Mountain View", "state", "CA",
                                     "zip", 94043LL)));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      IsNullExpr(std::make_shared<Field>("address.street"))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

TEST_F(NestedPropertiesPipelineTest, WhereIsNotNull) {
  auto doc1 = Doc("users/a", 1000,
                  Map("address", Map("city", "San Francisco", "state", "CA",
                                     "zip", 94105LL, "street", nullptr)));
  auto doc2 = Doc("users/b", 1000,
                  Map("address", Map("street", "76", "city", "New York",
                                     "state", "NY", "zip", 10011LL)));  // Match
  auto doc3 = Doc("users/c", 1000,
                  Map("address", Map("city", "Mountain View", "state", "CA",
                                     "zip", 94043LL)));
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      NotExpr(IsNullExpr(std::make_shared<Field>("address.street")))));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2));
}

TEST_F(NestedPropertiesPipelineTest, SortWithExists) {
  auto doc1 = Doc("users/a", 1000,
                  Map("address", Map("street", "41", "city", "San Francisco",
                                     "state", "CA", "zip", 94105LL)));  // Match
  auto doc2 = Doc("users/b", 1000,
                  Map("address", Map("street", "76", "city", "New York",
                                     "state", "NY", "zip", 10011LL)));  // Match
  auto doc3 = Doc("users/c", 1000,
                  Map("address", Map("city", "Mountain View", "state", "CA",
                                     "zip", 94043LL)));
  auto doc4 = Doc("users/d", 1000, Map());
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      ExistsExpr(std::make_shared<Field>("address.street"))));
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("address.street"),
                                     Ordering::Direction::ASCENDING)}));

  // Filter for street exists (doc1, doc2), then sort by street asc ("41", "76")
  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1, doc2));
}

TEST_F(NestedPropertiesPipelineTest, SortWithoutExists) {
  auto doc1 = Doc("users/a", 1000,
                  Map("address", Map("street", "41", "city", "San Francisco",
                                     "state", "CA", "zip", 94105LL)));
  auto doc2 = Doc("users/b", 1000,
                  Map("address", Map("street", "76", "city", "New York",
                                     "state", "NY", "zip", 10011LL)));
  auto doc3 = Doc("users/c", 1000,
                  Map("address", Map("city", "Mountain View", "state", "CA",
                                     "zip", 94043LL)));
  auto doc4 = Doc("users/d", 1000, Map());
  PipelineInputOutputVector documents = {doc1, doc2, doc3, doc4};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<SortStage>(
      std::vector<Ordering>{Ordering(std::make_unique<Field>("address.street"),
                                     Ordering::Direction::ASCENDING)}));

  // Sort by street asc. Missing fields sort first by key (c, d), then existing
  // fields by value ("41", "76") Expected order: doc3, doc4, doc1, doc2
  auto results = RunPipeline(pipeline, documents);
  EXPECT_THAT(results, SizeIs(4));
  EXPECT_THAT(results, ElementsAre(doc3, doc4, doc1, doc2));
}

TEST_F(NestedPropertiesPipelineTest, QuotedNestedPropertyFilterNested) {
  auto doc1 = Doc("users/a", 1000, Map("address.city", "San Francisco"));
  auto doc2 = Doc("users/b", 1000,
                  Map("address", Map("city", "San Francisco")));  // Match
  auto doc3 = Doc("users/c", 1000, Map());
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>("address.city"),
              SharedConstant(Value("San Francisco"))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc2));
}

TEST_F(NestedPropertiesPipelineTest, QuotedNestedPropertyFilterQuotedNested) {
  auto doc1 =
      Doc("users/a", 1000, Map("address.city", "San Francisco"));  // Match
  auto doc2 =
      Doc("users/b", 1000, Map("address", Map("city", "San Francisco")));
  auto doc3 = Doc("users/c", 1000, Map());
  PipelineInputOutputVector documents = {doc1, doc2, doc3};

  RealtimePipeline pipeline = StartPipeline("/users");
  // Use FieldPath constructor for field names containing dots
  pipeline = pipeline.AddingStage(std::make_shared<Where>(
      EqExpr({std::make_shared<Field>(FieldPath({"address.city"})),
              SharedConstant(Value("San Francisco"))})));

  EXPECT_THAT(RunPipeline(pipeline, documents), ElementsAre(doc1));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
