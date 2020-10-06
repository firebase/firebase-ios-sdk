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

#include "Firestore/core/src/model/document.h"

#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/field_value.h"
#include "Firestore/core/src/model/unknown_document.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/strings/string_view.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

using testutil::Doc;
using testutil::Field;
using testutil::Key;
using testutil::Map;
using testutil::Value;
using testutil::Version;
using testutil::WrapObject;

TEST(DocumentTest, Constructor) {
  DocumentKey key = Key("messages/first");
  SnapshotVersion version = Version(1001);
  ObjectValue data = WrapObject("a", 1);
  Document doc(data, key, version, DocumentState::kSynced);

  EXPECT_EQ(MaybeDocument::Type::Document, doc.type());
  EXPECT_EQ(doc.key(), Key("messages/first"));
  EXPECT_EQ(doc.version(), version);
  EXPECT_EQ(doc.data(), data);
  EXPECT_EQ(doc.has_local_mutations(), false);
  EXPECT_EQ(doc.has_pending_writes(), false);

  Document doc2(data, key, version, DocumentState::kLocalMutations);
  EXPECT_EQ(doc2.has_local_mutations(), true);
  EXPECT_EQ(doc2.has_pending_writes(), true);

  Document doc3(data, key, version, DocumentState::kCommittedMutations);
  EXPECT_EQ(doc3.has_committed_mutations(), true);
  EXPECT_EQ(doc3.has_pending_writes(), true);
}

TEST(DocumentTest, ExtractsFields) {
  Document doc = Doc("rooms/eros", 1001,
                     Map("desc", "Discuss all the project related stuff",
                         "owner", Map("name", "Jonny", "title", "scallywag")));

  EXPECT_EQ(doc.field(Field("desc")),
            Value("Discuss all the project related stuff"));
  EXPECT_EQ(doc.field(Field("owner.title")), Value("scallywag"));
}

TEST(DocumentTest, Equality) {
  Document doc = Doc("some/path", 1, Map("a", 1));
  EXPECT_EQ(doc, Doc("some/path", 1, Map("a", 1)));
  EXPECT_NE(doc, Doc("other/path", 1, Map("a", 1)));
  EXPECT_NE(doc, Doc("some/path", 2, Map("a", 1)));
  EXPECT_NE(doc, Doc("some/path", 1, Map("b", 1)));
  EXPECT_NE(doc, Doc("some/path", 1, Map("a", 2)));
  EXPECT_NE(doc,
            Doc("some/path", 1, Map("a", 1), DocumentState::kLocalMutations));

  EXPECT_NE(doc, UnknownDocument(Key("same/path"), Version(1)));
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
