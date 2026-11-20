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

#include <utility>

namespace firebase {
namespace firestore {
namespace remote {

TlsVerificationCoalescer::TlsVerificationCoalescer(
    std::chrono::seconds max_pending_age, Clock clock)
    : max_pending_age_(max_pending_age), clock_(clock ? std::move(clock) : [] {
        return std::chrono::steady_clock::now();
      }) {
}

void TlsVerificationCoalescer::Evaluate(const std::string& key,
                                        const Start& start,
                                        Waiter waiter) {
  uint64_t generation = 0;
  std::vector<Waiter> expired_waiters;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    SteadyTime now = clock_();
    std::vector<PendingWaiter> waiters;

    auto joinable = joinable_.find(key);
    if (joinable != joinable_.end()) {
      Group& group = groups_.at(joinable->second);
      if (now - group.started < max_pending_age_) {
        group.waiters.push_back(PendingWaiter{now, std::move(waiter)});
        return;
      }
      // Presumed lost: a new generation takes over the key. Waiters that
      // joined recently move to it with their original join times (so each
      // moves at most once); older ones time out, outside the lock. The lost
      // generation's `Done`, should it ever run, is ignored.
      for (PendingWaiter& pending : group.waiters) {
        if (now - pending.joined < max_pending_age_) {
          waiters.push_back(std::move(pending));
        } else {
          expired_waiters.push_back(std::move(pending.callback));
        }
      }
      groups_.erase(joinable->second);
      joinable_.erase(joinable);
    }

    generation = next_generation_++;
    waiters.push_back(PendingWaiter{now, std::move(waiter)});
    groups_[generation] = Group{key, now, std::move(waiters)};
    joinable_[key] = generation;
  }

  if (!expired_waiters.empty()) {
    const grpc::Status timeout(grpc::StatusCode::UNAVAILABLE,
                               "TLS certificate verification timed out");
    for (Waiter& expired : expired_waiters) {
      expired(timeout);
    }
  }
  start([this, generation](grpc::Status status) {
    Finish(generation, std::move(status));
  });
}

void TlsVerificationCoalescer::Finish(uint64_t generation,
                                      grpc::Status status) {
  std::vector<PendingWaiter> waiters;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = groups_.find(generation);
    if (it == groups_.end()) return;  // Duplicate or superseded completion.
    waiters = std::move(it->second.waiters);
    auto joinable = joinable_.find(it->second.key);
    if (joinable != joinable_.end() && joinable->second == generation) {
      joinable_.erase(joinable);
    }
    groups_.erase(it);
  }
  for (PendingWaiter& waiter : waiters) {
    waiter.callback(status);
  }
}

size_t TlsVerificationCoalescer::pending_count() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return groups_.size();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
