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

#ifndef FIRESTORE_CORE_SRC_PIPELINE_STRING_EVALUATION_H_
#define FIRESTORE_CORE_SRC_PIPELINE_STRING_EVALUATION_H_

#include <memory>
#include <string>
#include "Firestore/core/src/pipeline/expression_evaluation.h"

namespace firebase {
namespace firestore {
namespace core {

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

class CoreStringConcat : public EvaluableExpr {
 public:
  explicit CoreStringConcat(const api::FunctionExpr& expr)
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

class CoreStringContains : public StringSearchBase {
 public:
  explicit CoreStringContains(const api::FunctionExpr& expr)
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

class CoreStringReverse : public EvaluableExpr {
 public:
  explicit CoreStringReverse(const api::FunctionExpr& expr)
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

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_PIPELINE_STRING_EVALUATION_H_
