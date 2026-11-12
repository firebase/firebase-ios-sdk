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

#ifndef FIRESTORE_CORE_TEST_UNIT_REMOTE_TLS_TEST_PKI_H_
#define FIRESTORE_CORE_TEST_UNIT_REMOTE_TLS_TEST_PKI_H_

// Runtime X.509 test PKI built with the API subset shared by OpenSSL 3 and
// BoringSSL. Apple tests generate certificates with Security.framework instead
// (see grpc_tls_credentials_provider_apple_test.mm), so this helper is only
// compiled on non-Apple platforms.
#if !defined(__APPLE__)

#include <chrono>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include "absl/strings/string_view.h"

// Forward declarations so that the header does not depend on OpenSSL headers.
// `EVP_PKEY` and `X509` are typedefs of these structs in both OpenSSL and
// BoringSSL.
struct evp_pkey_st;
struct x509_st;

namespace firebase {
namespace firestore {
namespace remote {
namespace tls_testing {

/** Options for `IssueTestCertificate()`. */
struct TestCertOptions {
  std::string common_name;

  /** Whether the certificate is a CA (basicConstraints CA:TRUE). */
  bool is_ca = false;

  /** DNS subjectAltName entries, e.g. "loopback.firestore.test". */
  std::vector<std::string> dns_sans;

  /** IP subjectAltName entries in textual form, e.g. "127.0.0.1" or "::1". */
  std::vector<std::string> ip_sans;

  /** Validity window relative to now. */
  std::chrono::seconds not_before_offset = std::chrono::hours(-2);
  std::chrono::seconds not_after_offset = std::chrono::hours(48);
};

/**
 * A generated certificate together with its private key.
 *
 * Copies share the underlying key and certificate objects (which are never
 * mutated after creation).
 */
class TestCertificate {
 public:
  TestCertificate() = default;

  /** The certificate as a PEM `CERTIFICATE` block. */
  const std::string& cert_pem() const {
    return cert_pem_;
  }

  /** The certificate as DER bytes. */
  const std::string& cert_der() const {
    return cert_der_;
  }

  /** The private key as a PKCS#8 PEM `PRIVATE KEY` block. */
  const std::string& private_key_pem() const {
    return key_pem_;
  }

  /** The DER-encoded SubjectPublicKeyInfo of the certificate. */
  const std::string& spki_der() const {
    return spki_der_;
  }

  const std::string& common_name() const {
    return common_name_;
  }

  /** Borrowed pointers to the underlying library objects. */
  evp_pkey_st* key() const {
    return key_.get();
  }
  x509_st* x509() const {
    return x509_.get();
  }

  bool valid() const {
    return x509_ != nullptr;
  }

 private:
  friend TestCertificate IssueTestCertificate(const TestCertOptions&,
                                              const TestCertificate*,
                                              const TestCertificate*);

  std::shared_ptr<evp_pkey_st> key_;
  std::shared_ptr<x509_st> x509_;
  std::string cert_pem_;
  std::string cert_der_;
  std::string key_pem_;
  std::string spki_der_;
  std::string common_name_;
};

/**
 * Issues a new EC P-256 / SHA-256 certificate.
 *
 * @param options Subject, SANs, CA flag and validity.
 * @param issuer The issuing CA, or null for a self-signed certificate.
 * @param reuse_key_from If non-null, the new certificate reuses this
 *     certificate's key pair instead of generating a new one. Combined with the
 *     same `common_name`, this produces a re-issued or cross-signed copy of the
 *     same CA (same subject and SPKI, different issuer or serial).
 *
 * Fails a test assertion (HARD_ASSERT) if the crypto library reports an error.
 */
TestCertificate IssueTestCertificate(
    const TestCertOptions& options,
    const TestCertificate* issuer,
    const TestCertificate* reuse_key_from = nullptr);

/** Concatenates the PEM encodings of `certs` in order. */
std::string PemChain(const std::vector<const TestCertificate*>& certs);

/**
 * A ready-made test PKI:
 *
 *   root ──► intermediate ──► leaf / expired_leaf
 *   cross_root ──► cross_intermediate (same subject + key as `intermediate`)
 *
 * `cross_intermediate` is `intermediate` cross-signed by `cross_root`, so a
 * client that trusts only `cross_root` can validate `leaf` via the alternate
 * path `leaf ─► cross_intermediate ─► cross_root`.
 */
struct TestPki {
  TestCertificate root;
  TestCertificate intermediate;
  TestCertificate cross_root;
  TestCertificate cross_intermediate;
  TestCertificate leaf;
  TestCertificate expired_leaf;

  /** `leaf` followed by `intermediate`, as a TLS server would send it. */
  std::string ServerChainPem() const;

  /** `expired_leaf` followed by `intermediate`. */
  std::string ExpiredServerChainPem() const;
};

/**
 * Creates a `TestPki`. `label` is embedded in the CA common names so that
 * independent PKIs in one test binary never share a subject name. Both leaves
 * get `leaf_dns_sans` and `leaf_ip_sans`.
 */
TestPki CreateTestPki(absl::string_view label,
                      const std::vector<std::string>& leaf_dns_sans,
                      const std::vector<std::string>& leaf_ip_sans = {});

}  // namespace tls_testing
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // !defined(__APPLE__)

#endif  // FIRESTORE_CORE_TEST_UNIT_REMOTE_TLS_TEST_PKI_H_
