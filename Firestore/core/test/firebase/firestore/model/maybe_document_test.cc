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

inline MaybeDocument MakeDocument(const absl::string_view path, int second) {
  return DocumentKey::FromPathString(path), SnapshotVersion(Timestamp(second, 777));
}

}  // anonymous namespace

TEST(MaybeDocument, Getter) {
  const MaybeDocument& doc = MakeDocument("i/am/a/path", 123);
  EXPECT_EQ(DocumentKey::FromPathString("i/am/a/path"), doc.key());
  EXPECT_EQ(SnapshotVersion(Timestamp(123, 456)), doc.timestamp());
}

TEST(MaybeDocument, Comparison) {
  EXPECT_LT(MakeDocument("123", 456), MakeDocument("456", 123));
  EXPECT_GT(MakeDocument("456", 123), MakeDocument("123", 456));
  EXPECT_LE(MakeDocument("123", 456), MakeDocument("456", 123));
  EXPECT_LE(MakeDocument("123", 456), MakeDocument("123", 456));
  EXPECT_GE(MakeDocument("456", 123), MakeDocument("123", 456));
  EXPECT_GE(MakeDocument("456", 123), MakeDocument("456", 123));
  EXPECT_EQ(MakeDocument("123", 456), MakeDocument("123", 456));
  EXPECT_NE(MakeDocument("123", 456), MakeDocument("456", 123));
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
