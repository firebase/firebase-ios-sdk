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

#include "Firestore/core/src/remote/connectivity_monitor.h"

#include "Firestore/core/src/util/hard_assert.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::AsyncQueue;

// Returns the default monitor that does nothing. This is to ensure that
// build doesn't break on platforms which don't yet implement
// `ConnectivityMonitor`.
std::unique_ptr<ConnectivityMonitor> ConnectivityMonitor::Create(
    const std::shared_ptr<AsyncQueue>& worker_queue) {
  return absl::make_unique<ConnectivityMonitor>(worker_queue);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
