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
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/core/expressions_eval.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "google/firestore/v1/document.nanopb.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {

namespace {

template <typename T, typename Q>
api::FunctionExpr eq(T lhs, Q rhs) {
  return api::FunctionExpr(
      "eq", {std::make_shared<T>(lhs), std::make_shared<Q>(rhs)});
}

api::Constant constant(int value) {
  google_firestore_v1_Value result;
  result.which_value_type = google_firestore_v1_Value_integer_value_tag;
  result.integer_value = value;
  return api::Constant(nanopb::MakeSharedMessage(std::move(result)));
}

remote::Serializer serializer(model::DatabaseId("test-project"));

api::EvaluateContext NewContext() {
  return api::EvaluateContext{&serializer};
}

}  // namespace

namespace core {

using testutil::Doc;
using testutil::Map;

TEST(Eq, Basic) {
  auto result = eq(api::Field("foo"), constant(42))
                    .ToEvaluable()
                    ->Evaluate(NewContext(), Doc("docs/1", 0, Map("foo", 42)));

  ASSERT_TRUE(model::Equals(*result.value(), model::TrueValue()));
}

}  //  namespace core
}  //  namespace firestore
}  //  namespace firebase
