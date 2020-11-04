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

#include "Firestore/core/src/model/no_document.h"

#include "Firestore/core/src/model/unknown_document.h"
#include "absl/strings/string_view.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

namespace {

inline NoDocument MakeNoDocument(absl::string_view path,
                                 const Timestamp& timestamp) {
  return NoDocument(DocumentKey::FromPathString(path.data()),
                    SnapshotVersion(timestamp),
                    /*has_committed_mutations=*/false);
}

}  // namespace

TEST(NoDocument, Getter) {
  const NoDocument& doc = MakeNoDocument("i/am/a/path", Timestamp(123, 456));
  EXPECT_EQ(MaybeDocument::Type::NoDocument, doc.type());
  EXPECT_EQ(DocumentKey::FromPathString("i/am/a/path"), doc.key());
  EXPECT_EQ(SnapshotVersion(Timestamp(123, 456)), doc.version());

  // NoDocument and UnknownDocument will not equal.
  EXPECT_NE(NoDocument(DocumentKey::FromPathString("same/path"),
                       SnapshotVersion(Timestamp()),
                       /*has_committed_mutations=*/false),
            UnknownDocument(DocumentKey::FromPathString("same/path"),
                            SnapshotVersion(Timestamp())));
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
