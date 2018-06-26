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

#include "Firestore/core/src/firebase/firestore/remote/exponential_backoff.h"

#include <random>

#include "Firestore/core/src/firebase/firestore/util/log.h"

using firebase::firestore::util::AsyncQueue;

namespace firebase {
namespace firestore {
namespace remote {

namespace chr = std::chrono;

void ExponentialBackoff::BackoffAndRun(AsyncQueue::Operation&& operation) {
  Cancel();

  // First schedule the block using the current base (which may be 0 and should
  // be honored as such).
  const auto delay_with_jitter = chr::duration_cast<chr::milliseconds>(
      current_base_ + GetDelayWithJitter());
  if (delay_with_jitter.count() > 0) {
    LOG_DEBUG("Backing off for %s milliseconds (base delay: %s seconds)",
              delay_with_jitter.count(), current_base_.count());
  }

  delayed_operation_ = queue_->EnqueueAfterDelay(delay_with_jitter, timer_id_,
                                                 std::move(operation));

  // Apply backoff factor to determine next delay, but ensure it is within
  // bounds.
  current_base_ = ClampDelay(current_base_ * backoff_factor_);
}

/** Returns a random value in the range [-current_base_/2, current_base_/2] */
auto ExponentialBackoff::GetDelayWithJitter() -> RealSeconds {
  std::uniform_real_distribution<double> distribution;
  const auto random_double = distribution(secure_random_);
  return (random_double - 0.5) * current_base_;
}

auto ExponentialBackoff::ClampDelay(const RealSeconds delay) const
    -> RealSeconds {
  if (delay < initial_delay_) {
    return initial_delay_;
  }
  if (delay > max_delay_) {
    return max_delay_;
  }
  return delay;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
