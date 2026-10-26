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
// destructed on the AsyncQueue passed to the constructor (enforced by
// HARD_ASSERT in both constructor and destructor).
//
// The NWPathMonitor update handler and the iOS foreground-notification
// observer block both dispatch work onto the AsyncQueue. Those
// dispatched lambdas capture raw `this` and a std::weak_ptr<State>
// liveness token. Their safety relies on:
//   1. Outer handler blocks check `weak_state.expired()` but never hold
//      a strong `State` reference across `Enqueue`. Thus, calling
//      `state_.reset()` in the destructor immediately invalidates all
//      future and not-yet-run inner lambdas.
//   2. The destructor cancels the monitor, resets `state_`, and drains
//      `monitor_queue_` via `dispatch_sync`, ensuring that any in-flight
//      outer handler completes before destruction finishes.
//   3. The constructor, destructor, and inner lambdas all run on the same
//      serial AsyncQueue, so inner lambdas and destruction cannot interleave.
//      Any inner lambda already queued when destruction begins will observe
//      an expired `weak_state` when it runs and safely bail out without
//      dereferencing `this`.
//
// If construction or destruction is moved off the AsyncQueue, these
// invariants break and inner lambdas may dereference a dangling `this` pointer.
//
// Tests that create a ConnectivityMonitorApple directly must
// explicitly construct and destroy it on its AsyncQueue:
//   std::unique_ptr<ConnectivityMonitorApple> monitor;
//   worker_queue->EnqueueBlocking([&] {
//     monitor = std::make_unique<ConnectivityMonitorApple>(worker_queue);
//   });
//   ...
//   worker_queue->EnqueueBlocking([&] { monitor.reset(); });
// See FSTConnectivityMonitorTests for examples.
class ConnectivityMonitorApple : public ConnectivityMonitor {
 public:
  explicit ConnectivityMonitorApple(
      const std::shared_ptr<util::AsyncQueue>& worker_queue);
  ~ConnectivityMonitorApple() override;

  // Expose for testing. Test-only, must be called on the AsyncQueue.
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
