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

#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"

#include "absl/strings/string_view.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

namespace {

inline MaybeDocument MakeMaybeDocument(const absl::string_view path,
                                       const Timestamp& timestamp) {
  return MaybeDocument(DocumentKey::FromPathString(path.data()),
                       SnapshotVersion(timestamp));
}

inline bool operator<(const MaybeDocument& lhs, const MaybeDocument& rhs) {
  static const DocumentKeyComparator less;
  return less(lhs, rhs);
}

}  // anonymous namespace

TEST(MaybeDocument, Getter) {
  const MaybeDocument& doc =
      MakeMaybeDocument("i/am/a/path", Timestamp(123, 456));
  EXPECT_EQ(MaybeDocument::Type::Unknown, doc.type());
  EXPECT_EQ(DocumentKey::FromPathString("i/am/a/path"), doc.key());
  EXPECT_EQ(SnapshotVersion(Timestamp(123, 456)), doc.version());
}

TEST(MaybeDocument, Comparison) {
  EXPECT_TRUE(MakeMaybeDocument("root/123", Timestamp(456, 123)) <
              MakeMaybeDocument("root/456", Timestamp(123, 456)));
  // MaybeDocument comparision is purely key-based.
  EXPECT_FALSE(MakeMaybeDocument("root/123", Timestamp(111, 111)) <
               MakeMaybeDocument("root/123", Timestamp(222, 222)));

  EXPECT_EQ(MakeMaybeDocument("root/123", Timestamp(456, 123)),
            MakeMaybeDocument("root/123", Timestamp(456, 123)));
  EXPECT_NE(MakeMaybeDocument("root/123", Timestamp(456, 123)),
            MakeMaybeDocument("root/456", Timestamp(456, 123)));
  EXPECT_NE(MakeMaybeDocument("root/123", Timestamp(456, 123)),
            MakeMaybeDocument("root/123", Timestamp(123, 456)));
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
