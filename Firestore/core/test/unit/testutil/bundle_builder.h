/*
 * Copyright 2021 Google LLC
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
#ifndef FIRESTORE_CORE_TEST_UNIT_TESTUTIL_BUNDLE_BUILDER_H_
#define FIRESTORE_CORE_TEST_UNIT_TESTUTIL_BUNDLE_BUILDER_H_

#include <array>
#include <string>
#include <vector>

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/util/status_fwd.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace testutil {

namespace {

std::array<std::string, 7> BundleTemplate() {
  std::string metadata =
      "{\"metadata\":{\"id\":\"test-bundle\",\"createTime\":{\"seconds\":1001,"
      "\"nanos\":9999},"
      "\"version\":1,\"totalDocuments\":2,\"totalBytes\":{totalBytes}}}";
  std::string named_query1 =
      "{\"namedQuery\":{\"name\":\"limit\",\"readTime\":{\"seconds\":1000,"
      "\"nanos\":9999},"
      "\"bundledQuery\":{\"parent\":\"projects/{projectId}/databases/(default)/"
      "documents\","
      "\"structuredQuery\":{\"from\":[{\"collectionId\":\"coll-1\"}],"
      "\"orderBy\":"
      "[{\"field\":{\"fieldPath\":\"bar\"},\"direction\":\"DESCENDING\"},{"
      "\"field\":"
      "{\"fieldPath\":\"__name__\"},\"direction\":\"DESCENDING\"}],\"limit\":"
      "{\"value\":1}},\"limitType\":\"FIRST\"}}}";
  std::string named_query2 =
      "{\"namedQuery\":{\"name\":\"limit-to-last\",\"readTime\":{\"seconds\":"
      "1000,\"nanos\":9999},"
      "\"bundledQuery\":{\"parent\":\"projects/{projectId}/databases/(default)/"
      "documents\","
      "\"structuredQuery\":{\"from\":[{\"collectionId\":\"coll-1\"}],"
      "\"orderBy\":"
      "[{\"field\":{\"fieldPath\":\"bar\"},\"direction\":\"DESCENDING\"},{"
      "\"field\":"
      "{\"fieldPath\":\"__name__\"},\"direction\":\"DESCENDING\"}],\"limit\":"
      "{\"value\":1}},\"limitType\":\"LAST\"}}}";
  std::string document_metadata1 =
      "{\"documentMetadata\":{\"name\":"
      "\"projects/{projectId}/databases/(default)/documents/coll-1/"
      "a\",\"readTime\":"
      "{\"seconds\":1000,\"nanos\":9999},\"exists\":true}}";
  std::string document_1 =
      "{\"document\":{\"name\":\"projects/{projectId}/databases/(default)/"
      "documents/coll-1/a\","
      "\"createTime\":{\"seconds\":1,\"nanos\":9},\"updateTime\":{\"seconds\":"
      "1,"
      "\"nanos\":9},\"fields\":{\"k\":{\"stringValue\":\"a\"},\"bar\":"
      "{\"integerValue\":1}}}}";
  std::string document_metadata2 =
      "{\"documentMetadata\":{\"name\":"
      "\"projects/{projectId}/databases/(default)/documents/coll-1/"
      "b\",\"readTime\":"
      "{\"seconds\":1000,\"nanos\":9999},\"exists\":true}}";
  std::string document_2 =
      "{\"document\":{\"name\":\"projects/{projectId}/databases/(default)/"
      "documents/coll-1/b\","
      "\"createTime\":{\"seconds\":1,\"nanos\":9},\"updateTime\":{\"seconds\":"
      "1,"
      "\"nanos\":9},\"fields\":{\"k\":{\"stringValue\":\"b\"},\"bar\":"
      "{\"integerValue\":2}}}}";
  return {metadata,   named_query1,       named_query2, document_metadata1,
          document_1, document_metadata2, document_2};
}

std::string ReplaceAll(std::string str,
                       const std::string& from,
                       const std::string& to) {
  size_t start_pos = 0;
  while ((start_pos = str.find(from, start_pos)) != std::string::npos) {
    str.replace(start_pos, from.length(), to);
    start_pos +=
        to.length();  // Handles case where 'to' is a substring of 'from'
  }
  return str;
}

}  // namespace

std::string CreateBundle(const std::string& project_id) {
  std::string bundle;

  auto bundle_tempalte = BundleTemplate();
  for (size_t i = 1; i < bundle_tempalte.size(); ++i) {
    auto element = ReplaceAll(bundle_tempalte[i], "{projectId}", project_id);
    bundle.append(std::to_string(element.size()));
    bundle.append(std::move(element));
  }

  std::string metadata = ReplaceAll(bundle_tempalte[0], "{totalBytes}",
                                    std::to_string(bundle.size()));
  return std::to_string(metadata.size()) + metadata + bundle;
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_BUNDLE_BUILDER_H_
