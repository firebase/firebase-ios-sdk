/*
 * Copyright 2025 Google LLC
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

#ifndef FIRESTORE_CORE_TEST_UNIT_CORE_PIPELINE_UTILS_H_
#define FIRESTORE_CORE_TEST_UNIT_CORE_PIPELINE_UTILS_H_

#include <memory>
#include <string>
#include <unordered_set>
#include <vector>

#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"  // Include for gtest types used in MATCHER_P

namespace firebase {
namespace firestore {
namespace core {

// Provides a shared placeholder Firestore instance for pipeline tests.
std::unique_ptr<remote::Serializer> TestSerializer();

// Basic matcher to compare document vectors by key.
// TODO(wuandy): Enhance to compare contents if necessary.
MATCHER_P(ReturnsDocs, expected_docs, "") {
  if (arg.size() != expected_docs.size()) {
    *result_listener << "Expected " << expected_docs.size()
                     << " documents, but got " << arg.size();
    return false;
  }
  for (size_t i = 0; i < arg.size(); ++i) {
    if (arg[i].key() != expected_docs[i].key()) {
      *result_listener << "Document at index " << i
                       << " mismatch. Expected key: "
                       << expected_docs[i].key().ToString()
                       << ", got key: " << arg[i].key().ToString();
      return false;
    }
    // Optionally add content comparison here if needed
  }
  return true;
}

MATCHER_P(ReturnsDocsIgnoringOrder, expected_docs, "") {
  if (arg.size() != expected_docs.size()) {
    *result_listener << "Expected " << expected_docs.size()
                     << " documents, but got " << arg.size();
    return false;
  }
  std::unordered_set<std::string> expected_keys;
  for (size_t i = 0; i < expected_docs.size(); ++i) {
    expected_keys.insert(expected_docs[i].key().ToString());
  }

  for (const auto& actual : arg) {
    if (expected_keys.find(actual.key().ToString()) == expected_keys.end()) {
      *result_listener << "Document " << actual.key().ToString()
                       << " was not found in expected documents";
      return false;
    }
  }

  return true;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_CORE_PIPELINE_UTILS_H_
