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

#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_VERIFICATION_CACHE_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_VERIFICATION_CACHE_H_

#include <chrono>
#include <cstdint>
#include <functional>
#include <list>
#include <mutex>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/src/util/warnings.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/support/status.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {

/**
 * Coalesces concurrent TLS chain evaluations with the same key and caches
 * successful results for a short time.
 *
 * - If a successful result for `key` is cached and has not expired,
 *   `Evaluate()` invokes `waiter` with OK before returning and does not call
 *   `start`.
 * - Otherwise, if an evaluation for `key` started less than
 *   `max_pending_age` ago is still in flight, `waiter` is attached to it and
 *   `start` is not called. An older evaluation is presumed lost: a new one is
 *   started, and the old one, should it ever finish, resolves only its own
 *   waiters.
 * - Otherwise `start` is called (once, without any lock held) to begin a new
 *   evaluation. When it calls the `Done` it was given, every waiter attached
 *   to that evaluation is invoked exactly once with the status, without any
 *   lock held. Later calls to that `Done` are ignored. An OK status is cached
 *   for `ttl`, but never past `cache_until`; failures are never cached.
 *
 * The cache holds at most `capacity` entries and evicts the least recently
 * used. Cancellation is not handled here: callers that need it (such as
 * `AsyncTlsVerifier`, whose tracker ignores completions for cancelled
 * verifications) simply ignore their waiter's later invocation. A shared
 * evaluation therefore always runs to completion for the remaining waiters.
 *
 * Thread-safe. Must outlive every evaluation it starts.
 */
class TlsVerificationCoalescer {
 public:
  using SystemTime = std::chrono::system_clock::time_point;
  using SteadyTime = std::chrono::steady_clock::time_point;
  using Waiter = std::function<void(grpc::Status)>;
  /**
   * Reports an evaluation's result, and the wall-clock time after which a
   * success must no longer be served from the cache (such as the leaf
   * certificate's notAfter; `SystemTime::max()` if unknown).
   */
  using Done = std::function<void(grpc::Status status, SystemTime cache_until)>;
  using Start = std::function<void(Done done)>;

  /** Clocks, replaceable in tests. */
  struct Clocks {
    std::function<SteadyTime()> steady;
    std::function<SystemTime()> system;
  };

  TlsVerificationCoalescer(std::chrono::seconds ttl,
                           std::chrono::seconds max_pending_age,
                           size_t capacity,
                           Clocks clocks = {});

  TlsVerificationCoalescer(const TlsVerificationCoalescer&) = delete;
  TlsVerificationCoalescer& operator=(const TlsVerificationCoalescer&) = delete;

  void Evaluate(const std::string& key, const Start& start, Waiter waiter);

  /** For tests only. */
  size_t cache_size() const;

 private:
  struct Group {
    std::string key;
    SteadyTime started;
    std::vector<Waiter> waiters;
  };

  struct CacheEntry {
    SteadyTime expiry;
    std::list<std::string>::iterator lru_position;
  };

  void Finish(uint64_t generation, grpc::Status status, SystemTime cache_until);

  const std::chrono::seconds ttl_;
  const std::chrono::seconds max_pending_age_;
  const size_t capacity_;
  const Clocks clocks_;

  mutable std::mutex mutex_;
  uint64_t next_generation_ = 1;
  // Every evaluation in flight, by generation.
  std::unordered_map<uint64_t, Group> groups_;
  // The generation new waiters for a key may join.
  std::unordered_map<std::string, uint64_t> joinable_;
  std::unordered_map<std::string, CacheEntry> cache_;
  // Most recently used at the front.
  std::list<std::string> lru_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_VERIFICATION_CACHE_H_
