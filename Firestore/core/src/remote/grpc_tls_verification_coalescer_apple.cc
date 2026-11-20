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

#include "Firestore/core/src/remote/grpc_tls_verification_coalescer_apple.h"

namespace firebase {
namespace firestore {
namespace remote {

TlsVerificationCoalescer::TlsVerificationCoalescer(
    std::chrono::seconds ttl,
    std::chrono::seconds max_pending_age,
    size_t capacity,
    Clocks clocks)
    : ttl_(ttl),
      max_pending_age_(max_pending_age),
      capacity_(capacity),
      clocks_{clocks.steady ? std::move(clocks.steady)
                            : [] { return std::chrono::steady_clock::now(); },
              clocks.system ? std::move(clocks.system)
                            : [] { return std::chrono::system_clock::now(); }} {
}

void TlsVerificationCoalescer::Evaluate(const std::string& key,
                                        const Start& start,
                                        Waiter waiter) {
  uint64_t generation = 0;
  std::vector<Waiter> expired_waiters;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    SteadyTime now = clocks_.steady();

    auto cached = cache_.find(key);
    if (cached != cache_.end()) {
      if (now < cached->second.expiry) {
        lru_.splice(lru_.begin(), lru_, cached->second.lru_position);
        generation = 0;
      } else {
        lru_.erase(cached->second.lru_position);
        cache_.erase(cached);
        cached = cache_.end();
      }
    }

    if (cached == cache_.end()) {
      std::vector<PendingWaiter> migrated_waiters;
      auto joinable = joinable_.find(key);
      if (joinable != joinable_.end()) {
        Group& group = groups_.at(joinable->second);
        if (now - group.started < max_pending_age_) {
          group.waiters.push_back(PendingWaiter{now, std::move(waiter)});
          return;
        }
        // Presumed lost: forget it, and let a new generation take over the
        // key. Waiters younger than `max_pending_age_` move to the new
        // generation with their original join times (so each migrates at most
        // once); older waiters time out outside the lock. The lost
        // generation's `Done`, should it ever run, is ignored.
        for (PendingWaiter& pending : group.waiters) {
          if (now - pending.joined < max_pending_age_) {
            migrated_waiters.push_back(std::move(pending));
          } else {
            expired_waiters.push_back(std::move(pending.callback));
          }
        }
        groups_.erase(joinable->second);
        joinable_.erase(joinable);
      }
      generation = next_generation_++;
      migrated_waiters.push_back(PendingWaiter{now, std::move(waiter)});
      groups_[generation] = Group{key, now, std::move(migrated_waiters)};
      joinable_[key] = generation;
    }
  }

  if (generation == 0) {
    waiter(grpc::Status::OK);  // Cache hit.
    return;
  }
  if (!expired_waiters.empty()) {
    const grpc::Status timeout(grpc::StatusCode::UNAVAILABLE,
                               "TLS certificate verification timed out");
    for (Waiter& expired : expired_waiters) {
      expired(timeout);
    }
    expired_waiters.clear();
  }
  start([this, generation](grpc::Status status, SystemTime cache_until) {
    Finish(generation, std::move(status), cache_until);
  });
}

void TlsVerificationCoalescer::Finish(uint64_t generation,
                                      grpc::Status status,
                                      SystemTime cache_until) {
  std::vector<PendingWaiter> waiters;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = groups_.find(generation);
    if (it == groups_.end()) return;  // Duplicate or superseded completion.
    std::string key = std::move(it->second.key);
    waiters = std::move(it->second.waiters);
    groups_.erase(it);
    auto joinable = joinable_.find(key);
    if (joinable != joinable_.end() && joinable->second == generation) {
      joinable_.erase(joinable);
    }

    // `cache_until` is wall-clock time; the TTL and expiry use the steady
    // clock, so that adjusting the wall clock cannot extend an entry.
    SystemTime system_now = clocks_.system();
    if (status.ok() && capacity_ > 0 && ttl_ > std::chrono::seconds::zero() &&
        system_now < cache_until) {
      std::chrono::seconds lifetime = ttl_;
      if (system_now > SystemTime::max() - ttl_ ||
          cache_until < system_now + ttl_) {
        lifetime = std::chrono::duration_cast<std::chrono::seconds>(
            cache_until - system_now);
      }
      if (lifetime > std::chrono::seconds::zero()) {
        SteadyTime expiry = clocks_.steady() + lifetime;

        auto existing = cache_.find(key);
        if (existing != cache_.end()) {
          lru_.erase(existing->second.lru_position);
          cache_.erase(existing);
        }
        lru_.push_front(key);
        cache_[key] = CacheEntry{expiry, lru_.begin()};
        while (cache_.size() > capacity_) {
          cache_.erase(lru_.back());
          lru_.pop_back();
        }
      }
    }
  }
  for (PendingWaiter& waiter : waiters) {
    waiter.callback(status);
  }
}

size_t TlsVerificationCoalescer::cache_size() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return cache_.size();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
