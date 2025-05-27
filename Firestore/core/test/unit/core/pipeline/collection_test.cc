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
#include <utility>

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/api/realtime_pipeline.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/core/expressions_eval.h"
#include "Firestore/core/src/core/firestore_client.h"
#include "Firestore/core/src/core/pipeline_run.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/remote/firebase_metadata_provider.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "google/firestore/v1/document.nanopb.h"

#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {

namespace {

template <typename T, typename Q>
api::FunctionExpr Eql(T lhs, Q rhs) {
  return api::FunctionExpr(
      "eq", {std::make_shared<T>(lhs), std::make_shared<Q>(rhs)});
}

api::Constant ConstantF(int value) {
  google_firestore_v1_Value result;
  result.which_value_type = google_firestore_v1_Value_integer_value_tag;
  result.integer_value = value;
  return api::Constant(nanopb::MakeSharedMessage(std::move(result)));
}

auto serializer = remote::Serializer(model::DatabaseId("test-project"));

}  // namespace

namespace core {

using testutil::Doc;
using testutil::Map;

TEST(Collection, Basic) {
  auto ppl = api::RealtimePipeline({}, serializer)
                 .AddingStage(std::make_shared<api::CollectionSource>("foo"))
                 .AddingStage(std::make_shared<api::Where>(
                     std::make_shared<api::FunctionExpr>(
                         Eql(api::Field("bar"), ConstantF(42)))));

  auto doc1 = Doc("foo/1", 0, Map("bar", 42));
  auto doc2 = Doc("foo/2", 0, Map("bar", "43"));
  auto doc3 = Doc("xxx/1", 0, Map("bar", 42));

  const auto results = RunPipeline(ppl, {doc1, doc2, doc3});

  auto x = results.size();
  EXPECT_EQ(x, 1);
  // EXPECT_THAT(RunPipeline(ppl, {doc1, doc2, doc3}), Returns({doc1}));
}

}  //  namespace core
}  //  namespace firestore
}  //  namespace firebase
