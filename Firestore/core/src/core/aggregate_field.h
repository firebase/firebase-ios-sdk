//
// Created by Cheryl Lin on 2023-03-23.
//

#ifndef FIREBASE_AGGREGATE_FIELD_H
#define FIREBASE_AGGREGATE_FIELD_H

#include <iosfwd>
#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/model/model_fwd.h"

namespace firebase {
namespace firestore {

namespace core {

class AggregateBaseField {
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

  explicit AggregateBaseField(std::shared_ptr<const Rep>&& rep) : rep_(rep) {
  }

  const Rep& rep() const {
    return *rep_;
  }

 private:
  std::shared_ptr<const Rep> rep_;
};

class CountAggregateField : public AggregateBaseField {
 protected:
  static CountAggregateField Create() {
    return CountAggregateField(std::make_shared<const Rep>());
  };

 private:
  class Rep : public AggregateBaseField::Rep {
   public:
    Rep() {
    }

    Type type() const override {
      return Type::kCountAggregateField;
    }
  };

  explicit CountAggregateField(std::shared_ptr<const Rep>&& rep)
      : AggregateBaseField(std::move(rep)) {
  }

  std::shared_ptr<const Rep> rep_;
};

class AverageAggregateField : public AggregateBaseField {
 protected:
  static AverageAggregateField Create() {
    return AverageAggregateField(std::make_shared<const Rep>());
  };

 private:
  class Rep : public AggregateBaseField::Rep {
   public:
    Rep() {
    }

    Type type() const override {
      return Type::kAverageAggregateField;
    }
  };

  explicit AverageAggregateField(std::shared_ptr<const Rep>&& rep)
      : AggregateBaseField(std::move(rep)) {
  }

  std::shared_ptr<const Rep> rep_;
};

class AggregateField : CountAggregateField, AverageAggregateField {
 public:
  static CountAggregateField count() {
    return CountAggregateField::Create();
  }

  static AverageAggregateField average() {
    return AverageAggregateField::Create();
  }
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_AGGREGATE_FIELD_H
