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

#include "Firestore/core/src/remote/grpc_tls_target_host.h"

#include <cstddef>

#include "absl/strings/ascii.h"
#include "absl/strings/match.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

bool IsAllDigits(absl::string_view s) {
  if (s.empty()) return false;
  for (char c : s) {
    if (!absl::ascii_isdigit(static_cast<unsigned char>(c))) return false;
  }
  return true;
}

// A decimal TCP port in [0, 65535].
bool IsValidPort(absl::string_view port) {
  if (!IsAllDigits(port) || port.size() > 5) return false;
  int value = 0;
  for (char c : port) value = value * 10 + (c - '0');
  return value <= 65535;
}

// Dotted-quad IPv4 with decimal octets in [0, 255] and no leading zeros (which
// some parsers read as octal).
bool IsValidIpv4(absl::string_view s) {
  int parts = 0;
  while (true) {
    size_t dot = s.find('.');
    absl::string_view octet = s.substr(0, dot);
    if (!IsAllDigits(octet) || octet.size() > 3) return false;
    if (octet.size() > 1 && octet[0] == '0') return false;
    int value = 0;
    for (char c : octet) value = value * 10 + (c - '0');
    if (value > 255) return false;
    ++parts;
    if (dot == absl::string_view::npos) break;
    s.remove_prefix(dot + 1);
  }
  return parts == 4;
}

// RFC 4291 section 2.2 text forms, without a zone ID.
bool IsValidIpv6(absl::string_view s) {
  if (s.empty()) return false;
  size_t double_colon = s.find("::");
  if (double_colon != absl::string_view::npos &&
      s.find("::", double_colon + 1) != absl::string_view::npos) {
    return false;
  }

  // Counts the 16-bit groups in a colon-separated run with no "::".
  // `allow_ipv4_tail` permits a trailing dotted quad (worth two groups).
  auto count_groups = [](absl::string_view run, bool allow_ipv4_tail,
                         int* groups) -> bool {
    *groups = 0;
    if (run.empty()) return true;
    while (true) {
      size_t colon = run.find(':');
      absl::string_view group = run.substr(0, colon);
      if (colon == absl::string_view::npos && allow_ipv4_tail &&
          absl::StrContains(group, '.')) {
        if (!IsValidIpv4(group)) return false;
        *groups += 2;
        return true;
      }
      if (group.empty() || group.size() > 4) return false;
      for (char c : group) {
        if (!absl::ascii_isxdigit(static_cast<unsigned char>(c))) return false;
      }
      ++*groups;
      if (colon == absl::string_view::npos) return true;
      run.remove_prefix(colon + 1);
    }
  };

  if (double_colon == absl::string_view::npos) {
    int groups = 0;
    return count_groups(s, /*allow_ipv4_tail=*/true, &groups) && groups == 8;
  }

  int head = 0;
  int tail = 0;
  if (!count_groups(s.substr(0, double_colon), /*allow_ipv4_tail=*/false,
                    &head) ||
      !count_groups(s.substr(double_colon + 2), /*allow_ipv4_tail=*/true,
                    &tail)) {
    return false;
  }
  // "::" stands for at least one zero group.
  return head + tail <= 7;
}

bool IsValidZoneId(absl::string_view zone) {
  if (zone.empty()) return false;
  for (char c : zone) {
    if (!absl::ascii_isalnum(static_cast<unsigned char>(c)) && c != '-' &&
        c != '.' && c != '_' && c != '~' && c != '%') {
      return false;
    }
  }
  return true;
}

// Validates an IPv6 literal with an optional `%zone` suffix and returns the
// address without the zone.
absl::optional<TlsTargetHost> ParseIpv6WithZone(absl::string_view s) {
  size_t percent = s.find('%');
  if (percent != absl::string_view::npos) {
    if (!IsValidZoneId(s.substr(percent + 1))) return absl::nullopt;
    s = s.substr(0, percent);
  }
  if (!IsValidIpv6(s)) return absl::nullopt;
  return TlsTargetHost{std::string(s), TlsTargetHost::Kind::kIpv6};
}

bool IsDnsChar(char c) {
  return absl::ascii_isalnum(static_cast<unsigned char>(c)) || c == '-' ||
         c == '.' || c == '_';
}

absl::optional<TlsTargetHost> ParseDnsOrIpv4(absl::string_view host) {
  if (host.empty()) return absl::nullopt;
  bool numeric = true;
  for (char c : host) {
    if (!IsDnsChar(c)) return absl::nullopt;
    if (!absl::ascii_isdigit(static_cast<unsigned char>(c)) && c != '.') {
      numeric = false;
    }
  }
  if (numeric) {
    // Never treat something that looks like an address as a DNS name.
    if (!IsValidIpv4(host)) return absl::nullopt;
    return TlsTargetHost{std::string(host), TlsTargetHost::Kind::kIpv4};
  }
  return TlsTargetHost{std::string(host), TlsTargetHost::Kind::kDns};
}

}  // namespace

absl::optional<TlsTargetHost> ParseTlsTargetHost(
    absl::string_view target_name) {
  if (target_name.empty()) return absl::nullopt;

  // Bracketed IPv6: "[addr]" or "[addr]:port".
  if (target_name.front() == '[') {
    size_t close = target_name.find(']');
    if (close == absl::string_view::npos) return absl::nullopt;
    absl::string_view inner = target_name.substr(1, close - 1);
    absl::string_view rest = target_name.substr(close + 1);
    if (!rest.empty()) {
      if (rest.front() != ':' || !IsValidPort(rest.substr(1))) {
        return absl::nullopt;
      }
    }
    return ParseIpv6WithZone(inner);
  }

  size_t first_colon = target_name.find(':');
  if (first_colon == absl::string_view::npos) {
    return ParseDnsOrIpv4(target_name);
  }

  // More than one colon: a bare IPv6 literal (which cannot carry a port).
  if (target_name.find(':', first_colon + 1) != absl::string_view::npos) {
    return ParseIpv6WithZone(target_name);
  }

  // "host:port".
  if (!IsValidPort(target_name.substr(first_colon + 1))) return absl::nullopt;
  return ParseDnsOrIpv4(target_name.substr(0, first_colon));
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
