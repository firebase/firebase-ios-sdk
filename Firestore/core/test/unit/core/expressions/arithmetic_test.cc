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
#include <limits>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/core/expressions_eval.h"
#include "Firestore/core/test/unit/testutil/expression_test_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using api::Expr;
using model::MutableDocument;  // Used as PipelineInputOutput alias
using testing::_;
using testutil::AddExpr;
using testutil::DivideExpr;
using testutil::EvaluateExpr;
using testutil::ModExpr;
using testutil::MultiplyExpr;
using testutil::Returns;
using testutil::ReturnsError;
using testutil::SharedConstant;
using testutil::SubtractExpr;
using testutil::Value;

// Base fixture for common setup (if needed later)
class ArithmeticExpressionsTest : public ::testing::Test {};

// Fixture for Add function tests
class AddFunctionTest : public ArithmeticExpressionsTest {};

// Fixture for Subtract function tests
class SubtractFunctionTest : public ArithmeticExpressionsTest {};

// Fixture for Multiply function tests
class MultiplyFunctionTest : public ArithmeticExpressionsTest {};

// Fixture for Divide function tests
class DivideFunctionTest : public ArithmeticExpressionsTest {};

// Fixture for Mod function tests
class ModFunctionTest : public ArithmeticExpressionsTest {};

// --- Add Tests ---

TEST_F(AddFunctionTest, BasicNumerics) {
  EXPECT_THAT(
      EvaluateExpr(*AddExpr({SharedConstant(1LL), SharedConstant(2LL)})),
      Returns(Value(3LL)));
  EXPECT_THAT(
      EvaluateExpr(*AddExpr({SharedConstant(1LL), SharedConstant(2.5)})),
      Returns(Value(3.5)));
  EXPECT_THAT(
      EvaluateExpr(*AddExpr({SharedConstant(1.0), SharedConstant(2LL)})),
      Returns(Value(3.0)));
  EXPECT_THAT(
      EvaluateExpr(*AddExpr({SharedConstant(1.0), SharedConstant(2.0)})),
      Returns(Value(3.0)));
}

TEST_F(AddFunctionTest, BasicNonNumerics) {
  EXPECT_THAT(
      EvaluateExpr(*AddExpr({SharedConstant(1LL), SharedConstant("1")})),
      ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*AddExpr({SharedConstant("1"), SharedConstant(1.0)})),
      ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*AddExpr({SharedConstant("1"), SharedConstant("1")})),
      ReturnsError());
}

TEST_F(AddFunctionTest, DoubleLongAdditionOverflow) {
  // Note: C++ double can represent Long.MAX_VALUE + 1.0 exactly, unlike some JS
  // representations.
  EXPECT_THAT(EvaluateExpr(*AddExpr({SharedConstant(9223372036854775807LL),
                                     SharedConstant(1.0)})),
              Returns(Value(9.223372036854776e+18)));
  EXPECT_THAT(EvaluateExpr(*AddExpr({SharedConstant(9.223372036854776e+18),
                                     SharedConstant(100LL)})),
              Returns(Value(9.223372036854776e+18 + 100.0)));
}

TEST_F(AddFunctionTest, DoubleAdditionOverflow) {
  EXPECT_THAT(EvaluateExpr(*AddExpr(
                  {SharedConstant(std::numeric_limits<double>::max()),
                   SharedConstant(std::numeric_limits<double>::max())})),
              Returns(Value(std::numeric_limits<double>::infinity())));
  EXPECT_THAT(EvaluateExpr(*AddExpr(
                  {SharedConstant(-std::numeric_limits<double>::max()),
                   SharedConstant(-std::numeric_limits<double>::max())})),
              Returns(Value(-std::numeric_limits<double>::infinity())));
}

TEST_F(AddFunctionTest, SumPosAndNegInfinityReturnNaN) {
  EXPECT_THAT(EvaluateExpr(*AddExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(-std::numeric_limits<double>::infinity())})),
              Returns(Value(std::numeric_limits<double>::quiet_NaN())));
}

TEST_F(AddFunctionTest, LongAdditionOverflow) {
  EXPECT_THAT(EvaluateExpr(
                  *AddExpr({SharedConstant(std::numeric_limits<int64_t>::max()),
                            SharedConstant(1LL)})),
              ReturnsError());  // Expect error due to overflow
  EXPECT_THAT(EvaluateExpr(
                  *AddExpr({SharedConstant(std::numeric_limits<int64_t>::min()),
                            SharedConstant(-1LL)})),
              ReturnsError());  // Expect error due to overflow
  EXPECT_THAT(EvaluateExpr(*AddExpr(
                  {SharedConstant(1LL),
                   SharedConstant(std::numeric_limits<int64_t>::max())})),
              ReturnsError());  // Expect error due to overflow
}

TEST_F(AddFunctionTest, NanNumberReturnNaN) {
  double nan_val = std::numeric_limits<double>::quiet_NaN();
  EXPECT_THAT(
      EvaluateExpr(*AddExpr({SharedConstant(1LL), SharedConstant(nan_val)})),
      Returns(Value(nan_val)));
  EXPECT_THAT(
      EvaluateExpr(*AddExpr({SharedConstant(1.0), SharedConstant(nan_val)})),
      Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*AddExpr({SharedConstant(9007199254740991LL),
                                     SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*AddExpr({SharedConstant(-9007199254740991LL),
                                     SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(
      EvaluateExpr(*AddExpr({SharedConstant(std::numeric_limits<double>::max()),
                             SharedConstant(nan_val)})),
      Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*AddExpr(
                  {SharedConstant(std::numeric_limits<double>::lowest()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*AddExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*AddExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
}

TEST_F(AddFunctionTest, NanNotNumberTypeReturnError) {
  EXPECT_THAT(EvaluateExpr(*AddExpr(
                  {SharedConstant(std::numeric_limits<double>::quiet_NaN()),
                   SharedConstant("hello world")})),
              ReturnsError());
}

TEST_F(AddFunctionTest, MultiArgument) {
  // EvaluateExpr handles single expression, so nest calls for multi-arg
  auto add12 = AddExpr({SharedConstant(1LL), SharedConstant(2LL)});
  EXPECT_THAT(EvaluateExpr(*AddExpr({add12, SharedConstant(3LL)})),
              Returns(Value(6LL)));

  auto add10_2 = AddExpr({SharedConstant(1.0), SharedConstant(2LL)});
  EXPECT_THAT(EvaluateExpr(*AddExpr({add10_2, SharedConstant(3LL)})),
              Returns(Value(6.0)));
}

// --- Subtract Tests ---

TEST_F(SubtractFunctionTest, BasicNumerics) {
  EXPECT_THAT(
      EvaluateExpr(*SubtractExpr({SharedConstant(1LL), SharedConstant(2LL)})),
      Returns(Value(-1LL)));
  EXPECT_THAT(
      EvaluateExpr(*SubtractExpr({SharedConstant(1LL), SharedConstant(2.5)})),
      Returns(Value(-1.5)));
  EXPECT_THAT(
      EvaluateExpr(*SubtractExpr({SharedConstant(1.0), SharedConstant(2LL)})),
      Returns(Value(-1.0)));
  EXPECT_THAT(
      EvaluateExpr(*SubtractExpr({SharedConstant(1.0), SharedConstant(2.0)})),
      Returns(Value(-1.0)));
}

TEST_F(SubtractFunctionTest, BasicNonNumerics) {
  EXPECT_THAT(
      EvaluateExpr(*SubtractExpr({SharedConstant(1LL), SharedConstant("1")})),
      ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*SubtractExpr({SharedConstant("1"), SharedConstant(1.0)})),
      ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*SubtractExpr({SharedConstant("1"), SharedConstant("1")})),
      ReturnsError());
}

TEST_F(SubtractFunctionTest, DoubleSubtractionOverflow) {
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(-std::numeric_limits<double>::max()),
                   SharedConstant(std::numeric_limits<double>::max())})),
              Returns(Value(-std::numeric_limits<double>::infinity())));
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(std::numeric_limits<double>::max()),
                   SharedConstant(-std::numeric_limits<double>::max())})),
              Returns(Value(std::numeric_limits<double>::infinity())));
}

TEST_F(SubtractFunctionTest, LongSubtractionOverflow) {
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(std::numeric_limits<int64_t>::min()),
                   SharedConstant(1LL)})),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(std::numeric_limits<int64_t>::max()),
                   SharedConstant(-1LL)})),
              ReturnsError());
}

TEST_F(SubtractFunctionTest, NanNumberReturnNaN) {
  double nan_val = std::numeric_limits<double>::quiet_NaN();
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(1LL), SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(1.0), SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*SubtractExpr({SharedConstant(9007199254740991LL),
                                          SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*SubtractExpr({SharedConstant(-9007199254740991LL),
                                          SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(std::numeric_limits<double>::max()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(std::numeric_limits<double>::lowest()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
}

TEST_F(SubtractFunctionTest, NanNotNumberTypeReturnError) {
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(std::numeric_limits<double>::quiet_NaN()),
                   SharedConstant("hello world")})),
              ReturnsError());
}

TEST_F(SubtractFunctionTest, PositiveInfinity) {
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(1LL)})),
              Returns(Value(std::numeric_limits<double>::infinity())));
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(1LL),
                   SharedConstant(std::numeric_limits<double>::infinity())})),
              Returns(Value(-std::numeric_limits<double>::infinity())));
}

TEST_F(SubtractFunctionTest, NegativeInfinity) {
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(1LL)})),
              Returns(Value(-std::numeric_limits<double>::infinity())));
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(1LL),
                   SharedConstant(-std::numeric_limits<double>::infinity())})),
              Returns(Value(std::numeric_limits<double>::infinity())));
}

TEST_F(SubtractFunctionTest, PositiveInfinityNegativeInfinity) {
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(-std::numeric_limits<double>::infinity())})),
              Returns(Value(std::numeric_limits<double>::infinity())));
  EXPECT_THAT(EvaluateExpr(*SubtractExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(std::numeric_limits<double>::infinity())})),
              Returns(Value(-std::numeric_limits<double>::infinity())));
}

// --- Multiply Tests ---

TEST_F(MultiplyFunctionTest, BasicNumerics) {
  EXPECT_THAT(
      EvaluateExpr(*MultiplyExpr({SharedConstant(1LL), SharedConstant(2LL)})),
      Returns(Value(2LL)));
  EXPECT_THAT(
      EvaluateExpr(*MultiplyExpr({SharedConstant(3LL), SharedConstant(2.5)})),
      Returns(Value(7.5)));
  EXPECT_THAT(
      EvaluateExpr(*MultiplyExpr({SharedConstant(1.0), SharedConstant(2LL)})),
      Returns(Value(2.0)));
  EXPECT_THAT(
      EvaluateExpr(*MultiplyExpr({SharedConstant(1.32), SharedConstant(2.0)})),
      Returns(Value(2.64)));
}

TEST_F(MultiplyFunctionTest, BasicNonNumerics) {
  EXPECT_THAT(
      EvaluateExpr(*MultiplyExpr({SharedConstant(1LL), SharedConstant("1")})),
      ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*MultiplyExpr({SharedConstant("1"), SharedConstant(1.0)})),
      ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*MultiplyExpr({SharedConstant("1"), SharedConstant("1")})),
      ReturnsError());
}

TEST_F(MultiplyFunctionTest, DoubleLongMultiplicationOverflow) {
  // C++ double handles this fine
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr({SharedConstant(9223372036854775807LL),
                                          SharedConstant(100.0)})),
              Returns(Value(9.223372036854776e+20)));  // Approx
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr({SharedConstant(9223372036854775807LL),
                                          SharedConstant(100LL)})),
              ReturnsError());  // Integer overflow
}

TEST_F(MultiplyFunctionTest, DoubleMultiplicationOverflow) {
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(std::numeric_limits<double>::max()),
                   SharedConstant(std::numeric_limits<double>::max())})),
              Returns(Value(std::numeric_limits<double>::infinity())));
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(-std::numeric_limits<double>::max()),
                   SharedConstant(std::numeric_limits<double>::max())})),
              Returns(Value(-std::numeric_limits<double>::infinity())));
}

TEST_F(MultiplyFunctionTest, LongMultiplicationOverflow) {
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(std::numeric_limits<int64_t>::max()),
                   SharedConstant(10LL)})),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(std::numeric_limits<int64_t>::min()),
                   SharedConstant(10LL)})),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(-10LL),
                   SharedConstant(std::numeric_limits<int64_t>::max())})),
              ReturnsError());
  // Note: min * -10 overflows
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(-10LL),
                   SharedConstant(std::numeric_limits<int64_t>::min())})),
              ReturnsError());
}

TEST_F(MultiplyFunctionTest, NanNumberReturnNaN) {
  double nan_val = std::numeric_limits<double>::quiet_NaN();
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(1LL), SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(1.0), SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr({SharedConstant(9007199254740991LL),
                                          SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr({SharedConstant(-9007199254740991LL),
                                          SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(std::numeric_limits<double>::max()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(std::numeric_limits<double>::lowest()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
}

TEST_F(MultiplyFunctionTest, NanNotNumberTypeReturnError) {
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(std::numeric_limits<double>::quiet_NaN()),
                   SharedConstant("hello world")})),
              ReturnsError());
}

TEST_F(MultiplyFunctionTest, PositiveInfinity) {
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(1LL)})),
              Returns(Value(std::numeric_limits<double>::infinity())));
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(1LL),
                   SharedConstant(std::numeric_limits<double>::infinity())})),
              Returns(Value(std::numeric_limits<double>::infinity())));
}

TEST_F(MultiplyFunctionTest, NegativeInfinity) {
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(1LL)})),
              Returns(Value(-std::numeric_limits<double>::infinity())));
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(1LL),
                   SharedConstant(-std::numeric_limits<double>::infinity())})),
              Returns(Value(-std::numeric_limits<double>::infinity())));
}

TEST_F(MultiplyFunctionTest,
       PositiveInfinityNegativeInfinityReturnsNegativeInfinity) {
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(-std::numeric_limits<double>::infinity())})),
              Returns(Value(-std::numeric_limits<double>::infinity())));
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(std::numeric_limits<double>::infinity())})),
              Returns(Value(-std::numeric_limits<double>::infinity())));
}

TEST_F(MultiplyFunctionTest, MultiArgument) {
  auto mult12 = MultiplyExpr({SharedConstant(1LL), SharedConstant(2LL)});
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr({mult12, SharedConstant(3LL)})),
              Returns(Value(6LL)));

  auto mult23 = MultiplyExpr({SharedConstant(2LL), SharedConstant(3LL)});
  EXPECT_THAT(EvaluateExpr(*MultiplyExpr({SharedConstant(1.0), mult23})),
              Returns(Value(6.0)));
}

// --- Divide Tests ---

TEST_F(DivideFunctionTest, BasicNumerics) {
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(10LL), SharedConstant(2LL)})),
      Returns(Value(5LL)));
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(10LL), SharedConstant(2.0)})),
      Returns(Value(5.0)));
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(10.0), SharedConstant(3LL)})),
      Returns(Value(10.0 / 3.0)));
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(10.0), SharedConstant(7.0)})),
      Returns(Value(10.0 / 7.0)));
}

TEST_F(DivideFunctionTest, BasicNonNumerics) {
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(1LL), SharedConstant("1")})),
      ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant("1"), SharedConstant(1.0)})),
      ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant("1"), SharedConstant("1")})),
      ReturnsError());
}

TEST_F(DivideFunctionTest, LongDivision) {
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(10LL), SharedConstant(3LL)})),
      Returns(Value(3LL)));  // Integer division
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(-10LL), SharedConstant(3LL)})),
      Returns(Value(-3LL)));  // Integer division
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(10LL), SharedConstant(-3LL)})),
      Returns(Value(-3LL)));  // Integer division
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(-10LL), SharedConstant(-3LL)})),
      Returns(Value(3LL)));  // Integer division
}

TEST_F(DivideFunctionTest, DoubleDivisionOverflow) {
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(std::numeric_limits<double>::max()),
                   SharedConstant(0.5)})),  // Multiplying by 2 essentially
              Returns(Value(std::numeric_limits<double>::infinity())));
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(-std::numeric_limits<double>::max()),
                   SharedConstant(0.5)})),
              Returns(Value(-std::numeric_limits<double>::infinity())));
}

TEST_F(DivideFunctionTest, ByZero) {
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(1LL), SharedConstant(0LL)})),
      ReturnsError());  // Integer division by zero is error
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(1.1), SharedConstant(0.0)})),
      Returns(Value(std::numeric_limits<double>::infinity())));
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(1.1), SharedConstant(-0.0)})),
      Returns(Value(-std::numeric_limits<double>::infinity())));
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(0.0), SharedConstant(0.0)})),
      Returns(Value(std::numeric_limits<double>::quiet_NaN())));
}

TEST_F(DivideFunctionTest, NanNumberReturnNaN) {
  double nan_val = std::numeric_limits<double>::quiet_NaN();
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(1LL), SharedConstant(nan_val)})),
      Returns(Value(nan_val)));
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(nan_val), SharedConstant(1LL)})),
      Returns(Value(nan_val)));
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(1.0), SharedConstant(nan_val)})),
      Returns(Value(nan_val)));
  EXPECT_THAT(
      EvaluateExpr(*DivideExpr({SharedConstant(nan_val), SharedConstant(1.0)})),
      Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(nan_val), SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(nan_val),
                   SharedConstant(-std::numeric_limits<double>::infinity())})),
              Returns(Value(nan_val)));
}

TEST_F(DivideFunctionTest, NanNotNumberTypeReturnError) {
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(std::numeric_limits<double>::quiet_NaN()),
                   SharedConstant("hello world")})),
              ReturnsError());
}

TEST_F(DivideFunctionTest, PositiveInfinity) {
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(1LL)})),
              Returns(Value(std::numeric_limits<double>::infinity())));
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(1LL),
                   SharedConstant(std::numeric_limits<double>::infinity())})),
              Returns(Value(0.0)));
}

TEST_F(DivideFunctionTest, NegativeInfinity) {
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(1LL)})),
              Returns(Value(-std::numeric_limits<double>::infinity())));
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(1LL),
                   SharedConstant(-std::numeric_limits<double>::infinity())})),
              Returns(Value(-0.0)));  // Note: -0.0
}

TEST_F(DivideFunctionTest, PositiveInfinityNegativeInfinityReturnsNan) {
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(-std::numeric_limits<double>::infinity())})),
              Returns(Value(std::numeric_limits<double>::quiet_NaN())));
  EXPECT_THAT(EvaluateExpr(*DivideExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(std::numeric_limits<double>::infinity())})),
              Returns(Value(std::numeric_limits<double>::quiet_NaN())));
}

// --- Mod Tests ---

TEST_F(ModFunctionTest, DivisorZeroThrowsError) {
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(42LL), SharedConstant(0LL)})),
      ReturnsError());
  // Note: C++ doesn't distinguish -0LL from 0LL
  // EXPECT_TRUE(AssertResultEquals(
  //     EvaluateExpr(*ModExpr({SharedConstant(42LL), SharedConstant(-0LL)})),
  //     EvaluateResult::NewError()));

  // Double modulo by zero returns NaN in our implementation (matching JS %)
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(42.0), SharedConstant(0.0)})),
      Returns(Value(std::numeric_limits<double>::quiet_NaN())));
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(42.0), SharedConstant(-0.0)})),
      Returns(Value(std::numeric_limits<double>::quiet_NaN())));
}

TEST_F(ModFunctionTest, DividendZeroReturnsZero) {
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(0LL), SharedConstant(42LL)})),
      Returns(Value(0LL)));
  // Note: C++ doesn't distinguish -0LL from 0LL
  // EXPECT_THAT(
  //     EvaluateExpr(*ModExpr({SharedConstant(-0LL), SharedConstant(42LL)})),
  //     Returns(Value(0LL)));

  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(0.0), SharedConstant(42.0)})),
      Returns(Value(0.0)));
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(-0.0), SharedConstant(42.0)})),
      Returns(Value(-0.0)));
}

TEST_F(ModFunctionTest, LongPositivePositive) {
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(10LL), SharedConstant(3LL)})),
      Returns(Value(1LL)));
}

TEST_F(ModFunctionTest, LongNegativeNegative) {
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(-10LL), SharedConstant(-3LL)})),
      Returns(Value(-1LL)));  // C++ % behavior
}

TEST_F(ModFunctionTest, LongPositiveNegative) {
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(10LL), SharedConstant(-3LL)})),
      Returns(Value(1LL)));  // C++ % behavior
}

TEST_F(ModFunctionTest, LongNegativePositive) {
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(-10LL), SharedConstant(3LL)})),
      Returns(Value(-1LL)));  // C++ % behavior
}

TEST_F(ModFunctionTest, DoublePositivePositive) {
  auto result =
      EvaluateExpr(*ModExpr({SharedConstant(10.5), SharedConstant(3.0)}));
  EXPECT_EQ(result.type(), EvaluateResult::ResultType::kDouble);
  EXPECT_NEAR(result.value()->double_value, 1.5, 1e-9);
}

TEST_F(ModFunctionTest, DoubleNegativeNegative) {
  auto result =
      EvaluateExpr(*ModExpr({SharedConstant(-7.3), SharedConstant(-1.8)}));
  EXPECT_EQ(result.type(), EvaluateResult::ResultType::kDouble);
  EXPECT_NEAR(result.value()->double_value, -0.1, 1e-9);  // std::fmod behavior
}

TEST_F(ModFunctionTest, DoublePositiveNegative) {
  auto result =
      EvaluateExpr(*ModExpr({SharedConstant(9.8), SharedConstant(-2.5)}));
  EXPECT_EQ(result.type(), EvaluateResult::ResultType::kDouble);
  EXPECT_NEAR(result.value()->double_value, 2.3, 1e-9);  // std::fmod behavior
}

TEST_F(ModFunctionTest, DoubleNegativePositive) {
  auto result =
      EvaluateExpr(*ModExpr({SharedConstant(-7.5), SharedConstant(2.3)}));
  EXPECT_EQ(result.type(), EvaluateResult::ResultType::kDouble);
  EXPECT_NEAR(result.value()->double_value, -0.6, 1e-9);  // std::fmod behavior
}

TEST_F(ModFunctionTest, LongPerfectlyDivisible) {
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(10LL), SharedConstant(5LL)})),
      Returns(Value(0LL)));
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(-10LL), SharedConstant(5LL)})),
      Returns(Value(0LL)));
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(10LL), SharedConstant(-5LL)})),
      Returns(Value(0LL)));
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(-10LL), SharedConstant(-5LL)})),
      Returns(Value(0LL)));
}

TEST_F(ModFunctionTest, DoublePerfectlyDivisible) {
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(10.0), SharedConstant(2.5)})),
      Returns(Value(0.0)));
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(10.0), SharedConstant(-2.5)})),
      Returns(Value(0.0)));
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(-10.0), SharedConstant(2.5)})),
      Returns(Value(-0.0)));
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(-10.0), SharedConstant(-2.5)})),
      Returns(Value(-0.0)));
}

TEST_F(ModFunctionTest, NonNumericsReturnError) {
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(10LL), SharedConstant("1")})),
      ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant("1"), SharedConstant(10LL)})),
      ReturnsError());
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant("1"), SharedConstant("1")})),
      ReturnsError());
}

TEST_F(ModFunctionTest, NanNumberReturnNaN) {
  double nan_val = std::numeric_limits<double>::quiet_NaN();
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(1LL), SharedConstant(nan_val)})),
      Returns(Value(nan_val)));
  EXPECT_THAT(
      EvaluateExpr(*ModExpr({SharedConstant(1.0), SharedConstant(nan_val)})),
      Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(nan_val)})),
              Returns(Value(nan_val)));
}

TEST_F(ModFunctionTest, NanNotNumberTypeReturnError) {
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(std::numeric_limits<double>::quiet_NaN()),
                   SharedConstant("hello world")})),
              ReturnsError());
}

TEST_F(ModFunctionTest, NumberPosInfinityReturnSelf) {
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(1LL),
                   SharedConstant(std::numeric_limits<double>::infinity())})),
              Returns(Value(1.0)));  // fmod(1, inf) -> 1
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(42.123),
                   SharedConstant(std::numeric_limits<double>::infinity())})),
              Returns(Value(42.123)));
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(-99.9),
                   SharedConstant(std::numeric_limits<double>::infinity())})),
              Returns(Value(-99.9)));
}

TEST_F(ModFunctionTest, PosInfinityNumberReturnNaN) {
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(1LL)})),
              Returns(Value(std::numeric_limits<double>::quiet_NaN())));
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(42.123)})),
              Returns(Value(std::numeric_limits<double>::quiet_NaN())));
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(-99.9)})),
              Returns(Value(std::numeric_limits<double>::quiet_NaN())));
}

TEST_F(ModFunctionTest, NumberNegInfinityReturnSelf) {
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(1LL),
                   SharedConstant(-std::numeric_limits<double>::infinity())})),
              Returns(Value(1.0)));  // fmod(1, -inf) -> 1
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(42.123),
                   SharedConstant(-std::numeric_limits<double>::infinity())})),
              Returns(Value(42.123)));
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(-99.9),
                   SharedConstant(-std::numeric_limits<double>::infinity())})),
              Returns(Value(-99.9)));
}

TEST_F(ModFunctionTest, NegInfinityNumberReturnNaN) {
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(1LL)})),
              Returns(Value(std::numeric_limits<double>::quiet_NaN())));
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(42.123)})),
              Returns(Value(std::numeric_limits<double>::quiet_NaN())));
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(-std::numeric_limits<double>::infinity()),
                   SharedConstant(-99.9)})),
              Returns(Value(std::numeric_limits<double>::quiet_NaN())));
}

TEST_F(ModFunctionTest, PosAndNegInfinityReturnNaN) {
  EXPECT_THAT(EvaluateExpr(*ModExpr(
                  {SharedConstant(std::numeric_limits<double>::infinity()),
                   SharedConstant(-std::numeric_limits<double>::infinity())})),
              Returns(Value(std::numeric_limits<double>::quiet_NaN())));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
