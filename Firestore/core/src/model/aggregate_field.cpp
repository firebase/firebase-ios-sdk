//
// Created by Mark Duckworth on 3/17/23.
//

#include "aggregate_field.h"

namespace firebase {
namespace firestore {
namespace model {

bool operator==(const AggregateField& lhs,
                const AggregateField& rhs) {
  return lhs.field_path == rhs.field_path && lhs.alias == rhs.alias;
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase