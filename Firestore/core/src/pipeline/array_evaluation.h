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

#ifndef FIRESTORE_CORE_SRC_PIPELINE_ARRAY_EVALUATION_H_
#define FIRESTORE_CORE_SRC_PIPELINE_ARRAY_EVALUATION_H_

#include <memory>
#include "Firestore/core/src/pipeline/expression_evaluation.h"

namespace firebase {
namespace firestore {
namespace core {

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

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_PIPELINE_ARRAY_EVALUATION_H_
