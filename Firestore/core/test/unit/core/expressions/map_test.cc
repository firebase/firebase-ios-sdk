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
#include <vector>

#include "Firestore/core/src/api/expressions.h"  // For api::Expr, api::MapGet
#include "Firestore/core/src/core/expressions_eval.h"
#include "Firestore/core/src/model/value_util.h"  // For value constants
#include "Firestore/core/test/unit/testutil/expression_test_util.h"  // For test helpers
#include "Firestore/core/test/unit/testutil/testutil.h"  // For test helpers like Value, Map
#include "gmock/gmock.h"  // For matchers like Returns
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using api::Expr;
// using api::MapGet; // Removed incorrect using
using api::FunctionExpr;  // Added for creating map_get
using testutil::EvaluateExpr;
using testutil::Map;
using testutil::Returns;
using testutil::ReturnsError;
using testutil::ReturnsUnset;
using testutil::SharedConstant;
using testutil::Value;

// Fixture for MapGet function tests
class MapGetTest : public ::testing::Test {};

// Helper to create a MapGet expression
inline std::shared_ptr<Expr> MapGetExpr(std::shared_ptr<Expr> map_expr,
                                        std::shared_ptr<Expr> key_expr) {
  return std::make_shared<FunctionExpr>(
      "map_get", std::vector<std::shared_ptr<Expr>>{std::move(map_expr),
                                                    std::move(key_expr)});
}

TEST_F(MapGetTest, GetExistingKeyReturnsValue) {
  auto map_expr =
      SharedConstant(Map("a", Value(1LL), "b", Value(2LL), "c", Value(3LL)));
  auto key_expr = SharedConstant("b");
  EXPECT_THAT(EvaluateExpr(*MapGetExpr(map_expr, key_expr)),
              Returns(Value(2LL)));
}

TEST_F(MapGetTest, GetMissingKeyReturnsUnset) {
  auto map_expr =
      SharedConstant(Map("a", Value(1LL), "b", Value(2LL), "c", Value(3LL)));
  auto key_expr = SharedConstant("d");
  EXPECT_THAT(EvaluateExpr(*MapGetExpr(map_expr, key_expr)), ReturnsUnset());
}

TEST_F(MapGetTest, GetEmptyMapReturnsUnset) {
  auto map_expr = SharedConstant(Map());
  auto key_expr = SharedConstant("d");
  EXPECT_THAT(EvaluateExpr(*MapGetExpr(map_expr, key_expr)), ReturnsUnset());
}

TEST_F(MapGetTest, GetWrongMapTypeReturnsError) {
  auto map_expr =
      SharedConstant("not a map");  // Pass a string instead of a map
  auto key_expr = SharedConstant("d");
  EXPECT_THAT(EvaluateExpr(*MapGetExpr(map_expr, key_expr)), ReturnsError());
}

TEST_F(MapGetTest, GetWrongKeyTypeReturnsError) {
  auto map_expr = SharedConstant(Map());
  auto key_expr = SharedConstant(false);
  EXPECT_THAT(EvaluateExpr(*MapGetExpr(map_expr, key_expr)), ReturnsError());
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
