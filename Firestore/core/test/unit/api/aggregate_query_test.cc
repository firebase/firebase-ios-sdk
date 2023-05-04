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

// TODO(b/280805906) Remove these tests for the count specific API after the c++
// SDK migrates to the new Aggregate API

#include <memory>
#include <string>
#include <utility>

#include "Firestore/core/src/api/aggregate_query.h"
#include "Firestore/core/src/api/query_core.h"
#include "Firestore/core/src/util/status.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {

using model::AggregateAlias;
using util::Status;

namespace api {

class MockAggregateQuery : public AggregateQuery {
 public:
  StatusOr<ObjectValue> mockResult;

  ~MockAggregateQuery() override = default;

  MockAggregateQuery(Query query,
                     std::vector<AggregateField>&& aggregates,
                     StatusOr<ObjectValue>&& mockResult)
      : AggregateQuery(query, std::move(aggregates)),
        mockResult(std::move(mockResult)){};

  void GetAggregate(AggregateQueryCallback&& callback) override {
    callback(mockResult);
  }
};

class AggregateQueryTest {
 public:
  static const Query& GetQuery(const AggregateQuery& aggregateQuery) {
    return aggregateQuery.query_;
  }

  static const std::vector<AggregateField>& GetAggregates(
      const AggregateQuery& aggregateQuery) {
    return aggregateQuery.aggregates_;
  }
};

namespace {

// Assert that the Get method calls GetAggregate method
// and that the result from GetAggregate is processed
// appropriately
TEST(AggregateQuery, GetCallsGetAggregateOk) {
  // Params for Get: Query and AggregateField vector
  Query query;
  AggregateField countAggregateField(AggregateField::OpKind::Count,
                                     AggregateAlias("count"));
  std::vector<AggregateField> aggregates{countAggregateField};

  // Mock aggregate field result
  google_firestore_v1_AggregationResult_AggregateFieldsEntry
      mockAggregatesField[1];
  mockAggregatesField[0].key =
      nanopb::ByteString(absl::string_view("count")).release();
  mockAggregatesField[0].value.which_value_type =
      google_firestore_v1_Value_integer_value_tag;
  mockAggregatesField[0].value.integer_value = 10;

  // Mock ObjectValue result
  ObjectValue mockObjectValue =
      ObjectValue::FromAggregateFieldsEntry(mockAggregatesField, 1);

  // Set mocked result on our MockAggregateQuery object
  MockAggregateQuery aggregateQuery(query, std::move(aggregates),
                                    StatusOr<ObjectValue>(mockObjectValue));

  // Call the Get method
  size_t callbackCount = 0;
  aggregateQuery.Get([&callbackCount](const StatusOr<int64_t>& result) mutable {
    callbackCount++;
    EXPECT_EQ(result.ok(), true);
    EXPECT_EQ(result.ValueOrDie(), 10);
  });

  // Assert
  EXPECT_EQ(callbackCount, 1);
}

// Assert that the Get method calls GetAggregate method
// and that an error result from GetAggregate is processed
// appropriately
TEST(AggregateQuery, GetCallsGetAggregateError) {
  // Params for Get: Query and AggregateField vector
  Query query;
  AggregateField countAggregateField(AggregateField::OpKind::Count,
                                     AggregateAlias("count"));
  std::vector<AggregateField> aggregates{countAggregateField};

  // Mock error status
  Status mockError = Status(Error::kErrorInternal, "foo");

  // Set mocked result on our MockAggregateQuery object
  MockAggregateQuery aggregateQuery(query, std::move(aggregates),
                                    StatusOr<ObjectValue>(mockError));

  // Call the Get method
  size_t callbackCount = 0;
  aggregateQuery.Get([&callbackCount](const StatusOr<int64_t>& result) mutable {
    callbackCount++;
    EXPECT_EQ(result.ok(), false);
    EXPECT_EQ(result.status().code(), Error::kErrorInternal);
    EXPECT_EQ(result.status().error_message(), "foo");
  });

  // Assert
  EXPECT_EQ(callbackCount, 1);
}

// Assert that the Query.Count method creates an AggregateQuery
// with the expected query and aggregates
TEST(Query, Count) {
  // Baseline Query
  Query query;

  // Testing the Count() method
  AggregateQuery aggregateQuery = query.Count();

  auto internalQuery = AggregateQueryTest::GetQuery(aggregateQuery);
  auto internalAggregates = AggregateQueryTest::GetAggregates(aggregateQuery);

  // Assert
  EXPECT_EQ(internalQuery, query);
  EXPECT_EQ(internalAggregates.size(), 1);
  EXPECT_EQ(internalAggregates[0].op, AggregateField::OpKind::Count);
  EXPECT_EQ(internalAggregates[0].alias.StringValue(), "count");
}

}  // namespace

}  // namespace api
}  // namespace firestore
}  // namespace firebase
