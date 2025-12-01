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

#ifndef FIRESTORE_CORE_SRC_CORE_PIPELINE_EVALUATION_TIMESTAMP_H_
#define FIRESTORE_CORE_SRC_CORE_PIPELINE_EVALUATION_TIMESTAMP_H_

#include <memory>
#include "Firestore/core/src/core/pipeline/expression.h"

namespace firebase {
namespace firestore {
namespace core {

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

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_CORE_PIPELINE_EVALUATION_TIMESTAMP_H_
