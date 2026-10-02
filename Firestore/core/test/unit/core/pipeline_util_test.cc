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

#include "Firestore/core/src/core/pipeline_util.h"

#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/realtime_pipeline.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/core/bound.h"
#include "Firestore/core/src/core/pipeline_run.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/core/target.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/test/unit/core/pipeline/utils.h"
#include "Firestore/core/test/unit/testutil/expression_test_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using api::Field;
using model::FieldPath;
using model::ResourcePath;

// Helper to create a core::Query
core::Query TestCoreQuery(const std::string& path_str) {
  return core::Query(ResourcePath::FromString(path_str));
}

// Helper to create a core::Target (from a Query)
core::Target TestCoreTarget(const std::string& path_str) {
  return TestCoreQuery(path_str).ToTarget();
}

api::RealtimePipeline StartPipeline(
    const std::string& collection_path) {  // Return RealtimePipeline
  std::vector<std::shared_ptr<api::EvaluableStage>>
      stages;  // Use EvaluableStage
  stages.push_back(std::make_shared<api::CollectionSource>(collection_path));
  return api::RealtimePipeline(std::move(stages),
                               TestSerializer());  // Construct RealtimePipeline
}

// Helper to create a simple api::RealtimePipeline
api::RealtimePipeline TestPipeline(int id) {
  auto pipeline = StartPipeline("coll");
  if (id == 1) {
    pipeline = pipeline.AddingStage(
        std::make_shared<api::Where>(testutil::NotExpr(testutil::GtExpr(
            {std::make_shared<Field>("score"),
             testutil::SharedConstant(testutil::Value(90LL))}))));
  } else if (id == 2) {
    pipeline = pipeline.AddingStage(
        std::make_shared<api::Where>(testutil::NotExpr(testutil::LtExpr(
            {std::make_shared<Field>("score"),
             testutil::SharedConstant(testutil::Value(90LL))}))));
  } else if (id == 3) {  // Same as id 1
    pipeline = pipeline.AddingStage(
        std::make_shared<api::Where>(testutil::NotExpr(testutil::GtExpr(
            {std::make_shared<Field>("score"),
             testutil::SharedConstant(testutil::Value(90LL))}))));
  }
  return pipeline;
}

TEST(PipelineUtilTest, QueryOrPipelineEquality) {
  core::Query q1 = TestCoreQuery("coll/doc1");
  core::Query q2 = TestCoreQuery("coll/doc1");  // Same as q1
  core::Query q3 = TestCoreQuery("coll/doc2");  // Different from q1
  api::RealtimePipeline p1 = TestPipeline(1);
  api::RealtimePipeline p2 = TestPipeline(3);  // Same as p1
  api::RealtimePipeline p3 = TestPipeline(2);  // Different from p1

  QueryOrPipeline qop_q1(q1);
  QueryOrPipeline qop_q2(q2);
  QueryOrPipeline qop_q3(q3);
  QueryOrPipeline qop_p1(p1);
  QueryOrPipeline qop_p2(p2);
  QueryOrPipeline qop_p3(p3);
  QueryOrPipeline default_qop1;
  QueryOrPipeline default_qop2;
  QueryOrPipeline qop_default_query(core::Query{});

  EXPECT_EQ(qop_q1, qop_q2);
  EXPECT_NE(qop_q1, qop_q3);
  EXPECT_NE(qop_q1, qop_p1);  // Query vs Pipeline
  EXPECT_EQ(qop_p1, qop_p2);
  EXPECT_NE(qop_p1, qop_p3);

  EXPECT_EQ(default_qop1, default_qop2);
  EXPECT_EQ(default_qop1, qop_default_query);
  EXPECT_NE(default_qop1, qop_q1);
}

TEST(PipelineUtilTest, QueryOrPipelineHashing) {
  core::Query q1 = TestCoreQuery("coll/doc1");
  core::Query q2 = TestCoreQuery("coll/doc1");
  core::Query q3 = TestCoreQuery("coll/doc2");
  api::RealtimePipeline p1 = TestPipeline(1);
  api::RealtimePipeline p2 = TestPipeline(3);
  api::RealtimePipeline p3 = TestPipeline(2);

  QueryOrPipeline qop_q1(q1);
  QueryOrPipeline qop_q2(q2);
  QueryOrPipeline qop_q3(q3);
  QueryOrPipeline qop_p1(p1);
  QueryOrPipeline qop_p2(p2);
  QueryOrPipeline qop_p3(p3);
  QueryOrPipeline default_qop1;
  QueryOrPipeline qop_default_query(core::Query{});

  std::hash<QueryOrPipeline> hasher;
  EXPECT_EQ(hasher(qop_q1), hasher(qop_q2));
  EXPECT_EQ(qop_q1.Hash(), qop_q2.Hash());

  // Note: Hashes are not guaranteed to be different for different objects,
  // but they should be for the ones we construct here.
  EXPECT_NE(hasher(qop_q1), hasher(qop_q3));
  EXPECT_NE(qop_q1.Hash(), qop_q3.Hash());

  EXPECT_NE(hasher(qop_q1), hasher(qop_p1));
  EXPECT_NE(qop_q1.Hash(), qop_p1.Hash());

  EXPECT_EQ(hasher(qop_p1), hasher(qop_p2));
  EXPECT_EQ(qop_p1.Hash(), qop_p2.Hash());

  EXPECT_NE(hasher(qop_p1), hasher(qop_p3));
  EXPECT_NE(qop_p1.Hash(), qop_p3.Hash());

  EXPECT_EQ(hasher(default_qop1), hasher(QueryOrPipeline(core::Query{})));
  EXPECT_EQ(default_qop1.Hash(), QueryOrPipeline(core::Query{}).Hash());
}

TEST(PipelineUtilTest, QueryOrPipelineInUnorderedMap) {
  std::unordered_map<QueryOrPipeline, int> map;
  core::Query q_a = TestCoreQuery("coll/docA");
  api::RealtimePipeline p_a = TestPipeline(1);  // Unique pipeline A
  core::Query q_b = TestCoreQuery("coll/docB");
  api::RealtimePipeline p_b = TestPipeline(2);  // Unique pipeline B

  QueryOrPipeline key_q_a(q_a);
  QueryOrPipeline key_p_a(p_a);

  map[key_q_a] = 100;
  map[key_p_a] = 200;

  ASSERT_EQ(map.size(), 2);
  EXPECT_EQ(map.at(key_q_a), 100);
  EXPECT_EQ(map.at(QueryOrPipeline(TestCoreQuery("coll/docA"))), 100);
  EXPECT_EQ(map.at(key_p_a), 200);
  EXPECT_EQ(map.at(QueryOrPipeline(TestPipeline(1))),
            200);  // TestPipeline(1) is same as p_a

  EXPECT_EQ(map.count(QueryOrPipeline(q_b)), 0);
  EXPECT_EQ(map.count(QueryOrPipeline(p_b)), 0);
  EXPECT_EQ(map.count(QueryOrPipeline(TestCoreQuery("coll/nonexistent"))), 0);
  EXPECT_EQ(map.count(QueryOrPipeline(TestPipeline(0))), 0);  // Empty pipeline
}

TEST(PipelineUtilTest, TargetOrPipelineEquality) {
  core::Target t1 = TestCoreTarget("coll/doc1");
  core::Target t2 = TestCoreTarget("coll/doc1");  // Same as t1
  core::Target t3 = TestCoreTarget("coll/doc2");  // Different from t1
  api::RealtimePipeline p1 = TestPipeline(1);
  api::RealtimePipeline p2 = TestPipeline(3);  // Same as p1
  api::RealtimePipeline p3 = TestPipeline(2);  // Different from p1

  TargetOrPipeline top_t1(t1);
  TargetOrPipeline top_t2(t2);
  TargetOrPipeline top_t3(t3);
  TargetOrPipeline top_p1(p1);
  TargetOrPipeline top_p2(p2);
  TargetOrPipeline top_p3(p3);
  TargetOrPipeline default_top1;
  TargetOrPipeline default_top2;
  TargetOrPipeline top_default_target(core::Target{});

  EXPECT_EQ(top_t1, top_t2);
  EXPECT_NE(top_t1, top_t3);
  EXPECT_NE(top_t1, top_p1);  // Target vs Pipeline
  EXPECT_EQ(top_p1, top_p2);
  EXPECT_NE(top_p1, top_p3);

  EXPECT_EQ(default_top1, default_top2);
  EXPECT_EQ(default_top1, top_default_target);
  EXPECT_NE(default_top1, top_t1);
}

TEST(PipelineUtilTest, TargetOrPipelineHashing) {
  core::Target t1 = TestCoreTarget("coll/doc1");
  core::Target t2 = TestCoreTarget("coll/doc1");
  core::Target t3 = TestCoreTarget("coll/doc2");
  api::RealtimePipeline p1 = TestPipeline(1);
  api::RealtimePipeline p2 = TestPipeline(3);
  api::RealtimePipeline p3 = TestPipeline(2);

  TargetOrPipeline top_t1(t1);
  TargetOrPipeline top_t2(t2);
  TargetOrPipeline top_t3(t3);
  TargetOrPipeline top_p1(p1);
  TargetOrPipeline top_p2(p2);
  TargetOrPipeline top_p3(p3);
  TargetOrPipeline default_top1;

  std::hash<TargetOrPipeline> hasher;
  EXPECT_EQ(hasher(top_t1), hasher(top_t2));
  EXPECT_EQ(top_t1.Hash(), top_t2.Hash());

  EXPECT_NE(hasher(top_t1), hasher(top_t3));
  EXPECT_NE(top_t1.Hash(), top_t3.Hash());

  EXPECT_NE(hasher(top_t1), hasher(top_p1));
  EXPECT_NE(top_t1.Hash(), top_p1.Hash());

  EXPECT_EQ(hasher(top_p1), hasher(top_p2));
  EXPECT_EQ(top_p1.Hash(), top_p2.Hash());

  EXPECT_NE(hasher(top_p1), hasher(top_p3));
  EXPECT_NE(top_p1.Hash(), top_p3.Hash());

  EXPECT_EQ(hasher(default_top1), hasher(TargetOrPipeline(core::Target{})));
  EXPECT_EQ(default_top1.Hash(), TargetOrPipeline(core::Target{}).Hash());
}

TEST(PipelineUtilTest, TargetOrPipelineInUnorderedMap) {
  std::unordered_map<TargetOrPipeline, int> map;
  core::Target t_x = TestCoreTarget("coll/docX");
  api::RealtimePipeline p_x =
      TestPipeline(1);  // Unique pipeline X (same as p_a before)
  core::Target t_y = TestCoreTarget("coll/docY");
  api::RealtimePipeline p_y =
      TestPipeline(2);  // Unique pipeline Y (same as p_b before)

  TargetOrPipeline key_t_x(t_x);
  TargetOrPipeline key_p_x(p_x);

  map[key_t_x] = 300;
  map[key_p_x] = 400;

  ASSERT_EQ(map.size(), 2);
  EXPECT_EQ(map.at(key_t_x), 300);
  EXPECT_EQ(map.at(TargetOrPipeline(TestCoreTarget("coll/docX"))), 300);
  EXPECT_EQ(map.at(key_p_x), 400);
  EXPECT_EQ(map.at(TargetOrPipeline(TestPipeline(1))), 400);

  EXPECT_EQ(map.count(TargetOrPipeline(t_y)), 0);
  EXPECT_EQ(map.count(TargetOrPipeline(p_y)), 0);
  EXPECT_EQ(map.count(TargetOrPipeline(TestCoreTarget("coll/nonexistent"))), 0);
  EXPECT_EQ(map.count(TargetOrPipeline(TestPipeline(0))), 0);  // Empty pipeline
}

namespace {

using model::PipelineInputOutputVector;

// Documents sorted by (a, b, __name__), which is also their order by
// (a, __name__) and by __name__ alone.
PipelineInputOutputVector CursorTestDocs() {
  return {testutil::Doc("k/1", 1000, testutil::Map("a", 1, "b", 1)),
          testutil::Doc("k/2", 1000, testutil::Map("a", 2, "b", 1)),
          testutil::Doc("k/3", 1000, testutil::Map("a", 2, "b", 2)),
          testutil::Doc("k/4", 1000, testutil::Map("a", 2, "b", 2)),
          testutil::Doc("k/5", 1000, testutil::Map("a", 3, "b", 1))};
}

// Returns a reference value for `path` in the database of TestSerializer(),
// which is the value that pipelines evaluate `__name__` to.
nanopb::Message<google_firestore_v1_Value> KeyRef(absl::string_view path) {
  return testutil::Ref("test-project", path);
}

// Converts `query` to pipeline stages and runs them over `documents`.
PipelineInputOutputVector RunQueryAsPipeline(
    const core::Query& query, const PipelineInputOutputVector& documents) {
  api::RealtimePipeline pipeline(ToPipelineStages(query), TestSerializer());
  return RunPipeline(pipeline, documents);
}

// Returns the `documents` (which must be in query order) that `query` matches.
PipelineInputOutputVector QueryMatches(
    const core::Query& query, const PipelineInputOutputVector& documents) {
  PipelineInputOutputVector result;
  for (const auto& doc : documents) {
    if (query.Matches(doc)) {
      result.push_back(doc);
    }
  }
  return result;
}

}  // namespace

TEST(PipelineUtilTest, ToPipelineStagesInclusiveBoundsWithDocumentKeyCursor) {
  // A document snapshot cursor has a value for every normalized ordering,
  // including the implicit `__name__` ordering.
  PipelineInputOutputVector docs = CursorTestDocs();
  core::Query query =
      testutil::Query("k").AddingOrderBy(testutil::OrderBy("a"));

  core::Query start_at = query.StartingAt(
      Bound::FromValue(testutil::Array(2, KeyRef("k/3")), /*inclusive=*/true));
  EXPECT_THAT(
      RunQueryAsPipeline(start_at, docs),
      ReturnsDocs(PipelineInputOutputVector{docs[2], docs[3], docs[4]}));

  core::Query end_at = query.EndingAt(
      Bound::FromValue(testutil::Array(2, KeyRef("k/3")), /*inclusive=*/true));
  EXPECT_THAT(
      RunQueryAsPipeline(end_at, docs),
      ReturnsDocs(PipelineInputOutputVector{docs[0], docs[1], docs[2]}));
}

TEST(PipelineUtilTest, ToPipelineStagesInclusiveBoundsWithPartialCursor) {
  PipelineInputOutputVector docs = CursorTestDocs();
  core::Query query = testutil::Query("k")
                          .AddingOrderBy(testutil::OrderBy("a"))
                          .AddingOrderBy(testutil::OrderBy("b"));

  core::Query start_at = query.StartingAt(
      Bound::FromValue(testutil::Array(2), /*inclusive=*/true));
  EXPECT_THAT(RunQueryAsPipeline(start_at, docs),
              ReturnsDocs(PipelineInputOutputVector{docs[1], docs[2], docs[3],
                                                    docs[4]}));

  core::Query end_at =
      query.EndingAt(Bound::FromValue(testutil::Array(2), /*inclusive=*/true));
  EXPECT_THAT(RunQueryAsPipeline(end_at, docs),
              ReturnsDocs(PipelineInputOutputVector{docs[0], docs[1], docs[2],
                                                    docs[3]}));
}

TEST(PipelineUtilTest, ToPipelineStagesInclusiveBoundsOnDocumentKeyOnly) {
  PipelineInputOutputVector docs = CursorTestDocs();
  core::Query query = testutil::Query("k");

  core::Query start_at = query.StartingAt(
      Bound::FromValue(testutil::Array(KeyRef("k/3")), /*inclusive=*/true));
  EXPECT_THAT(
      RunQueryAsPipeline(start_at, docs),
      ReturnsDocs(PipelineInputOutputVector{docs[2], docs[3], docs[4]}));

  core::Query end_at = query.EndingAt(
      Bound::FromValue(testutil::Array(KeyRef("k/3")), /*inclusive=*/true));
  EXPECT_THAT(
      RunQueryAsPipeline(end_at, docs),
      ReturnsDocs(PipelineInputOutputVector{docs[0], docs[1], docs[2]}));
}

TEST(PipelineUtilTest, ToPipelineStagesCursorsMatchQuerySemantics) {
  PipelineInputOutputVector docs = CursorTestDocs();
  core::Query by_key = testutil::Query("k");
  core::Query by_a = by_key.AddingOrderBy(testutil::OrderBy("a"));
  core::Query by_a_b = by_a.AddingOrderBy(testutil::OrderBy("b"));

  std::vector<std::pair<core::Query, Bound>> cursors;
  for (bool inclusive : {true, false}) {
    cursors.emplace_back(
        by_key, Bound::FromValue(testutil::Array(KeyRef("k/3")), inclusive));
    cursors.emplace_back(by_a, Bound::FromValue(testutil::Array(2), inclusive));
    cursors.emplace_back(
        by_a, Bound::FromValue(testutil::Array(2, KeyRef("k/3")), inclusive));
    cursors.emplace_back(by_a_b,
                         Bound::FromValue(testutil::Array(2), inclusive));
    cursors.emplace_back(by_a_b,
                         Bound::FromValue(testutil::Array(2, 2), inclusive));
    cursors.emplace_back(
        by_a_b,
        Bound::FromValue(testutil::Array(2, 2, KeyRef("k/4")), inclusive));
  }

  for (const auto& cursor : cursors) {
    core::Query start_at = cursor.first.StartingAt(cursor.second);
    EXPECT_THAT(RunQueryAsPipeline(start_at, docs),
                ReturnsDocs(QueryMatches(start_at, docs)))
        << start_at.ToString();

    core::Query end_at = cursor.first.EndingAt(cursor.second);
    EXPECT_THAT(RunQueryAsPipeline(end_at, docs),
                ReturnsDocs(QueryMatches(end_at, docs)))
        << end_at.ToString();
  }
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
