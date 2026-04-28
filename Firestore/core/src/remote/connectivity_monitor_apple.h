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

class ConnectivityMonitorApple : public ConnectivityMonitor {
 public:
  explicit ConnectivityMonitorApple(
      const std::shared_ptr<util::AsyncQueue>& worker_queue);
  ~ConnectivityMonitorApple() override;

  // Expose for testing
  absl::optional<NetworkStatus> GetCurrentStatus() const {
    return current_status_;
  }

 protected:
  bool foreground_transition_pending_ = false;
  bool initial_status_set_ = false;

 private:
  nw_path_monitor_t monitor_ = nullptr;
  absl::optional<NetworkStatus> current_status_;
  std::shared_ptr<bool> alive_;
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
  id<NSObject> observer_ = nil;
#endif
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // defined(__APPLE__)

#endif  // FIRESTORE_CORE_SRC_REMOTE_CONNECTIVITY_MONITOR_APPLE_H_
