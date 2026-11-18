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
#include <string>
#include <utility>

#include "absl/strings/ascii.h"

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

bool IsAllDigitsAndDots(absl::string_view s) {
  for (char c : s) {
    if (!absl::ascii_isdigit(static_cast<unsigned char>(c)) && c != '.') {
      return false;
    }
  }
  return true;
}

bool ContainsNonAscii(absl::string_view s) {
  for (char c : s) {
    if (static_cast<unsigned char>(c) >= 0x80) return true;
  }
  return false;
}

}  // namespace

absl::optional<TlsTargetHost> ParseTlsTargetHost(
    absl::string_view target_name) {
  // An embedded NUL would truncate the C string handed to inet_pton, zone IDs
  // are never part of a certificate identity, and internationalized names
  // must arrive Punycode-encoded.
  if (target_name.empty() ||
      target_name.find('\0') != absl::string_view::npos ||
      target_name.find('%') != absl::string_view::npos ||
      ContainsNonAscii(target_name)) {
    return absl::nullopt;
  }
  std::string text(target_name);

  in6_addr addr6 = {};
  if (PtoN(AF_INET6, text, &addr6)) {
    std::string canonical = NtoP(AF_INET6, &addr6);
    if (canonical.empty()) return absl::nullopt;
    return TlsTargetHost{std::move(canonical), TlsTargetHost::Kind::kIpv6};
  }
  // gRPC strips ports and brackets before calling verifiers, and DNS names
  // never contain ':', so anything else with a colon is malformed.
  if (text.find(':') != std::string::npos) return absl::nullopt;

  // The round trip rejects forms that some parsers accept but read
  // differently, such as leading zeros (octal) or fewer than four parts.
  in_addr addr4 = {};
  if (PtoN(AF_INET, text, &addr4) && NtoP(AF_INET, &addr4) == text) {
    return TlsTargetHost{std::move(text), TlsTargetHost::Kind::kIpv4};
  }
  // Never treat something that looks like an IPv4 address as a DNS name.
  if (IsAllDigitsAndDots(text)) return absl::nullopt;

  return TlsTargetHost{std::move(text), TlsTargetHost::Kind::kDns};
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
