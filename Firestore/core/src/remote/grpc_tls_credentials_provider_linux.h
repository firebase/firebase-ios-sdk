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

#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_LINUX_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_LINUX_H_

#include "Firestore/core/src/remote/grpc_tls_credentials_provider.h"

// The system CA store implementation is used on every platform that is neither
// Apple (Security.framework) nor Windows (CryptoAPI): Linux, Android, the BSDs,
// Fuchsia, and so on.
#if !defined(__APPLE__) && !defined(_WIN32)

#include <cstddef>
#include <functional>
#include <memory>
#include <string>
#include <unordered_set>
#include <vector>

#include "Firestore/core/src/util/warnings.h"
#include "absl/strings/string_view.h"
#include "absl/types/optional.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/support/status.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {

/**
 * Where to look for trust anchors and distrust (blocklist) entries.
 *
 * The defaults read the system CA store. Every field other than `ca_path`
 * exists so tests can point the loader at temporary files.
 */
struct LinuxTrustConfig {
  /**
   * If non-empty, the only anchor source consulted: a PEM bundle file or a
   * directory of PEM files. Environment variables and distro defaults are then
   * ignored.
   */
  std::string ca_path;

  /**
   * Looks up an environment variable. Defaults to `secure_getenv` semantics
   * (variables are ignored in set-uid / set-gid processes).
   */
  std::function<absl::optional<std::string>(const char* name)> get_env;

  /** Overrides the distro CA bundle files, tried in order. */
  absl::optional<std::vector<std::string>> bundle_files;

  /** Overrides the distro CA directories, used if no bundle file is found. */
  absl::optional<std::vector<std::string>> cert_dirs;

  /**
   * Overrides the distro distrust directories. Every certificate (or `PUBLIC
   * KEY`) in these directories is blocklisted.
   */
  absl::optional<std::vector<std::string>> blocklist_dirs;

  /**
   * Overrides the distro "trust bundles" (OpenSSL `TRUSTED CERTIFICATE`
   * files). Only entries explicitly distrusted for TLS server authentication
   * are taken from these files, and they are blocklisted.
   */
  absl::optional<std::vector<std::string>> trust_bundle_files;
};

/** Trust material loaded from the system. Immutable once loaded. */
struct LinuxTrustStore {
  /**
   * The trust anchors as plain PEM `CERTIFICATE` blocks: de-duplicated, with
   * every blocklisted certificate removed.
   */
  std::string anchors_pem;
  size_t anchor_count = 0;

  /** Human-readable description of where the anchors came from. */
  std::string anchor_source;

  /** SHA-256 digests of blocklisted certificates (DER). */
  std::unordered_set<std::string> blocked_cert_sha256;

  /** SHA-256 digests of blocklisted SubjectPublicKeyInfos (DER). */
  std::unordered_set<std::string> blocked_spki_sha256;

  bool has_anchors() const {
    return anchor_count > 0;
  }

  /**
   * Returns whether a certificate, given its DER encoding and the DER encoding
   * of its SubjectPublicKeyInfo, is blocklisted.
   */
  bool IsBlocked(absl::string_view cert_der, absl::string_view spki_der) const;
};

/**
 * Loads the system trust anchors and blocklist described by `config`.
 *
 * Anchors come from the first source below that yields at least one usable
 * certificate:
 *
 *  1. `config.ca_path`, if set (and then nothing else is consulted);
 *  2. the file named by `GRPC_DEFAULT_SSL_ROOTS_FILE_PATH`, then
 * `SSL_CERT_FILE`;
 *  3. the colon-separated directories in `GRPC_SYSTEM_SSL_ROOTS_DIR`, then
 *     `SSL_CERT_DIR`;
 *  4. the first distro CA bundle file that exists;
 *  5. all of the distro CA directories.
 *
 * An environment variable that is set but yields no certificates (missing or
 * empty file, say) is logged and skipped, falling through to the next source,
 * as in Go's crypto/x509.
 *
 * Every source is parsed with `TRUSTED CERTIFICATE` support. Entries
 * explicitly distrusted for TLS server authentication are blocklisted, entries
 * trusted only for other purposes are dropped, and the rest are re-emitted as
 * plain `CERTIFICATE` blocks. Blocklisted certificates (by certificate or
 * SubjectPublicKeyInfo digest) are never anchors.
 */
LinuxTrustStore LoadLinuxTrustStore(const LinuxTrustConfig& config = {});

/**
 * Checks a peer certificate chain that the TLS library has already validated
 * against `store.anchors_pem`:
 *
 *  - rejects the chain if any certificate in it is blocklisted;
 *  - verifies that the leaf (the first certificate) matches `target_name`
 *    (`host`, `host:port`, `[ipv6]:port`, ...) via its subjectAltNames.
 *
 * gRPC's default hostname verifier is replaced by any custom certificate
 * verifier, so this hostname check is the only one performed during the
 * handshake.
 *
 * Returns `UNAVAILABLE` if `store` has no trust anchors, and
 * `UNAUTHENTICATED` for every other failure.
 */
grpc::Status VerifyLinuxPeerCertificateChain(absl::string_view pem_chain,
                                             absl::string_view target_name,
                                             const LinuxTrustStore& store);

/**
 * Creates gRPC `TlsCredentials` that validate server chains against the system
 * CA store described by `config`, and reject blocklisted certificates and
 * hostname mismatches.
 *
 * If no trust anchors are found, the error is logged and the returned
 * credentials fail every TLS handshake (RPCs fail with `UNAVAILABLE`) instead
 * of falling back to an embedded root bundle.
 */
std::shared_ptr<grpc::ChannelCredentials> CreateLinuxTlsCredentials(
    const LinuxTrustConfig& config = {});

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // !defined(__APPLE__) && !defined(_WIN32)

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_TLS_CREDENTIALS_PROVIDER_LINUX_H_
