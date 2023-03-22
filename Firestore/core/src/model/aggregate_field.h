//
// Created by Mark Duckworth on 3/17/23.
//

#ifndef FIREBASE_AGGREGATE_FIELD_H_
#define FIREBASE_AGGREGATE_FIELD_H_

#include "Firestore/core/src/model/aggregate_alias.h"
#include "Firestore/core/src/model/field_path.h"

namespace firebase {
namespace firestore {
namespace model {


class AggregateField {
 public:
  const model::AggregateAlias alias;
  AggregateField(model::AggregateAlias&& alias)
      : alias(std::move(alias)) {
  }
};

class CountAggregateField : AggregateField {
 public:
  CountAggregateField(model::AggregateAlias&& alias)
      : AggregateField(std::move(alias)) {
  }
};

class SumAggregateField : AggregateField {
 public:
  const model::FieldPath field_path;
  SumAggregateField(model::AggregateAlias&& alias, model::FieldPath field_path)
      : AggregateField(std::move(alias)), field_path(std::move(field_path))  {
  }
};

class AverageAggregateField : AggregateField {
 public:
  const model::FieldPath field_path;
  AverageAggregateField(model::AggregateAlias&& alias, model::FieldPath field_path)
      : AggregateField(std::move(alias)), field_path(std::move(field_path)) {
  }

  friend bool operator==(const AggregateField& lhs, const AggregateField& rhs);
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_AGGREGATE_FIELD_H_
