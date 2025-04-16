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

#include <initializer_list>
#include <limits>  // Required for quiet_NaN()
#include <memory>
#include <vector>

#include "Firestore/core/src/api/expressions.h"  // For api::Expr, api::Constant, api::Field
#include "Firestore/core/src/core/expressions_eval.h"
// #include "Firestore/core/src/model/field_value.h" // Removed incorrect
// include
#include "Firestore/core/src/model/value_util.h"  // For value constants like NullValue, NaNValue
#include "Firestore/core/test/unit/testutil/expression_test_util.h"  // For test helpers
#include "Firestore/core/test/unit/testutil/testutil.h"  // For test helpers like Value, Array, Map
#include "gmock/gmock.h"  // For matchers like Returns
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using api::Expr;
// using model::FieldValue; // Removed incorrect using declaration
using testutil::Array;
using testutil::ArrayContainsAllExpr;
using testutil::ArrayContainsAnyExpr;
using testutil::ArrayContainsExpr;
using testutil::ArrayLengthExpr;
using testutil::Constant;  // Use testutil::Constant for consistency
using testutil::EvaluateExpr;
using testutil::Field;
using testutil::Map;
using testutil::Returns;
using testutil::ReturnsError;
using testutil::ReturnsNull;
using testutil::ReturnsUnset;
using testutil::SharedConstant;
using testutil::Value;

// Fixture for ArrayContainsAll function tests
class ArrayContainsAllTest : public ::testing::Test {};

// Fixture for ArrayContainsAny function tests
class ArrayContainsAnyTest : public ::testing::Test {};

// Fixture for ArrayContains function tests
class ArrayContainsTest : public ::testing::Test {};

// Fixture for ArrayLength function tests
class ArrayLengthTest : public ::testing::Test {};

// --- ArrayContainsAll Tests ---

TEST_F(ArrayContainsAllTest, ContainsAll) {
  EXPECT_THAT(
      EvaluateExpr(*ArrayContainsAllExpr(
          {SharedConstant(Array(Value("1"), Value(42LL), Value(true),
                                Value("additional"), Value("values"),
                                Value("in"), Value("array"))),
           SharedConstant(Array(Value("1"), Value(42LL), Value(true)))})),
      Returns(Value(true)));
}

TEST_F(ArrayContainsAllTest, DoesNotContainAll) {
  EXPECT_THAT(EvaluateExpr(*ArrayContainsAllExpr(
                  {SharedConstant(Array(Value("1"), Value(42LL), Value(true))),
                   SharedConstant(Array(Value("1"), Value(99LL)))})),
              Returns(Value(false)));
}

TEST_F(ArrayContainsAllTest, EquivalentNumerics) {
  EXPECT_THAT(
      EvaluateExpr(*ArrayContainsAllExpr(
          {SharedConstant(Array(Value(42LL), Value(true), Value("additional"),
                                Value("values"), Value("in"), Value("array"))),
           SharedConstant(Array(Value(42.0), Value(true)))})),
      Returns(Value(true)));
}

TEST_F(ArrayContainsAllTest, ArrayToSearchIsEmpty) {
  EXPECT_THAT(EvaluateExpr(*ArrayContainsAllExpr(
                  {SharedConstant(Array()),
                   SharedConstant(Array(Value(42.0), Value(true)))})),
              Returns(Value(false)));
}

TEST_F(ArrayContainsAllTest, SearchValueIsEmpty) {
  EXPECT_THAT(EvaluateExpr(*ArrayContainsAllExpr(
                  {SharedConstant(Array(Value(42.0), Value(true))),
                   SharedConstant(Array())})),
              Returns(Value(true)));
}

TEST_F(ArrayContainsAllTest, SearchValueIsNaN) {
  // NaN comparison always returns false in Firestore
  EXPECT_THAT(
      EvaluateExpr(*ArrayContainsAllExpr(
          {SharedConstant(Array(Value(std::numeric_limits<double>::quiet_NaN()),
                                Value(42.0))),
           SharedConstant(
               Array(Value(std::numeric_limits<double>::quiet_NaN())))})),
      Returns(Value(false)));
}

TEST_F(ArrayContainsAllTest, SearchValueHasDuplicates) {
  EXPECT_THAT(
      EvaluateExpr(*ArrayContainsAllExpr(
          {SharedConstant(Array(Value(true), Value("hi"))),
           SharedConstant(Array(Value(true), Value(true), Value(true)))})),
      Returns(Value(true)));
}

TEST_F(ArrayContainsAllTest, ArrayToSearchIsEmptySearchValueIsEmpty) {
  EXPECT_THAT(EvaluateExpr(*ArrayContainsAllExpr(
                  {SharedConstant(Array()), SharedConstant(Array())})),
              Returns(Value(true)));
}

TEST_F(ArrayContainsAllTest, LargeNumberOfElements) {
  // Construct the array to search expression
  std::vector<nanopb::Message<google_firestore_v1_Value>>
      elements_to_search_vec;
  elements_to_search_vec.reserve(500);
  for (int i = 1; i <= 500; ++i) {
    elements_to_search_vec.push_back(Value(static_cast<int64_t>(i)));
  }
  auto array_to_search_expr =
      SharedConstant(model::ArrayValue(std::move(elements_to_search_vec)));

  // Construct the list of expressions to find
  std::vector<nanopb::Message<google_firestore_v1_Value>>
      elements_to_find_exprs;
  elements_to_find_exprs.reserve(500);
  for (int i = 1; i <= 500; ++i) {
    elements_to_find_exprs.push_back(Value(static_cast<int64_t>(i)));
  }
  auto elements_to_find_expr =
      SharedConstant(model::ArrayValue(std::move(elements_to_search_vec)));

  // Pass the combined vector to the helper
  EXPECT_THAT(EvaluateExpr(*ArrayContainsAllExpr(
                  {array_to_search_expr, elements_to_find_expr})),
              Returns(Value(true)));
}

// --- ArrayContainsAny Tests ---

TEST_F(ArrayContainsAnyTest, ValueFoundInArray) {
  auto array_to_search =
      SharedConstant(Array(Value(42LL), Value("matang"), Value(true)));
  EXPECT_THAT(EvaluateExpr(*ArrayContainsAnyExpr(
                  {array_to_search,
                   SharedConstant(Array(Value("matang"), Value(false)))})),
              Returns(Value(true)));
}

TEST_F(ArrayContainsAnyTest, EquivalentNumerics) {
  auto array_to_search =
      SharedConstant(Array(Value(42LL), Value("matang"), Value(true)));
  EXPECT_THAT(
      EvaluateExpr(*ArrayContainsAnyExpr(
          {array_to_search, SharedConstant(Array(Value(42.0), Value(2LL)))})),
      Returns(Value(true)));
}

TEST_F(ArrayContainsAnyTest, ValuesNotFoundInArray) {
  auto array_to_search =
      SharedConstant(Array(Value(42LL), Value("matang"), Value(true)));
  EXPECT_THAT(EvaluateExpr(*ArrayContainsAnyExpr(
                  {array_to_search,
                   SharedConstant(Array(Value(99LL), Value("false")))})),
              Returns(Value(false)));
}

TEST_F(ArrayContainsAnyTest, BothInputTypeIsArray) {
  auto array_to_search =
      SharedConstant(Array(Array(Value(1LL), Value(2LL), Value(3LL)),
                           Array(Value(4LL), Value(5LL), Value(6LL)),
                           Array(Value(7LL), Value(8LL), Value(9LL))));
  auto values_to_find =
      SharedConstant(Array(Array(Value(1LL), Value(2LL), Value(3LL)),
                           Array(Value(4LL), Value(5LL), Value(6LL))));
  EXPECT_THAT(
      EvaluateExpr(*ArrayContainsAnyExpr({array_to_search, values_to_find})),
      Returns(Value(true)));
}

TEST_F(ArrayContainsAnyTest, SearchIsNullReturnsNull) {
  auto array_to_search = SharedConstant(
      Array(Value(nullptr), Value(1LL), Value("matang"), Value(true)));
  EXPECT_THAT(EvaluateExpr(*ArrayContainsAnyExpr(
                  {array_to_search, SharedConstant(Array(Value(nullptr)))})),
              ReturnsNull());
}

TEST_F(ArrayContainsAnyTest, ArrayIsNotArrayTypeReturnsError) {
  EXPECT_THAT(EvaluateExpr(*ArrayContainsAnyExpr(
                  {SharedConstant("matang"),
                   SharedConstant(Array(Value("matang"), Value(false)))})),
              ReturnsError());
}

TEST_F(ArrayContainsAnyTest, SearchIsNotArrayTypeReturnsError) {
  EXPECT_THAT(EvaluateExpr(*ArrayContainsAnyExpr(
                  {SharedConstant(Array(Value("matang"), Value(false))),
                   SharedConstant("matang")})),
              ReturnsError());
}

TEST_F(ArrayContainsAnyTest, ArrayNotFoundReturnsError) {
  EXPECT_THAT(EvaluateExpr(*ArrayContainsAnyExpr(
                  {std::make_shared<api::Field>("not-exist"),
                   SharedConstant(Array(Value("matang"), Value(false)))})),
              ReturnsError());
}

TEST_F(ArrayContainsAnyTest, SearchNotFoundReturnsError) {
  auto array_to_search =
      SharedConstant(Array(Value(42LL), Value("matang"), Value(true)));
  EXPECT_THAT(
      EvaluateExpr(*ArrayContainsAnyExpr(
          {array_to_search, std::make_shared<api::Field>("not-exist")})),
      ReturnsError());
}

// --- ArrayContains Tests ---

TEST_F(ArrayContainsTest, ValueFoundInArray) {
  EXPECT_THAT(EvaluateExpr(*ArrayContainsExpr(
                  {SharedConstant(Array(Value("hello"), Value("world"))),
                   SharedConstant("hello")})),
              Returns(Value(true)));
}

TEST_F(ArrayContainsTest, ValueNotFoundInArray) {
  auto array_to_search =
      SharedConstant(Array(Value(42LL), Value("matang"), Value(true)));
  EXPECT_THAT(
      EvaluateExpr(*ArrayContainsExpr({array_to_search, SharedConstant(4LL)})),
      Returns(Value(false)));
}

// Note: `not` function is not directly available as an expression builder yet.
// TEST_F(ArrayContainsTest, NotArrayContainsFunctionValueNotFoundInArray) { ...
// }

TEST_F(ArrayContainsTest, EquivalentNumerics) {
  auto array_to_search =
      SharedConstant(Array(Value(42LL), Value("matang"), Value(true)));
  EXPECT_THAT(
      EvaluateExpr(*ArrayContainsExpr({array_to_search, SharedConstant(42.0)})),
      Returns(Value(true)));
}

TEST_F(ArrayContainsTest, BothInputTypeIsArray) {
  auto array_to_search =
      SharedConstant(Array(Array(Value(1LL), Value(2LL), Value(3LL)),
                           Array(Value(4LL), Value(5LL), Value(6LL)),
                           Array(Value(7LL), Value(8LL), Value(9LL))));
  auto value_to_find =
      SharedConstant(Array(Value(1LL), Value(2LL), Value(3LL)));
  EXPECT_THAT(
      EvaluateExpr(*ArrayContainsExpr({array_to_search, value_to_find})),
      Returns(Value(true)));
}

TEST_F(ArrayContainsTest, SearchValueIsNullReturnsNull) {
  auto array_to_search = SharedConstant(
      Array(Value(nullptr), Value(1LL), Value("matang"), Value(true)));
  EXPECT_THAT(EvaluateExpr(*ArrayContainsExpr(
                  {array_to_search, SharedConstant(nullptr)})),
              ReturnsNull());  // Null comparison returns Null
}

TEST_F(ArrayContainsTest, SearchValueIsNullEmptyValuesArrayReturnsNull) {
  EXPECT_THAT(EvaluateExpr(*ArrayContainsExpr(
                  {SharedConstant(Array()), SharedConstant(nullptr)})),
              ReturnsNull());  // Null comparison returns Null
}

TEST_F(ArrayContainsTest, SearchValueIsMap) {
  auto array_expr =
      SharedConstant(Array(Value(123LL), Map("foo", Value(123LL)),
                           Map("bar", Value(42LL)), Map("foo", Value(42LL))));
  auto map_expr = SharedConstant(Map("foo", Value(42LL)));
  EXPECT_THAT(EvaluateExpr(*ArrayContainsExpr({array_expr, map_expr})),
              Returns(Value(true)));
}

TEST_F(ArrayContainsTest, SearchValueIsNaN) {
  // NaN comparison always returns false
  auto array_expr = SharedConstant(
      Array(Value(std::numeric_limits<double>::quiet_NaN()), Value("foo")));
  auto nan_expr = SharedConstant(std::numeric_limits<double>::quiet_NaN());
  EXPECT_THAT(EvaluateExpr(*ArrayContainsExpr({array_expr, nan_expr})),
              Returns(Value(false)));
}

TEST_F(ArrayContainsTest, ArrayToSearchIsNotArrayTypeReturnsError) {
  EXPECT_THAT(EvaluateExpr(*ArrayContainsExpr(
                  {SharedConstant("matang"), SharedConstant("values")})),
              ReturnsError());
}

TEST_F(ArrayContainsTest, ArrayToSearchNotFoundReturnsError) {
  EXPECT_THAT(EvaluateExpr(
                  *ArrayContainsExpr({std::make_shared<api::Field>("not-exist"),
                                      SharedConstant("matang")})),
              ReturnsError());  // Field not found results in Unset
}

TEST_F(ArrayContainsTest, ArrayToSearchIsEmptyReturnsFalse) {
  EXPECT_THAT(EvaluateExpr(*ArrayContainsExpr(
                  {SharedConstant(Array()), SharedConstant("matang")})),
              Returns(Value(false)));
}

TEST_F(ArrayContainsTest, SearchValueReferenceNotFoundReturnsError) {
  auto array_to_search =
      SharedConstant(Array(Value(42LL), Value("matang"), Value(true)));
  EXPECT_THAT(
      EvaluateExpr(*ArrayContainsExpr(
          {array_to_search, std::make_shared<api::Field>("not-exist")})),
      ReturnsError());  // Field not found results in Unset
}

// --- ArrayLength Tests ---

TEST_F(ArrayLengthTest, Length) {
  EXPECT_THAT(EvaluateExpr(*ArrayLengthExpr({SharedConstant(
                  Array(Value("1"), Value(42LL), Value(true)))})),
              Returns(Value(3LL)));
}

TEST_F(ArrayLengthTest, EmptyArray) {
  EXPECT_THAT(EvaluateExpr(*ArrayLengthExpr({SharedConstant(Array())})),
              Returns(Value(0LL)));
}

TEST_F(ArrayLengthTest, ArrayWithDuplicateElements) {
  EXPECT_THAT(EvaluateExpr(*ArrayLengthExpr(
                  {SharedConstant(Array(Value(true), Value(true)))})),
              Returns(Value(2LL)));
}

TEST_F(ArrayLengthTest, NotArrayTypeReturnsError) {
  // VectorValue not directly supported as FieldValue yet.
  // Test with other non-array types.
  EXPECT_THAT(EvaluateExpr(*ArrayLengthExpr({SharedConstant("notAnArray")})),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*ArrayLengthExpr({SharedConstant(123LL)})),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*ArrayLengthExpr({SharedConstant(true)})),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*ArrayLengthExpr({SharedConstant(Map())})),
              ReturnsError());
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
