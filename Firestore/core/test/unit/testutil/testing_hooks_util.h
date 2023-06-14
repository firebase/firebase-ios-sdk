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

#ifndef FIRESTORE_CORE_TEST_UNIT_TESTUTIL_TESTING_HOOKS_UTIL_H_
#define FIRESTORE_CORE_TEST_UNIT_TESTUTIL_TESTING_HOOKS_UTIL_H_

#include <functional>
#include <vector>

#include "Firestore/core/src/util/testing_hooks.h"

namespace firebase {
namespace firestore {
namespace testutil {

/**
 * Captures all existence filter mismatches in the Watch 'Listen' stream that
 * occur during the execution of the given callback.
 * @param callback The callback to invoke; during the invocation of this
 * callback all existence filter mismatches will be captured.
 * @return the captured existence filter mismatches.
 */
std::vector<util::TestingHooks::ExistenceFilterMismatchInfo>
CaptureExistenceFilterMismatches(std::function<void()> callback);

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_TESTING_HOOKS_UTIL_H_
