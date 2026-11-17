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

#if defined(_WIN32)
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#include <arpa/inet.h>  // NOLINT(build/include)
#include <netinet/in.h>
#endif  // defined(_WIN32)

#include <cstddef>
#include <cstdint>
#include <string>
#include <utility>

#include "absl/strings/ascii.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

#if defined(_WIN32)
bool PtoN(int family, const std::string& text, void* addr) {
  return InetPtonA(family, text.c_str(), addr) == 1;
}
std::string NtoP(int family, const void* addr) {
  char text[INET6_ADDRSTRLEN] = {};
  return InetNtopA(family, addr, text, sizeof(text)) ? text : "";
}
#else
bool PtoN(int family, const std::string& text, void* addr) {
  return inet_pton(family, text.c_str(), addr) == 1;
}
std::string NtoP(int family, const void* addr) {
  char text[INET6_ADDRSTRLEN] = {};
  return inet_ntop(family, addr, text, sizeof(text)) ? text : "";
}
#endif  // defined(_WIN32)

bool IsDnsChar(char c) {
  return absl::ascii_isalnum(static_cast<unsigned char>(c)) || c == '-' ||
         c == '.' || c == '_';
}

bool IsZoneIdChar(char c) {
  return absl::ascii_isalnum(static_cast<unsigned char>(c)) || c == '-' ||
         c == '.' || c == '_' || c == '~' || c == '%';
}

bool IsIpv6Char(char c) {
  return absl::ascii_isxdigit(static_cast<unsigned char>(c)) || c == ':' ||
         c == '.';
}

template <typename Pred>
bool AllOf(absl::string_view s, Pred pred) {
  for (char c : s) {
    if (!pred(c)) return false;
  }
  return true;
}

// Validates an IPv6 literal with an optional `%zone` suffix and returns the
// address, without the zone, as `inet_ntop` writes it, but with any embedded
// IPv4 suffix rewritten in hex (`::ffff:127.0.0.1` -> `::ffff:7f00:1`).
absl::optional<TlsTargetHost> ParseIpv6(absl::string_view s) {
  size_t percent = s.find('%');
  if (percent != absl::string_view::npos) {
    absl::string_view zone = s.substr(percent + 1);
    if (zone.empty() || !AllOf(zone, IsZoneIdChar)) return absl::nullopt;
    s = s.substr(0, percent);
  }
  // Also guarantees there is no embedded NUL to truncate the C string.
  if (!AllOf(s, IsIpv6Char)) return absl::nullopt;

  in6_addr addr = {};
  if (!PtoN(AF_INET6, std::string(s), &addr)) return absl::nullopt;
  std::string text = NtoP(AF_INET6, &addr);
  if (text.empty()) return absl::nullopt;

  size_t last_colon = text.rfind(':');
  if (text.find('.', last_colon) != std::string::npos) {
    const auto* b = reinterpret_cast<const uint8_t*>(&addr);
    text.erase(last_colon + 1);
    absl::StrAppend(&text, absl::Hex((b[12] << 8) | b[13]), ":",
                    absl::Hex((b[14] << 8) | b[15]));
  }
  return TlsTargetHost{std::move(text), TlsTargetHost::Kind::kIpv6};
}

absl::optional<TlsTargetHost> ParseDnsOrIpv4(absl::string_view host) {
  if (host.empty() || !AllOf(host, IsDnsChar)) return absl::nullopt;
  bool numeric = AllOf(host, [](char c) {
    return absl::ascii_isdigit(static_cast<unsigned char>(c)) || c == '.';
  });
  if (!numeric) {
    return TlsTargetHost{std::string(host), TlsTargetHost::Kind::kDns};
  }
  // Never treat something that looks like an address as a DNS name. The
  // round trip rejects forms that some parsers accept but read differently,
  // such as leading zeros (octal) or fewer than four parts.
  std::string text(host);
  in_addr addr = {};
  if (!PtoN(AF_INET, text, &addr) || NtoP(AF_INET, &addr) != text) {
    return absl::nullopt;
  }
  return TlsTargetHost{std::move(text), TlsTargetHost::Kind::kIpv4};
}

}  // namespace

absl::optional<TlsTargetHost> ParseTlsTargetHost(
    absl::string_view target_name) {
  if (target_name.find(':') != absl::string_view::npos) {
    return ParseIpv6(target_name);
  }
  return ParseDnsOrIpv4(target_name);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
