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

#include "Firestore/core/src/api/expressions.h"  // For api::Expr
#include "Firestore/core/src/core/expressions_eval.h"
#include "Firestore/core/src/model/value_util.h"  // For value constants
#include "Firestore/core/test/unit/testutil/expression_test_util.h"  // For test helpers
#include "Firestore/core/test/unit/testutil/testutil.h"  // For test helpers like Value, Map, Doc
#include "gmock/gmock.h"  // For matchers like Returns
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using testutil::Doc;
using testutil::EvaluateExpr;
using testutil::Map;
using testutil::Returns;
using testutil::ReturnsUnset;
using testutil::Value;

// Fixture for Field expression tests
class FieldTest : public ::testing::Test {};

// --- Field Tests ---

TEST_F(FieldTest, CanGetField) {
  // Create a document with the field "exists" set to true.
  auto doc_with_field = Doc("coll/doc1", 1, Map("exists", Value(true)));
  auto field_expr = std::make_shared<api::Field>("exists");
  EXPECT_THAT(EvaluateExpr(*field_expr, doc_with_field), Returns(Value(true)));
}

TEST_F(FieldTest, ReturnsUnsetIfNotFound) {
  auto field_expr = std::make_shared<api::Field>("not-exists");
  EXPECT_THAT(EvaluateExpr(*field_expr), ReturnsUnset());
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
