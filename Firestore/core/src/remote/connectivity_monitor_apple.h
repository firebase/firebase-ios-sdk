/*
 * Copyright 2026 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_REMOTE_CONNECTIVITY_MONITOR_APPLE_H_
#define FIRESTORE_CORE_SRC_REMOTE_CONNECTIVITY_MONITOR_APPLE_H_

#include <memory>

#include "Firestore/core/src/remote/connectivity_monitor.h"

#if defined(__APPLE__)

#import <Network/Network.h>
#include <dispatch/dispatch.h>

namespace firebase {
namespace firestore {
namespace remote {

// IMPORTANT: ConnectivityMonitorApple must be both constructed AND
// destructed on the AsyncQueue passed to the constructor.
//
// The NWPathMonitor update handler and the iOS foreground-notification
// observer block both dispatch work onto the AsyncQueue. Those
// dispatched lambdas capture raw `this` and a std::weak_ptr<State>
// liveness token. Their safety relies on:
//   1. The destructor calls dispatch_sync on monitor_queue_ to drain
//      any in-flight outer handler blocks before resetting state_.
//   2. The destructor and the inner lambdas run on the same serial
//      AsyncQueue, so they cannot interleave.
//
// If destruction is moved off the AsyncQueue, invariant (2) breaks
// and inner lambdas may dereference a dangling `this` pointer.
class ConnectivityMonitorApple : public ConnectivityMonitor {
 public:
  explicit ConnectivityMonitorApple(
      const std::shared_ptr<util::AsyncQueue>& worker_queue);
  ~ConnectivityMonitorApple() override;

  // Expose for testing. Test-only, must be called after AsyncQueue activity has
  // settled.
  absl::optional<NetworkStatus> GetCurrentStatus() const {
    return current_status();
  }

 private:
  // Liveness token used by handler blocks to detect destruction.
  // Held via std::shared_ptr; handlers capture std::weak_ptr<State>.
  // Intentionally empty — see class-level comment for why holding
  // weak_ptr<State> + raw `this` is sufficient under our destructor
  // invariant.
  struct State {};

  nw_path_monitor_t monitor_ = nullptr;
  dispatch_queue_t monitor_queue_ = nullptr;
  std::shared_ptr<State> state_;
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
  id<NSObject> observer_ = nil;
#endif
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // defined(__APPLE__)

#endif  // FIRESTORE_CORE_SRC_REMOTE_CONNECTIVITY_MONITOR_APPLE_H_
