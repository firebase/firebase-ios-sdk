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
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"

namespace firebase {
namespace firestore {
namespace remote {

using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::TimerId;
namespace chr = std::chrono;

ExponentialBackoff::ExponentialBackoff(AsyncQueue* queue,
                                       TimerId timer_id,
                                       double backoff_factor,
                                       Milliseconds initial_delay,
                                       Milliseconds max_delay)
    : queue_{queue},
      timer_id_{timer_id},
      backoff_factor_{backoff_factor},
      initial_delay_{initial_delay},
      max_delay_{max_delay} {
  HARD_ASSERT(queue, "Queue can't be null");

  HARD_ASSERT(backoff_factor >= 1.0, "Backoff factor must be at least 1");

  HARD_ASSERT(initial_delay.count() >= 0, "Delays must be non-negative");
  HARD_ASSERT(max_delay.count() >= 0, "Delays must be non-negative");
  HARD_ASSERT(initial_delay <= max_delay,
              "Initial delay can't be greater than max delay");
}

void ExponentialBackoff::BackoffAndRun(AsyncQueue::Operation&& operation) {
  Cancel();

  // First schedule the block using the current base (which may be 0 and should
  // be honored as such).
  Milliseconds delay_with_jitter = current_base_ + GetDelayWithJitter();
  if (delay_with_jitter.count() > 0) {
    LOG_DEBUG("Backing off for %s milliseconds (base delay: %s milliseconds)",
              delay_with_jitter.count(), current_base_.count());
  }

  delayed_operation_ = queue_->EnqueueAfterDelay(delay_with_jitter, timer_id_,
                                                 std::move(operation));

  // Apply backoff factor to determine next delay, but ensure it is within
  // bounds.
  current_base_ = ClampDelay(
      chr::duration_cast<Milliseconds>(current_base_ * backoff_factor_));
}

ExponentialBackoff::Milliseconds ExponentialBackoff::GetDelayWithJitter() {
  std::uniform_real_distribution<double> distribution;
  double random_double = distribution(secure_random_);
  return chr::duration_cast<Milliseconds>((random_double - 0.5) *
                                          current_base_);
}

ExponentialBackoff::Milliseconds ExponentialBackoff::ClampDelay(
    Milliseconds delay) const {
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
