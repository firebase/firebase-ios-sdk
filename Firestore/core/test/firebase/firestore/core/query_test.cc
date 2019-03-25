/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/core/query.h"

#include <cmath>

#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using model::Document;
using model::FieldValue;
using model::ResourcePath;
using testutil::Doc;
using testutil::Filter;

TEST(QueryTest, MatchesBasedOnDocumentKey) {
  Document doc1 = *Doc("rooms/eros/messages/1");
  Document doc2 = *Doc("rooms/eros/messages/2");
  Document doc3 = *Doc("rooms/other/messages/1");

  Query query = Query::AtPath({"rooms", "eros", "messages", "1"});
  EXPECT_TRUE(query.Matches(doc1));
  EXPECT_FALSE(query.Matches(doc2));
  EXPECT_FALSE(query.Matches(doc3));
}

TEST(QueryTest, MatchesShallowAncestorQuery) {
  Document doc1 = *Doc("rooms/eros/messages/1");
  Document doc1_meta = *Doc("rooms/eros/messages/1/meta/1");
  Document doc2 = *Doc("rooms/eros/messages/2");
  Document doc3 = *Doc("rooms/other/messages/1");

  Query query = Query::AtPath({"rooms", "eros", "messages"});
  EXPECT_TRUE(query.Matches(doc1));
  EXPECT_FALSE(query.Matches(doc1_meta));
  EXPECT_TRUE(query.Matches(doc2));
  EXPECT_FALSE(query.Matches(doc3));
}

TEST(QueryTest, EmptyFieldsAreAllowedForQueries) {
  Document doc1 = *Doc("rooms/eros/messages/1", 0,
                       {{"text", FieldValue::FromString("msg1")}});
  Document doc2 = *Doc("rooms/eros/messages/2");

  Query query = Query::AtPath({"rooms", "eros", "messages"})
                    .Filter(Filter("text", "==", "msg1"));
  EXPECT_TRUE(query.Matches(doc1));
  EXPECT_FALSE(query.Matches(doc2));
}

TEST(QueryTest, PrimitiveValueFilter) {
  Query query1 = Query::AtPath(ResourcePath::FromString("collection"))
                     .Filter(Filter("sort", ">=", 2));
  Query query2 = Query::AtPath(ResourcePath::FromString("collection"))
                     .Filter(Filter("sort", "<=", 2));

  Document doc1 =
      *Doc("collection/1", 0, {{"sort", FieldValue::FromInteger(1)}});
  Document doc2 =
      *Doc("collection/2", 0, {{"sort", FieldValue::FromInteger(2)}});
  Document doc3 =
      *Doc("collection/3", 0, {{"sort", FieldValue::FromInteger(3)}});
  Document doc4 = *Doc("collection/4", 0, {{"sort", FieldValue::False()}});
  Document doc5 =
      *Doc("collection/5", 0, {{"sort", FieldValue::FromString("string")}});

  EXPECT_FALSE(query1.Matches(doc1));
  EXPECT_TRUE(query1.Matches(doc2));
  EXPECT_TRUE(query1.Matches(doc3));
  EXPECT_FALSE(query1.Matches(doc4));
  EXPECT_FALSE(query1.Matches(doc5));

  EXPECT_TRUE(query2.Matches(doc1));
  EXPECT_TRUE(query2.Matches(doc2));
  EXPECT_FALSE(query2.Matches(doc3));
  EXPECT_FALSE(query2.Matches(doc4));
  EXPECT_FALSE(query2.Matches(doc5));
}

TEST(QueryTest, NanFilter) {
  Query query = Query::AtPath(ResourcePath::FromString("collection"))
                    .Filter(Filter("sort", "==", NAN));

  Document doc1 = *Doc("collection/1", 0, {{"sort", FieldValue::Nan()}});
  Document doc2 =
      *Doc("collection/2", 0, {{"sort", FieldValue::FromInteger(2)}});
  Document doc3 =
      *Doc("collection/3", 0, {{"sort", FieldValue::FromDouble(3.1)}});
  Document doc4 = *Doc("collection/4", 0, {{"sort", FieldValue::False()}});
  Document doc5 =
      *Doc("collection/5", 0, {{"sort", FieldValue::FromString("string")}});

  EXPECT_TRUE(query.Matches(doc1));
  EXPECT_FALSE(query.Matches(doc2));
  EXPECT_FALSE(query.Matches(doc3));
  EXPECT_FALSE(query.Matches(doc4));
  EXPECT_FALSE(query.Matches(doc5));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
