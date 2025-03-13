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

namespace firebase {
namespace firestore {
namespace api {

class Expr {
 public:
  Expr() = default;
  virtual ~Expr() = default;
  virtual google_firestore_v1_Value to_proto() const = 0;
};

class Field : public Expr {
 public:
  explicit Field(std::string name) : name_(std::move(name)) {
  }
  google_firestore_v1_Value to_proto() const override;

 private:
  std::string name_;
};

class Constant : public Expr {
 public:
  explicit Constant(double value) : value_(value) {
  }
  google_firestore_v1_Value to_proto() const override;

 private:
  double value_;
};

class FunctionExpr : public Expr {
 public:
  FunctionExpr(std::string name, std::vector<std::shared_ptr<Expr>> args)
      : name_(std::move(name)), args_(std::move(args)) {
  }

  google_firestore_v1_Value to_proto() const override;

 private:
  std::string name_;
  std::vector<std::shared_ptr<Expr>> args_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_EXPRESSIONS_H_
