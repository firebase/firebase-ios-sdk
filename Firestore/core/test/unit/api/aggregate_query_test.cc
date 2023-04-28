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

#include <memory>

#include "gtest/gtest.h"

#include "Firestore/core/src/api/aggregate_query.h"
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/remote/firebase_metadata_provider.h"

namespace firebase {
namespace firestore {
namespace api {
namespace {

TEST(AggregateQuery, Equality) {
  {
    auto firestore = std::make_shared<Firestore>();
    AggregateQuery aggregate_query1 = Query{core::Query{model::ResourcePath{"foo"}}, firestore}.Count();
    AggregateQuery aggregate_query2 = Query{core::Query{model::ResourcePath{"foo"}}, firestore}.Count();
    AggregateQuery aggregate_query3 = Query{core::Query{model::ResourcePath{"bar"}}, firestore}.Count();

    EXPECT_EQ(aggregate_query1, aggregate_query1);
    EXPECT_EQ(aggregate_query1, aggregate_query2);
    EXPECT_NE(aggregate_query1, aggregate_query3);
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

}  // namespace

}  // namespace api
}  // namespace firestore
}  // namespace firebase
