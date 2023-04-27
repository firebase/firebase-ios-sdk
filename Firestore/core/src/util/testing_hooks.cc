/*
 * Copyright 2023 Google LLC
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

#include <mutex>
#include <vector>

#include "Firestore/core/src/util/testing_hooks.h"

#include "absl/base/attributes.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

using ExistenceFilterMismatchCallback =
    std::function<void(const TestingHooks::ExistenceFilterMismatchInfo&)>;

class OnExistenceFilterMismatchListenerRegistration final
    : public api::ListenerRegistration {
 public:
  void Remove() override {
  }
};

}  // namespace

ABSL_ATTRIBUTE_UNUSED  // This function is only used in integration tests
    std::shared_ptr<api::ListenerRegistration>
    TestingHooks::OnExistenceFilterMismatch(
        ExistenceFilterMismatchCallback callback) {
  (void)callback;
  return std::make_shared<OnExistenceFilterMismatchListenerRegistration>();
}

void TestingHooks::NotifyOnExistenceFilterMismatch(
    const ExistenceFilterMismatchInfo& info) {
  (void)info;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
