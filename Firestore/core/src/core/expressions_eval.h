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
#include <utility>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/nanopb/message.h"

namespace firebase {
namespace firestore {
namespace core {

/** Represents the result of evaluating an expression. */
class EvaluateResult {
 public:
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

class CoreAdd : public EvaluableExpr {
 public:
  explicit CoreAdd(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreSubtract : public EvaluableExpr {
 public:
  explicit CoreSubtract(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreMultiply : public EvaluableExpr {
 public:
  explicit CoreMultiply(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreDivide : public EvaluableExpr {
 public:
  explicit CoreDivide(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
};

class CoreMod : public EvaluableExpr {
 public:
  explicit CoreMod(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 private:
  std::unique_ptr<api::FunctionExpr> expr_;
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

/**
 * Converts a high-level expression representation into an evaluable one.
 */
std::unique_ptr<EvaluableExpr> FunctionToEvaluable(
    const api::FunctionExpr& function);

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_CORE_EXPRESSIONS_EVAL_H_
