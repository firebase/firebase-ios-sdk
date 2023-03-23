//
// Created by Cheryl Lin on 2023-03-23.
//
#include "Firestore/core/src/core/aggregate_field.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using testutil::AndFilters;
using testutil::Field;
using testutil::OrFilters;
using testutil::Query;
using testutil::Resource;
using testutil::Value;

namespace {

enum class AggregateKind {
  count,
  average,
};

AggregateKind get(CountAggregateField) {
  return AggregateKind::count;
}

AggregateKind get(AverageAggregateField) {
  return AggregateKind::average;
}

// Note: AggregateBaseField is different from AggregateField
std::vector<AggregateBaseField> create() {
  return {AggregateField::count(), AggregateField::average()};
}

}  // namespace

TEST(AggregateTest, Override) {
  EXPECT_EQ(AggregateKind::count, get(AggregateField::count()));
  EXPECT_EQ(AggregateKind::average, get(AggregateField::average()));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
