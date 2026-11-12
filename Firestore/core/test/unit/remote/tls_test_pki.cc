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

#include "Firestore/core/test/unit/remote/tls_test_pki.h"

#if !defined(__APPLE__)

#include <atomic>
#include <utility>

#include "Firestore/core/src/util/hard_assert.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/str_join.h"
#include "openssl/bio.h"
#include "openssl/bn.h"
#include "openssl/evp.h"
#include "openssl/obj_mac.h"
#include "openssl/pem.h"
#include "openssl/rand.h"
#include "openssl/x509.h"
#include "openssl/x509v3.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace tls_testing {
namespace {

struct BioDeleter {
  void operator()(BIO* bio) const {
    BIO_free(bio);
  }
};
using UniqueBio = std::unique_ptr<BIO, BioDeleter>;

struct PkeyCtxDeleter {
  void operator()(EVP_PKEY_CTX* ctx) const {
    EVP_PKEY_CTX_free(ctx);
  }
};

struct ExtensionDeleter {
  void operator()(X509_EXTENSION* ext) const {
    X509_EXTENSION_free(ext);
  }
};

std::shared_ptr<EVP_PKEY> GenerateP256Key() {
  std::unique_ptr<EVP_PKEY_CTX, PkeyCtxDeleter> ctx(
      EVP_PKEY_CTX_new_id(EVP_PKEY_EC, nullptr));
  HARD_ASSERT(ctx != nullptr, "EVP_PKEY_CTX_new_id failed");
  HARD_ASSERT(EVP_PKEY_keygen_init(ctx.get()) == 1,
              "EVP_PKEY_keygen_init failed");
  HARD_ASSERT(EVP_PKEY_CTX_set_ec_paramgen_curve_nid(ctx.get(),
                                                     NID_X9_62_prime256v1) == 1,
              "EVP_PKEY_CTX_set_ec_paramgen_curve_nid failed");
  EVP_PKEY* raw = nullptr;
  HARD_ASSERT(EVP_PKEY_keygen(ctx.get(), &raw) == 1 && raw != nullptr,
              "EVP_PKEY_keygen failed");
  return std::shared_ptr<EVP_PKEY>(raw, EVP_PKEY_free);
}

std::string BioContents(BIO* bio) {
  char* data = nullptr;
  long len = BIO_get_mem_data(bio, &data);  // NOLINT(runtime/int)
  HARD_ASSERT(len >= 0, "BIO_get_mem_data failed");
  return std::string(data, static_cast<size_t>(len));
}

void AddExtension(X509* cert,
                  X509V3_CTX* ctx,
                  int nid,
                  const std::string& value) {
  std::unique_ptr<X509_EXTENSION, ExtensionDeleter> ext(
      X509V3_EXT_nconf_nid(nullptr, ctx, nid, value.c_str()));
  HARD_ASSERT(ext != nullptr, "X509V3_EXT_nconf_nid(%s, %s) failed", nid,
              value);
  HARD_ASSERT(X509_add_ext(cert, ext.get(), -1) == 1, "X509_add_ext failed");
}

uint64_t NextSerial() {
  // Random high bits so that serials differ across test runs, plus a counter
  // so that serials never collide within one run.
  static std::atomic<uint64_t> counter{0};
  uint32_t random_bits = 0;
  RAND_bytes(reinterpret_cast<uint8_t*>(&random_bits), sizeof(random_bits));
  return (static_cast<uint64_t>(random_bits & 0x7fffffff) << 24) |
         (++counter & 0xffffff);
}

}  // namespace

TestCertificate IssueTestCertificate(const TestCertOptions& options,
                                     const TestCertificate* issuer,
                                     const TestCertificate* reuse_key_from) {
  HARD_ASSERT(issuer == nullptr || issuer->valid(), "Invalid issuer");
  HARD_ASSERT(reuse_key_from == nullptr || reuse_key_from->valid(),
              "Invalid key source");

  TestCertificate result;
  result.common_name_ = options.common_name;
  result.key_ =
      reuse_key_from != nullptr ? reuse_key_from->key_ : GenerateP256Key();

  std::shared_ptr<X509> cert(X509_new(), X509_free);
  HARD_ASSERT(cert != nullptr, "X509_new failed");
  HARD_ASSERT(X509_set_version(cert.get(), 2) == 1, "X509_set_version failed");

  HARD_ASSERT(ASN1_INTEGER_set_uint64(X509_get_serialNumber(cert.get()),
                                      NextSerial()) == 1,
              "ASN1_INTEGER_set_uint64 failed");

  HARD_ASSERT(
      X509_gmtime_adj(X509_getm_notBefore(cert.get()),
                      static_cast<long>(  // NOLINT(runtime/int)
                          options.not_before_offset.count())) != nullptr,
      "X509_gmtime_adj(notBefore) failed");
  HARD_ASSERT(X509_gmtime_adj(X509_getm_notAfter(cert.get()),
                              static_cast<long>(  // NOLINT(runtime/int)
                                  options.not_after_offset.count())) != nullptr,
              "X509_gmtime_adj(notAfter) failed");

  X509_NAME* subject = X509_get_subject_name(cert.get());
  HARD_ASSERT(X509_NAME_add_entry_by_txt(
                  subject, "O", MBSTRING_ASC,
                  reinterpret_cast<const unsigned char*>("Firestore Test"), -1,
                  -1, 0) == 1,
              "X509_NAME_add_entry_by_txt(O) failed");
  HARD_ASSERT(X509_NAME_add_entry_by_txt(subject, "CN", MBSTRING_ASC,
                                         reinterpret_cast<const unsigned char*>(
                                             options.common_name.c_str()),
                                         -1, -1, 0) == 1,
              "X509_NAME_add_entry_by_txt(CN) failed");

  X509* issuer_cert = issuer != nullptr ? issuer->x509_.get() : cert.get();
  HARD_ASSERT(
      X509_set_issuer_name(cert.get(), X509_get_subject_name(issuer_cert)) == 1,
      "X509_set_issuer_name failed");
  HARD_ASSERT(X509_set_pubkey(cert.get(), result.key_.get()) == 1,
              "X509_set_pubkey failed");

  // Value-initialize so that fields not set by `X509V3_set_ctx` (such as the
  // config database) are null in both OpenSSL and BoringSSL.
  X509V3_CTX ctx{};
  X509V3_set_ctx(&ctx, issuer_cert, cert.get(), nullptr, nullptr, 0);

  if (options.is_ca) {
    AddExtension(cert.get(), &ctx, NID_basic_constraints, "critical,CA:TRUE");
    AddExtension(cert.get(), &ctx, NID_key_usage,
                 "critical,keyCertSign,cRLSign,digitalSignature");
  } else {
    AddExtension(cert.get(), &ctx, NID_basic_constraints, "critical,CA:FALSE");
    AddExtension(cert.get(), &ctx, NID_key_usage, "critical,digitalSignature");
    AddExtension(cert.get(), &ctx, NID_ext_key_usage, "serverAuth");
  }
  AddExtension(cert.get(), &ctx, NID_subject_key_identifier, "hash");
  if (issuer != nullptr) {
    AddExtension(cert.get(), &ctx, NID_authority_key_identifier,
                 "keyid:always");
  }

  std::vector<std::string> sans;
  for (const std::string& dns : options.dns_sans) {
    sans.push_back(absl::StrCat("DNS:", dns));
  }
  for (const std::string& ip : options.ip_sans) {
    sans.push_back(absl::StrCat("IP:", ip));
  }
  if (!sans.empty()) {
    AddExtension(cert.get(), &ctx, NID_subject_alt_name,
                 absl::StrJoin(sans, ","));
  }

  EVP_PKEY* signing_key =
      issuer != nullptr ? issuer->key_.get() : result.key_.get();
  HARD_ASSERT(X509_sign(cert.get(), signing_key, EVP_sha256()) > 0,
              "X509_sign failed");

  UniqueBio cert_bio(BIO_new(BIO_s_mem()));
  HARD_ASSERT(PEM_write_bio_X509(cert_bio.get(), cert.get()) == 1,
              "PEM_write_bio_X509 failed");
  result.cert_pem_ = BioContents(cert_bio.get());

  UniqueBio key_bio(BIO_new(BIO_s_mem()));
  HARD_ASSERT(
      PEM_write_bio_PrivateKey(key_bio.get(), result.key_.get(), nullptr,
                               nullptr, 0, nullptr, nullptr) == 1,
      "PEM_write_bio_PrivateKey failed");
  result.key_pem_ = BioContents(key_bio.get());

  uint8_t* der = nullptr;
  int der_len = i2d_X509(cert.get(), &der);
  HARD_ASSERT(der_len > 0, "i2d_X509 failed");
  result.cert_der_.assign(reinterpret_cast<const char*>(der),
                          static_cast<size_t>(der_len));
  OPENSSL_free(der);

  uint8_t* spki = nullptr;
  int spki_len = i2d_X509_PUBKEY(X509_get_X509_PUBKEY(cert.get()), &spki);
  HARD_ASSERT(spki_len > 0, "i2d_X509_PUBKEY failed");
  result.spki_der_.assign(reinterpret_cast<const char*>(spki),
                          static_cast<size_t>(spki_len));
  OPENSSL_free(spki);

  result.x509_ = std::move(cert);
  return result;
}

std::string PemChain(const std::vector<const TestCertificate*>& certs) {
  std::string out;
  for (const TestCertificate* cert : certs) {
    out += cert->cert_pem();
  }
  return out;
}

std::string TestPki::ServerChainPem() const {
  return PemChain({&leaf, &intermediate});
}

std::string TestPki::ExpiredServerChainPem() const {
  return PemChain({&expired_leaf, &intermediate});
}

TestPki CreateTestPki(absl::string_view label,
                      const std::vector<std::string>& leaf_dns_sans,
                      const std::vector<std::string>& leaf_ip_sans) {
  TestPki pki;

  TestCertOptions root_opts;
  root_opts.common_name = absl::StrCat("Firestore Test Root CA ", label);
  root_opts.is_ca = true;
  pki.root = IssueTestCertificate(root_opts, /*issuer=*/nullptr);

  TestCertOptions cross_root_opts;
  cross_root_opts.common_name =
      absl::StrCat("Firestore Test Cross Root CA ", label);
  cross_root_opts.is_ca = true;
  pki.cross_root = IssueTestCertificate(cross_root_opts, /*issuer=*/nullptr);

  TestCertOptions inter_opts;
  inter_opts.common_name =
      absl::StrCat("Firestore Test Intermediate CA ", label);
  inter_opts.is_ca = true;
  pki.intermediate = IssueTestCertificate(inter_opts, &pki.root);
  pki.cross_intermediate =
      IssueTestCertificate(inter_opts, &pki.cross_root,
                           /*reuse_key_from=*/&pki.intermediate);

  TestCertOptions leaf_opts;
  leaf_opts.common_name = leaf_dns_sans.empty()
                              ? absl::StrCat("Firestore Test Leaf ", label)
                              : leaf_dns_sans.front();
  leaf_opts.dns_sans = leaf_dns_sans;
  leaf_opts.ip_sans = leaf_ip_sans;
  pki.leaf = IssueTestCertificate(leaf_opts, &pki.intermediate);

  TestCertOptions expired_opts = leaf_opts;
  expired_opts.not_before_offset = std::chrono::hours(-48);
  expired_opts.not_after_offset = std::chrono::hours(-24);
  pki.expired_leaf = IssueTestCertificate(expired_opts, &pki.intermediate);

  return pki;
}

}  // namespace tls_testing
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // !defined(__APPLE__)
