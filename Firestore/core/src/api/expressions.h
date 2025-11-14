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

#ifndef FIRESTORE_CORE_SRC_API_EXPRESSIONS_H_
#define FIRESTORE_CORE_SRC_API_EXPRESSIONS_H_

#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/nanopb/message.h"

namespace firebase {
namespace firestore {
namespace core {
class EvaluableExpr;
}  // namespace core
namespace api {

class Expr {
 public:
  Expr() = default;
  virtual ~Expr() = default;
  virtual google_firestore_v1_Value to_proto() const = 0;
  virtual std::unique_ptr<core::EvaluableExpr> ToEvaluable() const = 0;
};

class Selectable : public Expr {
 public:
  ~Selectable() override = default;
  virtual const std::string& alias() const = 0;
};

class Field : public Selectable {
 public:
  explicit Field(model::FieldPath field_path)
      : field_path_(std::move(field_path)),
        alias_(field_path_.CanonicalString()) {
  }
  ~Field() override = default;

  explicit Field(std::string name);

  google_firestore_v1_Value to_proto() const override;

  const std::string& alias() const override {
    return alias_;
  }
  const model::FieldPath& field_path() const {
    return field_path_;
  }

  std::unique_ptr<core::EvaluableExpr> ToEvaluable() const override;

 private:
  model::FieldPath field_path_;
  std::string alias_;
};

class Constant : public Expr {
 public:
  explicit Constant(nanopb::SharedMessage<google_firestore_v1_Value> value)
      : value_(std::move(value)) {
  }
  google_firestore_v1_Value to_proto() const override;

  const google_firestore_v1_Value& value() const;

  std::unique_ptr<core::EvaluableExpr> ToEvaluable() const override;

 private:
  nanopb::SharedMessage<google_firestore_v1_Value> value_;
};

class FunctionExpr : public Expr {
 public:
  FunctionExpr(std::string name, std::vector<std::shared_ptr<Expr>> params)
      : name_(std::move(name)), params_(std::move(params)) {
  }

  google_firestore_v1_Value to_proto() const override;

  std::unique_ptr<core::EvaluableExpr> ToEvaluable() const override;

  const std::string& name() const {
    return name_;
  }

  const std::vector<std::shared_ptr<Expr>>& params() const {
    return params_;
  }

 private:
  std::string name_;
  std::vector<std::shared_ptr<Expr>> params_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_EXPRESSIONS_H_
