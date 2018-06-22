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

#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using model::Document;
using testutil::Doc;

TEST(QueryTest, MatchesBasedOnDocumentKey) {
  Document doc1 = Doc("rooms/eros/messages/1", /*version=*/0);
  Document doc2 = Doc("rooms/eros/messages/2", /*version=*/0);
  Document doc3 = Doc("rooms/other/messages/1", /*version=*/0);

  Query query = Query::AtPath({"rooms", "eros", "messages", "1"});
  EXPECT_TRUE(query.Matches(doc1));
  EXPECT_FALSE(query.Matches(doc2));
  EXPECT_FALSE(query.Matches(doc3));
}

TEST(QueryTest, MatchesShallowAncestorQuery) {
  Document doc1 = Doc("rooms/eros/messages/1", /*version=*/0);
  Document doc1_meta = Doc("rooms/eros/messages/1/meta/1", /*version=*/0);
  Document doc2 = Doc("rooms/eros/messages/2", /*version=*/0);
  Document doc3 = Doc("rooms/other/messages/1", /*version=*/0);

  Query query = Query::AtPath({"rooms", "eros", "messages"});
  EXPECT_TRUE(query.Matches(doc1));
  EXPECT_FALSE(query.Matches(doc1_meta));
  EXPECT_TRUE(query.Matches(doc2));
  EXPECT_FALSE(query.Matches(doc3));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
