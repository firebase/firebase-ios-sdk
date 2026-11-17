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

#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_TARGET_HOST_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_TARGET_HOST_H_

#include <string>

#include "absl/strings/string_view.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace remote {

/** The host part of a TLS target name, for certificate hostname checks. */
struct TlsTargetHost {
  enum class Kind { kDns, kIpv4, kIpv6 };

  /**
   * The bare host: a DNS name, a dotted-quad IPv4 address, or an IPv6 address
   * without zone ID. IPv6 addresses are in the system's `inet_ntop` text form
   * (RFC 5952), except that an embedded IPv4 suffix (such as in IPv4-mapped
   * addresses) is written in hex (`::ffff:7f00:1`), because Apple's
   * `SecPolicyCreateSSL` only matches IPv4-mapped addresses written that way.
   * Currently only the Apple certificate verifier consumes this form; it is
   * not what users should write as a host (gRPC's per-call check expects
   * `inet_ntop` text, see `CreateDefaultTlsCredentials()`).
   */
  std::string host;
  Kind kind = Kind::kDns;
};

/**
 * Validates and normalizes the host to verify against a server certificate
 * from the `target_name` that gRPC passes to certificate verifiers.
 *
 * gRPC has already removed any port and IPv6 brackets (its TLS security
 * connector keeps only the host from `SplitHostPort()`), so this accepts only
 * a bare host: a DNS name, a dotted-quad IPv4 literal, or an IPv6 literal with
 * an optional `%zone` suffix, which is stripped (zone IDs are never part of
 * certificate identities).
 *
 * Returns `nullopt` for anything else, including: an empty host; control,
 * whitespace, non-ASCII, or URL-reserved characters; ports and brackets;
 * IPv4 literals that do not round-trip through `inet_pton`/`inet_ntop`
 * unchanged (such as leading zeros, which some parsers read as octal); and
 * IPv6 literals or zone IDs that are malformed.
 */
absl::optional<TlsTargetHost> ParseTlsTargetHost(absl::string_view target_name);

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_TARGET_HOST_H_
