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

#ifndef FIRESTORE_CORE_SRC_PIPELINE_COMPARISON_EVALUATION_H_
#define FIRESTORE_CORE_SRC_PIPELINE_COMPARISON_EVALUATION_H_

#include <memory>
#include "Firestore/core/src/pipeline/expression_evaluation.h"

namespace firebase {
namespace firestore {
namespace core {

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

class CoreEqual : public ComparisonBase {
 public:
  explicit CoreEqual(const api::FunctionExpr& expr) : ComparisonBase(expr) {
  }

 protected:
  EvaluateResult CompareToResult(const EvaluateResult& left,
                                 const EvaluateResult& right) const override;
};

class CoreNotEqual : public ComparisonBase {
 public:
  explicit CoreNotEqual(const api::FunctionExpr& expr) : ComparisonBase(expr) {
  }

 protected:
  EvaluateResult CompareToResult(const EvaluateResult& left,
                                 const EvaluateResult& right) const override;
};

class CoreLessThan : public ComparisonBase {
 public:
  explicit CoreLessThan(const api::FunctionExpr& expr) : ComparisonBase(expr) {
  }

 protected:
  EvaluateResult CompareToResult(const EvaluateResult& left,
                                 const EvaluateResult& right) const override;
};

class CoreLessThanOrEqual : public ComparisonBase {
 public:
  explicit CoreLessThanOrEqual(const api::FunctionExpr& expr)
      : ComparisonBase(expr) {
  }

 protected:
  EvaluateResult CompareToResult(const EvaluateResult& left,
                                 const EvaluateResult& right) const override;
};

class CoreGreaterThan : public ComparisonBase {
 public:
  explicit CoreGreaterThan(const api::FunctionExpr& expr)
      : ComparisonBase(expr) {
  }

 protected:
  EvaluateResult CompareToResult(const EvaluateResult& left,
                                 const EvaluateResult& right) const override;
};

class CoreGreaterThanOrEqual : public ComparisonBase {
 public:
  explicit CoreGreaterThanOrEqual(const api::FunctionExpr& expr)
      : ComparisonBase(expr) {
  }

 protected:
  EvaluateResult CompareToResult(const EvaluateResult& left,
                                 const EvaluateResult& right) const override;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_PIPELINE_COMPARISON_EVALUATION_H_
