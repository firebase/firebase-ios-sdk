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

#include <string>

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
  Field(const std::string& name) : name_(name) {};
  google_firestore_v1_Value to_proto() const override;

 private:
  std::string name_;
};

class Constant : public Expr {
 public:
  Constant(double value) : value_(value) {};
  google_firestore_v1_Value to_proto() const override;

 private:
  double value_;
};

class Eq : public Expr {
 public:
  Eq(std::shared_ptr<Expr> left, std::shared_ptr<Expr> right)
      : left_(left), right_(right) {
  }

  google_firestore_v1_Value to_proto() const override;

 private:
  std::shared_ptr<Expr> left_;
  std::shared_ptr<Expr> right_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_EXPRESSIONS_H_
