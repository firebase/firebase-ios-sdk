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

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>

#include "absl/strings/ascii.h"
#include "absl/strings/match.h"
#include "absl/strings/str_cat.h"

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

// A decimal TCP port in [1, 65535]. Port 0 is not connectable.
bool IsValidPort(absl::string_view port) {
  if (!IsAllDigits(port) || port.size() > 5) return false;
  int value = 0;
  for (char c : port) value = value * 10 + (c - '0');
  return value >= 1 && value <= 65535;
}

// Dotted-quad IPv4 with decimal octets in [0, 255] and no leading zeros (which
// some parsers read as octal). Stores the octets in `*octets` if non-null.
bool ParseIpv4(absl::string_view s, std::array<uint8_t, 4>* octets) {
  int parts = 0;
  while (true) {
    size_t dot = s.find('.');
    absl::string_view octet = s.substr(0, dot);
    if (!IsAllDigits(octet) || octet.size() > 3) return false;
    if (octet.size() > 1 && octet[0] == '0') return false;
    int value = 0;
    for (char c : octet) value = value * 10 + (c - '0');
    if (value > 255) return false;
    if (parts >= 4) return false;
    if (octets != nullptr) (*octets)[parts] = static_cast<uint8_t>(value);
    ++parts;
    if (dot == absl::string_view::npos) break;
    s.remove_prefix(dot + 1);
  }
  return parts == 4;
}

bool IsValidIpv4(absl::string_view s) {
  return ParseIpv4(s, nullptr);
}

using Ipv6Groups = std::array<uint16_t, 8>;

// Parses a colon-separated run of 16-bit hex groups containing no "::" and
// appends them to `*groups`. `allow_ipv4_tail` permits a trailing dotted quad
// (worth two groups).
bool ParseIpv6Run(absl::string_view run,
                  bool allow_ipv4_tail,
                  std::vector<uint16_t>* groups) {
  if (run.empty()) return true;
  while (true) {
    size_t colon = run.find(':');
    absl::string_view group = run.substr(0, colon);
    if (colon == absl::string_view::npos && allow_ipv4_tail &&
        absl::StrContains(group, '.')) {
      std::array<uint8_t, 4> octets;
      if (!ParseIpv4(group, &octets)) return false;
      groups->push_back(static_cast<uint16_t>((octets[0] << 8) | octets[1]));
      groups->push_back(static_cast<uint16_t>((octets[2] << 8) | octets[3]));
      return true;
    }
    if (group.empty() || group.size() > 4) return false;
    uint16_t value = 0;
    for (char c : group) {
      if (!absl::ascii_isxdigit(static_cast<unsigned char>(c))) return false;
      int digit =
          absl::ascii_isdigit(static_cast<unsigned char>(c))
              ? c - '0'
              : absl::ascii_tolower(static_cast<unsigned char>(c)) - 'a' + 10;
      value = static_cast<uint16_t>((value << 4) | digit);
    }
    groups->push_back(value);
    if (colon == absl::string_view::npos) return true;
    run.remove_prefix(colon + 1);
  }
}

// Parses the RFC 4291 section 2.2 text forms, without a zone ID.
bool ParseIpv6(absl::string_view s, Ipv6Groups* out) {
  if (s.empty()) return false;
  size_t double_colon = s.find("::");
  if (double_colon != absl::string_view::npos &&
      s.find("::", double_colon + 1) != absl::string_view::npos) {
    return false;
  }

  std::vector<uint16_t> head;
  if (double_colon == absl::string_view::npos) {
    if (!ParseIpv6Run(s, /*allow_ipv4_tail=*/true, &head) || head.size() != 8) {
      return false;
    }
    std::copy(head.begin(), head.end(), out->begin());
    return true;
  }

  std::vector<uint16_t> tail;
  if (!ParseIpv6Run(s.substr(0, double_colon), /*allow_ipv4_tail=*/false,
                    &head) ||
      !ParseIpv6Run(s.substr(double_colon + 2), /*allow_ipv4_tail=*/true,
                    &tail)) {
    return false;
  }
  // "::" stands for at least one zero group.
  if (head.size() + tail.size() > 7) return false;
  out->fill(0);
  std::copy(head.begin(), head.end(), out->begin());
  std::copy(tail.begin(), tail.end(), out->end() - tail.size());
  return true;
}

// Formats `groups` in the RFC 5952 canonical text form: lowercase hex without
// leading zeros, with the longest run of two or more zero groups (the first,
// on a tie) compressed to "::". Unlike RFC 5952 section 5, IPv4-mapped and
// other embedded-IPv4 addresses are also written in hex, because Apple's
// SecPolicyCreateSSL only matches IPv4-mapped addresses written that way.
std::string FormatIpv6(const Ipv6Groups& groups) {
  int best_start = -1;
  int best_length = 1;
  for (int i = 0; i < 8;) {
    if (groups[i] != 0) {
      ++i;
      continue;
    }
    int start = i;
    while (i < 8 && groups[i] == 0) ++i;
    if (i - start > best_length) {
      best_start = start;
      best_length = i - start;
    }
  }

  std::string out;
  for (int i = 0; i < 8;) {
    if (i == best_start) {
      out += "::";
      i += best_length;
      continue;
    }
    if (!out.empty() && out.back() != ':') out += ':';
    absl::StrAppend(&out, absl::Hex(groups[i]));
    ++i;
  }
  return out;
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
// address, without the zone, in canonical form (see `FormatIpv6`).
absl::optional<TlsTargetHost> ParseIpv6WithZone(absl::string_view s) {
  size_t percent = s.find('%');
  if (percent != absl::string_view::npos) {
    if (!IsValidZoneId(s.substr(percent + 1))) return absl::nullopt;
    s = s.substr(0, percent);
  }
  Ipv6Groups groups;
  if (!ParseIpv6(s, &groups)) return absl::nullopt;
  return TlsTargetHost{FormatIpv6(groups), TlsTargetHost::Kind::kIpv6};
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
