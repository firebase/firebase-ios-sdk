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

#include "Firestore/core/src/firebase/firestore/model/document.h"

#include "absl/strings/string_view.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

namespace {

inline Document MakeDocument(const absl::string_view data,
                             const absl::string_view path,
                             const Timestamp& timestamp,
                             bool has_local_mutations) {
  return Document(FieldValue::ObjectValue(
                      {{"field", FieldValue::StringValue(data.data())}}),
                  DocumentKey::FromPathString(path.data()),
                  SnapshotVersion(timestamp), has_local_mutations);
}

}  // anonymous namespace

TEST(Document, Getter) {
  const Document& doc =
      MakeDocument("foo", "i/am/a/path", Timestamp(123, 456), true);
  EXPECT_EQ(MaybeDocument::Type::Document, doc.type());
  EXPECT_EQ(
      FieldValue::ObjectValue({{"field", FieldValue::StringValue("foo")}}),
      doc.data());
  EXPECT_EQ(DocumentKey::FromPathString("i/am/a/path"), doc.key());
  EXPECT_EQ(SnapshotVersion(Timestamp(123, 456)), doc.version());
  EXPECT_TRUE(doc.has_local_mutations());
}

TEST(Document, Comparison) {
  EXPECT_EQ(MakeDocument("foo", "i/am/a/path", Timestamp(123, 456), true),
            MakeDocument("foo", "i/am/a/path", Timestamp(123, 456), true));
  EXPECT_NE(MakeDocument("foo", "i/am/a/path", Timestamp(123, 456), true),
            MakeDocument("bar", "i/am/a/path", Timestamp(123, 456), true));
  EXPECT_NE(
      MakeDocument("foo", "i/am/a/path", Timestamp(123, 456), true),
      MakeDocument("foo", "i/am/another/path", Timestamp(123, 456), true));
  EXPECT_NE(MakeDocument("foo", "i/am/a/path", Timestamp(123, 456), true),
            MakeDocument("foo", "i/am/a/path", Timestamp(456, 123), true));
  EXPECT_NE(MakeDocument("foo", "i/am/a/path", Timestamp(123, 456), true),
            MakeDocument("foo", "i/am/a/path", Timestamp(123, 456), false));

  // Document and MaybeDocument will not equal. In particular, Document and
  // NoDocument will not equal, which I won't test here.
  EXPECT_NE(Document(FieldValue::ObjectValue({}),
                     DocumentKey::FromPathString("same/path"),
                     SnapshotVersion(Timestamp()), false),
            MaybeDocument(DocumentKey::FromPathString("same/path"),
                          SnapshotVersion(Timestamp())));
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
