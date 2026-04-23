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

#include "Firestore/core/src/remote/connectivity_monitor_apple.h"
#include "Firestore/core/src/remote/connectivity_monitor.h"

#if defined(__APPLE__)

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
#import <UIKit/UIKit.h>
#endif

#import <Network/Network.h>
#include <dispatch/dispatch.h>

#include <memory>

#include "Firestore/core/src/util/log.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace {

using NetworkStatus = ConnectivityMonitor::NetworkStatus;
using util::AsyncQueue;

NetworkStatus ToNetworkStatus(nw_path_t path) {
  nw_path_status_t status = nw_path_get_status(path);
  if (status != nw_path_status_satisfied) {
    return NetworkStatus::Unavailable;
  }

#if TARGET_OS_IPHONE || TARGET_OS_VISION
  if (nw_path_uses_interface_type(path, nw_interface_type_cellular)) {
    return NetworkStatus::AvailableViaCellular;
  }
#endif
  return NetworkStatus::Available;
}

}  // namespace

ConnectivityMonitorApple::ConnectivityMonitorApple(
    const std::shared_ptr<AsyncQueue>& worker_queue)
    : ConnectivityMonitor{worker_queue} {
  monitor_ = nw_path_monitor_create();
  if (!monitor_) {
    LOG_DEBUG("Failed to create network monitor.");
    return;
  }

  dispatch_queue_attr_t attrs = dispatch_queue_attr_make_with_qos_class(
      DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY,
      DISPATCH_QUEUE_PRIORITY_DEFAULT);
  monitor_queue_ = dispatch_queue_create(
      "com.google.firebase.firestore.network.monitor", attrs);

  nw_path_monitor_set_queue(monitor_, monitor_queue_);

  // Capture `this` is safe because we call `nw_path_monitor_cancel` in the
  // destructor, which ensures no more callbacks are delivered.
  nw_path_monitor_set_update_handler(monitor_, ^(nw_path_t path) {
    auto status = ToNetworkStatus(path);
    this->queue()->Enqueue([this, status] {
      if (!this->current_status_.has_value()) {
        this->current_status_ = status;
        this->SetInitialStatus(status);
      } else {
        this->current_status_ = status;
        this->MaybeInvokeCallbacks(status);
      }
    });
  });

  nw_path_monitor_start(monitor_);

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
  this->observer_ = [[NSNotificationCenter defaultCenter]
      addObserverForName:UIApplicationWillEnterForegroundNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification* note) {
                NSLog(@"ConnectivityMonitorApple: Received "
                      @"UIApplicationWillEnterForegroundNotification");
                this->queue()->Enqueue([this] {
                  // Force a reconnect by invoking callbacks with the current
                  // status
                  if (this->current_status_.has_value() &&
                      this->current_status_.value() !=
                          NetworkStatus::Unavailable) {
                    NSLog(@"ConnectivityMonitorApple: Invoking callbacks on "
                          @"foreground");
                    this->InvokeCallbacks(this->current_status_.value());
                  } else {
                    NSLog(@"ConnectivityMonitorApple: Skipping callbacks on "
                          @"foreground, has_value: %d, status: %d",
                          this->current_status_.has_value(),
                          this->current_status_.has_value()
                              ? (int)this->current_status_.value()
                              : -1);
                  }
                });
              }];
#endif
}

ConnectivityMonitorApple::~ConnectivityMonitorApple() {
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
  if (this->observer_) {
    [[NSNotificationCenter defaultCenter] removeObserver:this->observer_];
    this->observer_ = nil;
  }
#endif
  if (monitor_) {
    nw_path_monitor_set_update_handler(monitor_, nil);
    nw_path_monitor_cancel(monitor_);
    monitor_ = nil;
  }
}

std::unique_ptr<ConnectivityMonitor> ConnectivityMonitor::Create(
    const std::shared_ptr<AsyncQueue>& worker_queue) {
  return absl::make_unique<ConnectivityMonitorApple>(worker_queue);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // defined(__APPLE__)
