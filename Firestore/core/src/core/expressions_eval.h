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

class CoreEq : public EvaluableExpr {
 public:
  explicit CoreEq(const api::FunctionExpr& expr)
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
