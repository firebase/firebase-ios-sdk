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

#ifndef FIRESTORE_CORE_SRC_CORE_EXPRESSIONS_EVAL_H_
#define FIRESTORE_CORE_SRC_CORE_EXPRESSIONS_EVAL_H_

#include <memory>
#include <string>
#include <utility>
#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/nanopb/message.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace core {

// Forward declaration removed, definition moved below

/** Represents the result of evaluating an expression. */
class EvaluateResult {
 public:
  // TODO(BSON): Add bson types here when integrating.
  enum class ResultType {
    kError = 0,
    kUnset = 1,
    kNull = 2,
    kBoolean = 3,
    kInt = 4,
    kDouble = 5,
    kTimestamp = 6,
    kString = 7,
    kBytes = 8,
    kReference = 9,
    kGeoPoint = 10,
    kArray = 11,
    kMap = 12,
    kFieldReference = 13,
    kVector = 14
  };

  // Disallow default instance as it is invalid
  EvaluateResult() = delete;

  static EvaluateResult NewError() {
    return EvaluateResult(ResultType::kError,
                          nanopb::Message<google_firestore_v1_Value>());
  }

  static EvaluateResult NewUnset() {
    return EvaluateResult(ResultType::kUnset,
                          nanopb::Message<google_firestore_v1_Value>());
  }

  static EvaluateResult NewNull();

  static EvaluateResult NewValue(
      nanopb::Message<google_firestore_v1_Value> value);

  ResultType type() const {
    return type_;
  }

  const google_firestore_v1_Value* value() const {
    return value_.get();
  }

  bool IsErrorOrUnset() const {
    return type_ == ResultType::kError || type_ == ResultType::kUnset;
  }

  bool IsNull() const {
    return type_ == ResultType::kNull;
  }

 private:
  EvaluateResult(ResultType type,
                 nanopb::Message<google_firestore_v1_Value> message);

  nanopb::Message<google_firestore_v1_Value> value_;
  ResultType type_;
};

/** An interface representing an expression that can be evaluated. */
class EvaluableExpr {
 public:
  virtual ~EvaluableExpr() = default;

  /**
   * Evaluates the expression against the given document within the provided
   * context.
   * @param context The context for evaluation (e.g., variable bindings).
   * @param document The document to evaluate against.
   * @return The result of the evaluation.
   */
  virtual EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const = 0;
};

class CoreField : public EvaluableExpr {
 public:
  explicit CoreField(std::unique_ptr<api::Expr> expr) : expr_(std::move(expr)) {
  }

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::Expr> expr_;
};

class CoreConstant : public EvaluableExpr {
 public:
  explicit CoreConstant(std::unique_ptr<api::Expr> expr)
      : expr_(std::move(expr)) {
  }

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::Expr> expr_;
};

/** Base class for binary comparison expressions (==, !=, <, <=, >, >=). */
class ComparisonBase : public EvaluableExpr {
 public:
  explicit ComparisonBase(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 protected:
  /**
   * Performs the specific comparison logic after operands have been evaluated
   * and basic checks (Error, Unset, Null) have passed.
   */
  virtual EvaluateResult CompareToResult(const EvaluateResult& left,
                                         const EvaluateResult& right) const = 0;

  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreEq : public ComparisonBase {
 public:
  explicit CoreEq(const api::FunctionExpr& expr) : ComparisonBase(expr) {
  }

 protected:
  EvaluateResult CompareToResult(const EvaluateResult& left,
                                 const EvaluateResult& right) const override;
};

class CoreNeq : public ComparisonBase {
 public:
  explicit CoreNeq(const api::FunctionExpr& expr) : ComparisonBase(expr) {
  }

 protected:
  EvaluateResult CompareToResult(const EvaluateResult& left,
                                 const EvaluateResult& right) const override;
};

class CoreLt : public ComparisonBase {
 public:
  explicit CoreLt(const api::FunctionExpr& expr) : ComparisonBase(expr) {
  }

 protected:
  EvaluateResult CompareToResult(const EvaluateResult& left,
                                 const EvaluateResult& right) const override;
};

class CoreLte : public ComparisonBase {
 public:
  explicit CoreLte(const api::FunctionExpr& expr) : ComparisonBase(expr) {
  }

 protected:
  EvaluateResult CompareToResult(const EvaluateResult& left,
                                 const EvaluateResult& right) const override;
};

class CoreGt : public ComparisonBase {
 public:
  explicit CoreGt(const api::FunctionExpr& expr) : ComparisonBase(expr) {
  }

 protected:
  EvaluateResult CompareToResult(const EvaluateResult& left,
                                 const EvaluateResult& right) const override;
};

class CoreGte : public ComparisonBase {
 public:
  explicit CoreGte(const api::FunctionExpr& expr) : ComparisonBase(expr) {
  }

 protected:
  EvaluateResult CompareToResult(const EvaluateResult& left,
                                 const EvaluateResult& right) const override;
};

// --- Base Class for Arithmetic Operations ---
class ArithmeticBase : public EvaluableExpr {
 public:
  explicit ArithmeticBase(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  ~ArithmeticBase() override = default;

  // Implementation is inline below
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 protected:
  // Performs the specific integer operation (e.g., add, subtract).
  // Returns Error result on overflow or invalid operation (like div/mod by
  // zero).
  virtual EvaluateResult PerformIntegerOperation(int64_t lhs,
                                                 int64_t rhs) const = 0;

  // Performs the specific double operation.
  // Returns Error result on invalid operation (like div/mod by zero).
  virtual EvaluateResult PerformDoubleOperation(double lhs,
                                                double rhs) const = 0;

  // Applies the arithmetic operation between two evaluated results.
  // Mirrors the logic from TypeScript's applyArithmetics.
  // Implementation is inline below
  EvaluateResult ApplyOperation(const EvaluateResult& left,
                                const EvaluateResult& right) const;

  std::unique_ptr<api::FunctionExpr> expr_;
};
// --- End Base Class for Arithmetic Operations ---

class CoreAdd : public ArithmeticBase {
 public:
  explicit CoreAdd(const api::FunctionExpr& expr) : ArithmeticBase(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

class CoreSubtract : public ArithmeticBase {
 public:
  explicit CoreSubtract(const api::FunctionExpr& expr) : ArithmeticBase(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

class CoreMultiply : public ArithmeticBase {
 public:
  explicit CoreMultiply(const api::FunctionExpr& expr) : ArithmeticBase(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

class CoreDivide : public ArithmeticBase {
 public:
  explicit CoreDivide(const api::FunctionExpr& expr) : ArithmeticBase(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

class CoreMod : public ArithmeticBase {
 public:
  explicit CoreMod(const api::FunctionExpr& expr) : ArithmeticBase(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

// --- Array Expressions ---

class CoreArrayReverse : public EvaluableExpr {
 public:
  explicit CoreArrayReverse(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreArrayContains : public EvaluableExpr {
 public:
  explicit CoreArrayContains(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreArrayContainsAll : public EvaluableExpr {
 public:
  explicit CoreArrayContainsAll(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreArrayContainsAny : public EvaluableExpr {
 public:
  explicit CoreArrayContainsAny(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreArrayLength : public EvaluableExpr {
 public:
  explicit CoreArrayLength(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

// --- String Expressions ---

/** Base class for binary string search functions (starts_with, ends_with,
 * str_contains). */
class StringSearchBase : public EvaluableExpr {
 public:
  explicit StringSearchBase(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 protected:
  /**
   * Performs the specific string search logic after operands have been
   * evaluated and basic checks (Error, Unset, Null, Type) have passed.
   */
  virtual EvaluateResult PerformSearch(const std::string& value,
                                       const std::string& search) const = 0;

  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreByteLength : public EvaluableExpr {
 public:
  explicit CoreByteLength(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreCharLength : public EvaluableExpr {
 public:
  explicit CoreCharLength(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreStrConcat : public EvaluableExpr {
 public:
  explicit CoreStrConcat(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreEndsWith : public StringSearchBase {
 public:
  explicit CoreEndsWith(const api::FunctionExpr& expr)
      : StringSearchBase(expr) {
  }

 protected:
  EvaluateResult PerformSearch(const std::string& value,
                               const std::string& search) const override;
};

class CoreStartsWith : public StringSearchBase {
 public:
  explicit CoreStartsWith(const api::FunctionExpr& expr)
      : StringSearchBase(expr) {
  }

 protected:
  EvaluateResult PerformSearch(const std::string& value,
                               const std::string& search) const override;
};

class CoreStrContains : public StringSearchBase {
 public:
  explicit CoreStrContains(const api::FunctionExpr& expr)
      : StringSearchBase(expr) {
  }

 protected:
  EvaluateResult PerformSearch(const std::string& value,
                               const std::string& search) const override;
};

class CoreToLower : public EvaluableExpr {
 public:
  explicit CoreToLower(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreToUpper : public EvaluableExpr {
 public:
  explicit CoreToUpper(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreTrim : public EvaluableExpr {
 public:
  explicit CoreTrim(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreReverse : public EvaluableExpr {
 public:
  explicit CoreReverse(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreRegexContains : public StringSearchBase {
 public:
  explicit CoreRegexContains(const api::FunctionExpr& expr)
      : StringSearchBase(expr) {
  }

 protected:
  EvaluateResult PerformSearch(const std::string& value,
                               const std::string& search) const override;
};

class CoreRegexMatch : public StringSearchBase {
 public:
  explicit CoreRegexMatch(const api::FunctionExpr& expr)
      : StringSearchBase(expr) {
  }

 protected:
  EvaluateResult PerformSearch(const std::string& value,
                               const std::string& search) const override;
};

class CoreLike : public StringSearchBase {
 public:
  explicit CoreLike(const api::FunctionExpr& expr) : StringSearchBase(expr) {
  }

 protected:
  EvaluateResult PerformSearch(const std::string& value,
                               const std::string& search) const override;
};

// --- Map Expressions ---

class CoreMapGet : public EvaluableExpr {
 public:
  explicit CoreMapGet(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

// --- Logical Expressions ---

class CoreAnd : public EvaluableExpr {
 public:
  explicit CoreAnd(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreOr : public EvaluableExpr {
 public:
  explicit CoreOr(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreXor : public EvaluableExpr {
 public:
  explicit CoreXor(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreCond : public EvaluableExpr {
 public:
  explicit CoreCond(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreEqAny : public EvaluableExpr {
 public:
  explicit CoreEqAny(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreNotEqAny : public EvaluableExpr {
 public:
  explicit CoreNotEqAny(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreIsNan : public EvaluableExpr {
 public:
  explicit CoreIsNan(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreIsNotNan : public EvaluableExpr {
 public:
  explicit CoreIsNotNan(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreIsNull : public EvaluableExpr {
 public:
  explicit CoreIsNull(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreIsNotNull : public EvaluableExpr {
 public:
  explicit CoreIsNotNull(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreIsError : public EvaluableExpr {
 public:
  explicit CoreIsError(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreLogicalMaximum : public EvaluableExpr {
 public:
  explicit CoreLogicalMaximum(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreLogicalMinimum : public EvaluableExpr {
 public:
  explicit CoreLogicalMinimum(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

// --- Debugging Expressions ---

class CoreExists : public EvaluableExpr {
 public:
  explicit CoreExists(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreNot : public EvaluableExpr {
 public:
  explicit CoreNot(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

// --- Timestamp Expressions ---

/** Base class for converting Unix time (micros/millis/seconds) to Timestamp. */
class UnixToTimestampBase : public EvaluableExpr {
 public:
  explicit UnixToTimestampBase(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 protected:
  /** Performs the specific conversion logic after input validation. */
  virtual EvaluateResult ToTimestamp(int64_t value) const = 0;

  std::unique_ptr<api::FunctionExpr> expr_;
};

// Note: Implementations are in expressions_eval.cc
class CoreUnixMicrosToTimestamp : public UnixToTimestampBase {
 public:
  explicit CoreUnixMicrosToTimestamp(const api::FunctionExpr& expr);

 protected:
  EvaluateResult ToTimestamp(int64_t value) const override;
};

class CoreUnixMillisToTimestamp : public UnixToTimestampBase {
 public:
  explicit CoreUnixMillisToTimestamp(const api::FunctionExpr& expr);

 protected:
  EvaluateResult ToTimestamp(int64_t value) const override;
};

class CoreUnixSecondsToTimestamp : public UnixToTimestampBase {
 public:
  explicit CoreUnixSecondsToTimestamp(const api::FunctionExpr& expr);

 protected:
  EvaluateResult ToTimestamp(int64_t value) const override;
};

/** Base class for converting Timestamp to Unix time (micros/millis/seconds). */
class TimestampToUnixBase : public EvaluableExpr {
 public:
  explicit TimestampToUnixBase(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 protected:
  /** Performs the specific conversion logic after input validation. */
  virtual EvaluateResult ToUnix(
      const google_protobuf_Timestamp& ts) const = 0;  // Use protobuf type

  std::unique_ptr<api::FunctionExpr> expr_;
};

// Note: Implementations are in expressions_eval.cc
class CoreTimestampToUnixMicros : public TimestampToUnixBase {
 public:
  explicit CoreTimestampToUnixMicros(const api::FunctionExpr& expr);

 protected:
  EvaluateResult ToUnix(const google_protobuf_Timestamp& ts) const override;
};

class CoreTimestampToUnixMillis : public TimestampToUnixBase {
 public:
  explicit CoreTimestampToUnixMillis(const api::FunctionExpr& expr);

 protected:
  EvaluateResult ToUnix(const google_protobuf_Timestamp& ts) const override;
};

class CoreTimestampToUnixSeconds : public TimestampToUnixBase {
 public:
  explicit CoreTimestampToUnixSeconds(const api::FunctionExpr& expr);

 protected:
  EvaluateResult ToUnix(const google_protobuf_Timestamp& ts) const override;
};

/** Base class for timestamp arithmetic (add/sub). */
class TimestampArithmeticBase : public EvaluableExpr {
 public:
  explicit TimestampArithmeticBase(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 protected:
  /** Performs the specific arithmetic operation. */
  // Return optional<int64> as int128 is not needed and adds complexity
  virtual absl::optional<int64_t> PerformArithmetic(
      int64_t initial_micros, int64_t micros_to_operate) const = 0;

  std::unique_ptr<api::FunctionExpr> expr_;
};

// Note: Implementations are in expressions_eval.cc
class CoreTimestampAdd : public TimestampArithmeticBase {
 public:
  explicit CoreTimestampAdd(const api::FunctionExpr& expr);

 protected:
  absl::optional<int64_t> PerformArithmetic(
      int64_t initial_micros, int64_t micros_to_operate) const override;
};

class CoreTimestampSub : public TimestampArithmeticBase {
 public:
  explicit CoreTimestampSub(const api::FunctionExpr& expr);

 protected:
  absl::optional<int64_t> PerformArithmetic(
      int64_t initial_micros, int64_t micros_to_operate) const override;
};

/**
 * Converts a high-level expression representation into an evaluable one.
 */
std::unique_ptr<EvaluableExpr> FunctionToEvaluable(
    const api::FunctionExpr& function);

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_CORE_EXPRESSIONS_EVAL_H_
