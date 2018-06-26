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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_EXPONENTIAL_BACKOFF_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_EXPONENTIAL_BACKOFF_H_

#include <chrono>

#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/secure_random.h"

namespace firebase {
namespace firestore {
namespace remote {

class ExponentialBackoff {
 public:
  /**
   * Initializes a helper for running delayed tasks following an exponential
   * backoff curve between attempts.
   *
   * Each delay is made up of a "base" delay which follows the exponential
   * backoff curve, and a +/- <=50% "jitter" that is calculated and added to the
   * base delay. This prevents clients from accidentally synchronizing their
   * delays causing spikes of load to the backend.
   *
   * @param queue The queue to run operations on.
   * @param timer_id The id to use when scheduling backoff operations on the
   *     queue.
   * @param backoff_factor The multiplier to use to determine the extended base
   *     delay after each attempt.
   * @param initial_delay The initial delay (used as the base delay on the first
   *     retry attempt). Note that jitter will still be applied, so the actual
   *     delay could be as little as `0.5*initial_delay`.
   * @param max_delay The maximum base delay after which no further backoff is
   *     performed. Note that jitter will still be applied, so the actual delay
   *     could be as much as `1.5*max_delay`.
   */
  ExponentialBackoff(util::AsyncQueue* queue,
                     util::TimerId timer_id,
                     double backoff_factor,
                     util::AsyncQueue::Milliseconds initial_delay,
                     util::AsyncQueue::Milliseconds max_delay)
      : queue_{queue},
        timer_id_{timer_id},
        backoff_factor_{backoff_factor},
        initial_delay_{initial_delay},
        max_delay_{max_delay} {
  }

  /**
   * Resets the backoff delay.
   *
   * The very next `backoffAndRun` will have no delay. If it is called again
   * (i.e. due to an error), `initial_delay` (plus jitter) will be used, and
   * subsequent ones will increase according to the `backoff_factor`.
   */
  void Reset() {
    current_base_ = RealSeconds{0};
  }

  /**
   * Resets the backoff to the maximum delay (e.g. for use after
   * a RESOURCE_EXHAUSTED error).
   */
  void ResetToMax() {
    current_base_ = max_delay_;
  }

  /**
   * Waits for `current_base` seconds, increases the delay and runs the
   * specified operation. If there was a pending operation waiting to be run
   * already, it will be canceled.
   */
  void BackoffAndRun(util::AsyncQueue::Operation&& operation);

  /** Cancels any pending backoff operation scheduled via `BackoffAndRun`. */
  void Cancel() {
    delayed_operation_.Cancel();
  }

 private:
  using RealSeconds = std::chrono::duration<double>;

  RealSeconds GetDelayWithJitter();
  RealSeconds ClampDelay(RealSeconds delay) const;

  util::AsyncQueue* queue_;
  util::TimerId timer_id_;
  util::DelayedOperation delayed_operation_;

  double backoff_factor_;
  RealSeconds current_base_{0};
  util::AsyncQueue::Milliseconds initial_delay_;
  util::AsyncQueue::Milliseconds max_delay_;
  util::SecureRandom secure_random_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_EXPONENTIAL_BACKOFF_H_
