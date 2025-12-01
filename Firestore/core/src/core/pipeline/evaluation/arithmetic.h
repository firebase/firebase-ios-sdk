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

#ifndef FIRESTORE_CORE_SRC_CORE_PIPELINE_EVALUATION_ARITHMETIC_H_
#define FIRESTORE_CORE_SRC_CORE_PIPELINE_EVALUATION_ARITHMETIC_H_

#include <memory>
#include "Firestore/core/src/core/pipeline/expression.h"

namespace firebase {
namespace firestore {
namespace core {

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

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_CORE_PIPELINE_EVALUATION_ARITHMETIC_H_
