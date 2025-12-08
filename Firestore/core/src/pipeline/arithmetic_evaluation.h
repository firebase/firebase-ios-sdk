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

#ifndef FIRESTORE_CORE_SRC_PIPELINE_ARITHMETIC_EVALUATION_H_
#define FIRESTORE_CORE_SRC_PIPELINE_ARITHMETIC_EVALUATION_H_

#include <memory>
#include "Firestore/core/src/pipeline/expression_evaluation.h"

namespace firebase {
namespace firestore {
namespace core {

// --- Base Class for Unary Arithmetic Operations ---
class UnaryArithmetic : public EvaluableExpression {
 public:
  explicit UnaryArithmetic(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  ~UnaryArithmetic() override = default;

  EvaluateResult Evaluate(
      const api::EvaluateContext& context,
      const model::PipelineInputOutput& document) const override;

 protected:
  // Performs the specific double operation.
  virtual EvaluateResult PerformOperation(double val) const = 0;

  std::unique_ptr<api::FunctionExpr> expr_;
};

// --- Base Class for Arithmetic Operations ---
class BinaryArithmetic : public EvaluableExpression {
 public:
  explicit BinaryArithmetic(const api::FunctionExpr& expr)
      : expr_(std::make_unique<api::FunctionExpr>(expr)) {
  }
  ~BinaryArithmetic() override = default;

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

class EvaluateAdd : public BinaryArithmetic {
 public:
  explicit EvaluateAdd(const api::FunctionExpr& expr) : BinaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

class EvaluateSubtract : public BinaryArithmetic {
 public:
  explicit EvaluateSubtract(const api::FunctionExpr& expr)
      : BinaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

class EvaluateMultiply : public BinaryArithmetic {
 public:
  explicit EvaluateMultiply(const api::FunctionExpr& expr)
      : BinaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

class EvaluateDivide : public BinaryArithmetic {
 public:
  explicit EvaluateDivide(const api::FunctionExpr& expr)
      : BinaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

class EvaluateMod : public BinaryArithmetic {
 public:
  explicit EvaluateMod(const api::FunctionExpr& expr) : BinaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

class EvaluatePow : public BinaryArithmetic {
 public:
  explicit EvaluatePow(const api::FunctionExpr& expr) : BinaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

class EvaluateRoundToPrecision : public BinaryArithmetic {
 public:
  explicit EvaluateRoundToPrecision(const api::FunctionExpr& expr)
      : BinaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

class EvaluateLog : public BinaryArithmetic {
 public:
  explicit EvaluateLog(const api::FunctionExpr& expr) : BinaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformIntegerOperation(int64_t lhs,
                                         int64_t rhs) const override;
  EvaluateResult PerformDoubleOperation(double lhs, double rhs) const override;
};

class EvaluateCeil : public UnaryArithmetic {
 public:
  explicit EvaluateCeil(const api::FunctionExpr& expr) : UnaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformOperation(double val) const override;
};

class EvaluateFloor : public UnaryArithmetic {
 public:
  explicit EvaluateFloor(const api::FunctionExpr& expr)
      : UnaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformOperation(double val) const override;
};

class EvaluateRound : public UnaryArithmetic {
 public:
  explicit EvaluateRound(const api::FunctionExpr& expr)
      : UnaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformOperation(double val) const override;
};

class EvaluateAbs : public UnaryArithmetic {
 public:
  explicit EvaluateAbs(const api::FunctionExpr& expr) : UnaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformOperation(double val) const override;
};

class EvaluateExp : public UnaryArithmetic {
 public:
  explicit EvaluateExp(const api::FunctionExpr& expr) : UnaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformOperation(double val) const override;
};

class EvaluateLn : public UnaryArithmetic {
 public:
  explicit EvaluateLn(const api::FunctionExpr& expr) : UnaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformOperation(double val) const override;
};

class EvaluateLog10 : public UnaryArithmetic {
 public:
  explicit EvaluateLog10(const api::FunctionExpr& expr)
      : UnaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformOperation(double val) const override;
};

class EvaluateSqrt : public UnaryArithmetic {
 public:
  explicit EvaluateSqrt(const api::FunctionExpr& expr) : UnaryArithmetic(expr) {
  }

 protected:
  EvaluateResult PerformOperation(double val) const override;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_PIPELINE_ARITHMETIC_EVALUATION_H_