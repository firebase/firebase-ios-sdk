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

#include "Firestore/core/src/firebase/firestore/local/reference_set.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

using model::DocumentKey;

TEST(ReferenceSetTest, AddOrRemoveReferences) {
  DocumentKey key = testutil::Key("foo/bar");

  ReferenceSet referenceSet{};
  EXPECT_TRUE(referenceSet.empty());
  EXPECT_FALSE(referenceSet.ContainsKey(key));

  referenceSet.AddReference(key, 1);
  EXPECT_TRUE(referenceSet.ContainsKey(key));
  EXPECT_FALSE(referenceSet.empty());

  referenceSet.AddReference(key, 2);
  EXPECT_TRUE(referenceSet.ContainsKey(key));

  referenceSet.RemoveReference(key, 1);
  EXPECT_TRUE(referenceSet.ContainsKey(key));

  referenceSet.RemoveReference(key, 3);
  EXPECT_TRUE(referenceSet.ContainsKey(key));

  referenceSet.RemoveReference(key, 2);
  EXPECT_FALSE(referenceSet.ContainsKey(key));
  EXPECT_TRUE(referenceSet.empty());
}

TEST(ReferenceSetTest, RemoteAllReferencesForTargetId) {
  DocumentKey key1 = testutil::Key("foo/bar");
  DocumentKey key2 = testutil::Key("foo/baz");
  DocumentKey key3 = testutil::Key("foo/blah");
  ReferenceSet referenceSet{};

  referenceSet.AddReference(key1, 1);
  referenceSet.AddReference(key2, 1);
  referenceSet.AddReference(key3, 2);
  EXPECT_FALSE(referenceSet.empty());
  EXPECT_TRUE(referenceSet.ContainsKey(key1));
  EXPECT_TRUE(referenceSet.ContainsKey(key2));
  EXPECT_TRUE(referenceSet.ContainsKey(key3));

  referenceSet.RemoveReferences(1);
  EXPECT_FALSE(referenceSet.empty());
  EXPECT_FALSE(referenceSet.ContainsKey(key1));
  EXPECT_FALSE(referenceSet.ContainsKey(key2));
  EXPECT_TRUE(referenceSet.ContainsKey(key3));

  referenceSet.RemoveReferences(2);
  EXPECT_TRUE(referenceSet.empty());
  EXPECT_FALSE(referenceSet.ContainsKey(key1));
  EXPECT_FALSE(referenceSet.ContainsKey(key2));
  EXPECT_FALSE(referenceSet.ContainsKey(key3));
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
