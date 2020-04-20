/*
 * Copyright 2018 Google LLC
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

#ifndef FIRESTORE_CORE_TEST_UNIT_TESTUTIL_APP_TESTING_H_
#define FIRESTORE_CORE_TEST_UNIT_TESTUTIL_APP_TESTING_H_

#include "absl/strings/string_view.h"

#if __OBJC__

@class FIRApp;
@class FIROptions;

namespace firebase {
namespace firestore {
namespace testutil {

/** Creates a set of default Firebase Options for testing. */
FIROptions* OptionsForUnitTesting(absl::string_view project_id = "project-id");

/** Creates a new Firebase App for testing. */
FIRApp* AppForUnitTesting(absl::string_view project_id = "project-id");

/** Creates a new Firebase App for testing from the given options. */
FIRApp* AppForUnitTesting(FIROptions* options);

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // __OBJC__

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_APP_TESTING_H_
