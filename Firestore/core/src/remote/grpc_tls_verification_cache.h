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
#include <functional>
#include <list>
#include <mutex>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/src/util/warnings.h"
#include "absl/strings/string_view.h"
#include "absl/types/optional.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/support/status.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {

/**
 * Returns the `notAfter` time of the DER-encoded X.509 certificate `der`, or
 * `nullopt` if it cannot be parsed. Only the RFC 5280 forms are accepted:
 * `UTCTime` (`YYMMDDHHMMSSZ`) and `GeneralizedTime` (`YYYYMMDDHHMMSSZ`).
 */
absl::optional<std::chrono::system_clock::time_point> ParseCertificateNotAfter(
    absl::string_view der);

/**
 * Coalesces concurrent TLS chain evaluations with the same key and caches
 * successful results for a short time.
 *
 * - If a successful result for `key` is cached and has not expired,
 *   `Evaluate()` invokes `waiter` with OK before returning and does not call
 *   `start`.
 * - Otherwise, if an evaluation for `key` is already in flight, `waiter` is
 *   attached to it and `start` is not called.
 * - Otherwise `start` is called (once, without any lock held) to begin a new
 *   evaluation. When it calls the `Done` it was given, every attached waiter
 *   is invoked exactly once with the status, without any lock held. An OK
 *   status is cached until the earlier of `now + ttl` and `cache_until`;
 *   failures are never cached.
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
  using TimePoint = std::chrono::system_clock::time_point;
  using Clock = std::function<TimePoint()>;
  using Waiter = std::function<void(grpc::Status)>;
  /** Reports an evaluation's result and how long a success may be cached. */
  using Done = std::function<void(grpc::Status status, TimePoint cache_until)>;
  using Start = std::function<void(Done done)>;

  TlsVerificationCoalescer(std::chrono::seconds ttl,
                           size_t capacity,
                           Clock clock = &std::chrono::system_clock::now);

  TlsVerificationCoalescer(const TlsVerificationCoalescer&) = delete;
  TlsVerificationCoalescer& operator=(const TlsVerificationCoalescer&) = delete;

  void Evaluate(const std::string& key, const Start& start, Waiter waiter);

  /** For tests only. */
  size_t cache_size() const;

 private:
  struct CacheEntry {
    TimePoint expiry;
    std::list<std::string>::iterator lru_position;
  };

  void Finish(const std::string& key,
              grpc::Status status,
              TimePoint cache_until);

  const std::chrono::seconds ttl_;
  const size_t capacity_;
  const Clock clock_;

  mutable std::mutex mutex_;
  std::unordered_map<std::string, std::vector<Waiter>> pending_;
  std::unordered_map<std::string, CacheEntry> cache_;
  // Most recently used at the front.
  std::list<std::string> lru_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_VERIFICATION_CACHE_H_
