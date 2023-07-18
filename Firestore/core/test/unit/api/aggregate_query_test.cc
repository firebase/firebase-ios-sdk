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

#include "gmock/gmock.h"
#include "gtest/gtest.h"

#include "Firestore/core/src/api/aggregate_query.h"
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/api/query_core.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/remote/firebase_metadata_provider.h"
#include "Firestore/core/src/util/status.h"

namespace firebase {
namespace firestore {

using model::AggregateAlias;
using ::testing::Invoke;
using util::Status;

namespace api {

class MockAggregateQuery : public AggregateQuery {
 public:
  using AggregateQuery::AggregateQuery;

  ~MockAggregateQuery() override = default;

  MOCK_METHOD(void,
              GetAggregate,
              (AggregateQueryCallback && callback),
              (override));
};

class AggregateQueryTest {
 public:
  static const Query& GetQuery(const AggregateQuery& aggregate_query) {
    return aggregate_query.query_;
  }

  static const std::vector<AggregateField>& GetAggregates(
      const AggregateQuery& aggregate_query) {
    return aggregate_query.aggregates_;
  }
};

namespace {
TEST(AggregateQuery, Equality) {
  {
    auto firestore = std::make_shared<Firestore>();
    AggregateQuery aggregate_query1 =
        Query{core::Query{model::ResourcePath{"foo"}}, firestore}.Count();
    AggregateQuery aggregate_query2 =
        Query{core::Query{model::ResourcePath{"foo"}}, firestore}.Count();
    AggregateQuery aggregate_query3 =
        Query{core::Query{model::ResourcePath{"bar"}}, firestore}.Count();

    EXPECT_TRUE(aggregate_query1 == aggregate_query1);
    EXPECT_TRUE(aggregate_query1 == aggregate_query2);
    EXPECT_TRUE(aggregate_query1 != aggregate_query3);

    EXPECT_FALSE(aggregate_query1 != aggregate_query1);
    EXPECT_FALSE(aggregate_query1 != aggregate_query2);
    EXPECT_FALSE(aggregate_query1 == aggregate_query3);
  }
}

TEST(AggregateQuery, GetQuery) {
  {
    auto firestore = std::make_shared<Firestore>();
    Query query1{core::Query{model::ResourcePath{"foo"}}, firestore};
    Query query2{core::Query{model::ResourcePath{"bar"}}, firestore};

    EXPECT_EQ(query1.Count().query(), query1);
    EXPECT_NE(query1.Count().query(), query2);
  }
}

// Assert that the Get member function calls GetAggregate member function
// and that the result from GetAggregate is processed
// appropriately
TEST(AggregateQuery, GetCallsGetAggregateOk) {
  // Test aggregate field result
  google_firestore_v1_AggregationResult_AggregateFieldsEntry
      aggregate_fields_entry[1];
  aggregate_fields_entry[0].key = nanopb::ByteString("aggregate_0").release();
  aggregate_fields_entry[0].value.which_value_type =
      google_firestore_v1_Value_integer_value_tag;
  aggregate_fields_entry[0].value.integer_value = 10;

  // Test alias map
  absl::flat_hash_map<std::string, std::string> alias_map;
  alias_map["aggregate_0"] = "count";

  // Test ObjectValue result
  ObjectValue object_value_result = ObjectValue::FromAggregateFieldsEntry(
      aggregate_fields_entry, 1, alias_map);

  // Create an AggregateQuery with mocked GetAggregate function that
  // invokes the callback with the test results from above
  AggregateField count_aggregate_field(AggregateField::OpKind::Count,
                                       AggregateAlias("count"));
  std::vector<AggregateField> aggregates{count_aggregate_field};
  MockAggregateQuery mock_aggregate_query({}, std::move(aggregates));
  EXPECT_CALL(mock_aggregate_query, GetAggregate)
      .Times(1)
      .WillOnce(Invoke([object_value_result = std::move(object_value_result)](
                           AggregateQueryCallback&& callback) {
        callback(object_value_result);
      }));

  // Call the Get function, which is the function under test
  int callback_count = 0;
  mock_aggregate_query.Get(
      [&callback_count](const StatusOr<int64_t>& result) mutable {
        callback_count++;
        ASSERT_EQ(result.ok(), true);
        EXPECT_EQ(result.ValueOrDie(), 10);
      });

  // Assert the callback was invoked
  EXPECT_EQ(callback_count, 1);
}

// Assert that the Get member function calls GetAggregate member function
// and that an error result from GetAggregate is processed
// appropriately
TEST(AggregateQuery, GetCallsGetAggregateError) {
  // Error result
  Status error_result = Status(Error::kErrorInternal, "foo");

  // Create an AggregateQuery with mocked GetAggregate function that
  // invokes the callback with the error status from above
  AggregateField count_aggregate_field(AggregateField::OpKind::Count,
                                       AggregateAlias("count"));
  std::vector<AggregateField> aggregates{count_aggregate_field};
  MockAggregateQuery mock_aggregate_query({}, std::move(aggregates));
  EXPECT_CALL(mock_aggregate_query, GetAggregate)
      .Times(1)
      .WillOnce(Invoke(
          [error_result = std::move(error_result)](
              AggregateQueryCallback&& callback) { callback(error_result); }));

  // Call the Get member function
  int callback_count = 0;
  mock_aggregate_query.Get(
      [&callback_count](const StatusOr<int64_t>& result) mutable {
        callback_count++;
        ASSERT_EQ(result.ok(), false);
        EXPECT_EQ(result.status().code(), Error::kErrorInternal);
        EXPECT_EQ(result.status().error_message(), "foo");
      });

  // Assert
  EXPECT_EQ(callback_count, 1);
}

// Assert that the Query::Count member function creates an AggregateQuery
// with the expected query and aggregates
TEST(Query, Count) {
  // Baseline Query
  Query query;

  // Testing the Count() function
  AggregateQuery aggregate_query = query.Count();

  const Query& internal_query = AggregateQueryTest::GetQuery(aggregate_query);
  const std::vector<AggregateField>& internal_aggregates =
      AggregateQueryTest::GetAggregates(aggregate_query);

  // Assert
  EXPECT_EQ(internal_query, query);
  ASSERT_EQ(internal_aggregates.size(), 1);
  EXPECT_EQ(internal_aggregates[0].op, AggregateField::OpKind::Count);
  EXPECT_EQ(internal_aggregates[0].alias.StringValue(), "count");
}

}  // namespace

}  // namespace api
}  // namespace firestore
}  // namespace firebase
