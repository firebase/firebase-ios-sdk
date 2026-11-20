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

#include <chrono>
#include <string>
#include <utility>
#include <vector>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

using SteadyTime = TlsVerificationCoalescer::SteadyTime;
using std::chrono::hours;
using std::chrono::seconds;

// A clock the test advances by hand.
struct FakeClock {
  SteadyTime now = SteadyTime() + hours(1);
  TlsVerificationCoalescer::Clock AsClock() {
    return [this] { return now; };
  }
};

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
  TlsVerificationCoalescer coalescer(seconds(60), clock.AsClock());
  FakeStarts starts;
  Results results;

  for (int i = 0; i < 5; ++i) {
    coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  }
  ASSERT_EQ(starts.dones.size(), 1u);
  EXPECT_TRUE(results.statuses.empty());

  starts.dones[0](grpc::Status::OK);
  ASSERT_EQ(results.statuses.size(), 5u);
  for (const grpc::Status& status : results.statuses) {
    EXPECT_TRUE(status.ok());
  }
  EXPECT_EQ(coalescer.pending_count(), 0u);

  // A duplicate completion is ignored.
  starts.dones[0](Untrusted());
  EXPECT_EQ(results.statuses.size(), 5u);
}

TEST(TlsVerificationCoalescerTest, DifferentKeysDoNotShare) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(seconds(60), clock.AsClock());
  FakeStarts starts;
  Results a, b;

  coalescer.Evaluate("a", starts.AsStart(), a.AsWaiter());
  coalescer.Evaluate("b", starts.AsStart(), b.AsWaiter());
  ASSERT_EQ(starts.dones.size(), 2u);
  starts.dones[1](Untrusted());
  EXPECT_TRUE(a.statuses.empty());
  ASSERT_EQ(b.statuses.size(), 1u);
  EXPECT_EQ(b.statuses[0].error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST(TlsVerificationCoalescerTest, CompletedEvaluationsAreNotReused) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(seconds(60), clock.AsClock());
  FakeStarts starts;
  Results results;

  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  starts.dones[0](grpc::Status::OK);

  // No caching: the next request starts a new evaluation.
  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  ASSERT_EQ(starts.dones.size(), 2u);
  EXPECT_EQ(results.statuses.size(), 1u);
  starts.dones[1](grpc::Status::OK);
  EXPECT_EQ(results.statuses.size(), 2u);
}

TEST(TlsVerificationCoalescerTest, FailuresAreSharedOnlyWithinTheGroup) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(seconds(60), clock.AsClock());
  FakeStarts starts;
  Results first, second, later;

  coalescer.Evaluate("key", starts.AsStart(), first.AsWaiter());
  coalescer.Evaluate("key", starts.AsStart(), second.AsWaiter());
  starts.dones[0](Untrusted());
  ASSERT_EQ(first.statuses.size(), 1u);
  ASSERT_EQ(second.statuses.size(), 1u);
  EXPECT_EQ(second.statuses[0].error_code(), grpc::StatusCode::UNAUTHENTICATED);

  coalescer.Evaluate("key", starts.AsStart(), later.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 2u);
  EXPECT_TRUE(later.statuses.empty());
}

TEST(TlsVerificationCoalescerTest, StalePendingEvaluationIsReplaced) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(seconds(60), clock.AsClock());
  FakeStarts starts;
  Results old_waiter, recent_waiter, fresh;

  coalescer.Evaluate("key", starts.AsStart(), old_waiter.AsWaiter());
  clock.now += seconds(30);
  coalescer.Evaluate("key", starts.AsStart(), recent_waiter.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 1u);

  // 60 s after it started, the first evaluation is presumed lost: a new one
  // starts. The waiter that joined 30 s ago moves to it; the original one,
  // now 60 s old, times out.
  clock.now += seconds(30);
  coalescer.Evaluate("key", starts.AsStart(), fresh.AsWaiter());
  ASSERT_EQ(starts.dones.size(), 2u);
  ASSERT_EQ(old_waiter.statuses.size(), 1u);
  EXPECT_EQ(old_waiter.statuses[0].error_code(), grpc::StatusCode::UNAVAILABLE);
  EXPECT_TRUE(recent_waiter.statuses.empty());
  EXPECT_EQ(coalescer.pending_count(), 1u);

  // The new generation resolves the moved and new waiters.
  starts.dones[1](grpc::Status::OK);
  ASSERT_EQ(recent_waiter.statuses.size(), 1u);
  EXPECT_TRUE(recent_waiter.statuses[0].ok());
  ASSERT_EQ(fresh.statuses.size(), 1u);

  // A late completion of the lost evaluation is ignored.
  starts.dones[0](Untrusted());
  EXPECT_EQ(old_waiter.statuses.size(), 1u);
  EXPECT_EQ(recent_waiter.statuses.size(), 1u);
  EXPECT_EQ(fresh.statuses.size(), 1u);
}

TEST(TlsVerificationCoalescerTest, MovedWaitersTimeOutOnTheNextRollover) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(seconds(60), clock.AsClock());
  FakeStarts starts;
  Results original, moved, trigger1, trigger2;

  coalescer.Evaluate("key", starts.AsStart(), original.AsWaiter());
  clock.now += seconds(30);
  coalescer.Evaluate("key", starts.AsStart(), moved.AsWaiter());
  clock.now += seconds(30);
  coalescer.Evaluate("key", starts.AsStart(), trigger1.AsWaiter());
  EXPECT_TRUE(moved.statuses.empty());  // Moved to generation 2.

  // Generation 2 is lost too; by now `moved` joined 90 s ago and times out
  // instead of moving again.
  clock.now += seconds(60);
  coalescer.Evaluate("key", starts.AsStart(), trigger2.AsWaiter());
  ASSERT_EQ(starts.dones.size(), 3u);
  ASSERT_EQ(moved.statuses.size(), 1u);
  EXPECT_EQ(moved.statuses[0].error_code(), grpc::StatusCode::UNAVAILABLE);
}

TEST(TlsVerificationCoalescerTest, WaitersRunWithoutTheLock) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(seconds(60), clock.AsClock());
  FakeStarts starts;
  Results nested;
  int calls = 0;

  // A waiter that re-enters the coalescer would deadlock if it ran under the
  // lock.
  coalescer.Evaluate("key", starts.AsStart(), [&](grpc::Status) {
    ++calls;
    coalescer.Evaluate("key", starts.AsStart(), nested.AsWaiter());
  });
  starts.dones[0](grpc::Status::OK);
  EXPECT_EQ(calls, 1);
  EXPECT_EQ(starts.dones.size(), 2u);  // The nested request started anew.
  EXPECT_TRUE(nested.statuses.empty());
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
