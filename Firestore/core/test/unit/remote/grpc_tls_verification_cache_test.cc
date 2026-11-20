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

#include "Firestore/core/src/remote/grpc_tls_verification_cache.h"

#include <chrono>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

using SystemTime = TlsVerificationCoalescer::SystemTime;
using SteadyTime = TlsVerificationCoalescer::SteadyTime;
using std::chrono::hours;
using std::chrono::minutes;
using std::chrono::seconds;

// Steady and wall clocks that the test advances by hand, together.
struct FakeClock {
  SteadyTime steady = SteadyTime() + hours(1);
  SystemTime now = SystemTime() + hours(24 * 365 * 50);

  void Advance(std::chrono::seconds amount) {
    steady += amount;
    now += amount;
  }

  TlsVerificationCoalescer::Clocks AsClocks() {
    return {[this] { return steady; }, [this] { return now; }};
  }
};

// TTL 5 min, pending evaluations presumed lost after 60 s.
std::unique_ptr<TlsVerificationCoalescer> MakeCoalescer(FakeClock* clock,
                                                        size_t capacity = 8) {
  return std::make_unique<TlsVerificationCoalescer>(
      minutes(5), seconds(60), capacity, clock->AsClocks());
}

// Records every evaluation started and lets the test finish it.
struct FakeStarts {
  std::vector<TlsVerificationCoalescer::Done> dones;
  TlsVerificationCoalescer::Start AsStart() {
    return [this](TlsVerificationCoalescer::Done done) {
      dones.push_back(std::move(done));
    };
  }
};

struct Results {
  std::vector<grpc::Status> statuses;
  TlsVerificationCoalescer::Waiter AsWaiter() {
    return
        [this](grpc::Status status) { statuses.push_back(std::move(status)); };
  }
};

grpc::Status Untrusted() {
  return grpc::Status(grpc::StatusCode::UNAUTHENTICATED, "untrusted");
}

TEST(TlsVerificationCoalescerTest, ConcurrentEvaluationsShareOneStart) {
  FakeClock clock;
  auto coalescer_ptr = MakeCoalescer(&clock);
  TlsVerificationCoalescer& coalescer = *coalescer_ptr;
  FakeStarts starts;
  Results results;

  for (int i = 0; i < 5; ++i) {
    coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  }
  ASSERT_EQ(starts.dones.size(), 1u);
  EXPECT_TRUE(results.statuses.empty());

  starts.dones[0](grpc::Status::OK, SystemTime::max());
  ASSERT_EQ(results.statuses.size(), 5u);
  for (const grpc::Status& status : results.statuses) {
    EXPECT_TRUE(status.ok());
  }

  // A duplicate completion is ignored.
  starts.dones[0](Untrusted(), SystemTime::max());
  EXPECT_EQ(results.statuses.size(), 5u);
}

TEST(TlsVerificationCoalescerTest, DifferentKeysDoNotShare) {
  FakeClock clock;
  auto coalescer_ptr = MakeCoalescer(&clock);
  TlsVerificationCoalescer& coalescer = *coalescer_ptr;
  FakeStarts starts;
  Results a, b;

  coalescer.Evaluate("a", starts.AsStart(), a.AsWaiter());
  coalescer.Evaluate("b", starts.AsStart(), b.AsWaiter());
  ASSERT_EQ(starts.dones.size(), 2u);
  starts.dones[1](Untrusted(), SystemTime::max());
  EXPECT_TRUE(a.statuses.empty());
  ASSERT_EQ(b.statuses.size(), 1u);
  EXPECT_EQ(b.statuses[0].error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST(TlsVerificationCoalescerTest, CacheHitSkipsEvaluation) {
  FakeClock clock;
  auto coalescer_ptr = MakeCoalescer(&clock);
  TlsVerificationCoalescer& coalescer = *coalescer_ptr;
  FakeStarts starts;
  Results results;

  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  starts.dones[0](grpc::Status::OK, SystemTime::max());
  EXPECT_EQ(coalescer.cache_size(), 1u);

  clock.Advance(minutes(4));
  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 1u);
  ASSERT_EQ(results.statuses.size(), 2u);
  EXPECT_TRUE(results.statuses[1].ok());
}

TEST(TlsVerificationCoalescerTest, CacheEntriesExpireAfterTtl) {
  FakeClock clock;
  auto coalescer_ptr = MakeCoalescer(&clock);
  TlsVerificationCoalescer& coalescer = *coalescer_ptr;
  FakeStarts starts;
  Results results;

  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  starts.dones[0](grpc::Status::OK, SystemTime::max());

  clock.Advance(minutes(5));
  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 2u);
  EXPECT_EQ(results.statuses.size(), 1u);
}

TEST(TlsVerificationCoalescerTest, CacheEntriesNeverOutliveCacheUntil) {
  FakeClock clock;
  auto coalescer_ptr = MakeCoalescer(&clock);
  TlsVerificationCoalescer& coalescer = *coalescer_ptr;
  FakeStarts starts;
  Results results;

  // The leaf expires in one minute, before the TTL.
  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  starts.dones[0](grpc::Status::OK, clock.now + minutes(1));

  clock.Advance(minutes(1));
  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 2u);

  // Already expired: not cached at all.
  starts.dones[1](grpc::Status::OK, clock.now - seconds(1));
  EXPECT_EQ(coalescer.cache_size(), 0u);
}

TEST(TlsVerificationCoalescerTest, FailuresAreNeverCached) {
  FakeClock clock;
  auto coalescer_ptr = MakeCoalescer(&clock);
  TlsVerificationCoalescer& coalescer = *coalescer_ptr;
  FakeStarts starts;
  Results results;

  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  starts.dones[0](Untrusted(), SystemTime::max());
  EXPECT_EQ(coalescer.cache_size(), 0u);

  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 2u);
}

TEST(TlsVerificationCoalescerTest, EvictsLeastRecentlyUsed) {
  FakeClock clock;
  auto coalescer_ptr = MakeCoalescer(&clock, 2);
  TlsVerificationCoalescer& coalescer = *coalescer_ptr;
  FakeStarts starts;
  Results results;

  for (const char* key : {"a", "b"}) {
    coalescer.Evaluate(key, starts.AsStart(), results.AsWaiter());
    starts.dones.back()(grpc::Status::OK, SystemTime::max());
  }
  // Touch "a" so that "b" is the least recently used.
  coalescer.Evaluate("a", starts.AsStart(), results.AsWaiter());
  coalescer.Evaluate("c", starts.AsStart(), results.AsWaiter());
  starts.dones.back()(grpc::Status::OK, SystemTime::max());
  EXPECT_EQ(coalescer.cache_size(), 2u);
  EXPECT_EQ(starts.dones.size(), 3u);

  coalescer.Evaluate("a", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 3u);  // Still cached.
  coalescer.Evaluate("b", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 4u);  // Evicted.
}

TEST(TlsVerificationCoalescerTest, WaitersRunWithoutTheLock) {
  FakeClock clock;
  auto coalescer_ptr = MakeCoalescer(&clock);
  TlsVerificationCoalescer& coalescer = *coalescer_ptr;
  FakeStarts starts;
  Results nested;
  int calls = 0;

  // A waiter that re-enters the coalescer would deadlock if it ran under the
  // lock.
  coalescer.Evaluate("key", starts.AsStart(), [&](grpc::Status) {
    ++calls;
    coalescer.Evaluate("key", starts.AsStart(), nested.AsWaiter());
  });
  starts.dones[0](grpc::Status::OK, SystemTime::max());
  EXPECT_EQ(calls, 1);
  ASSERT_EQ(nested.statuses.size(), 1u);  // Served from the cache.
  EXPECT_TRUE(nested.statuses[0].ok());
}

TEST(TlsVerificationCoalescerTest, WallClockChangesDoNotExtendCacheEntries) {
  FakeClock clock;
  auto coalescer = MakeCoalescer(&clock);
  FakeStarts starts;
  Results results;

  coalescer->Evaluate("key", starts.AsStart(), results.AsWaiter());
  starts.dones[0](grpc::Status::OK, SystemTime::max());

  // Setting the wall clock back does not keep the entry alive past the TTL.
  clock.now -= hours(1);
  clock.steady += minutes(5);
  coalescer->Evaluate("key", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 2u);
}

TEST(TlsVerificationCoalescerTest, StalePendingEvaluationIsNotJoined) {
  FakeClock clock;
  auto coalescer = MakeCoalescer(&clock);
  FakeStarts starts;
  Results old_waiter, joined, fresh;

  coalescer->Evaluate("key", starts.AsStart(), old_waiter.AsWaiter());
  clock.Advance(seconds(59));
  coalescer->Evaluate("key", starts.AsStart(), joined.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 1u);

  // The first evaluation is presumed lost after 60 s: a new one starts.
  clock.Advance(seconds(1));
  coalescer->Evaluate("key", starts.AsStart(), fresh.AsWaiter());
  ASSERT_EQ(starts.dones.size(), 2u);

  // The lost evaluation's waiters were dropped; the new generation resolves
  // only its own.
  starts.dones[1](grpc::Status::OK, SystemTime::max());
  EXPECT_TRUE(old_waiter.statuses.empty());
  EXPECT_TRUE(joined.statuses.empty());
  ASSERT_EQ(fresh.statuses.size(), 1u);

  // A late completion of the lost evaluation is ignored.
  starts.dones[0](Untrusted(), SystemTime::max());
  EXPECT_TRUE(old_waiter.statuses.empty());
  EXPECT_TRUE(joined.statuses.empty());
  EXPECT_EQ(fresh.statuses.size(), 1u);
  // The late failure does not evict the fresh success.
  EXPECT_EQ(coalescer->cache_size(), 1u);
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
