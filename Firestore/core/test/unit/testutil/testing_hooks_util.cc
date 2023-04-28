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

#include "Firestore/core/test/unit/testutil/testing_hooks_util.h"

#include <functional>
#include <memory>
#include <mutex>
#include <vector>

#include "Firestore/core/src/api/listener_registration.h"
#include "Firestore/core/src/util/defer.h"
#include "Firestore/core/src/util/testing_hooks.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"

namespace firebase {
namespace firestore {
namespace testutil {

using util::Defer;
using util::TestingHooks;

std::vector<TestingHooks::ExistenceFilterMismatchInfo>
CaptureExistenceFilterMismatches(std::function<void()> callback) {
  auto accumulator = AsyncAccumulator<
      TestingHooks::ExistenceFilterMismatchInfo>::NewInstance();

  TestingHooks& testing_hooks = TestingHooks::GetInstance();
  std::shared_ptr<api::ListenerRegistration> registration =
      testing_hooks.OnExistenceFilterMismatch(accumulator->AsCallback());
  Defer unregister_callback([registration]() { registration->Remove(); });

  callback();

  std::vector<TestingHooks::ExistenceFilterMismatchInfo> mismatches;
  while (!accumulator->IsEmpty()) {
    mismatches.push_back(accumulator->Shift());
  }

  return mismatches;
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
