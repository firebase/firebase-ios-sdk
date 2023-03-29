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

#ifndef FIREBASE_AGGREGATE_FIELD_1_H
#define FIREBASE_AGGREGATE_FIELD_1_H

#include <iosfwd>
#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/model/model_fwd.h"

namespace firebase {
namespace firestore {

namespace core {

class AggregateBaseField1 {
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

 protected:
  class Rep {
   public:
    virtual ~Rep() = default;

    virtual Type type() const {
      return Type::kAggregateField;
    }
  };

  explicit AggregateBaseField1(std::shared_ptr<const Rep>&& rep) : rep_(rep) {
  }

  const Rep& rep() const {
    return *rep_;
  }

 private:
  std::shared_ptr<const Rep> rep_;
};

class CountAggregateField1 : public AggregateBaseField1 {
 protected:
  static CountAggregateField1 Create() {
    return CountAggregateField1(std::make_shared<const Rep>());
  };

 private:
  class Rep : public AggregateBaseField1::Rep {
   public:
    Rep() {
    }

    Type type() const override {
      return Type::kCountAggregateField;
    }
  };

  explicit CountAggregateField1(std::shared_ptr<const Rep>&& rep)
      : AggregateBaseField1(std::move(rep)) {
  }

  std::shared_ptr<const Rep> rep_;
};

class AverageAggregateField1 : public AggregateBaseField1 {
 protected:
  static AverageAggregateField1 Create() {
    return AverageAggregateField1(std::make_shared<const Rep>());
  };

 private:
  class Rep : public AggregateBaseField1::Rep {
   public:
    Rep() {
    }

    Type type() const override {
      return Type::kAverageAggregateField;
    }
  };

  explicit AverageAggregateField1(std::shared_ptr<const Rep>&& rep)
      : AggregateBaseField1(std::move(rep)) {
  }

  std::shared_ptr<const Rep> rep_;
};

class AggregateField1 : CountAggregateField1, AverageAggregateField1 {
 public:
  static CountAggregateField1 count() {
    return CountAggregateField1::Create();
  }

  static AverageAggregateField1 average() {
    return AverageAggregateField1::Create();
  }
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_AGGREGATE_FIELD_1_H
