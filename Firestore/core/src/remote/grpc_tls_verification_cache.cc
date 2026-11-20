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

#include <algorithm>
#include <cstdint>

#include "absl/strings/ascii.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

// Reads one DER TLV from the front of `*in`. On success, stores the tag and
// value, advances `*in` past the TLV, and returns true.
bool ReadTlv(absl::string_view* in, uint8_t* tag, absl::string_view* value) {
  if (in->size() < 2) return false;
  *tag = static_cast<uint8_t>((*in)[0]);
  size_t pos = 1;
  size_t length = static_cast<uint8_t>((*in)[pos++]);
  if (length & 0x80) {
    size_t num_bytes = length & 0x7f;
    if (num_bytes == 0 || num_bytes > 4 || in->size() < pos + num_bytes) {
      return false;
    }
    length = 0;
    for (size_t i = 0; i < num_bytes; ++i) {
      length = (length << 8) | static_cast<uint8_t>((*in)[pos++]);
    }
  }
  if (in->size() - pos < length) return false;
  *value = in->substr(pos, length);
  in->remove_prefix(pos + length);
  return true;
}

bool ReadExpected(absl::string_view* in,
                  uint8_t expected_tag,
                  absl::string_view* value) {
  uint8_t tag = 0;
  return ReadTlv(in, &tag, value) && tag == expected_tag;
}

bool ParseDigits(absl::string_view s, int* out) {
  int value = 0;
  for (char c : s) {
    if (!absl::ascii_isdigit(static_cast<unsigned char>(c))) return false;
    value = value * 10 + (c - '0');
  }
  *out = value;
  return true;
}

// Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's
// days_from_civil).
int64_t DaysFromCivil(int64_t y, unsigned m, unsigned d) {
  y -= m <= 2;
  const int64_t era = (y >= 0 ? y : y - 399) / 400;
  const unsigned yoe = static_cast<unsigned>(y - era * 400);
  const unsigned doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
  const unsigned doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
  return era * 146097 + static_cast<int64_t>(doe) - 719468;
}

// Parses an RFC 5280 UTCTime (tag 0x17) or GeneralizedTime (tag 0x18).
absl::optional<std::chrono::system_clock::time_point> ParseTime(
    uint8_t tag, absl::string_view text) {
  int year = 0;
  if (tag == 0x17 && text.size() == 13) {
    if (!ParseDigits(text.substr(0, 2), &year)) return absl::nullopt;
    year += year < 50 ? 2000 : 1900;
    text.remove_prefix(2);
  } else if (tag == 0x18 && text.size() == 15) {
    if (!ParseDigits(text.substr(0, 4), &year)) return absl::nullopt;
    text.remove_prefix(4);
  } else {
    return absl::nullopt;
  }
  int month, day, hour, minute, second;
  if (text.back() != 'Z' || !ParseDigits(text.substr(0, 2), &month) ||
      !ParseDigits(text.substr(2, 2), &day) ||
      !ParseDigits(text.substr(4, 2), &hour) ||
      !ParseDigits(text.substr(6, 2), &minute) ||
      !ParseDigits(text.substr(8, 2), &second) || month < 1 || month > 12 ||
      day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59) {
    return absl::nullopt;
  }
  static constexpr int kDaysInMonth[] = {31, 28, 31, 30, 31, 30,
                                         31, 31, 30, 31, 30, 31};
  bool leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
  if (day > kDaysInMonth[month - 1] + (month == 2 && leap ? 1 : 0)) {
    return absl::nullopt;
  }
  int64_t seconds = DaysFromCivil(year, static_cast<unsigned>(month),
                                  static_cast<unsigned>(day)) *
                        86400 +
                    hour * 3600 + minute * 60 + second;
  return std::chrono::system_clock::time_point(
      std::chrono::duration_cast<std::chrono::system_clock::duration>(
          std::chrono::seconds(seconds)));
}

}  // namespace

absl::optional<std::chrono::system_clock::time_point> ParseCertificateNotAfter(
    absl::string_view der) {
  // Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, ... }
  // TBSCertificate ::= SEQUENCE { [0] version OPTIONAL, serialNumber,
  //     signature, issuer, validity, ... }
  // Validity ::= SEQUENCE { notBefore Time, notAfter Time }
  absl::string_view cert, tbs, ignored, validity, time;
  if (!ReadExpected(&der, 0x30, &cert) || !ReadExpected(&cert, 0x30, &tbs)) {
    return absl::nullopt;
  }
  if (!tbs.empty() && static_cast<uint8_t>(tbs[0]) == 0xa0 &&
      !ReadExpected(&tbs, 0xa0, &ignored)) {
    return absl::nullopt;
  }
  if (!ReadExpected(&tbs, 0x02, &ignored) ||   // serialNumber
      !ReadExpected(&tbs, 0x30, &ignored) ||   // signature
      !ReadExpected(&tbs, 0x30, &ignored) ||   // issuer
      !ReadExpected(&tbs, 0x30, &validity)) {  // validity
    return absl::nullopt;
  }
  uint8_t tag = 0;
  if (!ReadTlv(&validity, &tag, &time) ||  // notBefore
      !ReadTlv(&validity, &tag, &time)) {  // notAfter
    return absl::nullopt;
  }
  return ParseTime(tag, time);
}

TlsVerificationCoalescer::TlsVerificationCoalescer(std::chrono::seconds ttl,
                                                   size_t capacity,
                                                   Clock clock)
    : ttl_(ttl), capacity_(capacity), clock_(clock ? std::move(clock) : [] {
        return std::chrono::system_clock::now();
      }) {
}

void TlsVerificationCoalescer::Evaluate(const std::string& key,
                                        const Start& start,
                                        Waiter waiter) {
  bool cache_hit = false;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    auto cached = cache_.find(key);
    if (cached != cache_.end()) {
      if (clock_() < cached->second.expiry) {
        lru_.splice(lru_.begin(), lru_, cached->second.lru_position);
        cache_hit = true;
      } else {
        lru_.erase(cached->second.lru_position);
        cache_.erase(cached);
      }
    }
    if (!cache_hit) {
      auto pending = pending_.find(key);
      if (pending != pending_.end()) {
        pending->second.push_back(std::move(waiter));
        return;
      }
      pending_[key].push_back(std::move(waiter));
    }
  }
  if (cache_hit) {
    waiter(grpc::Status::OK);
    return;
  }
  start([this, key](grpc::Status status, TimePoint cache_until) {
    Finish(key, std::move(status), cache_until);
  });
}

void TlsVerificationCoalescer::Finish(const std::string& key,
                                      grpc::Status status,
                                      TimePoint cache_until) {
  std::vector<Waiter> waiters;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    auto pending = pending_.find(key);
    if (pending == pending_.end()) return;  // Duplicate completion.
    waiters = std::move(pending->second);
    pending_.erase(pending);

    TimePoint expiry = std::min(clock_() + ttl_, cache_until);
    if (status.ok() && capacity_ > 0 && clock_() < expiry) {
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
  for (Waiter& waiter : waiters) {
    waiter(status);
  }
}

size_t TlsVerificationCoalescer::cache_size() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return cache_.size();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
