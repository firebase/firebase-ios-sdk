/*
 * Copyright 2019 Google
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

#include "Firestore/core/test/firebase/firestore/testutil/async_testing.h"

#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace testutil {

using util::AsyncQueue;
using util::Executor;

std::unique_ptr<util::Executor> ExecutorForTesting(const char* name) {
  std::string label = absl::StrCat("firestore.testing.", name);
  return Executor::CreateSerial(label.c_str());
}

std::shared_ptr<util::AsyncQueue> AsyncQueueForTesting() {
  return std::make_shared<AsyncQueue>(ExecutorForTesting("worker"));
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
