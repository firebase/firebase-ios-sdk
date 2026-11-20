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
#include <string>
#include <utility>
#include <vector>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

using TimePoint = TlsVerificationCoalescer::TimePoint;
using std::chrono::hours;
using std::chrono::minutes;
using std::chrono::seconds;

// A clock the test advances by hand.
struct FakeClock {
  TimePoint now = TimePoint() + hours(24 * 365 * 50);
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
  TlsVerificationCoalescer coalescer(minutes(5), 8, clock.AsClock());
  FakeStarts starts;
  Results results;

  for (int i = 0; i < 5; ++i) {
    coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  }
  ASSERT_EQ(starts.dones.size(), 1u);
  EXPECT_TRUE(results.statuses.empty());

  starts.dones[0](grpc::Status::OK, clock.now + hours(1));
  ASSERT_EQ(results.statuses.size(), 5u);
  for (const grpc::Status& status : results.statuses) {
    EXPECT_TRUE(status.ok());
  }

  // A duplicate completion is ignored.
  starts.dones[0](Untrusted(), clock.now + hours(1));
  EXPECT_EQ(results.statuses.size(), 5u);
}

TEST(TlsVerificationCoalescerTest, DifferentKeysDoNotShare) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(minutes(5), 8, clock.AsClock());
  FakeStarts starts;
  Results a, b;

  coalescer.Evaluate("a", starts.AsStart(), a.AsWaiter());
  coalescer.Evaluate("b", starts.AsStart(), b.AsWaiter());
  ASSERT_EQ(starts.dones.size(), 2u);
  starts.dones[1](Untrusted(), clock.now + hours(1));
  EXPECT_TRUE(a.statuses.empty());
  ASSERT_EQ(b.statuses.size(), 1u);
  EXPECT_EQ(b.statuses[0].error_code(), grpc::StatusCode::UNAUTHENTICATED);
}

TEST(TlsVerificationCoalescerTest, CacheHitSkipsEvaluation) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(minutes(5), 8, clock.AsClock());
  FakeStarts starts;
  Results results;

  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  starts.dones[0](grpc::Status::OK, clock.now + hours(1));
  EXPECT_EQ(coalescer.cache_size(), 1u);

  clock.now += minutes(4);
  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 1u);
  ASSERT_EQ(results.statuses.size(), 2u);
  EXPECT_TRUE(results.statuses[1].ok());
}

TEST(TlsVerificationCoalescerTest, CacheEntriesExpireAfterTtl) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(minutes(5), 8, clock.AsClock());
  FakeStarts starts;
  Results results;

  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  starts.dones[0](grpc::Status::OK, clock.now + hours(1));

  clock.now += minutes(5);
  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 2u);
  EXPECT_EQ(results.statuses.size(), 1u);
}

TEST(TlsVerificationCoalescerTest, CacheEntriesNeverOutliveCacheUntil) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(minutes(5), 8, clock.AsClock());
  FakeStarts starts;
  Results results;

  // The leaf expires in one minute, before the TTL.
  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  starts.dones[0](grpc::Status::OK, clock.now + minutes(1));

  clock.now += minutes(1);
  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 2u);

  // Already expired: not cached at all.
  starts.dones[1](grpc::Status::OK, clock.now - seconds(1));
  EXPECT_EQ(coalescer.cache_size(), 0u);
}

TEST(TlsVerificationCoalescerTest, FailuresAreNeverCached) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(minutes(5), 8, clock.AsClock());
  FakeStarts starts;
  Results results;

  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  starts.dones[0](Untrusted(), clock.now + hours(1));
  EXPECT_EQ(coalescer.cache_size(), 0u);

  coalescer.Evaluate("key", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 2u);
}

TEST(TlsVerificationCoalescerTest, EvictsLeastRecentlyUsed) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(minutes(5), 2, clock.AsClock());
  FakeStarts starts;
  Results results;

  for (const char* key : {"a", "b"}) {
    coalescer.Evaluate(key, starts.AsStart(), results.AsWaiter());
    starts.dones.back()(grpc::Status::OK, clock.now + hours(1));
  }
  // Touch "a" so that "b" is the least recently used.
  coalescer.Evaluate("a", starts.AsStart(), results.AsWaiter());
  coalescer.Evaluate("c", starts.AsStart(), results.AsWaiter());
  starts.dones.back()(grpc::Status::OK, clock.now + hours(1));
  EXPECT_EQ(coalescer.cache_size(), 2u);
  EXPECT_EQ(starts.dones.size(), 3u);

  coalescer.Evaluate("a", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 3u);  // Still cached.
  coalescer.Evaluate("b", starts.AsStart(), results.AsWaiter());
  EXPECT_EQ(starts.dones.size(), 4u);  // Evicted.
}

TEST(TlsVerificationCoalescerTest, WaitersRunWithoutTheLock) {
  FakeClock clock;
  TlsVerificationCoalescer coalescer(minutes(5), 8, clock.AsClock());
  FakeStarts starts;
  Results nested;
  int calls = 0;

  // A waiter that re-enters the coalescer would deadlock if it ran under the
  // lock.
  coalescer.Evaluate("key", starts.AsStart(), [&](grpc::Status) {
    ++calls;
    coalescer.Evaluate("key", starts.AsStart(), nested.AsWaiter());
  });
  starts.dones[0](grpc::Status::OK, clock.now + hours(1));
  EXPECT_EQ(calls, 1);
  ASSERT_EQ(nested.statuses.size(), 1u);  // Served from the cache.
  EXPECT_TRUE(nested.statuses[0].ok());
}

// --- ParseCertificateNotAfter ------------------------------------------------

std::string Tlv(uint8_t tag, const std::string& value) {
  std::string out(1, static_cast<char>(tag));
  if (value.size() < 0x80) {
    out += static_cast<char>(value.size());
  } else {
    out += static_cast<char>(0x82);
    out += static_cast<char>(value.size() >> 8);
    out += static_cast<char>(value.size() & 0xff);
  }
  return out + value;
}

// A certificate skeleton with the given notBefore/notAfter TLVs. Fields after
// the validity are omitted; the parser stops there.
std::string CertWithValidity(const std::string& not_before,
                             const std::string& not_after,
                             bool with_version = true) {
  std::string tbs;
  if (with_version) tbs += Tlv(0xa0, Tlv(0x02, std::string(1, '\x02')));
  tbs += Tlv(0x02, std::string(1, '\x01'));     // serialNumber
  tbs += Tlv(0x30, Tlv(0x06, "\x2a\x86\x48"));  // signature
  tbs += Tlv(0x30, std::string(150, 'i'));      // issuer (long form length)
  tbs += Tlv(0x30, not_before + not_after);     // validity
  return Tlv(0x30, Tlv(0x30, tbs) + Tlv(0x30, ""));
}

TimePoint Utc(int y, int mo, int d, int h, int mi, int s) {
  // Days from 1970-01-01, matching the parser's civil-date conversion.
  int64_t yy = y - (mo <= 2);
  int64_t era = (yy >= 0 ? yy : yy - 399) / 400;
  int64_t yoe = yy - era * 400;
  int64_t doy = (153 * (mo + (mo > 2 ? -3 : 9)) + 2) / 5 + d - 1;
  int64_t doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
  int64_t days = era * 146097 + doe - 719468;
  return TimePoint(std::chrono::duration_cast<TimePoint::duration>(
      seconds(days * 86400 + h * 3600 + mi * 60 + s)));
}

TEST(ParseCertificateNotAfterTest, ParsesUtcTime) {
  auto not_after = ParseCertificateNotAfter(
      CertWithValidity(Tlv(0x17, "260101000000Z"), Tlv(0x17, "270315123456Z")));
  ASSERT_TRUE(not_after.has_value());
  EXPECT_EQ(*not_after, Utc(2027, 3, 15, 12, 34, 56));
  // Epoch sanity check: 1970-01-01T00:00:00Z.
  EXPECT_EQ(Utc(1970, 1, 1, 0, 0, 0).time_since_epoch().count(), 0);
}

TEST(ParseCertificateNotAfterTest, ParsesUtcTimeBefore2000) {
  auto not_after = ParseCertificateNotAfter(
      CertWithValidity(Tlv(0x17, "960101000000Z"), Tlv(0x17, "991231235959Z")));
  ASSERT_TRUE(not_after.has_value());
  EXPECT_EQ(*not_after, Utc(1999, 12, 31, 23, 59, 59));
}

TEST(ParseCertificateNotAfterTest, ParsesGeneralizedTime) {
  auto not_after = ParseCertificateNotAfter(
      CertWithValidity(Tlv(0x17, "260101000000Z"), Tlv(0x18, "20500229000000Z"),
                       /*with_version=*/false));
  EXPECT_FALSE(not_after.has_value());  // 2050 is not a leap year.
  not_after = ParseCertificateNotAfter(
      CertWithValidity(Tlv(0x17, "260101000000Z"), Tlv(0x18, "20520229000000Z"),
                       /*with_version=*/false));
  ASSERT_TRUE(not_after.has_value());
  EXPECT_EQ(*not_after, Utc(2052, 2, 29, 0, 0, 0));
}

TEST(ParseCertificateNotAfterTest, RejectsMalformedInput) {
  EXPECT_FALSE(ParseCertificateNotAfter("").has_value());
  EXPECT_FALSE(ParseCertificateNotAfter("\x30\x05\x30").has_value());
  // Non-Zulu, fractional, or wrongly sized times.
  for (const std::string& bad :
       {Tlv(0x17, "270315123456+0100"), Tlv(0x17, "2703151234Z"),
        Tlv(0x18, "20270315123456.5Z"), Tlv(0x17, "271315123456Z"),
        Tlv(0x04, "270315123456Z")}) {
    EXPECT_FALSE(ParseCertificateNotAfter(
                     CertWithValidity(Tlv(0x17, "260101000000Z"), bad))
                     .has_value());
  }
  // Truncated certificate.
  std::string cert =
      CertWithValidity(Tlv(0x17, "260101000000Z"), Tlv(0x17, "270315123456Z"));
  EXPECT_FALSE(
      ParseCertificateNotAfter(cert.substr(0, cert.size() - 10)).has_value());
}

}  // namespace
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
