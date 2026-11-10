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
   * without brackets or zone ID. IPv6 addresses are in canonical RFC 5952 text
   * form, except that embedded IPv4 (such as IPv4-mapped) addresses are also
   * written in hex (`::ffff:7f00:1`), the form every platform verifier accepts.
   */
  std::string host;
  Kind kind = Kind::kDns;
};

/**
 * Extracts the host to verify against a server certificate from the
 * `target_name` that gRPC passes to certificate verifiers.
 *
 * Accepts `host`, `host:port`, `[ipv6]`, `[ipv6]:port`, and a bare `ipv6`
 * literal. Strips the port, the brackets, and any IPv6 `%zone` suffix (zone
 * IDs are never part of certificate identities).
 *
 * Returns `nullopt` for anything else: an empty host; control, whitespace,
 * non-ASCII, or URL-reserved characters; an empty, non-numeric, or out-of-range
 * port (valid ports are 1-65535); malformed brackets; malformed IPv4 literals
 * (including leading zeros, which some parsers read as octal); and malformed
 * IPv6 literals or zone IDs.
 */
absl::optional<TlsTargetHost> ParseTlsTargetHost(absl::string_view target_name);

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_TARGET_HOST_H_
