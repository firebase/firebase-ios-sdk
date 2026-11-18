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
   * exactly as the system's `inet_ntop` writes it (RFC 5952; some platforms
   * write IPv4-mapped addresses in dotted form, such as `::ffff:127.0.0.1`).
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
 * a bare host. IPv6 literals are canonicalized with `inet_pton`/`inet_ntop`;
 * IPv4 literals must round-trip through them unchanged; anything else that
 * contains no `:` and is not made only of digits and dots is returned as a DNS
 * name, unchanged, for the platform verifier to match against the
 * certificate.
 *
 * Returns `nullopt` for: an empty host; an embedded NUL; any `%` (IPv6 zone
 * IDs are not accepted); non-ASCII characters (internationalized names must be
 * Punycode-encoded); a `:` outside a valid IPv6 literal (so ports and
 * bracketed IPv6 literals); and digit-and-dot strings that are not canonical
 * IPv4 literals (such as leading zeros, which some parsers read as octal, or
 * `127.1`).
 */
absl::optional<TlsTargetHost> ParseTlsTargetHost(absl::string_view target_name);

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_TARGET_HOST_H_
