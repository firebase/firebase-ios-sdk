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

#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/util/status_fwd.h"
#include "absl/strings/str_replace.h"

namespace firebase {
namespace firestore {
namespace testutil {

inline std::vector<std::string> BundleTemplate() {
  std::string metadata =
      R"|({"metadata":{"id":"test-bundle","createTime":{"seconds":1001,)|"
      R"|("nanos":9999},)|"
      R"|("version":1,"totalDocuments":2,"totalBytes":{totalBytes}}})|";

  std::string named_query1 =
      R"|({"namedQuery":{"name":"limit","readTime":{"seconds":1000,)|"
      R"|("nanos":9999},)|"
      R"|("bundledQuery":{"parent":"projects/{projectId}/databases/(default)/)|"
      R"|(documents",)|"
      R"|("structuredQuery":{"from":[{"collectionId":"coll-1"}],)|"
      R"|("orderBy":)|"
      R"|([{"field":{"fieldPath":"bar"},"direction":"DESCENDING"},{)|"
      R"|("field":)|"
      R"|({"fieldPath":"__name__"},"direction":"DESCENDING"}],"limit":)|"
      R"|({"value":1}},"limitType":"FIRST"}}})|";

  std::string named_query2 =
      R"|({"namedQuery":{"name":"limit-to-last","readTime":{"seconds":)|"
      R"|(1000,"nanos":9999},)|"
      R"|("bundledQuery":{"parent":"projects/{projectId}/databases/(default)/)|"
      R"|(documents",)|"
      R"|("structuredQuery":{"from":[{"collectionId":"coll-1"}],)|"
      R"|("orderBy":)|"
      R"|([{"field":{"fieldPath":"bar"},"direction":"DESCENDING"},{)|"
      R"|("field":)|"
      R"|({"fieldPath":"__name__"},"direction":"DESCENDING"}],"limit":)|"
      R"|({"value":1}},"limitType":"LAST"}}})|";

  std::string document_metadata1 =
      R"|({"documentMetadata":{"name":)|"
      R"|("projects/{projectId}/databases/(default)/documents/coll-1/)|"
      R"|(a","readTime":)|"
      R"|({"seconds":1000,"nanos":9999},"exists":true}})|";

  std::string document_1 =
      R"|({"document":{"name":"projects/{projectId}/databases/(default)/)|"
      R"|(documents/coll-1/a",)|"
      R"|("createTime":{"seconds":1,"nanos":9},"updateTime":{"seconds":)|"
      R"|(1,)|"
      R"|("nanos":9},"fields":{"k":{"stringValue":"a"},"bar":)|"
      R"|({"integerValue":1}}}})|";

  std::string document_metadata2 =
      R"|({"documentMetadata":{"name":)|"
      R"|("projects/{projectId}/databases/(default)/documents/coll-1/)|"
      R"|(b","readTime":)|"
      R"|({"seconds":1000,"nanos":9999},"exists":true}})|";

  std::string document_2 =
      R"|({"document":{"name":"projects/{projectId}/databases/(default)/)|"
      R"|(documents/coll-1/b",)|"
      R"|("createTime":{"seconds":1,"nanos":9},"updateTime":{"seconds":)|"
      R"|(1,)|"
      R"|("nanos":9},"fields":{"k":{"stringValue":"b"},"bar":)|"
      R"|({"integerValue":2}}}})|";

  return {metadata,   named_query1,       named_query2, document_metadata1,
          document_1, document_metadata2, document_2};
}

inline std::string CreateBundle(const std::string& project_id) {
  std::string bundle;

  auto bundle_template = BundleTemplate();
  for (size_t i = 1; i < bundle_template.size(); ++i) {
    auto element =
        absl::StrReplaceAll(bundle_template[i], {{"{projectId}", project_id}});
    bundle.append(std::to_string(element.size()));
    bundle.append(std::move(element));
  }

  std::string metadata = absl::StrReplaceAll(
      bundle_template[0], {{"{totalBytes}", std::to_string(bundle.size())}});
  return std::to_string(metadata.size()) + metadata + bundle;
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_BUNDLE_BUILDER_H_
