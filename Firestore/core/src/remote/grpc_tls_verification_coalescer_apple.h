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

#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_VERIFICATION_COALESCER_APPLE_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_VERIFICATION_COALESCER_APPLE_H_

#include <chrono>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

#include "Firestore/core/src/util/warnings.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/support/status.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {

/**
 * Coalesces concurrent TLS chain evaluations with the same key, so that they
 * share one evaluation.
 *
 * Used by the Apple verifier to mitigate trustd stalls: when trustd is slow,
 * gRPC abandons handshakes after about 20 seconds and retries them, and
 * without coalescing each retry would queue another evaluation behind the
 * stalled ones. The logic itself is plain C++ and is built only for Apple
 * platforms. Results are not cached: once an evaluation completes, the next
 * request for its key starts a new one.
 *
 * - If an evaluation for `key` started less than `max_pending_age` ago is in
 *   flight, `Evaluate()` attaches `waiter` to it and does not call `start`.
 * - Otherwise it calls `start` (once, without any lock held) to begin a new
 *   evaluation. When that evaluation calls the `Done` it was given, every
 *   waiter attached to it is invoked exactly once with the status, without any
 *   lock held. Later calls to that `Done` are ignored.
 * - An in-flight evaluation older than `max_pending_age` is presumed lost. The
 *   next `Evaluate()` for its key starts a new evaluation and moves to it the
 *   lost evaluation's waiters that joined less than `max_pending_age` ago
 *   (each waiter moves at most once, since its join time is kept); older
 *   waiters are invoked with `UNAVAILABLE`. The lost evaluation's `Done`,
 *   should it ever run, is ignored.
 *
 * Cancellation is not handled here: callers that need it (such as
 * `AsyncTlsVerifier`, whose tracker ignores completions for cancelled
 * verifications) simply ignore their waiter's later invocation. A shared
 * evaluation therefore always runs to completion for the remaining waiters.
 *
 * Thread-safe. Must outlive every evaluation it starts.
 */
class TlsVerificationCoalescer {
 public:
  using SteadyTime = std::chrono::steady_clock::time_point;
  using Waiter = std::function<void(grpc::Status)>;
  using Done = std::function<void(grpc::Status)>;
  using Start = std::function<void(Done done)>;
  using Clock = std::function<SteadyTime()>;

  /** `clock` defaults to `std::chrono::steady_clock::now`. */
  explicit TlsVerificationCoalescer(std::chrono::seconds max_pending_age,
                                    Clock clock = nullptr);

  TlsVerificationCoalescer(const TlsVerificationCoalescer&) = delete;
  TlsVerificationCoalescer& operator=(const TlsVerificationCoalescer&) = delete;

  void Evaluate(const std::string& key, const Start& start, Waiter waiter);

  /** Returns the number of evaluations in flight. For tests only. */
  size_t pending_count() const;

 private:
  struct PendingWaiter {
    SteadyTime joined;
    Waiter callback;
  };

  struct Group {
    std::string key;
    SteadyTime started;
    std::vector<PendingWaiter> waiters;
  };

  void Finish(uint64_t generation, grpc::Status status);

  const std::chrono::seconds max_pending_age_;
  const Clock clock_;

  mutable std::mutex mutex_;
  uint64_t next_generation_ = 1;
  // Every evaluation in flight, by generation.
  std::unordered_map<uint64_t, Group> groups_;
  // The generation new waiters for a key may join.
  std::unordered_map<std::string, uint64_t> joinable_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_VERIFICATION_COALESCER_APPLE_H_
