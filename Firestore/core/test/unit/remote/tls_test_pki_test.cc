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

#include <openssl/pem.h>
#include <openssl/x509.h>
#include <openssl/x509_vfy.h>
#include <openssl/x509v3.h>

#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/util/warnings.h"
#include "Firestore/core/test/unit/remote/tls_loopback_server.h"
#include "gtest/gtest.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/security/credentials.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {
namespace tls_testing {
namespace {

struct StoreDeleter {
  void operator()(X509_STORE* store) const {
    X509_STORE_free(store);
  }
};
struct StoreCtxDeleter {
  void operator()(X509_STORE_CTX* ctx) const {
    X509_STORE_CTX_free(ctx);
  }
};
struct StackDeleter {
  void operator()(STACK_OF(X509) * stack) const {
    sk_X509_free(stack);
  }
};

// Verifies `leaf` against `anchors` with `intermediates` as untrusted
// candidates. Returns the OpenSSL verify error (X509_V_OK on success).
int VerifyChain(const TestCertificate& leaf,
                const std::vector<const TestCertificate*>& intermediates,
                const std::vector<const TestCertificate*>& anchors) {
  std::unique_ptr<X509_STORE, StoreDeleter> store(X509_STORE_new());
  for (const TestCertificate* anchor : anchors) {
    EXPECT_EQ(X509_STORE_add_cert(store.get(), anchor->x509()), 1);
  }
  std::unique_ptr<STACK_OF(X509), StackDeleter> untrusted(sk_X509_new_null());
  for (const TestCertificate* inter : intermediates) {
    sk_X509_push(untrusted.get(), inter->x509());
  }
  std::unique_ptr<X509_STORE_CTX, StoreCtxDeleter> ctx(X509_STORE_CTX_new());
  EXPECT_EQ(
      X509_STORE_CTX_init(ctx.get(), store.get(), leaf.x509(), untrusted.get()),
      1);
  int ok = X509_verify_cert(ctx.get());
  int error = X509_STORE_CTX_get_error(ctx.get());
  return ok == 1 ? X509_V_OK : (error == X509_V_OK ? -1 : error);
}

TEST(TlsTestPkiTest, CertificatesHavePemDerKeyAndSpki) {
  TestPki pki = CreateTestPki("encodings", {"pki.firestore.test"});
  for (const TestCertificate* cert :
       {&pki.root, &pki.intermediate, &pki.cross_root, &pki.cross_intermediate,
        &pki.leaf, &pki.expired_leaf}) {
    ASSERT_TRUE(cert->valid());
    EXPECT_EQ(cert->cert_pem().rfind("-----BEGIN CERTIFICATE-----", 0), 0u);
    EXPECT_FALSE(cert->cert_der().empty());
    EXPECT_NE(cert->private_key_pem().find("PRIVATE KEY-----"),
              std::string::npos);
    EXPECT_FALSE(cert->spki_der().empty());
  }
  EXPECT_EQ(pki.leaf.common_name(), "pki.firestore.test");
}

TEST(TlsTestPkiTest, CrossSignedIntermediateSharesSubjectAndKey) {
  TestPki pki = CreateTestPki("cross", {"pki.firestore.test"});
  EXPECT_EQ(pki.cross_intermediate.spki_der(), pki.intermediate.spki_der());
  EXPECT_EQ(X509_NAME_cmp(X509_get_subject_name(pki.cross_intermediate.x509()),
                          X509_get_subject_name(pki.intermediate.x509())),
            0);
  EXPECT_NE(pki.cross_intermediate.cert_der(), pki.intermediate.cert_der());
  EXPECT_NE(X509_NAME_cmp(X509_get_issuer_name(pki.cross_intermediate.x509()),
                          X509_get_issuer_name(pki.intermediate.x509())),
            0);
}

TEST(TlsTestPkiTest, LeafValidatesThroughEitherPath) {
  TestPki pki = CreateTestPki("paths", {"pki.firestore.test"});
  EXPECT_EQ(VerifyChain(pki.leaf, {&pki.intermediate}, {&pki.root}), X509_V_OK);
  EXPECT_EQ(VerifyChain(pki.leaf, {&pki.cross_intermediate}, {&pki.cross_root}),
            X509_V_OK);
  EXPECT_NE(VerifyChain(pki.leaf, {&pki.intermediate}, {&pki.cross_root}),
            X509_V_OK);
}

TEST(TlsTestPkiTest, ExpiredLeafFailsValidation) {
  TestPki pki = CreateTestPki("expired", {"pki.firestore.test"});
  EXPECT_EQ(VerifyChain(pki.expired_leaf, {&pki.intermediate}, {&pki.root}),
            X509_V_ERR_CERT_HAS_EXPIRED);
}

TEST(TlsTestPkiTest, LeafHasRequestedSubjectAltNames) {
  TestPki pki =
      CreateTestPki("sans", {"pki.firestore.test"}, {"127.0.0.1", "::1"});
  // BoringSSL, unlike OpenSSL, does not treat a zero length as "use strlen".
  auto check_host = [&](const std::string& host) {
    return X509_check_host(pki.leaf.x509(), host.data(), host.size(), 0,
                           nullptr);
  };
  EXPECT_EQ(check_host("pki.firestore.test"), 1);
  EXPECT_NE(check_host("other.firestore.test"), 1);
  EXPECT_EQ(X509_check_ip_asc(pki.leaf.x509(), "127.0.0.1", 0), 1);
  EXPECT_EQ(X509_check_ip_asc(pki.leaf.x509(), "::1", 0), 1);
  EXPECT_NE(X509_check_ip_asc(pki.leaf.x509(), "10.0.0.1", 0), 1);
}

TEST(TlsTestPkiTest, PemChainConcatenatesInOrder) {
  TestPki pki = CreateTestPki("chain", {"pki.firestore.test"});
  EXPECT_EQ(pki.ServerChainPem(),
            pki.leaf.cert_pem() + pki.intermediate.cert_pem());
  EXPECT_EQ(PemChain({&pki.root, &pki.leaf}),
            pki.root.cert_pem() + pki.leaf.cert_pem());
}

TEST(TlsTestPkiTest, LoopbackServerEchoesOverTls) {
  TestPki pki = CreateTestPki("loopback", {"loopback.firestore.test"});
  TlsLoopbackServer server(pki.leaf.private_key_pem(), pki.ServerChainPem());
  ASSERT_TRUE(server.started());

  grpc::SslCredentialsOptions options;
  options.pem_root_certs = pki.root.cert_pem();
  std::shared_ptr<grpc::Channel> channel = CreateLoopbackChannel(
      server, grpc::SslCredentials(options), "loopback.firestore.test");

  std::string response;
  grpc::Status status = PerformUnaryEcho(channel, "ping", &response);
  ASSERT_TRUE(status.ok()) << status.error_message();
  EXPECT_EQ(response, "ping");
}

TEST(TlsTestPkiTest, LoopbackServerRejectsUntrustedClient) {
  TestPki pki =
      CreateTestPki("loopback-untrusted", {"loopback.firestore.test"});
  TestPki other = CreateTestPki("loopback-other", {"loopback.firestore.test"});
  TlsLoopbackServer server(pki.leaf.private_key_pem(), pki.ServerChainPem());
  ASSERT_TRUE(server.started());

  grpc::SslCredentialsOptions options;
  options.pem_root_certs = other.root.cert_pem();
  std::shared_ptr<grpc::Channel> channel = CreateLoopbackChannel(
      server, grpc::SslCredentials(options), "loopback.firestore.test");

  EXPECT_FALSE(PerformUnaryEcho(channel, "ping").ok());
}

}  // namespace
}  // namespace tls_testing
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // !defined(__APPLE__)
