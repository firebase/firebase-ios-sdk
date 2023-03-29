/*
 * Copyright 2023 Google LLC
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

#ifndef FIREBASE_AGGREGATE_FIELD_2_H
#define FIREBASE_AGGREGATE_FIELD_2_H

#include <iosfwd>
#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/model/model_fwd.h"

namespace firebase {
namespace firestore {

namespace core {

class CountAggregateField2;
class AverageAggregateField2;

class AggregateField2 {
 public:
  enum class Type {
    kAggregateField,
    kSumAggregateField,
    kCountAggregateField,
    kAverageAggregateField,
  };

  Type type() const {
    return rep_->type();
  }

  static std::shared_ptr<CountAggregateField2> count();

  static std::shared_ptr<AverageAggregateField2> average();

 protected:
  class Rep {
   public:
    virtual ~Rep() = default;

    virtual Type type() const {
      return Type::kAggregateField;
    }
  };

  explicit AggregateField2(std::shared_ptr<const Rep>&& rep) : rep_(rep) {
  }

  const Rep& rep() const {
    return *rep_;
  }

 private:
  std::shared_ptr<const Rep> rep_;
};

class CountAggregateField2 : public AggregateField2 {
 public:
  CountAggregateField2() : AggregateField2(std::make_shared<const Rep>()) {
  }

 private:
  class Rep : public AggregateField2::Rep {
   public:
    Rep() {
    }

    Type type() const override {
      return Type::kCountAggregateField;
    }
  };

  std::shared_ptr<const Rep> rep_;
};

class AverageAggregateField2 : public AggregateField2 {
 public:
  AverageAggregateField2() : AggregateField2(std::make_shared<const Rep>()) {
  }

 private:
  class Rep : public AggregateField2::Rep {
   public:
    Rep() {
    }

    Type type() const override {
      return Type::kAverageAggregateField;
    }
  };

  std::shared_ptr<const Rep> rep_;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_AGGREGATE_FIELD_2_H
